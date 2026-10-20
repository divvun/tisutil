import Carbon
import Darwin

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

    // [spec:tis:req:mutate.enable-disable+1]
    // [spec:tis:req:mutate.select]
    // [spec:tis:req:mutate.force-enable+2]
    public func requestChange(_ change: InputSourceChange, id: String) throws {
        let source = try reference(id: id)
        switch change {
        case .enable: try check(TISEnableInputSource(source), "TISEnableInputSource")
        case .forceEnable: try enableWithoutPrompt(source)
        case .disable: try check(TISDisableInputSource(source), "TISDisableInputSource")
        case .select: try check(TISSelectInputSource(source), "TISSelectInputSource")
        case .deselect: try check(TISDeselectInputSource(source), "TISDeselectInputSource")
        }
    }

    // [spec:tis:req:mutate.layout-override]
    public func layoutOverride() -> InputSource? {
        guard let layout = TISCopyInputMethodKeyboardLayoutOverride()?.takeRetainedValue() else {
            return nil
        }
        return InputSource(layout)
    }

    // [spec:tis:req:mutate.layout-override]
    public func setLayoutOverride(id: String) throws {
        try check(
            TISSetInputMethodKeyboardLayoutOverride(try reference(id: id)),
            "TISSetInputMethodKeyboardLayoutOverride"
        )
    }

    /// Reads private TIS properties: the layout name and number that
    /// `AppleEnabledInputSources` records, and whether the source comes with
    /// macOS. Without them a source is treated as third-party.
    // [spec:tis:req:session.prefs-fallback+2]
    public func preferenceSource(id: String) throws -> PreferenceSource {
        let reference = try reference(id: id)
        let source = InputSource(reference)
        func privateProperty(_ name: String) -> AnyObject? {
            privateTISKey(name).flatMap { property(of: reference, $0) }
        }
        return PreferenceSource(
            source: source,
            entry: EnabledSourceEntry(
                source,
                layoutName: privateProperty("kTISPropertyKeyLayoutName") as? String,
                layoutNumber: privateProperty("kTISPropertyKeyLayoutNumber") as? Int
            ),
            isFromSystem: privateProperty("kTISPropertyInputSourceIsFromSystem") as? Bool ?? false
        )
    }

    // [spec:tis:req:install.register]
    public func register(url: URL) throws {
        try check(TISRegisterInputSource(url as CFURL), "TISRegisterInputSource")
    }

    // [spec:tis:req:kit.lookup+2]
    public var layoutIDAliases: LayoutIDAliases { .installed }

    /// Runs the main run loop, not a plain sleep, so that the distributed
    /// notifications TIS refreshes its state from are delivered.
    // [spec:tis:req:mutate.verify+2]
    public func pause(seconds: Double) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// Filtering `TISCreateInputSourceList` by `kTISPropertyInputSourceID`
    /// misses bundled layouts that TIS currently reports under their other ID,
    /// so this matches against the full list instead.
    private func reference(id: String) throws -> TISInputSource {
        guard let list = TISCreateInputSourceList(nil, true)?.takeRetainedValue(),
            let source = firstMatch(
                list as! [TISInputSource],
                id: id,
                aliases: layoutIDAliases,
                idOf: { property(of: $0, kTISPropertyInputSourceID) as? String }
            )
        else {
            throw TISError.notFound(id: id)
        }
        return source
    }
}

/// A `CFStringRef` constant that HIToolbox exports but does not declare.
func privateTISKey(_ name: String) -> CFString? {
    guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }
    return Unmanaged<CFString>.fromOpaque(symbol.load(as: UnsafeRawPointer.self))
        .takeUnretainedValue()
}

// [spec:tis:req:mutate.force-enable+2]
@MainActor
func enableWithoutPrompt(
    _ source: TISInputSource,
    symbol: UnsafeMutableRawPointer? = dlsym(
        UnsafeMutableRawPointer(bitPattern: -2), "TISEnableInputSourceWithOptions")
) throws {
    let name = "TISEnableInputSourceWithOptions"
    guard let symbol else { throw TISError.unavailable(function: name) }
    typealias Enable = @convention(c) (TISInputSource, UInt32) -> OSStatus
    let enable = unsafeBitCast(symbol, to: Enable.self)
    // HIToolbox tests bit 1 to skip the approval sheet and enable directly.
    try check(enable(source, 2), name)
}
