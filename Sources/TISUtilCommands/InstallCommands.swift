import ArgumentParser
import Foundation
import TISKit

struct ActivationOptions: ParsableArguments {
    @Flag(help: "Enable every input source the item provides.")
    var enable = false

    @Flag(help: "Select the item's first input source, enabling it if needed.")
    var select = false

    var arguments: [String] {
        (enable ? ["--enable"] : []) + (select ? ["--select"] : [])
    }
}

// [spec:tis:req:install.register]
struct Register: InputSourceCommand {
    static let configuration = CommandConfiguration(
        abstract: "Register a keyboard layout or input method with TIS and list its sources.",
        discussion: """
            The item must already be in a Keyboard Layouts or Input Methods directory; \
            use install to copy it there first.
            """
    )

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions
    @OptionGroup var activation: ActivationOptions
    @OptionGroup var waiting: WaitOptions

    @Argument(help: "A .keylayout file, a keyboard layout bundle or an input method app.")
    var path: String

    @MainActor
    func execute(provider: some InputSourceProvider) throws -> CommandOutput {
        let item = try InstallableItem(url: URL(fileURLWithPath: path))
        let sources = try provider.activate(
            provider.register(item),
            enable: activation.enable,
            select: activation.select,
            timeout: waiting.timeout
        )
        return CommandOutput(stdout: try output.render(sources))
    }
}

// [spec:tis:req:install.place+1]
// [spec:tis:req:install.enable]
struct Install: InputSourceCommand {
    static let configuration = CommandConfiguration(
        abstract: "Copy a keyboard layout or input method into place and register it.",
        discussion: """
            Layouts go to Keyboard Layouts and input methods to Input Methods, under \
            ~/Library, or /Library with --system. An existing item with the same name is \
            replaced.
            """
    )

    static let systemLibrary = URL(fileURLWithPath: "/Library")

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions
    @OptionGroup var activation: ActivationOptions
    @OptionGroup var waiting: WaitOptions

    @Flag(help: "Install for every user under /Library rather than under ~/Library.")
    var system = false

    @Argument(help: "A .keylayout file, a keyboard layout bundle or an input method app.")
    var path: String

    var library: URL {
        if system {
            return Self.systemLibrary
        }
        let home =
            FileManager.default.homeDirectory(forUser: UserAccount.effective.name)
            ?? FileManager.default.homeDirectoryForCurrentUser
        return home.appending(path: "Library")
    }

    @MainActor
    func execute(provider: some InputSourceProvider) throws -> CommandOutput {
        try install(into: library, provider: provider)
    }

    @MainActor
    func install(into library: URL, provider: some InputSourceProvider) throws -> CommandOutput {
        let placed = try InstallableItem(url: URL(fileURLWithPath: path)).place(inLibrary: library)
        let sources = try provider.activate(
            provider.register(placed),
            enable: activation.enable,
            select: activation.select,
            timeout: waiting.timeout
        )
        return CommandOutput(stdout: try output.render(sources))
    }

    /// A root `install --system` copies here, as root, and registers in the
    /// target user's session through a re-executed `register`, because that
    /// user cannot write to /Library.
    // [spec:tis:req:install.place+1]
    func dispatch(in context: SessionContext) throws -> Int32? {
        guard system, context.runningAs.uid == 0 else {
            return try reexecIfNeeded(user: session.user, in: context)
        }
        let placed = try InstallableItem(url: URL(fileURLWithPath: path))
            .place(inLibrary: Self.systemLibrary)
        switch try routeAfterSystemCopy(of: placed, in: context) {
        case .here:
            return nil
        case .reexec(let user):
            return try reexec(as: user, arguments: registerArguments(for: placed))
        case .deferredToLogin(let output):
            try output.emit()
            return 0
        }
    }

    enum SystemInstallRoute: Equatable {
        case here
        case reexec(as: UserAccount)
        case deferredToLogin(CommandOutput)
    }

    // [spec:tis:req:install.place+1]
    func routeAfterSystemCopy(of placed: InstallableItem, in context: SessionContext) throws
        -> SystemInstallRoute
    {
        do {
            return switch try route(user: session.user, in: context) {
            case .here: .here
            case .reexec(let user): .reexec(as: user)
            }
        } catch SessionError.noSession(.none) where !activation.enable && !activation.select {
            return .deferredToLogin(
                CommandOutput(
                    stdout: output.json ? "[]" : "",
                    diagnostic:
                        "no user is logged in; \(placed.url.path) becomes available at the next login"
                )
            )
        }
    }

    func registerArguments(for placed: InstallableItem) -> [String] {
        ["register", placed.url.path] + (output.json ? ["--json"] : []) + activation.arguments
            + ["--timeout", String(waiting.timeout)]
    }
}
