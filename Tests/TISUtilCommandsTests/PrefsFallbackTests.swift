import ArgumentParser
import Foundation
import TISKitTestSupport
import Testing

@testable import TISKit
@testable import TISUtilCommands

private let away = UserAccount(name: "away", uid: 503)
private let irish = InputSource(id: "com.apple.keylayout.Irish", type: .keyboardLayout)
private let irishEntry = EnabledSourceEntry(
    kind: .keyboardLayout, layoutID: 50, layoutName: "Irish")
private let workman = InputSource(
    id: "org.sil.ukelele.keyboardlayout.workman.workman",
    type: .keyboardLayout,
    bundleID: "org.sil.ukelele.keyboardlayout.workman"
)
private let thirdPartySources = [
    PreferenceSource(
        source: workman,
        entry: EnabledSourceEntry(kind: .keyboardLayout, layoutID: 14844, layoutName: "Workman"),
        isFromSystem: false
    ),
    PreferenceSource(
        source: InputSource(
            id: "example.inputmethod", type: .inputMethod, bundleID: "example.inputmethod"),
        entry: EnabledSourceEntry(kind: .keyboardInputMethod, bundleID: "example.inputmethod"),
        isFromSystem: false
    ),
    PreferenceSource(
        source: InputSource(
            id: "example.inputmethod.mode", type: .inputMode, bundleID: "example.inputmethod",
            inputModeID: "example.mode"),
        entry: EnabledSourceEntry(
            kind: .inputMode, bundleID: "example.inputmethod", inputMode: "example.mode"),
        isFromSystem: false
    ),
    PreferenceSource(
        source: InputSource(
            id: "example.palette", type: .characterPalette, bundleID: "example.palette"),
        entry: EnabledSourceEntry(kind: .nonKeyboardInputMethod, bundleID: "example.palette"),
        isFromSystem: false
    ),
]

private final class MemoryStore: EnabledSourcesStore {
    var byUser: [String: [[String: Any]]] = [:]
    var writes = 0

    func entries(for user: String) -> [[String: Any]] { byUser[user] ?? [] }

    func setEntries(_ entries: [[String: Any]], for user: String) throws {
        byUser[user] = entries
        writes += 1
    }
}

@MainActor
private func provider() -> FixedInputSources {
    let found =
        [PreferenceSource(source: irish, entry: irishEntry, isFromSystem: true)]
        + thirdPartySources
    let sources = FixedInputSources(installed: found.map(\.source))
    sources.preferenceSources = Dictionary(uniqueKeysWithValues: found.map { ($0.source.id!, $0) })
    return sources
}

private func command<C: StateCommand>(_ type: C.Type, _ arguments: [String]) throws -> C {
    try #require(try TISUtil.parseAsRoot(arguments) as? C)
}

// [spec:tis:req:session.prefs-fallback+2/test]
@Test(arguments: [false, true])
@MainActor func enablingAnAppleSourceRecordsItForTheNextLogin(force: Bool) throws {
    let store = MemoryStore()
    let thirdPartyStore = MemoryStore()
    let enable = try command(
        Enable.self, ["enable", "--user", "away", irish.id!] + (force ? ["--force"] : []))

    let output = try enable.changeWithoutSession(
        enable: true, id: irish.id!, user: away, provider: provider(), store: store,
        thirdPartyStore: thirdPartyStore)

    #expect(
        store.entries(for: "away").compactMap(EnabledSourceEntry.init(dictionary:)) == [irishEntry])
    #expect(output.status == .success)
    #expect(output.diagnostic?.contains("next login") == true)

    _ = try enable.changeWithoutSession(
        enable: true, id: irish.id!, user: away, provider: provider(), store: store,
        thirdPartyStore: thirdPartyStore)
    #expect(store.entries(for: "away").count == 1)
    #expect(thirdPartyStore.writes == 0)
}

// [spec:tis:req:session.prefs-fallback+2/test]
@Test @MainActor func disablingAnAppleSourceRemovesIt() throws {
    let store = MemoryStore()
    let thirdPartyStore = MemoryStore()
    store.byUser["away"] = [irishEntry.dictionary]
    let disable = try command(Disable.self, ["disable", "--user", "away", irish.id!])

    _ = try disable.changeWithoutSession(
        enable: false, id: irish.id!, user: away, provider: provider(), store: store,
        thirdPartyStore: thirdPartyStore)
    #expect(store.entries(for: "away").isEmpty)
    #expect(thirdPartyStore.writes == 0)
}

