public enum InputSourceChange: String, Sendable, CaseIterable {
    case enable
    case forceEnable
    case disable
    case select
    case deselect

    public static let defaultTimeout = 60.0
    static let pollInterval = 0.25

    public var resultingState: String {
        switch self {
        case .enable, .forceEnable: "enabled"
        case .disable: "disabled"
        case .select: "selected"
        case .deselect: "deselected"
        }
    }

    func isSatisfied(by source: InputSource) -> Bool {
        switch self {
        case .enable, .forceEnable: source.isEnabled == true
        case .disable: source.isEnabled == false
        case .select: source.isSelected == true
        case .deselect: source.isSelected == false
        }
    }
}

extension InputSourceProvider {
    /// Applies `change` to the source with `id`, waits up to `timeout` seconds
    /// for it to take effect, and returns the source as TIS reports it then.
    // [spec:tis:req:mutate.enable-disable+1]
    // [spec:tis:req:mutate.select]
    // [spec:tis:req:mutate.verify+2]
    // [spec:tis:req:mutate.force-enable+2]
    public func apply(
        _ change: InputSourceChange,
        to id: String,
        enablingFirst: Bool = false,
        forceEnable: Bool = false,
        timeout: Double = InputSourceChange.defaultTimeout
    ) throws -> InputSource {
        let change: InputSourceChange = change == .enable && forceEnable ? .forceEnable : change
        let before = try source(id: id)
        if change == .select || change == .deselect, before.isSelectCapable != true {
            throw TISError.notSelectCapable(id: id)
        }
        if change.isSatisfied(by: before) {
            return before
        }
        if change == .select, before.isEnabled != true {
            guard enablingFirst else { throw TISError.notEnabled(id: id) }
            _ = try apply(.enable, to: id, forceEnable: forceEnable, timeout: timeout)
        }
        try requestChange(change, id: id)
        var waited = 0.0
        while true {
            let after = try source(id: before.id ?? id)
            if change.isSatisfied(by: after) {
                return after
            }
            guard waited < timeout else {
                throw TISError.notApplied(change, id: id)
            }
            pause(seconds: InputSourceChange.pollInterval)
            waited += InputSourceChange.pollInterval
        }
    }
}
