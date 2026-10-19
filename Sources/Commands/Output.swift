import ArgumentParser
import Foundation
import TISKit

// [spec:tis:req:cli.output-modes]
struct OutputOptions: ParsableArguments {
    @Flag(help: "Print JSON instead of human-readable text.")
    var json = false

    func render(_ sources: [InputSource]) throws -> String {
        json ? try jsonDocument(sources.map(InputSourceJSON.init)) : table(sources)
    }

    func render(_ source: InputSource) throws -> String {
        json ? try jsonDocument(InputSourceJSON(source)) : table([source])
    }
}

/// Commands return this and never print themselves, so tests can inspect
/// output and exit status without spawning a process.
// [spec:tis:req:cli.output-modes]
struct CommandOutput: Equatable {
    var stdout: String
    var status: ExitStatus = .success
    var diagnostic: String? = nil

    func emit() throws {
        if !stdout.isEmpty {
            print(stdout)
        }
        if let diagnostic {
            printDiagnostic(diagnostic)
        }
        if status != .success {
            throw ExitCode(status.rawValue)
        }
    }
}

// [spec:tis:req:cli.output-modes]
func printDiagnostic(_ message: String) {
    FileHandle.standardError.write(Data("tisutil: \(message)\n".utf8))
}

// [spec:tis:req:cli.output-modes]
func table(_ sources: [InputSource]) -> String {
    guard !sources.isEmpty else { return "" }
    let rows =
        [["ID", "TYPE", "STATE", "NAME"]]
        + sources.map { [$0.id ?? "-", $0.type?.name ?? "-", state($0), $0.localizedName ?? "-"] }
    let widths = (0..<3).map { column in rows.map { $0[column].count }.max() ?? 0 }
    return rows.map { row in
        (0..<3).map { row[$0].padding(widths[$0]) + "  " }.joined() + row[3]
    }.joined(separator: "\n")
}

func state(_ source: InputSource) -> String {
    switch (source.isSelected, source.isEnabled) {
    case (true?, _): "selected"
    case (_, true?): "enabled"
    case (_, false?): "disabled"
    default: "-"
    }
}
