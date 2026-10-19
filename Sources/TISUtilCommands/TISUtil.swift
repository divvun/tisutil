import ArgumentParser
import Foundation
import TISKit

public struct TISUtil: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "tisutil",
        abstract: "Query and manage macOS text input sources: keyboard layouts and input methods.",
        discussion: ExitStatus.helpText,
        subcommands: [List.self, Current.self, Show.self]
    )

    public init() {}

    // [spec:tis:req:cli.exit-codes]
    public static func main() {
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch let error as TISError {
            printDiagnostic(error.description)
            Foundation.exit(ExitStatus(for: error).rawValue)
        } catch {
            exit(withError: error)
        }
    }
}
