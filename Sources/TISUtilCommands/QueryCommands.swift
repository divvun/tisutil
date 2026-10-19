import ArgumentParser
import TISKit

// [spec:tis:req:query.list]
struct List: InputSourceCommand {
    static let configuration = CommandConfiguration(
        abstract: "List input sources. Only enabled sources are listed unless --all is given."
    )

    @OptionGroup var output: OutputOptions

    @Flag(help: "Include sources that are installed but not enabled.")
    var all = false

    @Option(
        help: "Only sources in this category: keyboard, palette or ink.",
        transform: InputSourceCategory.init
    )
    var category: InputSourceCategory?

    @Option(
        help: """
            Only sources of this type: keyboard-layout, input-method, \
            input-method-with-modes, input-mode, character-palette, keyboard-viewer or ink.
            """,
        transform: InputSourceType.init
    )
    var type: InputSourceType?

    @Option(help: "Only the source with exactly this ID.")
    var id: String?

    @Option(name: .customLong("bundle-id"), help: "Only sources from this bundle.")
    var bundleID: String?

    @Option(help: "Only sources for this BCP 47 language tag; se also matches se-NO.")
    var language: String?

    @Flag(inversion: .prefixedNo, help: "Only enabled, or with --no-enabled, disabled sources.")
    var enabled: Bool?

    @Flag(inversion: .prefixedNo, help: "Only selected, or with --no-selected, unselected sources.")
    var selected: Bool?

    var filter: InputSourceFilter {
        InputSourceFilter(
            category: category,
            type: type,
            id: id,
            bundleID: bundleID,
            language: language,
            isEnabled: enabled,
            isSelected: selected,
            includeAllInstalled: all
        )
    }

    @MainActor
    func execute(provider: some InputSourceProvider) throws -> CommandOutput {
        let sources = try provider.list(matching: filter)
        guard !sources.isEmpty else {
            return CommandOutput(
                stdout: try output.render(sources),
                status: .notFound,
                diagnostic: "no input source matches the filter"
            )
        }
        return CommandOutput(stdout: try output.render(sources))
    }
}

// [spec:tis:req:query.current]
struct Current: InputSourceCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show the current keyboard input source."
    )

    @OptionGroup var output: OutputOptions

    @Flag(help: "Show the current keyboard layout.")
    var layout = false

    @Flag(help: "Show the current ASCII-capable source, or with --layout, layout.")
    var ascii = false

    @Option(help: "Show the source macOS uses for this BCP 47 language tag.")
    var language: String?

    func validate() throws {
        if language != nil && (layout || ascii) {
            throw ValidationError("--language cannot be combined with --layout or --ascii.")
        }
    }

    var which: CurrentInputSource {
        switch (layout, ascii) {
        case (false, false): .keyboard
        case (true, false): .keyboardLayout
        case (false, true): .asciiCapableKeyboard
        case (true, true): .asciiCapableKeyboardLayout
        }
    }

    @MainActor
    func execute(provider: some InputSourceProvider) throws -> CommandOutput {
        let source =
            if let language {
                try provider.source(forLanguage: language)
            } else {
                try provider.current(which)
            }
        return CommandOutput(stdout: try output.render(source))
    }
}

// [spec:tis:req:query.show]
struct Show: InputSourceCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show every property of one input source."
    )

    @OptionGroup var output: OutputOptions

    @Argument(help: "The input source ID, for example com.apple.keylayout.ABC.")
    var id: String

    @MainActor
    func execute(provider: some InputSourceProvider) throws -> CommandOutput {
        let source = try provider.source(id: id)
        return CommandOutput(
            stdout: output.json ? try jsonDocument(InputSourceJSON(source)) : detail(source)
        )
    }
}

// [spec:tis:req:query.show]
func detail(_ source: InputSource) -> String {
    let fields: [(String, String)] = [
        ("ID", source.id ?? "-"),
        ("Name", source.localizedName ?? "-"),
        ("Category", source.category?.name ?? "-"),
        ("Type", source.type?.name ?? "-"),
        ("Bundle ID", source.bundleID ?? "-"),
        ("Input mode ID", source.inputModeID ?? "-"),
        ("Languages", source.languages?.joined(separator: ", ") ?? "-"),
        ("Icon image URL", source.iconImageURL?.absoluteString ?? "-"),
        ("Layout data", source.unicodeKeyLayoutDataSize.map { "present, \($0) bytes" } ?? "absent"),
        ("ASCII-capable", yesNo(source.isASCIICapable)),
        ("Enable-capable", yesNo(source.isEnableCapable)),
        ("Select-capable", yesNo(source.isSelectCapable)),
        ("Enabled", yesNo(source.isEnabled)),
        ("Selected", yesNo(source.isSelected)),
    ]
    let width = (fields.map(\.0.count).max() ?? 0) + 1
    return fields.map { "\(($0.0 + ":").padding(width))  \($0.1)" }.joined(separator: "\n")
}

private func yesNo(_ value: Bool?) -> String {
    value.map { $0 ? "yes" : "no" } ?? "-"
}
