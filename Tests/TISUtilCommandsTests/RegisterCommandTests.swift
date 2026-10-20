import ArgumentParser
import Foundation
import TISKitTestSupport
import Testing

@testable import TISKit
@testable import TISUtilCommands

// [spec:tis:req:install.register/test]
@Test @MainActor func registerCommandPrintsTheRegisteredIDs() throws {
    let file = FileManager.default.temporaryDirectory.appending(
        path: "tisutil-\(UUID().uuidString).keylayout")
    try Data(#"<keyboard group="126" id="-1" name="Test Layout"></keyboard>"#.utf8).write(to: file)
    let source = InputSource(
        id: "org.unknown.keylayout.TestLayout", type: .keyboardLayout, localizedName: "Test Layout")
    let sources = FixedInputSources(installed: [])
    sources.registrations[file.standardizedFileURL] = [source]

    let command = try #require(try TISUtil.parseAsRoot(["register", file.path]) as? Register)
    let output = try command.execute(provider: sources)

    #expect(output.status == .success)
    #expect(output.stdout.contains("org.unknown.keylayout.TestLayout"))
}

// [spec:tis:req:install.kind-detect/test]
@Test func unrecognisedItemsAreUsageErrors() {
    #expect(ExitStatus(for: InstallError.unrecognisedItem(path: "/x")) == .usage)
    #expect(ExitStatus(for: InstallError.nothingRegistered(path: "/x")) == .failure)
}

// [spec:tis:req:mutate.force-enable+2/test]
@Test(arguments: ["--enable", "--select"]) @MainActor
func registerCanForceItsActivation(_ activation: String) throws {
    let file = FileManager.default.temporaryDirectory.appending(
        path: "tisutil-\(UUID().uuidString).keylayout")
    defer { try? FileManager.default.removeItem(at: file) }
    try Data(#"<keyboard group="126" id="-1" name="Test Layout"></keyboard>"#.utf8).write(to: file)
    let source = InputSource(
        id: "org.unknown.keylayout.TestLayout", type: .keyboardLayout, localizedName: "Test Layout",
        isEnableCapable: true, isSelectCapable: true, isEnabled: false, isSelected: false)
    let sources = FixedInputSources(installed: [])
    sources.registrations[file.standardizedFileURL] = [source]
    let command = try #require(
        try TISUtil.parseAsRoot(["register", activation, "--force", file.path]) as? Register)

    _ = try command.execute(provider: sources)

    let expected: [InputSourceChange] =
        activation == "--select" ? [.forceEnable, .select] : [.forceEnable]
    #expect(sources.changeRequests.map(\.change) == expected)
}
