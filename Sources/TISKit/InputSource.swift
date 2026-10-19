import Carbon
import Foundation

// [spec:tis:def:kit.input-source]
public struct InputSource: Hashable, Sendable {
    public var id: String?
    public var category: InputSourceCategory?
    public var type: InputSourceType?
    public var bundleID: String?
    public var inputModeID: String?
    public var localizedName: String?
    public var languages: [String]?
    public var iconImageURL: URL?
    /// Size in bytes of the `uchr` keyboard layout data; `nil` when the source has none.
    public var unicodeKeyLayoutDataSize: Int?
    public var isASCIICapable: Bool?
    public var isEnableCapable: Bool?
    public var isSelectCapable: Bool?
    public var isEnabled: Bool?
    public var isSelected: Bool?

    public init(
        id: String? = nil,
        category: InputSourceCategory? = nil,
        type: InputSourceType? = nil,
        bundleID: String? = nil,
        inputModeID: String? = nil,
        localizedName: String? = nil,
        languages: [String]? = nil,
        iconImageURL: URL? = nil,
        unicodeKeyLayoutDataSize: Int? = nil,
        isASCIICapable: Bool? = nil,
        isEnableCapable: Bool? = nil,
        isSelectCapable: Bool? = nil,
        isEnabled: Bool? = nil,
        isSelected: Bool? = nil
    ) {
        self.id = id
        self.category = category
        self.type = type
        self.bundleID = bundleID
        self.inputModeID = inputModeID
        self.localizedName = localizedName
        self.languages = languages
        self.iconImageURL = iconImageURL
        self.unicodeKeyLayoutDataSize = unicodeKeyLayoutDataSize
        self.isASCIICapable = isASCIICapable
        self.isEnableCapable = isEnableCapable
        self.isSelectCapable = isSelectCapable
        self.isEnabled = isEnabled
        self.isSelected = isSelected
    }
}

extension InputSource {
    // [spec:tis:req:kit.property-snapshot]
    init(reading property: (CFString) -> AnyObject?) {
        self.init(
            id: property(kTISPropertyInputSourceID) as? String,
            category: (property(kTISPropertyInputSourceCategory) as? String).map(
                InputSourceCategory.init),
            type: (property(kTISPropertyInputSourceType) as? String).map(InputSourceType.init),
            bundleID: property(kTISPropertyBundleID) as? String,
            inputModeID: property(kTISPropertyInputModeID) as? String,
            localizedName: property(kTISPropertyLocalizedName) as? String,
            languages: property(kTISPropertyInputSourceLanguages) as? [String],
            iconImageURL: property(kTISPropertyIconImageURL) as? URL,
            unicodeKeyLayoutDataSize: (property(kTISPropertyUnicodeKeyLayoutData) as? Data)?.count,
            isASCIICapable: property(kTISPropertyInputSourceIsASCIICapable) as? Bool,
            isEnableCapable: property(kTISPropertyInputSourceIsEnableCapable) as? Bool,
            isSelectCapable: property(kTISPropertyInputSourceIsSelectCapable) as? Bool,
            isEnabled: property(kTISPropertyInputSourceIsEnabled) as? Bool,
            isSelected: property(kTISPropertyInputSourceIsSelected) as? Bool
        )
    }

    // [spec:tis:req:kit.property-snapshot]
    // [spec:tis:req:kit.main-thread]
    @MainActor
    init(_ source: TISInputSource) {
        self.init { key in
            guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
            return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue()
        }
    }
}
