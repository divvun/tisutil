import TISKit

public final class FixedInputSources: InputSourceProvider {
    public struct ChangeRequest: Equatable, Sendable {
        public var change: InputSourceChange
        public var id: String

        public init(_ change: InputSourceChange, _ id: String) {
            self.change = change
            self.id = id
        }
    }

    public var installed: [InputSource]
    public var current: [CurrentInputSource: InputSource]
    public var languages: [String: InputSource]
    /// When false, `requestChange` records the request but leaves the source
    /// unchanged, as TIS sometimes does.
    public var appliesChanges = true
    /// Source IDs that `requestChange` replaces, as TIS does for some
    /// third-party layouts in the process that changed them.
    public var idsAfterChange: [String: String] = [:]
    public private(set) var changeRequests: [ChangeRequest] = []

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

    public func requestChange(_ change: InputSourceChange, id: String) throws {
        changeRequests.append(ChangeRequest(change, id))
        guard appliesChanges, let index = installed.firstIndex(where: { $0.id == id }) else {
            return
        }
        switch change {
        case .enable: installed[index].isEnabled = true
        case .disable: installed[index].isEnabled = false
        case .select: installed[index].isSelected = true
        case .deselect: installed[index].isSelected = false
        }
        if let newID = idsAfterChange[id] {
            installed[index].id = newID
        }
    }
}
