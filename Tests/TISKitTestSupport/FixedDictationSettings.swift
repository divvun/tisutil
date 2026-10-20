import TISKit

public final class FixedDictationSettings: DictationSettings {
    /// `nil` makes reading whether dictation is on fail as unavailable.
    public var enabled: Bool?
    public var autoEnableValue: Bool?
    public var language: String?
    /// When false, setters record the request but change nothing.
    public var appliesChanges = true
    /// How many pauses pass before a dictation change takes effect.
    public var pausesBeforeApplying = 0
    public private(set) var pauses = 0
    public private(set) var requests: [String] = []
    private var pendingEnabled: Bool?

    nonisolated public init(enabled: Bool?, autoEnable: Bool?, language: String? = nil) {
        self.enabled = enabled
        self.autoEnableValue = autoEnable
        self.language = language
    }

    public func isEnabled() throws -> Bool {
        guard let enabled else { throw DictationError.unavailable("AFPreferences") }
        return enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        requests.append(enabled ? "enable" : "disable")
        guard appliesChanges else { return }
        if pauses < pausesBeforeApplying {
            pendingEnabled = enabled
        } else {
            self.enabled = enabled
        }
    }

    public func pause(seconds: Double) {
        pauses += 1
        if pauses >= pausesBeforeApplying, let pendingEnabled {
            enabled = pendingEnabled
            self.pendingEnabled = nil
        }
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
