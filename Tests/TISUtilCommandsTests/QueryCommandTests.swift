import ArgumentParser
import Foundation
import TISKitTestSupport
import Testing

@testable import TISKit
@testable import TISUtilCommands

private let kotoeri = InputSource(
    id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
    category: .keyboard,
    type: .inputMode,
    languages: ["ja"],
    isEnabled: false,
    isSelected: false
)

private let sources = FixedInputSources(
    installed: [abc, sme, kotoeri],
    current: [
        .keyboard: abc, .keyboardLayout: abc, .asciiCapableKeyboard: abc,
        .asciiCapableKeyboardLayout: sme,
    ],
    languages: ["se": sme]
)

private func command<C: ParsableCommand>(_ type: C.Type, _ arguments: [String]) throws -> C {
    try #require(try TISUtil.parseAsRoot(arguments) as? C)
}

// [spec:tis:req:query.list/test]
@Test func listFlagsMapOntoTheFilter() throws {
    let list = try command(
        List.self,
        [
            "list", "--all", "--category", "keyboard", "--type", "input-mode", "--id", "x",
            "--bundle-id", "b", "--language", "se", "--no-enabled", "--selected",
        ]
    )
    #expect(
        list.filter
            == InputSourceFilter(
                category: .keyboard,
                type: .inputMode,
                id: "x",
                bundleID: "b",
                language: "se",
                isEnabled: false,
                isSelected: true,
                includeAllInstalled: true
            )
    )
    #expect(try command(List.self, ["list"]).filter == InputSourceFilter())
}

// [spec:tis:req:query.list/test]
@Test @MainActor func listShowsEnabledSourcesUnlessAll() throws {
    let enabled = try command(List.self, ["list"]).execute(provider: sources)
    #expect(enabled.status == .success)
    #expect(enabled.stdout.contains(abc.id!) && !enabled.stdout.contains(kotoeri.id!))

    let all = try command(List.self, ["list", "--all"]).execute(provider: sources)
    #expect(all.stdout.contains(kotoeri.id!))
}

// [spec:tis:req:query.list/test]
@Test @MainActor func listWithNoMatchesExitsNotFound() throws {
    let output = try command(List.self, ["list", "--json", "--language", "fi"])
        .execute(provider: sources)
    #expect(output.status == .notFound)
    #expect(try JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [Any] != nil)
    #expect(output.diagnostic != nil)
}

// [spec:tis:req:query.current/test]
@Test func currentFlagsSelectTheVariant() throws {
    #expect(try command(Current.self, ["current"]).which == .keyboard)
    #expect(try command(Current.self, ["current", "--layout"]).which == .keyboardLayout)
    #expect(try command(Current.self, ["current", "--ascii"]).which == .asciiCapableKeyboard)
    #expect(
        try command(Current.self, ["current", "--ascii", "--layout"]).which
            == .asciiCapableKeyboardLayout
    )
    #expect(throws: (any Error).self) {
        try TISUtil.parseAsRoot(["current", "--language", "se", "--layout"])
    }
}

// [spec:tis:req:query.current/test]
@Test @MainActor func currentPrintsTheRequestedSource() throws {
    let ascii = try command(Current.self, ["current", "--json", "--ascii", "--layout"])
        .execute(provider: sources)
    let object = try #require(
        try JSONSerialization.jsonObject(with: Data(ascii.stdout.utf8)) as? [String: Any]
    )
    #expect(object["id"] as? String == sme.id)

    let language = try command(Current.self, ["current", "--language", "se"])
        .execute(provider: sources)
    #expect(language.stdout.contains(sme.id!))

    #expect(throws: TISError.noSourceForLanguage("fi")) {
        try command(Current.self, ["current", "--language", "fi"]).execute(provider: sources)
    }
}

// [spec:tis:req:query.show/test]
@Test @MainActor func showPrintsLayoutDataSizeNotTheData() throws {
    let output = try command(Show.self, ["show", abc.id!]).execute(provider: sources)
    #expect(output.stdout.contains("present, 4096 bytes"))
    #expect(output.stdout.contains("Selected:"))

    let bare = try command(Show.self, ["show", sme.id!]).execute(provider: sources)
    #expect(bare.stdout.contains("absent"))
}

// [spec:tis:req:query.show/test]
@Test @MainActor func showPrintsEveryProperty() throws {
    let human = detail(abc).split(separator: "\n")
    #expect(human.count == InputSourceJSON.CodingKeys.allCases.count)

    let json = try command(Show.self, ["show", "--json", kotoeri.id!]).execute(provider: sources)
    let object = try #require(
        try JSONSerialization.jsonObject(with: Data(json.stdout.utf8)) as? [String: Any]
    )
    #expect(object.count == InputSourceJSON.CodingKeys.allCases.count)
    #expect(object["isEnabled"] as? Bool == false)
}

// [spec:tis:req:query.show/test]
@Test @MainActor func showReportsAnUnknownID() {
    #expect(throws: TISError.notFound(id: "no.such")) {
        try command(Show.self, ["show", "no.such"]).execute(provider: sources)
    }
}
