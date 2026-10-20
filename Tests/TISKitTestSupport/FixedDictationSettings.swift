import TISKit

public final class FixedDictationSettings: DictationSettings {
    /// `nil` makes reading whether dictation is on fail as unavailable.
    public var enabled: Bool?
    public var autoEnableValue: Bool?
    public var language: String?
    /// When false, `setAutoEnable` records the request but changes nothing.
    public var appliesChanges = true
    public private(set) var requests: [String] = []

    nonisolated public init(enabled: Bool?, autoEnable: Bool?, language: String? = nil) {
        self.enabled = enabled
        self.autoEnableValue = autoEnable
        self.language = language
    }

    public func isEnabled() throws -> Bool {
        guard let enabled else { throw DictationError.unavailable("AFPreferences") }
        return enabled
    }

    public func autoEnable() throws -> Bool {
        guard let autoEnableValue else {
            throw DictationError.unavailable("TISGetDictationShouldAutoEnable")
        }
        return autoEnableValue
    }

    public func setAutoEnable(_ on: Bool) throws {
        guard autoEnableValue != nil else {
            throw DictationError.unavailable("TISSetDictationShouldAutoEnable")
        }
        requests.append(on ? "auto-enable on" : "auto-enable off")
        if appliesChanges {
            autoEnableValue = on
        }
    }
}
