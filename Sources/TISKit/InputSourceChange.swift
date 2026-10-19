public enum InputSourceChange: String, Sendable, CaseIterable {
    case enable
    case disable
    case select
    case deselect

    public var resultingState: String {
        switch self {
        case .enable: "enabled"
        case .disable: "disabled"
        case .select: "selected"
        case .deselect: "deselected"
        }
    }

    func isSatisfied(by source: InputSource) -> Bool {
        switch self {
        case .enable: source.isEnabled == true
        case .disable: source.isEnabled == false
        case .select: source.isSelected == true
        case .deselect: source.isSelected == false
        }
    }
}

extension InputSourceProvider {
    /// Applies `change` to the source with `id` and returns the source as TIS
    /// reports it afterwards.
    // [spec:tis:req:mutate.enable-disable]
    // [spec:tis:req:mutate.select]
    // [spec:tis:req:mutate.verify]
    public func apply(
        _ change: InputSourceChange,
        to id: String,
        enablingFirst: Bool = false
    ) throws -> InputSource {
        let before = try source(id: id)
        if change == .select || change == .deselect, before.isSelectCapable != true {
            throw TISError.notSelectCapable(id: id)
        }
        if change.isSatisfied(by: before) {
            return before
        }
        if change == .select, before.isEnabled != true {
            guard enablingFirst else { throw TISError.notEnabled(id: id) }
            _ = try apply(.enable, to: id)
        }
        try requestChange(change, id: id)
        let after = try source(id: before.id ?? id)
        guard change.isSatisfied(by: after) else {
            throw TISError.notApplied(change, id: id)
        }
        return after
    }
}
