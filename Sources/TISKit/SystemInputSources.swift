import Carbon

/// The input sources of the user session this process runs in.
public struct SystemInputSources: InputSourceProvider {
    nonisolated public init() {}

    // [spec:tis:req:kit.list]
    public func list(includeAllInstalled: Bool) throws -> [InputSource] {
        guard let list = TISCreateInputSourceList(nil, includeAllInstalled)?.takeRetainedValue()
        else {
            throw TISError.noResult(function: "TISCreateInputSourceList")
        }
        return (list as! [TISInputSource]).map(InputSource.init)
    }

    // [spec:tis:req:kit.current]
    public func current(_ which: CurrentInputSource) throws -> InputSource {
        let (function, copied): (String, Unmanaged<TISInputSource>?) =
            switch which {
            case .keyboard:
                ("TISCopyCurrentKeyboardInputSource", TISCopyCurrentKeyboardInputSource())
            case .keyboardLayout:
                (
                    "TISCopyCurrentKeyboardLayoutInputSource",
                    TISCopyCurrentKeyboardLayoutInputSource()
                )
            case .asciiCapableKeyboard:
                (
                    "TISCopyCurrentASCIICapableKeyboardInputSource",
                    TISCopyCurrentASCIICapableKeyboardInputSource()
                )
            case .asciiCapableKeyboardLayout:
                (
                    "TISCopyCurrentASCIICapableKeyboardLayoutInputSource",
                    TISCopyCurrentASCIICapableKeyboardLayoutInputSource()
                )
            }
        guard let source = copied?.takeRetainedValue() else {
            throw TISError.noResult(function: function)
        }
        return InputSource(source)
    }

    // [spec:tis:req:kit.current]
    public func source(forLanguage language: String) throws -> InputSource {
        guard let source = TISCopyInputSourceForLanguage(language as CFString)?.takeRetainedValue()
        else {
            throw TISError.noSourceForLanguage(language)
        }
        return InputSource(source)
    }
}
