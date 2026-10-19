import TISKitTestSupport
import Testing

@testable import TISKit

private let dvorak = InputSource(id: "com.apple.keylayout.Dvorak", type: .keyboardLayout)
private let kotoeri = InputSource(id: "com.apple.inputmethod.Kotoeri", type: .inputMethodWithModes)

// [spec:tis:req:mutate.layout-override/test]
@Test @MainActor func overrideSetsAKeyboardLayout() throws {
    let sources = FixedInputSources(installed: [dvorak, kotoeri])

    #expect(try sources.overrideLayout(with: dvorak.id!) == dvorak)
    #expect(sources.layoutOverride() == dvorak)
}

// [spec:tis:req:mutate.layout-override/test]
@Test @MainActor func overrideRefusesAnythingButAKeyboardLayout() {
    let sources = FixedInputSources(installed: [dvorak, kotoeri])

    #expect(throws: TISError.notAKeyboardLayout(id: kotoeri.id!)) {
        try sources.overrideLayout(with: kotoeri.id!)
    }
    #expect(sources.layoutOverride() == nil)
}

// [spec:tis:req:mutate.layout-override/test]
@Test @MainActor func systemOverrideIsReadable() {
    let layout = SystemInputSources().layoutOverride()
    #expect(layout == nil || layout?.type == .keyboardLayout)
}
