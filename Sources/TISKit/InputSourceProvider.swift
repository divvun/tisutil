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
    /// Makes the TIS call for `change` with no precondition or result checks;
    /// `apply(_:to:enablingFirst:)` adds those.
    func requestChange(_ change: InputSourceChange, id: String) throws
    func register(url: URL) throws
    var layoutIDAliases: LayoutIDAliases { get }
    /// Lets TIS deliver state changes, including the user's answer to a
    /// macOS prompt, while a change is being waited for.
    func pause(seconds: Double)
    /// The keyboard layout the current input method types with, if it has one.
    func layoutOverride() throws -> InputSource?
    func setLayoutOverride(id: String) throws
}

extension InputSourceProvider {
    /// Makes the keyboard layout with `id` the one the current input method
    /// types with, and returns that layout.
    // [spec:tis:req:mutate.layout-override]
    public func overrideLayout(with id: String) throws -> InputSource {
        let layout = try source(id: id)
        guard layout.type == .keyboardLayout else {
            throw TISError.notAKeyboardLayout(id: id)
        }
        try setLayoutOverride(id: layout.id ?? id)
        return layout
    }
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

    // [spec:tis:req:kit.lookup+2]
    public func source(id: String) throws -> InputSource {
        guard
            let match = firstMatch(
                try list(includeAllInstalled: true),
                id: id,
                aliases: layoutIDAliases,
                idOf: \.id
            )
        else {
            throw TISError.notFound(id: id)
        }
        return match
    }
}

// [spec:tis:req:kit.lookup+2]
func firstMatch<T>(
    _ items: [T],
    id: String,
    aliases: LayoutIDAliases,
    idOf: (T) -> String?
) -> T? {
    items.first { idOf($0) == id }
        ?? items.first { idOf($0).map { aliases.areSameLayout($0, id) } ?? false }
}
