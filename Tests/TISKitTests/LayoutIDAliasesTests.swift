import Foundation
import Testing

@testable import TISKit

private func keyboardLayouts(_ bundles: [String: [String: Any]]) throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(
        path: "tisutil-\(UUID().uuidString)")
    for (name, info) in bundles {
        let contents = directory.appending(path: "\(name)/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appending(path: "Info.plist"))
    }
    return directory
}

// [spec:tis:req:kit.lookup+2/test]
@Test func scanningPairsDeclaredAndGeneratedIDs() throws {
    let directory = try keyboardLayouts([
        "Workman.bundle": [
            "CFBundleIdentifier": "org.sil.ukelele.keyboardlayout.workman",
            "KLInfo_Workman": [
                "TISInputSourceID": "org.sil.ukelele.keyboardlayout.workman.workman"
            ],
            "KLInfo_Workman-P Extended": [
                "TISInputSourceID": "org.sil.ukelele.keyboardlayout.workman.workman-pextended"
            ],
        ],
        "sme.bundle": [
            "CFBundleIdentifier": "no.uit.giella.keyboards.sme.keyboardlayout.sme",
            "KLInfo_seSE": [
                "TISInputSourceID": "no.uit.giella.keyboards.sme.keyboardlayout.sme.seSE"
            ],
        ],
        "NoDeclaredIDs.bundle": ["CFBundleIdentifier": "com.example.plain"],
        "notabundle.txt": ["CFBundleIdentifier": "com.example.ignored"],
    ])
    let aliases = LayoutIDAliases.scanning([directory])

    #expect(
        aliases.areSameLayout(
            "org.sil.ukelele.keyboardlayout.workman.keylayout.Workman",
            "org.sil.ukelele.keyboardlayout.workman.workman"
        )
    )
    #expect(
        aliases.areSameLayout(
            "org.sil.ukelele.keyboardlayout.workman.keylayout.Workman-PExtended",
            "org.sil.ukelele.keyboardlayout.workman.workman-pextended"
        )
    )
    #expect(
        aliases.areSameLayout(
            "no.uit.giella.keyboards.sme.keyboardlayout.sme.keylayout.seSE",
            "no.uit.giella.keyboards.sme.keyboardlayout.sme.seSE"
        )
    )
}

// [spec:tis:req:kit.lookup+2/test]
@Test func differentLayoutsAndUnknownBundlesAreNotAliases() {
    var aliases = LayoutIDAliases()
    aliases.add(
        bundleID: "org.sil.ukelele.keyboardlayout.workman",
        layouts: [
            "Workman": "org.sil.ukelele.keyboardlayout.workman.workman",
            "Workman-P": "org.sil.ukelele.keyboardlayout.workman.workman-p",
        ]
    )

    #expect(
        !aliases.areSameLayout(
            "org.sil.ukelele.keyboardlayout.workman.keylayout.Workman",
            "org.sil.ukelele.keyboardlayout.workman.workman-p"
        )
    )
    #expect(!aliases.areSameLayout("com.example.keylayout.A", "com.example.a"))
    #expect(!LayoutIDAliases.none.areSameLayout("x.keylayout.Workman", "x.workman"))
}
