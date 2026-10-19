import ArgumentParser
import Foundation
import TISKitTestSupport
import Testing

@testable import TISKit
@testable import TISUtilCommands

private let root = UserAccount(name: "root", uid: 0)
private let brendan = UserAccount(name: "brendan", uid: 501)

private func install(_ arguments: [String]) throws -> Install {
    try #require(try TISUtil.parseAsRoot(["install"] + arguments) as? Install)
}

private func context(console: UserAccount?) -> SessionContext {
    SessionContext(
        runningAs: root,
        console: console,
        loggedIn: console.map { [$0] } ?? [],
        account: { $0 == "brendan" ? brendan : nil }
    )
}

private let placed = InstallableItem(
    url: URL(fileURLWithPath: "/Library/Keyboard Layouts/sme.bundle"),
    kind: .keyboardLayoutBundle(bundleID: "no.uit.giella.keyboards.sme.keyboardlayout.sme")
)

// [spec:tis:req:install.place+1/test]
// [spec:tis:req:mutate.force-enable+1/test]
@Test(arguments: [false, true]) @MainActor
func installCopiesRegistersAndActivates(force: Bool) throws {
    let source = FileManager.default.temporaryDirectory.appending(
        path: "tisutil-\(UUID().uuidString).keylayout")
    try Data(#"<keyboard group="126" id="-1" name="Test Layout"></keyboard>"#.utf8).write(
        to: source)
    let library = FileManager.default.temporaryDirectory.appending(
        path: "tisutil-\(UUID().uuidString)")
    let destination = library.appending(path: "Keyboard Layouts/\(source.lastPathComponent)")
        .standardizedFileURL
    let layout = InputSource(
        id: "org.unknown.keylayout.TestLayout",
        type: .keyboardLayout,
        localizedName: "Test Layout",
        isEnableCapable: true,
        isEnabled: false
    )
    let sources = FixedInputSources(installed: [])
    sources.registrations[destination] = [layout]

    let arguments = ["--enable", source.path] + (force ? ["--force"] : [])
    let output = try install(arguments).install(into: library, provider: sources)

    #expect(sources.registeredURLs == [destination])
    #expect(output.stdout.contains("org.unknown.keylayout.TestLayout"))
    #expect(sources.installed.first?.isEnabled == true)
    #expect(
        sources.changeRequests == [
            .init(force ? .forceEnable : .enable, layout.id!)
        ])
}

// [spec:tis:req:mutate.force-enable+1/test]
@Test func systemInstallForwardsForceToRegistration() throws {
    let command = try install([
        "--system", "--enable", "--select", "--force", "--timeout", "3", "/tmp/sme.bundle",
    ])
    let arguments = command.registerArguments(for: placed)
    let register = try #require(try TISUtil.parseAsRoot(arguments) as? Register)

    #expect(register.activation.enable)
    #expect(register.activation.select)
    #expect(register.activation.enablement.force)
    #expect(register.waiting.timeout == 3)
}

// [spec:tis:req:install.place+1/test]
@Test func rootSystemInstallRegistersInTheConsoleUsersSession() throws {
    let command = try install(["--system", "--json", "--enable", "/tmp/sme.bundle"])

    #expect(
        try command.routeAfterSystemCopy(of: placed, in: context(console: brendan))
            == .reexec(as: brendan)
    )
    #expect(
        command.registerArguments(for: placed) == [
            "register", "/Library/Keyboard Layouts/sme.bundle", "--json", "--enable", "--timeout",
            "60.0",
        ]
    )
}

// [spec:tis:req:install.place+1/test]
@Test func rootSystemInstallWithNoUserDefersToLogin() throws {
    let route = try install(["--system", "--json", "/tmp/sme.bundle"])
        .routeAfterSystemCopy(of: placed, in: context(console: nil))
    guard case .deferredToLogin(let output) = route else {
        Issue.record("expected the install to be deferred to login, got \(route)")
        return
    }
    #expect(output.status == .success)
    #expect(output.stdout == "[]")
    #expect(output.diagnostic?.contains("next login") == true)

    #expect(throws: SessionError.noSession(nil)) {
        try install(["--system", "--enable", "/tmp/sme.bundle"])
            .routeAfterSystemCopy(of: placed, in: context(console: nil))
    }
}

// [spec:tis:req:install.place+1/test]
@Test func unwritableDestinationsExitWithNoPermission() {
    #expect(ExitStatus(for: InstallError.notPermitted(path: "/Library/x")) == .noPermission)
    #expect(ExitStatus(for: InstallError.copyFailed(path: "/x", reason: "disk full")) == .failure)
}
