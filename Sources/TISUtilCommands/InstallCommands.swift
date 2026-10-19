import ArgumentParser
import Foundation
import TISKit

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

    @Argument(help: "A .keylayout file, a keyboard layout bundle or an input method app.")
    var path: String

    @MainActor
    func execute(provider: some InputSourceProvider) throws -> CommandOutput {
        let item = try InstallableItem(url: URL(fileURLWithPath: path))
        return CommandOutput(stdout: try output.render(provider.register(item)))
    }
}
