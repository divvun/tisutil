import Foundation
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
    /// Sources that `register(url:)` installs for each URL.
    public var registrations: [URL: [InputSource]] = [:]
    public private(set) var registeredURLs: [URL] = []
    public var layoutIDAliases = LayoutIDAliases.none
    /// How many pauses pass before a requested change takes effect, as when
    /// macOS waits for the user to allow it.
    public var pausesBeforeApplying = 0
    public private(set) var pauses = 0
    private var pendingChanges: [ChangeRequest] = []

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
        guard appliesChanges else { return }
        if pauses < pausesBeforeApplying {
            pendingChanges.append(ChangeRequest(change, id))
        } else {
            make(change, id: id)
        }
    }

    public func pause(seconds: Double) {
        pauses += 1
        if pauses >= pausesBeforeApplying {
            for request in pendingChanges {
                make(request.change, id: request.id)
            }
            pendingChanges = []
        }
    }

    private func make(_ change: InputSourceChange, id: String) {
        guard let index = installed.firstIndex(where: { $0.id == id }) else {
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

    public func register(url: URL) throws {
        registeredURLs.append(url)
        installed += registrations[url] ?? []
    }
}
