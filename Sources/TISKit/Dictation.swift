import Carbon
import Foundation

// [spec:tis:def:dictation.source]
public enum Dictation {
    public static let sourceID = "com.apple.inputmethod.ironwood"

    /// Whether dictation auto-enable is on, from the private
    /// `TISGetDictationShouldAutoEnable`; `nil` when HIToolbox does not
    /// export it.
    // [spec:tis:req:dictation.status]
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

public struct DictationStatus: Equatable, Sendable {
    /// `nil` when the Dictation input source is not installed.
    public var source: InputSource?
    public var autoEnable: Bool?

    public init(source: InputSource?, autoEnable: Bool?) {
        self.source = source
        self.autoEnable = autoEnable
    }
}

extension InputSourceProvider {
    // [spec:tis:req:dictation.status]
    public func dictationStatus(autoEnable: Bool?) throws -> DictationStatus {
        let source: InputSource?
        do {
            source = try self.source(id: Dictation.sourceID)
        } catch TISError.notFound {
            source = nil
        }
        return DictationStatus(source: source, autoEnable: autoEnable)
    }
}
