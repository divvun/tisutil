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
            Deselect.self,
        ]
    )

    public init() {}

    // [spec:tis:req:cli.exit-codes]
    public static func main() {
        do {
            var command = try parseAsRoot()
            if let command = command as? any InputSourceCommand,
                case .reexec(let user) = try route(user: command.session.user, in: .system())
            {
                Foundation.exit(
                    try reexec(as: user, arguments: Array(CommandLine.arguments.dropFirst())))
            }
            try command.run()
        } catch let error where error is TISError || error is SessionError {
            printDiagnostic("\(error)")
            Foundation.exit(ExitStatus(for: error).rawValue)
        } catch {
            exit(withError: error)
        }
    }
}
