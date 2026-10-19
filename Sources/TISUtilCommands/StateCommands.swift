import ArgumentParser
import TISKit

// [spec:tis:req:mutate.force-enable+1]
struct EnablementOptions: ParsableArguments {
    @Flag(help: "Skip the macOS approval sheet when enabling an input source.")
    var force = false
}

struct WaitOptions: ParsableArguments {
    @Option(
        help: """
            Seconds to wait for a change to take effect, including time for the user to \
            answer a macOS prompt.
            """
    )
    var timeout = InputSourceChange.defaultTimeout

    func validate() throws {
        guard timeout >= 0 else { throw ValidationError("--timeout cannot be negative.") }
    }
}

protocol StateCommand: InputSourceCommand {
    static var change: InputSourceChange { get }
    var output: OutputOptions { get }
    var waiting: WaitOptions { get }
    var id: String { get }
    var enablingFirst: Bool { get }
    var force: Bool { get }
}

extension StateCommand {
    var enablingFirst: Bool { false }
    var force: Bool { false }

    // [spec:tis:req:mutate.verify+2]
    // [spec:tis:req:mutate.force-enable+1]
    @MainActor
    func execute(provider: some InputSourceProvider) throws -> CommandOutput {
        let source = try provider.apply(
            Self.change,
            to: id,
            enablingFirst: enablingFirst,
            forceEnable: force,
            timeout: waiting.timeout
        )
        return CommandOutput(stdout: try output.render(source))
    }
}

private let idHelp = ArgumentHelp("The input source ID, for example com.apple.keylayout.ABC.")

// [spec:tis:req:mutate.enable-disable+1]
// [spec:tis:req:mutate.force-enable+1]
struct Enable: StateCommand {
    static let configuration = CommandConfiguration(
        abstract: "Enable an input source. Succeeds without change if it is already enabled."
    )
    static let change = InputSourceChange.enable

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions
    @OptionGroup var waiting: WaitOptions
    @OptionGroup var enablement: EnablementOptions

    var force: Bool { enablement.force }

    @Argument(help: idHelp)
    var id: String
}

// [spec:tis:req:mutate.enable-disable+1]
struct Disable: StateCommand {
    static let configuration = CommandConfiguration(
        abstract: "Disable an input source. Succeeds without change if it is already disabled."
    )
    static let change = InputSourceChange.disable

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions
    @OptionGroup var waiting: WaitOptions

    @Argument(help: idHelp)
    var id: String
}

// [spec:tis:req:mutate.select]
struct Select: StateCommand {
    static let configuration = CommandConfiguration(
        abstract: "Select an input source, making it the current one."
    )
    static let change = InputSourceChange.select

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions
    @OptionGroup var waiting: WaitOptions
    @OptionGroup var enablement: EnablementOptions

    var force: Bool { enablement.force }

    @Flag(name: .customLong("enable"), help: "Enable the source first if it is not enabled.")
    var enablingFirst = false

    @Argument(help: idHelp)
    var id: String

    // [spec:tis:req:mutate.force-enable+1]
    func validate() throws {
        if force && !enablingFirst {
            throw ValidationError("--force requires --enable.")
        }
    }
}

// [spec:tis:req:mutate.select]
struct Deselect: StateCommand {
    static let configuration = CommandConfiguration(
        abstract: "Deselect an input source. Only palette-like sources can be deselected."
    )
    static let change = InputSourceChange.deselect

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions
    @OptionGroup var waiting: WaitOptions

    @Argument(help: idHelp)
    var id: String
}

// [spec:tis:req:mutate.layout-override]
struct Override: InputSourceCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print or set the keyboard layout the current input method types with."
    )

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions

    @Argument(help: "A keyboard layout ID to set. Without it, the current override is printed.")
    var id: String?

    @MainActor
    func execute(provider: some InputSourceProvider) throws -> CommandOutput {
        if let id {
            return CommandOutput(stdout: try output.render(provider.overrideLayout(with: id)))
        }
        guard let layout = try provider.layoutOverride() else {
            return CommandOutput(
                stdout: output.json ? "null" : "",
                status: .notFound,
                diagnostic: "the current input method has no keyboard layout override"
            )
        }
        return CommandOutput(stdout: try output.render(layout))
    }
}
