import ArgumentParser
import TISKit

protocol InputSourceCommand: ParsableCommand, Sendable {
    @MainActor func execute(provider: some InputSourceProvider) throws -> CommandOutput
}

extension InputSourceCommand {
    /// ArgumentParser calls `run()` on the main thread, which is where TIS
    /// must be called; `assumeIsolated` traps if that ever stops being true.
    func run() throws {
        try MainActor.assumeIsolated {
            try execute(provider: SystemInputSources()).emit()
        }
    }
}
