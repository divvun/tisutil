import ArgumentParser
import TISKit

/// Installers branch on these values, so they are fixed across releases.
// [spec:tis:req:cli.exit-codes]
public enum ExitStatus: Int32, CaseIterable, Sendable {
    case success = 0
    case failure = 1
    case notFound = 2
    case usage = 64
    case noPermission = 77

    var meaning: String {
        switch self {
        case .success: "success"
        case .failure: "a TIS call or file-system operation failed"
        case .notFound: "no input source matches the requested ID or filter"
        case .usage: "usage error"
        case .noPermission:
            "the operation needs a privilege or user session that tisutil does not have"
        }
    }

    static var helpText: String {
        let lines = allCases.map { "  \(String($0.rawValue).padding(4))\($0.meaning)" }
        return (["EXIT STATUS:"] + lines).joined(separator: "\n")
    }

    // [spec:tis:req:cli.exit-codes]
    init(for error: any Error) {
        if let error = error as? any DiagnosedError {
            self = error.exitStatus
        } else {
            self = ExitStatus(rawValue: TISUtil.exitCode(for: error).rawValue) ?? .failure
        }
    }
}

/// Errors tisutil reports as a one-line diagnostic and a specific exit status.
protocol DiagnosedError: Error, CustomStringConvertible {
    var exitStatus: ExitStatus { get }
}

// [spec:tis:req:cli.exit-codes]
extension TISError: DiagnosedError {
    var exitStatus: ExitStatus {
        switch self {
        case .notFound, .noSourceForLanguage: .notFound
        case .notAKeyboardLayout: .usage
        default: .failure
        }
    }
}

// [spec:tis:req:cli.exit-codes]
extension InstallError: DiagnosedError {
    var exitStatus: ExitStatus {
        switch self {
        case .unrecognisedItem: .usage
        case .notPermitted: .noPermission
        case .nothingRegistered, .copyFailed: .failure
        }
    }
}

extension String {
    func padding(_ width: Int) -> String {
        padding(toLength: max(width, count), withPad: " ", startingAt: 0)
    }
}
