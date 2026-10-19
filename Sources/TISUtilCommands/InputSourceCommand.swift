import ArgumentParser
import TISKit

/// A command that acts in a user's session, and so may need to run again as
/// that user when started as root.
protocol SessionCommand: ParsableCommand, Sendable {
    var session: SessionOptions { get }
    /// Runs the command in another process when it must act in another
    /// session, returning that process's exit status; `nil` means run here.
    func dispatch(in context: SessionContext) throws -> Int32?
}

extension SessionCommand {
    func dispatch(in context: SessionContext) throws -> Int32? {
        try reexecIfNeeded(user: session.user, in: context)
    }
}

protocol InputSourceCommand: SessionCommand {
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
