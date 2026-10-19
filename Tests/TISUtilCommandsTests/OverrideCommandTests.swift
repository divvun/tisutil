import ArgumentParser
import Foundation
import TISKitTestSupport
import Testing

@testable import TISKit
@testable import TISUtilCommands

private let dvorak = InputSource(id: "com.apple.keylayout.Dvorak", type: .keyboardLayout)

private func override(_ arguments: [String]) throws -> Override {
    try #require(try TISUtil.parseAsRoot(["override"] + arguments) as? Override)
}

// [spec:tis:req:mutate.layout-override/test]
@Test @MainActor func overridePrintsTheCurrentOverride() throws {
    let sources = FixedInputSources(installed: [dvorak])
    sources.currentLayoutOverride = dvorak

    let output = try override([]).execute(provider: sources)
    #expect(output.status == .success)
    #expect(output.stdout.contains(dvorak.id!))
}

// [spec:tis:req:mutate.layout-override/test]
@Test @MainActor func overrideWithoutOneExitsNotFound() throws {
    let output = try override(["--json"]).execute(provider: FixedInputSources(installed: []))
    #expect(output.status == .notFound)
    #expect(output.stdout == "null")
    #expect(output.diagnostic != nil)
}

// [spec:tis:req:mutate.layout-override/test]
@Test @MainActor func overrideSetsTheGivenLayout() throws {
    let sources = FixedInputSources(installed: [dvorak])
    _ = try override([dvorak.id!]).execute(provider: sources)
    #expect(sources.currentLayoutOverride == dvorak)
    #expect(ExitStatus(for: TISError.notAKeyboardLayout(id: "x")) == .usage)
}
