import ArgumentParser
import Foundation
import TISKitTestSupport
import Testing

@testable import TISKit
@testable import TISUtilCommands

private let dictation = InputSource(
    id: "com.apple.inputmethod.ironwood",
    category: .palette,
    type: .characterPalette,
    localizedName: "Dictation",
    isEnabled: true,
    isSelected: false
)

private func command<C: ParsableCommand>(_ type: C.Type, _ arguments: [String]) throws -> C {
    try #require(try TISUtil.parseAsRoot(["dictation"] + arguments) as? C)
}

// [spec:tis:req:dictation.status+1/test]
@Test func statusSaysWhetherDictationIsOn() throws {
    #expect(
        try dictationReport(
            DictationStatus(
                isEnabled: true, language: "en_AU", source: dictation, autoEnable: false),
            json: false
        ) == """
            Dictation:     on
            Language:      en_AU
            Input source:  enabled, not selected
            Auto-enable:   off
            """
    )
    #expect(
        try dictationReport(DictationStatus(source: nil, autoEnable: nil), json: false) == """
            Dictation:     unknown
            Language:      unknown
            Input source:  not installed
            Auto-enable:   unknown
            """
    )
}

// [spec:tis:req:dictation.status+1/test]
@Test func statusJSONIsOneObject() throws {
    let json = try dictationReport(
        DictationStatus(isEnabled: false, language: nil, source: nil, autoEnable: true),
        json: true
    )
    let object = try #require(
        try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    )
    #expect(object["enabled"] as? Bool == false)
    #expect(object["language"] is NSNull)
    #expect(object["installed"] as? Bool == false)
    #expect(object["source"] is NSNull)
    #expect(object["autoEnable"] as? Bool == true)
}

// [spec:tis:req:dictation.languages/test]
@Test func languagesListEveryLocale() throws {
    let languages = [
        DictationLanguage(locale: "en-AU", isInstalled: true, flags: ["High Quality": true]),
        DictationLanguage(locale: "se-NO", isInstalled: false, flags: ["High Quality": false]),
    ]

    let human = try command(DictationLanguagesCommand.self, ["languages"]).report(languages)
    let lines = human.split(separator: "\n")
    #expect(lines.count == 3)
    #expect(
        lines[1].contains("en-AU") && lines[1].contains("yes") && lines[1].contains("High Quality"))
    #expect(lines[2].contains("se-NO") && lines[2].contains("no") && !lines[2].contains("High"))

    let json = try command(DictationLanguagesCommand.self, ["languages", "--json"]).report(
        languages)
    let array = try #require(
        try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
    #expect(array.map { $0["locale"] as? String } == ["en-AU", "se-NO"])
    #expect(array[0]["installed"] as? Bool == true)
}

// [spec:tis:req:dictation.enable/test]
@Test @MainActor func enableAndDisableCommandsChangeDictation() throws {
    let settings = FixedDictationSettings(enabled: false, autoEnable: false, language: "en_AU")
    let sources = FixedInputSources(installed: [dictation])

    let enabled = try command(DictationEnableCommand.self, ["enable"])
        .execute(provider: sources, settings: settings)
    #expect(enabled.stdout.contains("Dictation:     on"))
    #expect(enabled.stdout.contains("Auto-enable:   on"))

    let disabled = try command(DictationDisableCommand.self, ["disable", "--timeout", "1"])
        .execute(provider: sources, settings: settings)
    #expect(disabled.stdout.contains("Dictation:     off"))
    #expect(ExitStatus(for: DictationError.notApplied("dictation", expected: true)) == .failure)
}

// [spec:tis:req:dictation.auto-enable/test]
@Test @MainActor func autoEnablePrintsOrSetsTheSetting() throws {
    let settings = FixedDictationSettings(enabled: false, autoEnable: true)
    let sources = FixedInputSources(installed: [])

    #expect(
        try command(DictationAutoEnableCommand.self, ["auto-enable"])
            .execute(provider: sources, settings: settings).stdout == "on"
    )
    let off = try command(DictationAutoEnableCommand.self, ["auto-enable", "off", "--json"])
        .execute(provider: sources, settings: settings)
    #expect(
        try JSONSerialization.jsonObject(with: Data(off.stdout.utf8)) as? [String: Bool] == [
            "autoEnable": false
        ])
    #expect(throws: (any Error).self) {
        try TISUtil.parseAsRoot(["dictation", "auto-enable", "maybe"])
    }
}
