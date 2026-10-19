import ArgumentParser
import Foundation
import TISKit

struct SessionOptions: ParsableArguments {
    @Option(
        help: """
            Act on this logged-in user's input sources. Needs root unless it is you. \
            As root, the default is the console user.
            """
    )
    var user: String?
}

enum SessionError: Error, Equatable, CustomStringConvertible {
    case unknownUser(String)
    /// `nil` means no user is logged in at the console.
    case noSession(String?)
    case notPermitted(String)

    var description: String {
        switch self {
        case .unknownUser(let name): "there is no user named \(name)"
        case .noSession(nil): "no user is logged in at the console"
        case .noSession(let name?): "\(name) has no login session"
        case .notPermitted(let name): "acting on \(name)'s input sources needs root"
        }
    }

    var exitStatus: ExitStatus {
        switch self {
        case .unknownUser: .usage
        case .noSession, .notPermitted: .noPermission
        }
    }
}

enum SessionRoute: Equatable {
    case here
    case reexec(as: UserAccount)
}

struct SessionContext {
    var runningAs: UserAccount
    var console: UserAccount?
    var loggedIn: [UserAccount]
    var account: (String) -> UserAccount?

    static func system() -> SessionContext {
        SessionContext(
            runningAs: .effective,
            console: UserSessions.consoleUser(),
            loggedIn: UserSessions.loggedInUsers(),
            account: UserAccount.named
        )
    }
}

// [spec:tis:req:session.reexec]
// [spec:tis:req:session.privilege]
func route(user requested: String?, in context: SessionContext) throws -> SessionRoute {
    let isRoot = context.runningAs.uid == 0
    guard let requested else {
        guard isRoot else { return .here }
        guard let console = context.console else { throw SessionError.noSession(nil) }
        return console.uid == context.runningAs.uid ? .here : .reexec(as: console)
    }
    guard let target = context.account(requested) else {
        throw SessionError.unknownUser(requested)
    }
    if target.uid == context.runningAs.uid {
        return .here
    }
    guard isRoot else { throw SessionError.notPermitted(requested) }
    guard context.loggedIn.contains(where: { $0.uid == target.uid }) else {
        throw SessionError.noSession(requested)
    }
    return .reexec(as: target)
}

/// `launchctl asuser` puts the child in the user's bootstrap namespace, where
/// the TIS server for their session lives; `sudo -u` drops root so that TIS
/// and CFPreferences act for that user.
// [spec:tis:req:session.reexec]
func reexecArguments(as user: UserAccount, executable: String, arguments: [String]) -> [String] {
    ["asuser", String(user.uid), "/usr/bin/sudo", "-u", user.name, "--", executable] + arguments
}

// [spec:tis:req:session.reexec]
func reexec(as user: UserAccount, arguments: [String]) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = reexecArguments(
        as: user,
        executable: Bundle.main.executablePath ?? CommandLine.arguments[0],
        arguments: arguments
    )
    try process.run()
    process.waitUntilExit()
    return process.terminationReason == .exit
        ? process.terminationStatus : 128 + process.terminationStatus
}
