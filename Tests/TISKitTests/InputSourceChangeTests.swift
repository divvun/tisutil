import TISKitTestSupport
import Testing

@testable import TISKit

private let layoutID = "no.divvun.keylayout.sme"
private let paletteID = "com.apple.CharacterPaletteIM"

@MainActor
private func fixture(enabled: Bool = false, selected: Bool = false) -> FixedInputSources {
    FixedInputSources(installed: [
        InputSource(
            id: layoutID,
            type: .keyboardLayout,
            isSelectCapable: true,
            isEnabled: enabled,
            isSelected: selected
        ),
        InputSource(
            id: paletteID, type: .characterPalette, isSelectCapable: false, isEnabled: true),
    ])
}

// [spec:tis:req:mutate.enable-disable/test]
@Test @MainActor func enableAndDisableRequestTheChange() throws {
    let sources = fixture()

    #expect(try sources.apply(.enable, to: layoutID).isEnabled == true)
    #expect(try sources.apply(.disable, to: layoutID).isEnabled == false)
    #expect(sources.changeRequests == [.init(.enable, layoutID), .init(.disable, layoutID)])
}

// [spec:tis:req:mutate.enable-disable/test]
@Test @MainActor func enablingAnEnabledSourceChangesNothing() throws {
    let enabled = fixture(enabled: true)
    #expect(try enabled.apply(.enable, to: layoutID).isEnabled == true)
    #expect(enabled.changeRequests.isEmpty)

    let disabled = fixture()
    #expect(try disabled.apply(.disable, to: layoutID).isEnabled == false)
    #expect(disabled.changeRequests.isEmpty)
}

// [spec:tis:req:mutate.select/test]
@Test @MainActor func selectRefusesSourcesThatCannotBeSelected() {
    let sources = fixture()

    #expect(throws: TISError.notSelectCapable(id: paletteID)) {
        try sources.apply(.select, to: paletteID)
    }
    #expect(throws: TISError.notSelectCapable(id: paletteID)) {
        try sources.apply(.deselect, to: paletteID)
    }
    #expect(sources.changeRequests.isEmpty)
}

// [spec:tis:req:mutate.select/test]
@Test @MainActor func selectRequiresAnEnabledSourceUnlessAskedToEnable() throws {
    let sources = fixture()

    #expect(throws: TISError.notEnabled(id: layoutID)) {
        try sources.apply(.select, to: layoutID)
    }
    #expect(sources.changeRequests.isEmpty)

    let selected = try sources.apply(.select, to: layoutID, enablingFirst: true)
    #expect(selected.isEnabled == true && selected.isSelected == true)
    #expect(sources.changeRequests == [.init(.enable, layoutID), .init(.select, layoutID)])
}

// [spec:tis:req:mutate.select/test]
@Test @MainActor func deselectRequestsTheChange() throws {
    let sources = fixture(enabled: true, selected: true)

    #expect(try sources.apply(.deselect, to: layoutID).isSelected == false)
    #expect(sources.changeRequests == [.init(.deselect, layoutID)])
}

// [spec:tis:req:mutate.verify/test]
@Test @MainActor func changeThatDoesNotTakeEffectIsAnError() {
    let disabled = fixture()
    disabled.appliesChanges = false
    #expect(throws: TISError.notApplied(.enable, id: layoutID)) {
        try disabled.apply(.enable, to: layoutID)
    }

    let enabled = fixture(enabled: true)
    enabled.appliesChanges = false
    #expect(throws: TISError.notApplied(.select, id: layoutID)) {
        try enabled.apply(.select, to: layoutID)
    }
}

// [spec:tis:req:mutate.verify/test]
@Test @MainActor func verificationFollowsALayoutThatTISRenames() throws {
    let sources = FixedInputSources(installed: [
        InputSource(
            id: "so.example.layouts.keylayout.sv",
            type: .keyboardLayout,
            bundleID: "so.example.layouts",
            localizedName: "Swedish Alt",
            isSelectCapable: true,
            isEnabled: true,
            isSelected: false
        )
    ])
    sources.idsAfterChange = ["so.example.layouts.keylayout.sv": "so.example.layouts.sv"]

    let selected = try sources.apply(.select, to: "so.example.layouts.keylayout.sv")
    #expect(selected.id == "so.example.layouts.sv")
    #expect(selected.isSelected == true)
}

// [spec:tis:req:mutate.verify/test]
@Test @MainActor func changingAnUnknownSourceIsNotFound() {
    #expect(throws: TISError.notFound(id: "no.such")) {
        try fixture().apply(.enable, to: "no.such")
    }
}
