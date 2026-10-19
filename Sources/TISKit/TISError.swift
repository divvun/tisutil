import Carbon

// [spec:tis:req:kit.errors]
public enum TISError: Error, Equatable, Sendable {
    case status(OSStatus, function: String)
    /// A TIS function that returns an input source or a list returned NULL.
    case noResult(function: String)
    case notFound(id: String)
    case noSourceForLanguage(String)
}

extension TISError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .status(let status, let function):
            "\(function) failed with OSStatus \(status)"
        case .noResult(let function):
            "\(function) returned no result"
        case .notFound(let id):
            "no input source has the ID \(id)"
        case .noSourceForLanguage(let language):
            "no input source is available for the language \(language)"
        }
    }
}

// [spec:tis:req:kit.errors]
func check(_ status: OSStatus, _ function: String) throws {
    guard status == noErr else {
        throw TISError.status(status, function: function)
    }
}
