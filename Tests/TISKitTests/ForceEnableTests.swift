import Carbon
import TISKitTestSupport
import Testing

@testable import TISKit

private let sourceID = "org.example.keylayout.Test"

@MainActor
private func fixture(enabled: Bool = false) -> FixedInputSources {
    FixedInputSources(installed: [
        InputSource(
            id: sourceID, isEnableCapable: true, isSelectCapable: true,
            isEnabled: enabled, isSelected: false)
    ])
}

// [spec:tis:req:mutate.force-enable+1/test]
@Test @MainActor func forceEnableWaitsForTheChange() throws {
    let sources = fixture()
    sources.pausesBeforeApplying = 2

    #expect(try sources.apply(.enable, to: sourceID, forceEnable: true).isEnabled == true)
    #expect(sources.changeRequests == [.init(.forceEnable, sourceID)])
    #expect(sources.pauses == 2)
}

// [spec:tis:req:mutate.force-enable+1/test]
@Test @MainActor func forceEnableOfAnEnabledSourceMakesNoRequest() throws {
    let sources = fixture(enabled: true)

    #expect(try sources.apply(.enable, to: sourceID, forceEnable: true).isEnabled == true)
    #expect(sources.changeRequests.isEmpty)
}

// [spec:tis:req:mutate.force-enable+1/test]
@Test @MainActor func forceEnableStillRequiresAnExistingSource() {
    let sources = fixture()

    #expect(throws: TISError.notFound(id: "missing")) {
        try sources.apply(.enable, to: "missing", forceEnable: true)
    }
    #expect(sources.changeRequests.isEmpty)
}

// [spec:tis:req:mutate.force-enable+1/test]
@Test @MainActor func forceEnablePropagatesToSelectsEnableStep() throws {
    let sources = fixture()

    #expect(throws: TISError.notEnabled(id: sourceID)) {
        try sources.apply(.select, to: sourceID, forceEnable: true)
    }
    #expect(sources.changeRequests.isEmpty)

    let result = try sources.apply(
        .select, to: sourceID, enablingFirst: true, forceEnable: true)

    #expect(result.isSelected == true)
    #expect(sources.changeRequests == [.init(.forceEnable, sourceID), .init(.select, sourceID)])
}

// [spec:tis:req:mutate.force-enable+1/test]
// [spec:tis:req:mutate.verify+2/test]
@Test @MainActor func unappliedForceEnableTimesOutWithoutMentioningAPrompt() {
    let sources = fixture()
    sources.appliesChanges = false

    #expect(throws: TISError.notApplied(.forceEnable, id: sourceID)) {
        try sources.apply(.enable, to: sourceID, forceEnable: true, timeout: 1)
    }
    #expect(sources.pauses == 4)
    let message = TISError.notApplied(.forceEnable, id: sourceID).description
    #expect(message.contains("still not enabled"))
    #expect(!message.contains("denied"))
}

// [spec:tis:req:mutate.force-enable+1/test]
@Test @MainActor func forcedActivationEnablesEverySourceBeforeSelecting() throws {
    let first = fixture().installed[0]
    var second = first
    second.id = "org.example.keylayout.Second"
    let parent = InputSource(id: "parent", isEnableCapable: false, isSelectCapable: false)
    let sources = FixedInputSources(installed: [parent, first, second])

    let result = try sources.activate(
        sources.installed, enable: true, select: true, forceEnable: true)

    #expect(result.map(\.isEnabled) == [nil, true, true])
    #expect(result.map(\.isSelected) == [nil, true, false])
    #expect(
        sources.changeRequests == [
            .init(.forceEnable, sourceID), .init(.forceEnable, second.id!),
            .init(.select, sourceID),
        ])
}

// [spec:tis:req:mutate.force-enable+1/test]
@Test @MainActor func selectOnlyActivationForcesOnlyTheSelectedSource() throws {
    let first = fixture().installed[0]
    var second = first
    second.id = "org.example.keylayout.Second"
    let sources = FixedInputSources(installed: [first, second])

    let result = try sources.activate(
        sources.installed, enable: false, select: true, forceEnable: true)

    #expect(result.map(\.isEnabled) == [true, false])
    #expect(sources.changeRequests == [.init(.forceEnable, sourceID), .init(.select, sourceID)])
}

// [spec:tis:req:mutate.force-enable+1/test]
@Test @MainActor func forceEnablePassesTheOptionBitToTheResolvedFunction() throws {
    let source = try #require(TISCopyCurrentKeyboardInputSource()?.takeRetainedValue())
    let function: @convention(c) (TISInputSource, UInt32) -> OSStatus = { _, options in
        options == 2 ? noErr : OSStatus(paramErr)
    }

    try enableWithoutPrompt(
        source, symbol: unsafeBitCast(function, to: UnsafeMutableRawPointer.self))
}

// [spec:tis:req:mutate.force-enable+1/test]
@Test @MainActor func forceEnableReportsMissingSymbolsAndTISErrors() throws {
    let source = try #require(TISCopyCurrentKeyboardInputSource()?.takeRetainedValue())
    let name = "TISEnableInputSourceWithOptions"

    #expect(throws: TISError.unavailable(function: name)) {
        try enableWithoutPrompt(source, symbol: nil)
    }

    let function: @convention(c) (TISInputSource, UInt32) -> OSStatus = { _, _ in -50 }
    #expect(throws: TISError.status(-50, function: name)) {
        try enableWithoutPrompt(
            source, symbol: unsafeBitCast(function, to: UnsafeMutableRawPointer.self))
    }
    #expect(TISError.unavailable(function: name).description.contains(name))
}
