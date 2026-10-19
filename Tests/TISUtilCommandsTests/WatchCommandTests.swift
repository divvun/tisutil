import ArgumentParser
import Foundation
import Testing

@testable import TISKit
@testable import TISUtilCommands

// [spec:tis:req:watch.json-lines/test]
@Test func jsonEventsAreOneObjectPerLine() throws {
    let selected = try eventLine(.selected(abc), json: true)
    let enabled = try eventLine(.enabled([abc, sme]), json: true)

    for line in [selected, enabled] {
        #expect(!line.contains("\n"))
        #expect(try JSONSerialization.jsonObject(with: Data(line.utf8)) is [String: Any])
    }

    let selectedObject = try #require(
        try JSONSerialization.jsonObject(with: Data(selected.utf8)) as? [String: Any]
    )
    #expect(selectedObject["event"] as? String == "selected")
    let source = try #require(selectedObject["source"] as? [String: Any])
    #expect(Set(source.keys) == Set(InputSourceJSON.CodingKeys.allCases.map(\.rawValue)))

    let enabledObject = try #require(
        try JSONSerialization.jsonObject(with: Data(enabled.utf8)) as? [String: Any]
    )
    #expect(enabledObject["event"] as? String == "enabled")
    #expect((enabledObject["sources"] as? [Any])?.count == 2)
}

// [spec:tis:req:watch.stream/test]
@Test func humanEventsNameTheSources() throws {
    #expect(try eventLine(.selected(abc), json: false).contains("com.apple.keylayout.ABC"))
    let enabled = try eventLine(.enabled([abc, sme]), json: false)
    #expect(enabled.contains("2 sources"))
    #expect(enabled.contains("no.divvun.keylayout.sme"))
}

// [spec:tis:req:watch.stream/test]
@Test func watchActsInTheTargetUsersSession() throws {
    let command = try #require(
        try TISUtil.parseAsRoot(["watch", "--json", "--user", "ande"]) as? Watch
    )
    #expect(command.session.user == "ande")
    #expect(command.output.json)
}
