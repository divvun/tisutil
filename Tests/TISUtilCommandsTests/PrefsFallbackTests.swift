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
    let sources = FixedInputSources(installed: [irish, workman])
    sources.preferenceSources = [
        irish.id!: PreferenceSource(source: irish, entry: irishEntry, isFromSystem: true),
        workman.id!: PreferenceSource(
            source: workman,
            entry: EnabledSourceEntry(
                kind: .keyboardLayout, layoutID: 14844, layoutName: "Workman"),
            isFromSystem: false
        ),
    ]
    return sources
}

private func command<C: StateCommand>(_ type: C.Type, _ arguments: [String]) throws -> C {
    try #require(try TISUtil.parseAsRoot(arguments) as? C)
}

// [spec:tis:req:session.prefs-fallback+1/test]
@Test @MainActor func enablingAnAppleSourceRecordsItForTheNextLogin() throws {
    let store = MemoryStore()
    let enable = try command(Enable.self, ["enable", "--user", "away", irish.id!])

    let output = try enable.changeWithoutSession(
        enable: true, id: irish.id!, user: away, provider: provider(), store: store)

    #expect(
        store.entries(for: "away").compactMap(EnabledSourceEntry.init(dictionary:)) == [irishEntry])
    #expect(output.status == .success)
    #expect(output.diagnostic?.contains("next login") == true)

    _ = try enable.changeWithoutSession(
        enable: true, id: irish.id!, user: away, provider: provider(), store: store)
    #expect(store.entries(for: "away").count == 1)
}

// [spec:tis:req:session.prefs-fallback+1/test]
@Test @MainActor func disablingAnAppleSourceRemovesIt() throws {
    let store = MemoryStore()
    store.byUser["away"] = [irishEntry.dictionary]
    let disable = try command(Disable.self, ["disable", "--user", "away", irish.id!])

    _ = try disable.changeWithoutSession(
        enable: false, id: irish.id!, user: away, provider: provider(), store: store)
    #expect(store.entries(for: "away").isEmpty)
}

// [spec:tis:req:session.prefs-fallback+1/test]
@Test @MainActor func thirdPartySourcesAreRefusedWithoutTouchingPreferences() throws {
    let store = MemoryStore()
    let enable = try command(Enable.self, ["enable", "--force", "--user", "away", workman.id!])

    #expect(throws: SessionError.needsApproval(id: workman.id!, user: "away")) {
        try enable.changeWithoutSession(
            enable: true, id: workman.id!, user: away, provider: provider(), store: store)
    }
    #expect(store.writes == 0)
    #expect(ExitStatus(for: SessionError.needsApproval(id: "x", user: "away")) == .noPermission)
}

// [spec:tis:req:session.prefs-fallback+1/test]
@Test @MainActor func sourcesWithoutAnEntryCannotFallBack() throws {
    let sources = provider()
    sources.preferenceSources[irish.id!] = PreferenceSource(
        source: irish, entry: nil, isFromSystem: true)
    let enable = try command(Enable.self, ["enable", "--user", "away", irish.id!])

    #expect(throws: SessionError.noPreferenceEntry(id: irish.id!)) {
        try enable.changeWithoutSession(
            enable: true, id: irish.id!, user: away, provider: sources, store: MemoryStore())
    }
}
