import ArgumentParser
import Foundation
import TISKit

struct DictationCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dictation",
        abstract: "Report on and change macOS dictation.",
        subcommands: [
            DictationStatusCommand.self, DictationLanguagesCommand.self,
            DictationEnableCommand.self, DictationDisableCommand.self,
            DictationAutoEnableCommand.self,
        ]
    )
}

/// A dictation command, run against the current user's dictation settings.
protocol DictationSettingsCommand: InputSourceCommand {
    @MainActor
    func execute(provider: some InputSourceProvider, settings: some DictationSettings) throws
        -> CommandOutput
}

extension DictationSettingsCommand {
    @MainActor
    func execute(provider: some InputSourceProvider) throws -> CommandOutput {
        try execute(provider: provider, settings: SystemDictationSettings())
    }
}

// [spec:tis:req:dictation.status+1]
func dictationReport(_ status: DictationStatus, json: Bool) throws -> String {
    if json {
        return try jsonDocument(DictationStatusJSON(status: status))
    }
    let onOff = { (value: Bool?) in value.map { $0 ? "on" : "off" } ?? "unknown" }
    let source =
        status.source.map { source in
            [
                source.isEnabled == true ? "enabled" : "disabled",
                source.isSelected == true ? "selected" : "not selected",
            ].joined(separator: ", ")
        } ?? "not installed"
    return [
        "Dictation:     \(onOff(status.isEnabled))",
        "Language:      \(status.language ?? "unknown")",
        "Input source:  \(source)",
        "Auto-enable:   \(onOff(status.autoEnable))",
    ].joined(separator: "\n")
}

// [spec:tis:req:dictation.status+1]
struct DictationStatusCommand: DictationSettingsCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show whether dictation is on, its language, and its input source."
    )

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions

    @MainActor
    func execute(provider: some InputSourceProvider, settings: some DictationSettings) throws
        -> CommandOutput
    {
        let status = try provider.dictationStatus(settings: settings)
        return CommandOutput(stdout: try dictationReport(status, json: output.json))
    }
}

// [spec:tis:req:dictation.status+1]
struct DictationStatusJSON: Encodable {
    var status: DictationStatus

    enum CodingKeys: String, CodingKey {
        case enabled, language, installed, source, autoEnable
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status.isEnabled, forKey: .enabled)
        try container.encode(status.language, forKey: .language)
        try container.encode(status.source != nil, forKey: .installed)
        try container.encode(status.source.map(InputSourceJSON.init), forKey: .source)
        try container.encode(status.autoEnable, forKey: .autoEnable)
    }
}

// [spec:tis:req:dictation.enable]
struct DictationEnableCommand: DictationSettingsCommand {
    static let configuration = CommandConfiguration(
        commandName: "enable",
        abstract: "Turn dictation on."
    )

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions
    @OptionGroup var waiting: WaitOptions

    @MainActor
    func execute(provider: some InputSourceProvider, settings: some DictationSettings) throws
        -> CommandOutput
    {
        try settings.turnDictation(on: true, timeout: waiting.timeout)
        return CommandOutput(
            stdout: try dictationReport(
                provider.dictationStatus(settings: settings), json: output.json)
        )
    }
}

// [spec:tis:req:dictation.enable]
struct DictationDisableCommand: DictationSettingsCommand {
    static let configuration = CommandConfiguration(
        commandName: "disable",
        abstract: "Turn dictation off."
    )

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions
    @OptionGroup var waiting: WaitOptions

    @MainActor
    func execute(provider: some InputSourceProvider, settings: some DictationSettings) throws
        -> CommandOutput
    {
        try settings.turnDictation(on: false, timeout: waiting.timeout)
        return CommandOutput(
            stdout: try dictationReport(
                provider.dictationStatus(settings: settings), json: output.json)
        )
    }
}

enum OnOff: String, ExpressibleByArgument, CaseIterable {
    case on, off
}

// [spec:tis:req:dictation.auto-enable]
struct DictationAutoEnableCommand: DictationSettingsCommand {
    static let configuration = CommandConfiguration(
        commandName: "auto-enable",
        abstract: "Print or set whether dictation auto-enables."
    )

    @OptionGroup var output: OutputOptions
    @OptionGroup var session: SessionOptions

    @Argument(help: "on or off. Without it, the current setting is printed.")
    var state: OnOff?

    @MainActor
    func execute(provider: some InputSourceProvider, settings: some DictationSettings) throws
        -> CommandOutput
    {
        if let state {
            try settings.changeAutoEnable(to: state == .on)
        }
        let on = try settings.autoEnable()
        return CommandOutput(
            stdout: output.json ? try jsonDocument(["autoEnable": on]) : (on ? "on" : "off")
        )
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
