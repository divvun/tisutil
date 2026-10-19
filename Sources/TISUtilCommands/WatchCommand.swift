import ArgumentParser
import Foundation
import TISKit

// [spec:tis:req:watch.stream]
struct Watch: SessionCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print an event each time the selected or enabled input sources change.",
        discussion: "Runs until interrupted. With --json, each event is one JSON object per line."
    )

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions

    func run() throws {
        let json = output.json
        MainActor.assumeIsolated {
            let provider = SystemInputSources()
            let watcher = InputSourceWatcher()
            watcher.start { kind in
                do {
                    writeLine(try eventLine(provider.event(for: kind), json: json))
                } catch {
                    printDiagnostic("\(error)")
                }
            }
            withExtendedLifetime(watcher) {
                RunLoop.main.run()
            }
        }
    }
}

/// Writes straight to the file descriptor, so each event reaches a pipe as
/// soon as it happens rather than when a stdio buffer fills.
// [spec:tis:req:watch.json-lines]
func writeLine(_ line: String) {
    FileHandle.standardOutput.write(Data((line + "\n").utf8))
}

// [spec:tis:req:watch.json-lines]
func eventLine(_ event: InputSourceEvent, json: Bool) throws -> String {
    guard json else {
        return switch event {
        case .selected(let source):
            "selected  \(source.id ?? "-")  \(source.localizedName ?? "-")"
        case .enabled(let sources):
            "enabled   \(sources.count) sources: "
                + sources.map { $0.id ?? "-" }.joined(separator: ", ")
        }
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(EventJSON(event)), as: UTF8.self)
}

// [spec:tis:req:watch.json-lines]
struct EventJSON: Encodable {
    var event: InputSourceEvent

    init(_ event: InputSourceEvent) {
        self.event = event
    }

    enum CodingKeys: String, CodingKey {
        case event, source, sources
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch event {
        case .selected(let source):
            try container.encode("selected", forKey: .event)
            try container.encode(InputSourceJSON(source), forKey: .source)
        case .enabled(let sources):
            try container.encode("enabled", forKey: .event)
            try container.encode(sources.map(InputSourceJSON.init), forKey: .sources)
        }
    }
}
