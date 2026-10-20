import Foundation
import TISKitTestSupport
import Testing

@testable import TISKit

// [spec:tis:req:dictation.languages/test]
@Test func offlineStatusBecomesSortedLanguages() {
    let status: [String: Any] = [
        "en-US": ["Installed": true, "High Quality": true, "Voice Commands": false],
        "de-DE": ["Installed": false, "High Quality": true],
        "broken": "not a dictionary",
    ]

    #expect(
        Dictation.languages(fromOfflineStatus: status) == [
            DictationLanguage(locale: "de-DE", isInstalled: false, flags: ["High Quality": true]),
            DictationLanguage(
                locale: "en-US",
                isInstalled: true,
                flags: ["High Quality": true, "Voice Commands": false]
            ),
        ]
    )
}

// [spec:tis:req:dictation.status/test]
@Test @MainActor func statusReportsTheDictationSourceIfInstalled() throws {
    let dictation = InputSource(
        id: Dictation.sourceID,
        category: .palette,
        type: .characterPalette,
        isEnabled: false,
        isSelected: false
    )

    let installed = FixedInputSources(installed: [dictation])
    #expect(
        try installed.dictationStatus(autoEnable: true)
            == DictationStatus(source: dictation, autoEnable: true)
    )

    let missing = FixedInputSources(installed: [])
    #expect(
        try missing.dictationStatus(autoEnable: nil)
            == DictationStatus(source: nil, autoEnable: nil)
    )
}

// [spec:tis:req:dictation.status/test]
@Test @MainActor func autoEnableIsUnknownWithoutTheFunction() {
    #expect(Dictation.autoEnable(symbol: nil) == nil)
    #expect(Dictation.autoEnable() != nil)
}

// [spec:tis:def:dictation.source/test]
@Test @MainActor func dictationIsAPaletteInputSource() throws {
    let status = try SystemInputSources().dictationStatus(autoEnable: nil)
    if let source = status.source {
        #expect(source.category == .palette)
        #expect(source.id == Dictation.sourceID)
    }
}
