import Foundation
import TISKit

// [spec:tis:req:cli.json-shape]
struct InputSourceJSON: Encodable {
    var source: InputSource

    init(_ source: InputSource) {
        self.source = source
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, category, type, bundleID, inputModeID, localizedName, languages
        case iconImageURL, unicodeKeyLayoutDataSize
        case isASCIICapable, isEnableCapable, isSelectCapable, isEnabled, isSelected
    }

    /// Encodes every key, with `null` for absent values; synthesized
    /// `Encodable` would leave absent keys out.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source.id, forKey: .id)
        try container.encode(source.category?.name, forKey: .category)
        try container.encode(source.type?.name, forKey: .type)
        try container.encode(source.bundleID, forKey: .bundleID)
        try container.encode(source.inputModeID, forKey: .inputModeID)
        try container.encode(source.localizedName, forKey: .localizedName)
        try container.encode(source.languages, forKey: .languages)
        try container.encode(source.iconImageURL?.absoluteString, forKey: .iconImageURL)
        try container.encode(source.unicodeKeyLayoutDataSize, forKey: .unicodeKeyLayoutDataSize)
        try container.encode(source.isASCIICapable, forKey: .isASCIICapable)
        try container.encode(source.isEnableCapable, forKey: .isEnableCapable)
        try container.encode(source.isSelectCapable, forKey: .isSelectCapable)
        try container.encode(source.isEnabled, forKey: .isEnabled)
        try container.encode(source.isSelected, forKey: .isSelected)
    }
}

// [spec:tis:req:cli.json-shape]
func jsonDocument(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
}
