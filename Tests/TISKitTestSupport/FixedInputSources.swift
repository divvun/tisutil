import TISKit

public struct FixedInputSources: InputSourceProvider {
    public var installed: [InputSource]
    public var current: [CurrentInputSource: InputSource]
    public var languages: [String: InputSource]

    nonisolated public init(
        installed: [InputSource],
        current: [CurrentInputSource: InputSource] = [:],
        languages: [String: InputSource] = [:]
    ) {
        self.installed = installed
        self.current = current
        self.languages = languages
    }

    public func list(includeAllInstalled: Bool) -> [InputSource] {
        includeAllInstalled ? installed : installed.filter { $0.isEnabled == true }
    }

    public func current(_ which: CurrentInputSource) throws -> InputSource {
        guard let source = current[which] else {
            throw TISError.noResult(function: "current(\(which))")
        }
        return source
    }

    public func source(forLanguage language: String) throws -> InputSource {
        guard let source = languages[language] else {
            throw TISError.noSourceForLanguage(language)
        }
        return source
    }
}
