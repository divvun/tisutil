import ArgumentParser
import Foundation
import Testing

@testable import TISKit
@testable import TISUtilCommands

let abc = InputSource(
    id: "com.apple.keylayout.ABC",
    category: .keyboard,
    type: .keyboardLayout,
    localizedName: "ABC",
    languages: ["en"],
    unicodeKeyLayoutDataSize: 4096,
    isEnabled: true,
    isSelected: true
)

let sme = InputSource(
    id: "no.divvun.keylayout.sme",
    type: .keyboardLayout,
    localizedName: "Northern Sámi",
    isEnabled: true,
    isSelected: false
)

func decodeJSON(_ text: String) throws -> Any {
    try JSONSerialization.jsonObject(with: Data(text.utf8))
}

// [spec:tis:req:cli.json-shape/test]
@Test func absentPropertiesArePrintedAsNull() throws {
    let object = try #require(
        try decodeJSON(jsonDocument(InputSourceJSON(InputSource(id: "bare")))) as? [String: Any]
    )

    #expect(Set(object.keys) == Set(InputSourceJSON.CodingKeys.allCases.map(\.rawValue)))
    #expect(object["id"] as? String == "bare")
    for key in object.keys where key != "id" {
        #expect(object[key] is NSNull, "\(key) should be null")
    }
}

// [spec:tis:req:cli.json-shape/test]
@Test func listAndSingleOutputShareFieldNames() throws {
    let options = try OutputOptions.parse(["--json"])
    let list = try #require(try decodeJSON(options.render([abc, sme])) as? [[String: Any]])
    let single = try #require(try decodeJSON(options.render(abc)) as? [String: Any])

    #expect(list.count == 2)
    #expect(Set(list[0].keys) == Set(single.keys))
    #expect(single["type"] as? String == "keyboard-layout")
    #expect(single["category"] as? String == "keyboard")
    #expect(single["unicodeKeyLayoutDataSize"] as? Int == 4096)
}

// [spec:tis:req:cli.output-modes/test]
@Test func humanOutputIsATable() throws {
    let options = try OutputOptions.parse([])
    let lines = try options.render([abc, sme]).split(separator: "\n")

    #expect(lines.count == 3)
    #expect(lines[0].hasPrefix("ID"))
    #expect(lines[1].contains("com.apple.keylayout.ABC") && lines[1].contains("selected"))
    #expect(lines[2].contains("Northern Sámi") && lines[2].contains("enabled"))
    #expect(throws: (any Error).self) { try decodeJSON(lines.joined(separator: "\n")) }
}

// [spec:tis:req:cli.output-modes/test]
@Test func jsonModePrintsOneDocument() throws {
    let options = try OutputOptions.parse(["--json"])
    #expect(try decodeJSON(options.render([abc, sme])) is [Any])
    #expect(try decodeJSON(options.render([])) is [Any])
    #expect(try decodeJSON(options.render(abc)) is [String: Any])
}

// [spec:tis:req:cli.output-modes/test]
@Test func nonSuccessStatusBecomesExitCode() {
    let output = CommandOutput(stdout: "", status: .notFound, diagnostic: nil)
    #expect(throws: ExitCode(2)) { try output.emit() }
}
