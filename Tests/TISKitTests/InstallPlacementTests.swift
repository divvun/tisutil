import Foundation
import TISKitTestSupport
import Testing

@testable import TISKit

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "tisutil-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func layoutBundle(in directory: URL, marker: String) throws -> InstallableItem {
    let bundle = directory.appending(path: "sme.bundle")
    let resources = bundle.appending(path: "Contents/Resources")
    try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
    try PropertyListSerialization.data(
        fromPropertyList: ["CFBundleIdentifier": "no.uit.giella.keyboards.sme.keyboardlayout.sme"],
        format: .xml,
        options: 0
    ).write(to: bundle.appending(path: "Contents/Info.plist"))
    try Data(#"<keyboard group="126" id="-1" name="\#(marker)"></keyboard>"#.utf8)
        .write(to: resources.appending(path: "seSE.keylayout"))
    return try InstallableItem(url: bundle)
}

// [spec:tis:req:install.place+1/test]
@Test func layoutsGoToKeyboardLayoutsAndInputMethodsToInputMethods() throws {
    let library = try temporaryDirectory()
    let layout = try layoutBundle(in: temporaryDirectory(), marker: "one")
    let placed = try layout.place(inLibrary: library)

    #expect(
        placed.url == library.appending(path: "Keyboard Layouts/sme.bundle").standardizedFileURL)
    #expect(placed.kind == layout.kind)
    #expect(
        FileManager.default.fileExists(
            atPath: placed.url.appending(path: "Contents/Info.plist").path)
    )

    let inputMethod = InstallableItem(
        url: URL(fileURLWithPath: "/Applications/Avette.app"),
        kind: .inputMethod(bundleID: "eu.avette.inputmethod.Avette")
    )
    #expect(inputMethod.directoryName == "Input Methods")
}

// [spec:tis:req:install.place+1/test]
@Test func placingReplacesAnExistingItemAndLeavesNoStagingBehind() throws {
    let library = try temporaryDirectory()
    _ = try layoutBundle(in: temporaryDirectory(), marker: "old").place(inLibrary: library)
    let placed = try layoutBundle(in: temporaryDirectory(), marker: "new").place(inLibrary: library)

    let keylayout = try String(
        contentsOf: placed.url.appending(path: "Contents/Resources/seSE.keylayout"),
        encoding: .utf8
    )
    #expect(keylayout.contains("new"))
    #expect(
        try FileManager.default.contentsOfDirectory(
            atPath: library.appending(path: "Keyboard Layouts").path
        ) == ["sme.bundle"]
    )
}

// [spec:tis:req:install.place+1/test]
@Test func placingIntoAnUnwritableLibraryIsNotPermitted() throws {
    let library = try temporaryDirectory()
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: library.path)
    defer {
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: library.path)
    }
    let layout = try layoutBundle(in: temporaryDirectory(), marker: "x")

    #expect(throws: InstallError.self) { try layout.place(inLibrary: library) }
}

// [spec:tis:req:install.enable/test]
@Test @MainActor func activateEnablesEverySourceAndSelectsTheFirst() throws {
    let seSE = InputSource(
        id: "sme.seSE", isEnableCapable: true, isSelectCapable: true, isEnabled: false,
        isSelected: false)
    let seNO = InputSource(
        id: "sme.seNO", isEnableCapable: true, isSelectCapable: true, isEnabled: false,
        isSelected: false)
    let parent = InputSource(
        id: "sme.im", isEnableCapable: false, isSelectCapable: false, isEnabled: false)
    let sources = FixedInputSources(installed: [parent, seSE, seNO])

    let result = try sources.activate([parent, seSE, seNO], enable: true, select: true)

    #expect(result.map(\.isEnabled) == [false, true, true])
    #expect(result.map(\.isSelected) == [nil, true, false])
    #expect(
        sources.changeRequests == [
            .init(.enable, "sme.seSE"), .init(.enable, "sme.seNO"), .init(.select, "sme.seSE"),
        ]
    )
}

// [spec:tis:req:install.enable/test]
@Test @MainActor func activateSelectAloneEnablesOnlyTheSelectedSource() throws {
    let seSE = InputSource(
        id: "sme.seSE", isEnableCapable: true, isSelectCapable: true, isEnabled: false,
        isSelected: false)
    let seNO = InputSource(
        id: "sme.seNO", isEnableCapable: true, isSelectCapable: true, isEnabled: false,
        isSelected: false)
    let sources = FixedInputSources(installed: [seSE, seNO])

    _ = try sources.activate([seSE, seNO], enable: false, select: true)
    #expect(sources.changeRequests == [.init(.enable, "sme.seSE"), .init(.select, "sme.seSE")])

    let untouched = FixedInputSources(installed: [seSE])
    #expect(try untouched.activate([seSE], enable: false, select: false) == [seSE])
    #expect(untouched.changeRequests.isEmpty)
}

// [spec:tis:req:install.enable/test]
@Test @MainActor func activateFailsWhenAChangeDoesNotTakeEffect() {
    let seSE = InputSource(
        id: "sme.seSE", isEnableCapable: true, isSelectCapable: true, isEnabled: false,
        isSelected: false)
    let sources = FixedInputSources(installed: [seSE])
    sources.appliesChanges = false

    #expect(throws: TISError.notApplied(.enable, id: "sme.seSE")) {
        try sources.activate([seSE], enable: true, select: false)
    }
}
