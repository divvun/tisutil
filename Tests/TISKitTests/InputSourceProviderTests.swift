import TISKitTestSupport
import Testing

@testable import TISKit

private let abc = InputSource(
    id: "com.apple.keylayout.ABC",
    category: .keyboard,
    type: .keyboardLayout,
    bundleID: "com.apple.keylayout.ABC",
    languages: ["en"],
    isEnabled: true,
    isSelected: true
)
private let sme = InputSource(
    id: "no.divvun.keylayout.sme",
    category: .keyboard,
    type: .keyboardLayout,
    bundleID: "no.divvun.keyboard.sme",
    languages: ["se-NO"],
    isEnabled: true,
    isSelected: false
)
private let kotoeri = InputSource(
    id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
    category: .keyboard,
    type: .inputMode,
    bundleID: "com.apple.inputmethod.Kotoeri",
    languages: ["ja"],
    isEnabled: false,
    isSelected: false
)
private let palette = InputSource(
    id: "com.apple.CharacterPaletteIM",
    category: .palette,
    type: .characterPalette,
    isEnabled: true,
    isSelected: false
)
private let sources = FixedInputSources(installed: [abc, sme, kotoeri, palette])

// [spec:tis:req:kit.list/test]
@Test @MainActor func defaultListIsEnabledSourcesOnly() throws {
    #expect(try sources.list(matching: InputSourceFilter()) == [abc, sme, palette])
    #expect(
        try sources.list(matching: InputSourceFilter(includeAllInstalled: true))
            == [abc, sme, kotoeri, palette]
    )
}

// [spec:tis:req:kit.list/test]
@Test @MainActor func filterMatchesEveryField() throws {
    func list(_ filter: InputSourceFilter) throws -> [InputSource] {
        var filter = filter
        filter.includeAllInstalled = true
        return try sources.list(matching: filter)
    }

    #expect(try list(InputSourceFilter(category: .palette)) == [palette])
    #expect(try list(InputSourceFilter(type: .inputMode)) == [kotoeri])
    #expect(try list(InputSourceFilter(id: "no.divvun.keylayout.sme")) == [sme])
    #expect(try list(InputSourceFilter(bundleID: "com.apple.inputmethod.Kotoeri")) == [kotoeri])
    #expect(try list(InputSourceFilter(isEnabled: false)) == [kotoeri])
    #expect(try list(InputSourceFilter(isSelected: true)) == [abc])
    #expect(try list(InputSourceFilter(type: .keyboardLayout, isSelected: false)) == [sme])
}

// [spec:tis:req:kit.list/test]
@Test @MainActor func languageFilterMatchesTagAndSubtags() throws {
    func list(_ language: String) throws -> [InputSource] {
        try sources.list(matching: InputSourceFilter(language: language, includeAllInstalled: true))
    }

    #expect(try list("se") == [sme])
    #expect(try list("se-NO") == [sme])
    #expect(try list("SE-no") == [sme])
    #expect(try list("s").isEmpty)
    #expect(try list("ja") == [kotoeri])
}

// [spec:tis:req:kit.list/test]
@Test @MainActor func languageFilterAcceptsICUStyleTags() throws {
    let hindiLatin = InputSource(id: "com.example.hi-latn", languages: ["hi_Latn"], isEnabled: true)
    let sources = FixedInputSources(installed: [hindiLatin])

    #expect(try sources.list(matching: InputSourceFilter(language: "hi")) == [hindiLatin])
    #expect(try sources.list(matching: InputSourceFilter(language: "hi-Latn")) == [hindiLatin])
    #expect(try sources.list(matching: InputSourceFilter(language: "hi_Latn")) == [hindiLatin])
}

// [spec:tis:req:kit.lookup+2/test]
@Test @MainActor func lookupSearchesDisabledSources() throws {
    #expect(try sources.source(id: kotoeri.id!) == kotoeri)
}

// [spec:tis:req:kit.lookup+2/test]
@Test @MainActor func lookupAcceptsTheOtherIDOfABundledLayout() throws {
    var aliases = LayoutIDAliases()
    aliases.add(
        bundleID: "org.sil.ukelele.keyboardlayout.workman",
        layouts: ["Workman-P Extended": "org.sil.ukelele.keyboardlayout.workman.workman-pextended"]
    )
    let generated = InputSource(
        id: "org.sil.ukelele.keyboardlayout.workman.keylayout.Workman-PExtended",
        isEnabled: true
    )
    let declared = InputSource(
        id: "org.sil.ukelele.keyboardlayout.workman.workman-pextended",
        isEnabled: true
    )

    let onlyDeclared = FixedInputSources(installed: [declared])
    onlyDeclared.layoutIDAliases = aliases
    #expect(try onlyDeclared.source(id: generated.id!) == declared)

    let onlyGenerated = FixedInputSources(installed: [generated])
    onlyGenerated.layoutIDAliases = aliases
    #expect(try onlyGenerated.source(id: declared.id!) == generated)

    let both = FixedInputSources(installed: [declared, generated])
    both.layoutIDAliases = aliases
    #expect(try both.source(id: generated.id!) == generated)
    #expect(try both.source(id: declared.id!) == declared)

    let withoutAliases = FixedInputSources(installed: [declared])
    #expect(throws: TISError.notFound(id: generated.id!)) {
        try withoutAliases.source(id: generated.id!)
    }
}

// [spec:tis:req:kit.lookup+2/test]
@Test @MainActor func lookupMatchesExactlyAndReportsTheID() {
    #expect(throws: TISError.notFound(id: "com.apple.keylayout")) {
        try sources.source(id: "com.apple.keylayout")
    }
    #expect(throws: TISError.notFound(id: "com.apple.keylayout.abc")) {
        try sources.source(id: "com.apple.keylayout.abc")
    }
}
