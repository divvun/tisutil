import Carbon

// [spec:tis:req:kit.errors]
public enum TISError: Error, Equatable, Sendable {
    case status(OSStatus, function: String)
    /// A TIS function that returns an input source or a list returned NULL.
    case noResult(function: String)
    case unavailable(function: String)
    case notFound(id: String)
    case noSourceForLanguage(String)
    case notSelectCapable(id: String)
    case notEnabled(id: String)
    case notAKeyboardLayout(id: String)
    /// TIS returned `noErr`, but reading the source back shows the change was not made.
    case notApplied(InputSourceChange, id: String)
}

extension TISError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .status(let status, let function):
            "\(function) failed with OSStatus \(status)"
        case .noResult(let function):
            "\(function) returned no result"
        case .unavailable(let function):
            "\(function) is unavailable on this version of macOS"
        case .notFound(let id):
            "no input source has the ID \(id)"
        case .noSourceForLanguage(let language):
            "no input source is available for the language \(language)"
        case .notSelectCapable(let id):
            "\(id) cannot be selected or deselected"
        case .notEnabled(let id):
            "\(id) is not enabled"
        case .notAKeyboardLayout(let id):
            "\(id) is not a keyboard layout"
        case .notApplied(.enable, let id):
            "\(id) is still not enabled; if macOS asked to allow it, the request was denied or not answered"
        case .notApplied(let change, let id):
            "TIS reported success, but \(id) is still not \(change.resultingState)"
        }
    }
}

// [spec:tis:req:kit.errors]
func check(_ status: OSStatus, _ function: String) throws {
    guard status == noErr else {
        throw TISError.status(status, function: function)
    }
}
