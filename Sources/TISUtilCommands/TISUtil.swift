import ArgumentParser
import Foundation
import TISKit

public struct TISUtil: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "tisutil",
        abstract: "Query and manage macOS text input sources: keyboard layouts and input methods.",
        discussion: ExitStatus.helpText,
        subcommands: [
            List.self, Current.self, Show.self, Enable.self, Disable.self, Select.self,
            Deselect.self, Register.self, Install.self,
        ]
    )

    public init() {}

    // [spec:tis:req:cli.exit-codes]
    public static func main() {
        do {
            var command = try parseAsRoot()
            if let command = command as? any InputSourceCommand,
                let status = try command.dispatch(in: .system())
            {
                Foundation.exit(status)
            }
            try command.run()
        } catch let error as any DiagnosedError {
            printDiagnostic(error.description)
            Foundation.exit(error.exitStatus.rawValue)
        } catch {
            exit(withError: error)
        }
    }
}
