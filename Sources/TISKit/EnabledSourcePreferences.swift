import Foundation

/// One entry of the system or third-party enabled-source preferences that
/// macOS reads at login.
public struct EnabledSourceEntry: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case keyboardLayout = "Keyboard Layout"
        case inputMode = "Input Mode"
        case keyboardInputMethod = "Keyboard Input Method"
        case nonKeyboardInputMethod = "Non Keyboard Input Method"
    }

    static let kindKey = "InputSourceKind"
    static let bundleIDKey = "Bundle ID"
    static let inputModeKey = "Input Mode"
    static let layoutIDKey = "KeyboardLayout ID"
    static let layoutNameKey = "KeyboardLayout Name"

    public var kind: Kind
    public var bundleID: String?
    public var inputMode: String?
    public var layoutID: Int?
    public var layoutName: String?

    public init(
        kind: Kind,
        bundleID: String? = nil,
        inputMode: String? = nil,
        layoutID: Int? = nil,
        layoutName: String? = nil
    ) {
        self.kind = kind
        self.bundleID = bundleID
        self.inputMode = inputMode
        self.layoutID = layoutID
        self.layoutName = layoutName
    }

    /// `nil` when the source lacks a field its kind of entry needs.
    // [spec:tis:req:session.prefs-fallback+2]
    public init?(_ source: InputSource, layoutName: String?, layoutNumber: Int?) {
        switch source.type {
        case .keyboardLayout?:
            guard let layoutName, let layoutNumber else { return nil }
            self.init(kind: .keyboardLayout, layoutID: layoutNumber, layoutName: layoutName)
        case .inputMode?:
            guard let bundleID = source.bundleID, let mode = source.inputModeID else { return nil }
            self.init(kind: .inputMode, bundleID: bundleID, inputMode: mode)
        case .inputMethod?, .inputMethodWithModes?:
            guard let bundleID = source.bundleID else { return nil }
            self.init(kind: .keyboardInputMethod, bundleID: bundleID)
        case .characterPalette?, .keyboardViewer?, .ink?:
            guard let bundleID = source.bundleID else { return nil }
            self.init(kind: .nonKeyboardInputMethod, bundleID: bundleID)
        case .unknown?, nil:
            return nil
        }
    }

    public init?(dictionary: [String: Any]) {
        guard let kind = (dictionary[Self.kindKey] as? String).flatMap(Kind.init) else {
            return nil
        }
        self.init(
            kind: kind,
            bundleID: dictionary[Self.bundleIDKey] as? String,
            inputMode: dictionary[Self.inputModeKey] as? String,
            layoutID: dictionary[Self.layoutIDKey] as? Int,
            layoutName: dictionary[Self.layoutNameKey] as? String
        )
    }

    public var dictionary: [String: Any] {
        var dictionary: [String: Any] = [Self.kindKey: kind.rawValue]
        dictionary[Self.bundleIDKey] = bundleID
        dictionary[Self.inputModeKey] = inputMode
        dictionary[Self.layoutIDKey] = layoutID
        dictionary[Self.layoutNameKey] = layoutName
        return dictionary
    }

    /// `entries` with this entry added (`enable`) or removed. An entry that is
    /// already there is left in place, so the list keeps its order.
    // [spec:tis:req:session.prefs-fallback+2]
    public func applied(to entries: [[String: Any]], enable: Bool) -> [[String: Any]] {
        let isThis = { (entry: [String: Any]) in EnabledSourceEntry(dictionary: entry) == self }
        if enable {
            return entries.contains(where: isThis) ? entries : entries + [dictionary]
        }
        return entries.filter { !isThis($0) }
    }
}

/// A source as the enabled-sources preferences see it.
public struct PreferenceSource: Equatable, Sendable {
    public var source: InputSource
    public var entry: EnabledSourceEntry?
    /// True for input sources that come with macOS.
    public var isFromSystem: Bool

    public init(source: InputSource, entry: EnabledSourceEntry?, isFromSystem: Bool) {
        self.source = source
        self.entry = entry
        self.isFromSystem = isFromSystem
    }
}

public protocol EnabledSourcesStore {
    func entries(for user: String) -> [[String: Any]]
    func setEntries(_ entries: [[String: Any]], for user: String) throws
}

/// Reads and writes another user's preferences through cfprefsd, which needs
/// root. Editing the plist file directly would be overwritten from cfprefsd's
/// cache.
// [spec:tis:req:session.prefs-fallback+2]
public struct UserPreferencesStore: EnabledSourcesStore {
    public var domain: String
    public var key: String

    public init(domain: String = "com.apple.HIToolbox", key: String = "AppleEnabledInputSources") {
        self.domain = domain
        self.key = key
    }

    public static var thirdParty: Self {
        Self(domain: "com.apple.inputsources", key: "AppleEnabledThirdPartyInputSources")
    }

    public func entries(for user: String) -> [[String: Any]] {
        CFPreferencesCopyValue(
            key as CFString,
            domain as CFString,
            user as CFString,
            kCFPreferencesAnyHost
        ) as? [[String: Any]] ?? []
    }

    public func setEntries(_ entries: [[String: Any]], for user: String) throws {
        CFPreferencesSetValue(
            key as CFString,
            entries as CFArray,
            domain as CFString,
            user as CFString,
            kCFPreferencesAnyHost
        )
        guard CFPreferencesSynchronize(domain as CFString, user as CFString, kCFPreferencesAnyHost)
        else {
            throw TISError.noResult(function: "CFPreferencesSynchronize")
        }
    }
}
