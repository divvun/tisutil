import Carbon
import Foundation
import ObjectiveC

// [spec:tis:def:dictation.source]
public enum Dictation {
    public static let sourceID = "com.apple.inputmethod.ironwood"

    /// Whether dictation auto-enable is on, from the private
    /// `TISGetDictationShouldAutoEnable`; `nil` when HIToolbox does not
    /// export it.
    // [spec:tis:req:dictation.status+1]
    @MainActor
    public static func autoEnable(
        symbol: UnsafeMutableRawPointer? = dlsym(
            UnsafeMutableRawPointer(bitPattern: -2), "TISGetDictationShouldAutoEnable")
    ) -> Bool? {
        guard let symbol else { return nil }
        typealias Get = @convention(c) () -> Bool
        return unsafeBitCast(symbol, to: Get.self)()
    }

    // [spec:tis:req:dictation.languages]
    public static func languages(fromOfflineStatus status: [String: Any]) -> [DictationLanguage] {
        status.compactMap { locale, value -> DictationLanguage? in
            guard let entry = value as? [String: Any] else { return nil }
            var flags: [String: Bool] = [:]
            for (name, flag) in entry where name != "Installed" {
                if let flag = flag as? Bool {
                    flags[name] = flag
                }
            }
            return DictationLanguage(
                locale: locale,
                isInstalled: entry["Installed"] as? Bool ?? false,
                flags: flags
            )
        }
        .sorted { $0.locale < $1.locale }
    }

    /// The dictation locales of the user running this process.
    // [spec:tis:req:dictation.languages]
    public static func languages() -> [DictationLanguage] {
        let status = CFPreferencesCopyAppValue(
            "Offline Dictation Status" as CFString,
            "com.apple.assistant.support" as CFString
        )
        return languages(fromOfflineStatus: status as? [String: Any] ?? [:])
    }
}

public struct DictationLanguage: Equatable, Sendable {
    public var locale: String
    /// Whether the on-device model for this locale is installed.
    public var isInstalled: Bool
    public var flags: [String: Bool]

    public init(locale: String, isInstalled: Bool, flags: [String: Bool]) {
        self.locale = locale
        self.isInstalled = isInstalled
        self.flags = flags
    }
}

public enum DictationError: Error, Equatable, Sendable {
    case unavailable(String)
    case notApplied(String, expected: Bool)
}

extension DictationError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unavailable(let name):
            "\(name) is unavailable on this version of macOS"
        case .notApplied(let setting, let expected):
            "\(setting) is still \(expected ? "off" : "on")"
        }
    }
}

/// Dictation's settings as macOS keeps them.
@MainActor
public protocol DictationSettings {
    func isEnabled() throws -> Bool
    func autoEnable() throws -> Bool
    func setAutoEnable(_ on: Bool) throws
    var language: String? { get }
}

extension DictationSettings {
    // [spec:tis:req:dictation.auto-enable]
    public func changeAutoEnable(to on: Bool) throws {
        try setAutoEnable(on)
        guard try autoEnable() == on else {
            throw DictationError.notApplied("auto-enable", expected: on)
        }
    }
}

/// The current user's dictation settings. Whether dictation is on comes from
/// the private `AFPreferences` class in AssistantServices, because
/// `assistantd` owns that preference.
// [spec:tis:req:dictation.status+1]
// [spec:tis:req:dictation.auto-enable]
public struct SystemDictationSettings: DictationSettings {
    nonisolated public init() {}

    private func assistantPreferences(responding selector: String) throws -> NSObject {
        let path = "/System/Library/PrivateFrameworks/AssistantServices.framework/AssistantServices"
        guard dlopen(path, RTLD_NOW) != nil,
            let preferencesClass = objc_getClass("AFPreferences") as? NSObject.Type,
            let shared = preferencesClass.perform(NSSelectorFromString("sharedPreferences"))?
                .takeUnretainedValue() as? NSObject
        else {
            throw DictationError.unavailable("AFPreferences")
        }
        guard shared.responds(to: NSSelectorFromString(selector)) else {
            throw DictationError.unavailable("AFPreferences \(selector)")
        }
        return shared
    }

    public func isEnabled() throws -> Bool {
        let selector = NSSelectorFromString("dictationIsEnabled")
        let preferences = try assistantPreferences(responding: "dictationIsEnabled")
        typealias Getter = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(preferences.method(for: selector), to: Getter.self)(
            preferences, selector)
    }

    public func autoEnable() throws -> Bool {
        guard let value = Dictation.autoEnable() else {
            throw DictationError.unavailable("TISGetDictationShouldAutoEnable")
        }
        return value
    }

    public func setAutoEnable(_ on: Bool) throws {
        let name = "TISSetDictationShouldAutoEnable"
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else {
            throw DictationError.unavailable(name)
        }
        typealias Set = @convention(c) (Bool) -> Void
        unsafeBitCast(symbol, to: Set.self)(on)
    }

    // [spec:tis:req:dictation.status+1]
    public var language: String? {
        CFPreferencesCopyAppValue(
            "DictationIMLocaleIdentifier" as CFString,
            "com.apple.speech.recognition.AppleSpeechRecognition.prefs" as CFString
        ) as? String
    }
}

public struct DictationStatus: Equatable, Sendable {
    /// Whether dictation is on, as `assistantd` reports it.
    public var isEnabled: Bool?
    public var language: String?
    /// `nil` when the Dictation input source is not installed.
    public var source: InputSource?
    public var autoEnable: Bool?

    public init(
        isEnabled: Bool? = nil,
        language: String? = nil,
        source: InputSource?,
        autoEnable: Bool?
    ) {
        self.isEnabled = isEnabled
        self.language = language
        self.source = source
        self.autoEnable = autoEnable
    }
}

extension InputSourceProvider {
    /// Anything that cannot be read is `nil`.
    // [spec:tis:req:dictation.status+1]
    public func dictationStatus(settings: some DictationSettings) throws -> DictationStatus {
        let source: InputSource?
        do {
            source = try self.source(id: Dictation.sourceID)
        } catch TISError.notFound {
            source = nil
        }
        return DictationStatus(
            isEnabled: try? settings.isEnabled(),
            language: settings.language,
            source: source,
            autoEnable: try? settings.autoEnable()
        )
    }
}
