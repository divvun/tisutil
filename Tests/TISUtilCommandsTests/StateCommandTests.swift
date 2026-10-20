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

// [spec:tis:req:mutate.enable-disable+1/test]
@Test @MainActor func enableCommandPrintsTheEnabledSource() throws {
    let sources = fixture()
    let output = try parse(["enable", "--json", layoutID]).execute(provider: sources)
    let object = try #require(
        try JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [String: Any]
    )

    #expect(output.status == .success)
    #expect(object["id"] as? String == layoutID)
    #expect(object["isEnabled"] as? Bool == true)
    #expect(sources.changeRequests == [.init(.enable, layoutID)])
}

// [spec:tis:req:mutate.force-enable+2/test]
@Test @MainActor func forceEnableCommandPrintsTheEnabledSource() throws {
    let sources = fixture()
    let output = try parse(["enable", "--force", "--json", layoutID]).execute(provider: sources)
    let object = try #require(
        try JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [String: Any]
    )

    #expect(object["isEnabled"] as? Bool == true)
    #expect(sources.changeRequests == [.init(.forceEnable, layoutID)])
}

// [spec:tis:req:mutate.force-enable+2/test]
@Test @MainActor func selectWithForceEnablesBeforeSelecting() throws {
    let sources = fixture()
    _ = try parse(["select", "--enable", "--force", layoutID]).execute(provider: sources)

    #expect(sources.changeRequests == [.init(.forceEnable, layoutID), .init(.select, layoutID)])
}

// [spec:tis:req:mutate.force-enable+2/test]
@Test(arguments: [
    ["select", "--force", layoutID], ["disable", "--force", layoutID],
    ["deselect", "--force", layoutID], ["register", "--force", "/tmp/test.keylayout"],
    ["install", "--force", "/tmp/test.keylayout"],
])
func forceRequiresACommandThatEnables(_ arguments: [String]) {
    do {
        _ = try TISUtil.parseAsRoot(arguments)
        Issue.record("accepted --force without an enable operation")
    } catch {
        #expect(ExitStatus(for: error) == .usage)
    }
}

// [spec:tis:req:mutate.force-enable+2/test]
@Test @MainActor func unappliedForceEnableExitsWithFailure() throws {
    let sources = fixture()
    sources.appliesChanges = false

    do {
        _ = try parse(["enable", "--force", "--timeout", "0", layoutID])
            .execute(provider: sources)
        Issue.record("force enable succeeded although the change was not applied")
    } catch {
        #expect(error as? TISError == .notApplied(.forceEnable, id: layoutID))
        #expect(ExitStatus(for: error) == .failure)
    }
    #expect(ExitStatus(for: TISError.unavailable(function: "missing")) == .failure)
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

// [spec:tis:req:mutate.verify+2/test]
@Test func timeoutDefaultsToSixtySeconds() throws {
    #expect(try parse(["enable", layoutID]).waiting.timeout == 60)
    #expect(try parse(["select", "--timeout", "5", layoutID]).waiting.timeout == 5)
    #expect(throws: (any Error).self) {
        try TISUtil.parseAsRoot(["enable", "--timeout", "-1", layoutID])
    }
}

// [spec:tis:req:mutate.verify+2/test]
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
