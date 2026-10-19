import Carbon
import Foundation
import Testing

@testable import TISKit

private func snapshot(_ properties: [CFString: Any]) -> InputSource {
    let byKey = Dictionary(uniqueKeysWithValues: properties.map { ($0.key as String, $0.value) })
    return InputSource { key in byKey[key as String] as AnyObject? }
}

// [spec:tis:req:kit.property-snapshot/test]
@Test func snapshotReadsEveryProperty() {
    let source = snapshot([
        kTISPropertyInputSourceID: "no.divvun.keylayout.sme",
        kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as String,
        kTISPropertyInputSourceType: kTISTypeKeyboardLayout as String,
        kTISPropertyBundleID: "no.divvun.keyboard.sme",
        kTISPropertyInputModeID: "no.divvun.mode",
        kTISPropertyLocalizedName: "Northern Sámi",
        kTISPropertyInputSourceLanguages: ["se", "nb"],
        kTISPropertyIconImageURL: URL(fileURLWithPath: "/tmp/sme.icns"),
        kTISPropertyUnicodeKeyLayoutData: Data(count: 1234),
        kTISPropertyInputSourceIsASCIICapable: true,
        kTISPropertyInputSourceIsEnableCapable: true,
        kTISPropertyInputSourceIsSelectCapable: false,
        kTISPropertyInputSourceIsEnabled: true,
        kTISPropertyInputSourceIsSelected: false,
    ])

    #expect(
        source
            == InputSource(
                id: "no.divvun.keylayout.sme",
                category: .keyboard,
                type: .keyboardLayout,
                bundleID: "no.divvun.keyboard.sme",
                inputModeID: "no.divvun.mode",
                localizedName: "Northern Sámi",
                languages: ["se", "nb"],
                iconImageURL: URL(fileURLWithPath: "/tmp/sme.icns"),
                unicodeKeyLayoutDataSize: 1234,
                isASCIICapable: true,
                isEnableCapable: true,
                isSelectCapable: false,
                isEnabled: true,
                isSelected: false
            )
    )
}

// [spec:tis:req:kit.property-snapshot/test]
@Test func absentPropertiesAreNil() {
    let source = snapshot([kTISPropertyInputSourceID: "com.example.bare"])

    #expect(source == InputSource(id: "com.example.bare"))
    #expect(source.languages == nil)
    #expect(source.isEnabled == nil)
    #expect(source.unicodeKeyLayoutDataSize == nil)
}

// [spec:tis:req:kit.property-snapshot/test]
@Test func snapshotOfLiveSourceHasIdentity() throws {
    let ref = try #require(TISCopyCurrentKeyboardInputSource()?.takeRetainedValue())
    let source = InputSource(ref)

    #expect(source.id != nil)
    #expect(source.category == .keyboard)
    #expect(source.isSelected == true)
}
