import Foundation

public enum CurrentInputSource: Hashable, Sendable, CaseIterable {
    case keyboard
    case keyboardLayout
    case asciiCapableKeyboard
    case asciiCapableKeyboardLayout
}

// [spec:tis:req:kit.main-thread]
@MainActor
public protocol InputSourceProvider {
    /// With `includeAllInstalled` false, only enabled sources are returned.
    func list(includeAllInstalled: Bool) throws -> [InputSource]
    func current(_ which: CurrentInputSource) throws -> InputSource
    func source(forLanguage language: String) throws -> InputSource
}

// [spec:tis:req:kit.list]
public struct InputSourceFilter: Hashable, Sendable {
    public var category: InputSourceCategory?
    public var type: InputSourceType?
    public var id: String?
    public var bundleID: String?
    /// A BCP 47 tag; `se` matches sources that list `se` or `se-NO`.
    public var language: String?
    public var isEnabled: Bool?
    public var isSelected: Bool?
    public var includeAllInstalled: Bool

    public init(
        category: InputSourceCategory? = nil,
        type: InputSourceType? = nil,
        id: String? = nil,
        bundleID: String? = nil,
        language: String? = nil,
        isEnabled: Bool? = nil,
        isSelected: Bool? = nil,
        includeAllInstalled: Bool = false
    ) {
        self.category = category
        self.type = type
        self.id = id
        self.bundleID = bundleID
        self.language = language
        self.isEnabled = isEnabled
        self.isSelected = isSelected
        self.includeAllInstalled = includeAllInstalled
    }

    public func matches(_ source: InputSource) -> Bool {
        (category == nil || source.category == category)
            && (type == nil || source.type == type)
            && (id == nil || source.id == id)
            && (bundleID == nil || source.bundleID == bundleID)
            && (isEnabled == nil || source.isEnabled == isEnabled)
            && (isSelected == nil || source.isSelected == isSelected)
            && (language.map { source.supports(language: $0) } ?? true)
    }
}

extension InputSource {
    func supports(language tag: String) -> Bool {
        let tag = bcp47(tag)
        return languages?.contains {
            let candidate = bcp47($0)
            return candidate == tag || candidate.hasPrefix(tag + "-")
        } ?? false
    }
}

/// TIS reports some languages in ICU form (`hi_Latn`), not BCP 47 (`hi-Latn`).
private func bcp47(_ tag: String) -> String {
    tag.lowercased().replacingOccurrences(of: "_", with: "-")
}

extension InputSourceProvider {
    // [spec:tis:req:kit.list]
    public func list(matching filter: InputSourceFilter) throws -> [InputSource] {
        try list(includeAllInstalled: filter.includeAllInstalled).filter(filter.matches)
    }

    // [spec:tis:req:kit.lookup]
    public func source(id: String) throws -> InputSource {
        guard let match = try list(includeAllInstalled: true).first(where: { $0.id == id }) else {
            throw TISError.notFound(id: id)
        }
        return match
    }
}
