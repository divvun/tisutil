import Foundation
import Testing

@testable import TISKit

// [spec:tis:req:session.prefs-fallback+1/test]
@Test func keyboardLayoutEntriesMatchWhatMacOSRecords() {
    let swedishPro = InputSource(id: "com.apple.keylayout.Swedish-Pro", type: .keyboardLayout)
    let entry = EnabledSourceEntry(swedishPro, layoutName: "Swedish - Pro", layoutNumber: 7)

    #expect(
        entry.map { NSDictionary(dictionary: $0.dictionary) }
            == NSDictionary(dictionary: [
                "InputSourceKind": "Keyboard Layout",
                "KeyboardLayout ID": 7,
                "KeyboardLayout Name": "Swedish - Pro",
            ])
    )
    #expect(EnabledSourceEntry(swedishPro, layoutName: nil, layoutNumber: 7) == nil)
}

// [spec:tis:req:session.prefs-fallback+1/test]
@Test func entriesForOtherKindsUseBundleAndMode() {
    let mode = InputSource(
        type: .inputMode,
        bundleID: "com.apple.inputmethod.SCIM",
        inputModeID: "com.apple.inputmethod.SCIM.ITABC"
    )
    let palette = InputSource(type: .characterPalette, bundleID: "com.apple.CharacterPaletteIM")
    let method = InputSource(type: .inputMethodWithModes, bundleID: "com.apple.inputmethod.SCIM")

    #expect(
        EnabledSourceEntry(mode, layoutName: nil, layoutNumber: nil)
            == EnabledSourceEntry(
                kind: .inputMode,
                bundleID: "com.apple.inputmethod.SCIM",
                inputMode: "com.apple.inputmethod.SCIM.ITABC"
            )
    )
    #expect(
        EnabledSourceEntry(palette, layoutName: nil, layoutNumber: nil)?.kind
            == .nonKeyboardInputMethod
    )
    #expect(
        EnabledSourceEntry(method, layoutName: nil, layoutNumber: nil)?.kind == .keyboardInputMethod
    )
    #expect(
        EnabledSourceEntry(InputSource(type: .unknown("X")), layoutName: nil, layoutNumber: nil)
            == nil
    )
}

// [spec:tis:req:session.prefs-fallback+1/test]
@Test func applyingAnEntryAddsOrRemovesItOnce() {
    let irish = EnabledSourceEntry(kind: .keyboardLayout, layoutID: 50, layoutName: "Irish")
    let palette = EnabledSourceEntry(
        kind: .nonKeyboardInputMethod, bundleID: "com.apple.CharacterPaletteIM")
    let existing = [palette.dictionary]

    let enabled = irish.applied(to: existing, enable: true)
    #expect(enabled.compactMap(EnabledSourceEntry.init(dictionary:)) == [palette, irish])
    #expect(
        irish.applied(to: enabled, enable: true).compactMap(EnabledSourceEntry.init(dictionary:))
            == [palette, irish]
    )
    #expect(
        irish.applied(to: enabled, enable: false).compactMap(EnabledSourceEntry.init(dictionary:))
            == [palette]
    )
}

// [spec:tis:req:session.prefs-fallback+1/test]
@Test @MainActor func builtEntriesMatchTheEnabledAppleLayouts() throws {
    let system = SystemInputSources()
    let recorded = UserPreferencesStore().entries(for: UserAccount.effective.name)
        .compactMap(EnabledSourceEntry.init(dictionary:))
    let appleLayouts = try system.list(includeAllInstalled: false).filter {
        $0.type == .keyboardLayout && ($0.id ?? "").hasPrefix("com.apple.keylayout.")
    }
    for layout in appleLayouts {
        let found = try system.preferenceSource(id: layout.id!)
        #expect(found.isFromSystem)
        let entry = try #require(found.entry)
        #expect(recorded.contains(entry), "\(entry) is not among \(recorded)")
    }
}

/// An absolute path as the domain keeps the test's preferences out of
/// ~/Library/Preferences.
// [spec:tis:req:session.prefs-fallback+1/test]
@Test func preferencesStoreRoundTripsThroughCFPreferences() throws {
    let file = FileManager.default.temporaryDirectory.appending(
        path: "tisutil-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: file.appendingPathExtension("plist")) }
    let store = UserPreferencesStore(domain: file.path, key: "Entries")
    let user = UserAccount.effective.name
    let entry = EnabledSourceEntry(kind: .keyboardLayout, layoutID: 50, layoutName: "Irish")

    try store.setEntries([entry.dictionary], for: user)
    #expect(store.entries(for: user).compactMap(EnabledSourceEntry.init(dictionary:)) == [entry])
}
