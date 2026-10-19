import Foundation
import TISKitTestSupport
import Testing

@testable import TISKit

private let keylayoutXML = """
    <?xml version="1.1" encoding="UTF-8"?>
    <!DOCTYPE keyboard PUBLIC "" "file://localhost/System/Library/DTDs/KeyboardLayout.dtd">
    <keyboard group="126" id="-30047" name="seSE"><layouts/></keyboard>
    """

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "tisutil-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeBundle(
    at url: URL,
    info: [String: Any],
    resources: [String: String] = [:]
) throws -> URL {
    let contents = url.appending(path: "Contents")
    let resourceDirectory = contents.appending(path: "Resources")
    try FileManager.default.createDirectory(
        at: resourceDirectory, withIntermediateDirectories: true)
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        .write(to: contents.appending(path: "Info.plist"))
    for (name, text) in resources {
        try Data(text.utf8).write(to: resourceDirectory.appending(path: name))
    }
    return url
}

// [spec:tis:req:install.kind-detect/test]
@Test func detectsAKeylayoutFileByItsRootElement() throws {
    let file = try temporaryDirectory().appending(path: "seSE.keylayout")
    try Data(keylayoutXML.utf8).write(to: file)

    #expect(try InstallableItem(url: file).kind == .keyboardLayoutFile(name: "seSE"))
}

// [spec:tis:req:install.kind-detect/test]
@Test func detectsAKeyboardLayoutBundle() throws {
    let bundle = try makeBundle(
        at: temporaryDirectory().appending(path: "sme.bundle"),
        info: ["CFBundleIdentifier": "no.uit.giella.keyboards.sme.keyboardlayout.sme"],
        resources: ["seSE.keylayout": keylayoutXML]
    )

    #expect(
        try InstallableItem(url: bundle).kind
            == .keyboardLayoutBundle(bundleID: "no.uit.giella.keyboards.sme.keyboardlayout.sme")
    )
}

// [spec:tis:req:install.kind-detect/test]
@Test func detectsAnInputMethodFromItsInfoPlist() throws {
    let app = try makeBundle(
        at: temporaryDirectory().appending(path: "Avette.app"),
        info: [
            "CFBundleIdentifier": "eu.avette.inputmethod.Avette",
            "InputMethodConnectionName": "eu.avette.inputmethod.Avette_Connection",
        ]
    )

    #expect(
        try InstallableItem(url: app).kind == .inputMethod(bundleID: "eu.avette.inputmethod.Avette")
    )
}

// [spec:tis:req:install.kind-detect/test]
@Test func refusesAnythingElse() throws {
    let directory = try temporaryDirectory()
    let text = directory.appending(path: "notes.keylayout")
    try Data("not xml".utf8).write(to: text)
    let otherXML = directory.appending(path: "other.xml")
    try Data("<plist><dict/></plist>".utf8).write(to: otherXML)
    let emptyBundle = try makeBundle(
        at: directory.appending(path: "Empty.bundle"),
        info: ["CFBundleIdentifier": "com.example.empty"]
    )
    let noIdentifier = try makeBundle(
        at: directory.appending(path: "NoID.bundle"),
        info: [:],
        resources: ["x.keylayout": keylayoutXML]
    )

    for url in [text, otherXML, emptyBundle, noIdentifier, directory.appending(path: "missing")] {
        #expect(throws: InstallError.unrecognisedItem(path: url.path)) {
            try InstallableItem(url: url)
        }
    }
}

// [spec:tis:req:install.register/test]
@Test @MainActor func registerReturnsTheItemsSources() throws {
    let bundle = try makeBundle(
        at: temporaryDirectory().appending(path: "sme.bundle"),
        info: ["CFBundleIdentifier": "no.uit.giella.keyboards.sme.keyboardlayout.sme"],
        resources: ["seSE.keylayout": keylayoutXML]
    )
    let item = try InstallableItem(url: bundle)
    let seSE = InputSource(
        id: "no.uit.giella.keyboards.sme.keyboardlayout.sme.seSE",
        bundleID: "no.uit.giella.keyboards.sme.keyboardlayout.sme",
        isEnabled: false
    )
    let unrelated = InputSource(id: "com.apple.keylayout.ABC", bundleID: "com.apple.keylayout.ABC")
    let sources = FixedInputSources(installed: [unrelated])
    sources.registrations[item.url] = [seSE]

    #expect(try sources.register(item) == [seSE])
    #expect(sources.registeredURLs == [item.url])
}

// [spec:tis:req:install.register/test]
@Test @MainActor func registerFailsWhenNoSourcesAppear() throws {
    let file = try temporaryDirectory().appending(path: "seSE.keylayout")
    try Data(keylayoutXML.utf8).write(to: file)
    let item = try InstallableItem(url: file)

    #expect(throws: InstallError.nothingRegistered(path: item.url.path)) {
        try FixedInputSources(installed: []).register(item)
    }
}

// [spec:tis:req:install.register/test]
@Test func keylayoutFileOwnsLayoutsWithItsName() {
    let item = InstallableItem(
        url: URL(fileURLWithPath: "/x.keylayout"), kind: .keyboardLayoutFile(name: "seSE"))
    #expect(item.owns(InputSource(type: .keyboardLayout, localizedName: "seSE")))
    #expect(!item.owns(InputSource(type: .inputMode, localizedName: "seSE")))
    #expect(!item.owns(InputSource(type: .keyboardLayout, localizedName: "seFI")))
}
