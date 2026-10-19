import ArgumentParser
import Foundation
import TISKitTestSupport
import Testing

@testable import TISKit
@testable import TISUtilCommands

private let layoutID = "no.divvun.keylayout.sme"

@MainActor
private func fixture() -> FixedInputSources {
    FixedInputSources(installed: [
        InputSource(
            id: layoutID,
            type: .keyboardLayout,
            isSelectCapable: true,
            isEnabled: false,
            isSelected: false
        )
    ])
}

private func parse(_ arguments: [String]) throws -> any StateCommand {
    try #require(try TISUtil.parseAsRoot(arguments) as? any StateCommand)
}

// [spec:tis:req:mutate.enable-disable/test]
@Test @MainActor func enableCommandPrintsTheEnabledSource() throws {
    let sources = fixture()
    let output = try parse(["enable", "--json", layoutID]).execute(provider: sources)
    let object = try #require(
        try JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [String: Any]
    )

    #expect(output.status == .success)
    #expect(object["id"] as? String == layoutID)
    #expect(object["isEnabled"] as? Bool == true)
}

// [spec:tis:req:mutate.select/test]
@Test func selectEnableFlagEnablesFirst() throws {
    #expect(try parse(["select", layoutID]).enablingFirst == false)
    #expect(try parse(["select", "--enable", layoutID]).enablingFirst == true)
    #expect(try parse(["enable", layoutID]).enablingFirst == false)
}

// [spec:tis:req:mutate.select/test]
@Test @MainActor func selectCommandEnablesWhenAsked() throws {
    let sources = fixture()
    #expect(throws: TISError.notEnabled(id: layoutID)) {
        try parse(["select", layoutID]).execute(provider: sources)
    }
    _ = try parse(["select", "--enable", layoutID]).execute(provider: sources)
    #expect(sources.changeRequests.map(\.change) == [.enable, .select])
}

// [spec:tis:req:mutate.verify/test]
@Test @MainActor func unappliedChangeExitsWithFailure() throws {
    let sources = fixture()
    sources.appliesChanges = false

    do {
        _ = try parse(["enable", layoutID]).execute(provider: sources)
        Issue.record("enable succeeded although the change was not applied")
    } catch {
        #expect(error as? TISError == .notApplied(.enable, id: layoutID))
        #expect(ExitStatus(for: error) == .failure)
    }
}
