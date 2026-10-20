import ArgumentParser
import Foundation
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

// [spec:tis:req:dictation.status/test]
@Test func statusSaysWhetherDictationIsOn() throws {
    let human = try command(DictationStatusCommand.self, ["status"])
    #expect(
        try human.report(DictationStatus(source: dictation, autoEnable: false))
            == "Dictation:    enabled, not selected\nAuto-enable:  off"
    )
    #expect(
        try human.report(DictationStatus(source: nil, autoEnable: nil))
            == "Dictation:    not installed\nAuto-enable:  unknown"
    )
}

// [spec:tis:req:dictation.status/test]
@Test func statusJSONIsOneObject() throws {
    let json = try command(DictationStatusCommand.self, ["status", "--json"])
    let object = try #require(
        try JSONSerialization.jsonObject(
            with: Data(json.report(DictationStatus(source: nil, autoEnable: true)).utf8)
        ) as? [String: Any]
    )
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
