import ArgumentParser
import Foundation
import TISKit

struct DictationCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dictation",
        abstract: "Report on macOS dictation.",
        subcommands: [DictationStatusCommand.self, DictationLanguagesCommand.self]
    )
}

// [spec:tis:req:dictation.status]
struct DictationStatusCommand: InputSourceCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show whether dictation is enabled and selected, and whether it auto-enables."
    )

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions

    @MainActor
    func execute(provider: some InputSourceProvider) throws -> CommandOutput {
        let status = try provider.dictationStatus(autoEnable: Dictation.autoEnable())
        return CommandOutput(stdout: try report(status))
    }

    func report(_ status: DictationStatus) throws -> String {
        if output.json {
            return try jsonDocument(DictationStatusJSON(status: status))
        }
        let state =
            status.source.map { source in
                [
                    source.isEnabled == true ? "enabled" : "disabled",
                    source.isSelected == true ? "selected" : "not selected",
                ].joined(separator: ", ")
            } ?? "not installed"
        let autoEnable = status.autoEnable.map { $0 ? "on" : "off" } ?? "unknown"
        return "Dictation:    \(state)\nAuto-enable:  \(autoEnable)"
    }
}

// [spec:tis:req:dictation.status]
struct DictationStatusJSON: Encodable {
    var status: DictationStatus

    enum CodingKeys: String, CodingKey {
        case installed, source, autoEnable
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status.source != nil, forKey: .installed)
        try container.encode(status.source.map(InputSourceJSON.init), forKey: .source)
        try container.encode(status.autoEnable, forKey: .autoEnable)
    }
}

// [spec:tis:req:dictation.languages]
struct DictationLanguagesCommand: InputSourceCommand {
    static let configuration = CommandConfiguration(
        commandName: "languages",
        abstract: "List dictation languages and whether their on-device models are installed."
    )

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions

    @MainActor
    func execute(provider: some InputSourceProvider) throws -> CommandOutput {
        CommandOutput(stdout: try report(Dictation.languages()))
    }

    func report(_ languages: [DictationLanguage]) throws -> String {
        if output.json {
            return try jsonDocument(languages.map(DictationLanguageJSON.init))
        }
        guard !languages.isEmpty else { return "" }
        let width = max(languages.map(\.locale.count).max() ?? 0, "LOCALE".count)
        let rows = languages.map { language in
            let on = language.flags.filter(\.value).keys.sorted().joined(separator: ", ")
            return language.locale.padding(width) + "  "
                + (language.isInstalled ? "yes" : "no ").padding(9) + "  " + on
        }
        return (["LOCALE".padding(width) + "  " + "INSTALLED  FLAGS"] + rows).joined(
            separator: "\n")
    }
}

// [spec:tis:req:dictation.languages]
struct DictationLanguageJSON: Encodable {
    var language: DictationLanguage

    init(_ language: DictationLanguage) {
        self.language = language
    }

    enum CodingKeys: String, CodingKey {
        case locale, installed, flags
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(language.locale, forKey: .locale)
        try container.encode(language.isInstalled, forKey: .installed)
        try container.encode(language.flags, forKey: .flags)
    }
}
