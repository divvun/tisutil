import ArgumentParser

public struct Tisutil: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "tisutil",
        abstract: "Query and manage macOS text input sources: keyboard layouts and input methods."
    )

    public init() {}
}
