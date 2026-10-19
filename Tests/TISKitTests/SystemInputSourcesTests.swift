import Testing

@testable import TISKit

private let system = SystemInputSources()

// [spec:tis:req:kit.list/test]
// [spec:tis:req:kit.main-thread/test]
@Test @MainActor func systemListReturnsEnabledSources() throws {
    let enabled = try system.list(includeAllInstalled: false)
    let installed = try system.list(includeAllInstalled: true)

    #expect(!enabled.isEmpty)
    #expect(enabled.allSatisfy { $0.isEnabled == true })
    #expect(installed.count >= enabled.count)
    #expect(installed.contains { $0.isEnabled == false })
}

// [spec:tis:req:kit.current/test]
@Test @MainActor func systemCurrentSourcesHaveTheRequestedShape() throws {
    let keyboard = try system.current(.keyboard)
    #expect(keyboard.isSelected == true)
    #expect(keyboard.category == .keyboard)

    let layout = try system.current(.keyboardLayout)
    #expect(layout.type == .keyboardLayout)

    #expect(try system.current(.asciiCapableKeyboard).isASCIICapable == true)

    let asciiLayout = try system.current(.asciiCapableKeyboardLayout)
    #expect(asciiLayout.isASCIICapable == true)
    #expect(asciiLayout.type == .keyboardLayout)
}

// [spec:tis:req:kit.current/test]
@Test @MainActor func systemHasASourceForEnglish() throws {
    let source = try system.source(forLanguage: "en")
    #expect(source.supports(language: "en"))
}

// [spec:tis:req:kit.lookup/test]
@Test @MainActor func systemLookupFindsInstalledSources() throws {
    let installed = try system.list(includeAllInstalled: true)
    let disabled = try #require(installed.first { $0.isEnabled == false && $0.id != nil })
    #expect(try system.source(id: disabled.id!) == disabled)
    #expect(throws: TISError.notFound(id: "no.such.input-source")) {
        try system.source(id: "no.such.input-source")
    }
}
