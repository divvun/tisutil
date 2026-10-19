import ArgumentParser
import TISKit

protocol InputSourceCommand: ParsableCommand, Sendable {
    var session: SessionOptions { get }
    @MainActor func execute(provider: some InputSourceProvider) throws -> CommandOutput
    /// Runs the command in another process when it must act in another
    /// session, returning that process's exit status; `nil` means run here.
    func dispatch(in context: SessionContext) throws -> Int32?
}

extension InputSourceCommand {
    func dispatch(in context: SessionContext) throws -> Int32? {
        try reexecIfNeeded(user: session.user, in: context)
    }

    /// ArgumentParser calls `run()` on the main thread, which is where TIS
    /// must be called; `assumeIsolated` traps if that ever stops being true.
    func run() throws {
        try MainActor.assumeIsolated {
            try execute(provider: SystemInputSources()).emit()
        }
    }
}
