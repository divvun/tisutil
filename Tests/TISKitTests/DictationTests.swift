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

private let dictationSource = InputSource(
    id: Dictation.sourceID,
    category: .palette,
    type: .characterPalette,
    isEnabled: false,
    isSelected: false
)

// [spec:tis:req:dictation.status+1/test]
@Test @MainActor func statusReportsDictationAndItsInputSource() throws {
    let settings = FixedDictationSettings(enabled: true, autoEnable: true, language: "en_AU")

    #expect(
        try FixedInputSources(installed: [dictationSource]).dictationStatus(settings: settings)
            == DictationStatus(
                isEnabled: true,
                language: "en_AU",
                source: dictationSource,
                autoEnable: true
            )
    )
}

// [spec:tis:req:dictation.status+1/test]
@Test @MainActor func statusReportsWhatCannotBeReadAsUnknown() throws {
    let unavailable = FixedDictationSettings(enabled: nil, autoEnable: nil)

    #expect(
        try FixedInputSources(installed: []).dictationStatus(settings: unavailable)
            == DictationStatus(source: nil, autoEnable: nil)
    )
    #expect(Dictation.autoEnable(symbol: nil) == nil)
}

// [spec:tis:req:dictation.status+1/test]
@Test @MainActor func systemDictationSettingsAreReadable() throws {
    let settings = SystemDictationSettings()
    _ = try settings.isEnabled()
    _ = try settings.autoEnable()
}

// [spec:tis:def:dictation.source/test]
@Test @MainActor func dictationIsAPaletteInputSource() throws {
    let status = try SystemInputSources().dictationStatus(
        settings: FixedDictationSettings(enabled: nil, autoEnable: nil))
    if let source = status.source {
        #expect(source.category == .palette)
        #expect(source.id == Dictation.sourceID)
    }
}

// [spec:tis:req:dictation.auto-enable/test]
@Test @MainActor func autoEnableIsSetAndCheckedOnce() throws {
    let settings = FixedDictationSettings(enabled: false, autoEnable: true)
    try settings.changeAutoEnable(to: false)
    #expect(try !settings.autoEnable())

    let stuck = FixedDictationSettings(enabled: false, autoEnable: true)
    stuck.appliesChanges = false
    #expect(throws: DictationError.notApplied("auto-enable", expected: false)) {
        try stuck.changeAutoEnable(to: false)
    }
    #expect(throws: DictationError.unavailable("TISSetDictationShouldAutoEnable")) {
        try FixedDictationSettings(enabled: false, autoEnable: nil).changeAutoEnable(to: true)
    }
}