// [spec:tis:req:session.prefs-fallback+2/test]
@Test(arguments: thirdPartySources)
@MainActor func thirdPartyEnableWithoutForceLeavesPreferencesUntouched(_ found: PreferenceSource)
    throws
{
    let id = found.source.id!
    let store = MemoryStore()
    let thirdPartyStore = MemoryStore()
    let enable = try command(Enable.self, ["enable", "--user", "away", id])

    #expect(throws: SessionError.needsApproval(id: id, user: "away")) {
        try enable.changeWithoutSession(
            enable: true, id: id, user: away, provider: provider(), store: store,
            thirdPartyStore: thirdPartyStore)
    }
    #expect(store.writes == 0)
    #expect(thirdPartyStore.writes == 0)
    let error = SessionError.needsApproval(id: id, user: "away")
    #expect(ExitStatus(for: error) == .noPermission)
    #expect(error.description.contains("--force"))
}

// [spec:tis:req:session.prefs-fallback+2/test]
// [spec:tis:req:mutate.force-enable+2/test]
@Test(arguments: thirdPartySources)
@MainActor func forcedThirdPartyEnableRecordsItForTheNextLogin(_ found: PreferenceSource) throws {
    let id = found.source.id!
    let store = MemoryStore()
    store.byUser["away"] = [irishEntry.dictionary]
    let thirdPartyStore = MemoryStore()
    let unrelated: [String: Any] = ["unrecognized": "preserved"]
    thirdPartyStore.byUser["away"] = [unrelated]
    thirdPartyStore.byUser["another-user"] = []
    let enable = try command(Enable.self, ["enable", "--force", "--user", "away", id])

    for _ in 0..<2 {
        let output = try enable.changeWithoutSession(
            enable: true, id: id, user: away, provider: provider(), store: store,
            thirdPartyStore: thirdPartyStore)
        #expect(output.status == .success)
        #expect(output.diagnostic?.contains("next login") == true)
    }

    let recorded = thirdPartyStore.entries(for: "away")
    #expect(recorded.count == 2)
    #expect(
        recorded.first.map(NSDictionary.init(dictionary:)) == NSDictionary(dictionary: unrelated))
    #expect(recorded.compactMap(EnabledSourceEntry.init(dictionary:)) == [found.entry!])
    #expect(thirdPartyStore.entries(for: "another-user").isEmpty)
    #expect(store.writes == 0)
    #expect(
        store.entries(for: "away").compactMap(EnabledSourceEntry.init(dictionary:)) == [irishEntry])
}

// [spec:tis:req:session.prefs-fallback+2/test]
@Test(arguments: thirdPartySources)
@MainActor func disablingThirdPartySourcesNeedsNoForce(_ found: PreferenceSource) throws {
    let id = found.source.id!
    let store = MemoryStore()
    let thirdPartyStore = MemoryStore()
    let unrelated: [String: Any] = ["unrecognized": "preserved"]
    thirdPartyStore.byUser["away"] = [unrelated, found.entry!.dictionary]
    let disable = try command(Disable.self, ["disable", "--user", "away", id])

    let output = try disable.changeWithoutSession(
        enable: false, id: id, user: away, provider: provider(), store: store,
        thirdPartyStore: thirdPartyStore)

    #expect(
        thirdPartyStore.entries(for: "away").map(NSDictionary.init(dictionary:)) == [
            NSDictionary(dictionary: unrelated)
        ])
    #expect(store.writes == 0)
    #expect(output.status == .success)
    #expect(output.diagnostic?.contains("next login") == true)
}

// [spec:tis:req:session.prefs-fallback+2/test]
@Test @MainActor func sourcesWithoutAnEntryCannotFallBack() throws {
    let sources = provider()
    sources.preferenceSources[irish.id!] = PreferenceSource(
        source: irish, entry: nil, isFromSystem: true)
    let enable = try command(Enable.self, ["enable", "--user", "away", irish.id!])

    #expect(throws: SessionError.noPreferenceEntry(id: irish.id!)) {
        try enable.changeWithoutSession(
            enable: true, id: irish.id!, user: away, provider: sources, store: MemoryStore(),
            thirdPartyStore: MemoryStore())
    }
}
