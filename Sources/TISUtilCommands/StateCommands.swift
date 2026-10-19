import ArgumentParser
import TISKit

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
}

extension StateCommand {
    var enablingFirst: Bool { false }

    // [spec:tis:req:mutate.verify+1]
    @MainActor
    func execute(provider: some InputSourceProvider) throws -> CommandOutput {
        let source = try provider.apply(
            Self.change,
            to: id,
            enablingFirst: enablingFirst,
            timeout: waiting.timeout
        )
        return CommandOutput(stdout: try output.render(source))
    }
}

private let idHelp = ArgumentHelp("The input source ID, for example com.apple.keylayout.ABC.")

// [spec:tis:req:mutate.enable-disable]
struct Enable: StateCommand {
    static let configuration = CommandConfiguration(
        abstract: "Enable an input source. Succeeds without change if it is already enabled."
    )
    static let change = InputSourceChange.enable

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions
    @OptionGroup var waiting: WaitOptions

    @Argument(help: idHelp)
    var id: String
}

// [spec:tis:req:mutate.enable-disable]
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

    @Flag(name: .customLong("enable"), help: "Enable the source first if it is not enabled.")
    var enablingFirst = false

    @Argument(help: idHelp)
    var id: String
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
