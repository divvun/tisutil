import Foundation

public enum InstallError: Error, Equatable, Sendable {
    case unrecognisedItem(path: String)
    case nothingRegistered(path: String)
    case notPermitted(path: String)
    case copyFailed(path: String, reason: String)
}

extension InstallError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unrecognisedItem(let path):
            "\(path) is not a .keylayout file, a keyboard layout bundle or an input method"
        case .nothingRegistered(let path):
            "TIS registered \(path), but none of its input sources are installed"
        case .notPermitted(let path):
            "no permission to write \(path)"
        case .copyFailed(let path, let reason):
            "could not copy to \(path): \(reason)"
        }
    }
}

/// A keyboard layout or input method on disk that TIS can register.
public struct InstallableItem: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case keyboardLayoutFile(name: String)
        case keyboardLayoutBundle(bundleID: String)
        case inputMethod(bundleID: String)
    }

    public var url: URL
    public var kind: Kind

    /// Info.plist keys that only input method bundles carry.
    static let inputMethodKeys = [
        "InputMethodConnectionName", "InputMethodServerControllerClass", "ComponentInputModeDict",
        "tsInputMethodCharacterRepertoireKey",
    ]

    public init(url: URL, kind: Kind) {
        self.url = url.standardizedFileURL
        self.kind = kind
    }

    // [spec:tis:req:install.kind-detect]
    public init(url: URL) throws {
        self.url = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: self.url.path, isDirectory: &isDirectory),
            let kind = isDirectory.boolValue
                ? Self.bundleKind(at: self.url) : Self.fileKind(at: self.url)
        else {
            throw InstallError.unrecognisedItem(path: url.path)
        }
        self.kind = kind
    }

    static func fileKind(at url: URL) -> Kind? {
        guard let name = keyboardLayoutName(at: url) else { return nil }
        return .keyboardLayoutFile(name: name)
    }

    // [spec:tis:req:install.kind-detect]
    static func bundleKind(at url: URL) -> Kind? {
        let contents = url.appending(path: "Contents")
        guard let info = infoPlist(ofBundleAt: url),
            let bundleID = info["CFBundleIdentifier"] as? String
        else {
            return nil
        }
        if inputMethodKeys.contains(where: { info[$0] != nil }) {
            return .inputMethod(bundleID: bundleID)
        }
        let resources =
            (try? FileManager.default.contentsOfDirectory(
                at: contents.appending(path: "Resources"),
                includingPropertiesForKeys: nil
            )) ?? []
        return resources.contains { $0.pathExtension == "keylayout" }
            ? .keyboardLayoutBundle(bundleID: bundleID) : nil
    }

    /// The `name` attribute of a keyboard layout document's root `keyboard` element.
    // [spec:tis:req:install.kind-detect]
    static func keyboardLayoutName(at url: URL) -> String? {
        guard let parser = XMLParser(contentsOf: url) else { return nil }
        let delegate = RootElementReader()
        parser.delegate = delegate
        parser.parse()
        guard delegate.element == "keyboard" else { return nil }
        return delegate.attributes["name"]
    }

    public var directoryName: String {
        switch kind {
        case .inputMethod: "Input Methods"
        case .keyboardLayoutFile, .keyboardLayoutBundle: "Keyboard Layouts"
        }
    }

    /// Copies the item into the matching directory of `library` and returns
    /// the copy. The copy is staged on the same volume and moved into place
    /// with a rename, so TIS never sees a partly copied item.
    // [spec:tis:req:install.place+1]
    public func place(inLibrary library: URL) throws -> InstallableItem {
        let fileManager = FileManager.default
        let directory = library.appending(path: directoryName)
        let destination = directory.appending(path: url.lastPathComponent)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let staging = try fileManager.url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: directory,
                create: true
            )
            defer { try? fileManager.removeItem(at: staging) }
            let staged = staging.appending(path: url.lastPathComponent)
            try fileManager.copyItem(at: url, to: staged)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: staged)
            } else {
                try fileManager.moveItem(at: staged, to: destination)
            }
        } catch let error as CocoaError
            where error.code == .fileWriteNoPermission || error.code == .fileReadNoPermission
        {
            throw InstallError.notPermitted(path: destination.path)
        } catch {
            throw InstallError.copyFailed(
                path: destination.path, reason: error.localizedDescription)
        }
        return InstallableItem(url: destination, kind: kind)
    }

    // [spec:tis:req:install.register]
    public func owns(_ source: InputSource) -> Bool {
        switch kind {
        case .keyboardLayoutBundle(let bundleID), .inputMethod(let bundleID):
            source.bundleID == bundleID
        case .keyboardLayoutFile(let name):
            source.type == .keyboardLayout && source.localizedName == name
        }
    }
}

private final class RootElementReader: NSObject, XMLParserDelegate {
    var element: String?
    var attributes: [String: String] = [:]

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        element = elementName
        self.attributes = attributes
        parser.abortParsing()
    }
}

extension InputSourceProvider {
    /// Enables every enable-capable source in `sources` and, with `select`,
    /// selects the first select-capable one; returns the sources afterwards.
    // [spec:tis:req:install.enable]
    // [spec:tis:req:mutate.force-enable+1]
    public func activate(
        _ sources: [InputSource],
        enable: Bool,
        select: Bool,
        forceEnable: Bool = false,
        timeout: Double = InputSourceChange.defaultTimeout
    ) throws -> [InputSource] {
        var result = sources
        if enable {
            for (index, source) in result.enumerated() {
                guard let id = source.id, source.isEnableCapable == true else { continue }
                result[index] = try apply(
                    .enable, to: id, forceEnable: forceEnable, timeout: timeout)
            }
        }
        if select,
            let index = result.firstIndex(where: { $0.isSelectCapable == true && $0.id != nil })
        {
            result[index] = try apply(
                .select,
                to: result[index].id!,
                enablingFirst: true,
                forceEnable: forceEnable,
                timeout: timeout
            )
        }
        return result
    }

    /// Registers `item` and returns the installed sources it provides.
    // [spec:tis:req:install.register]
    public func register(_ item: InstallableItem) throws -> [InputSource] {
        try register(url: item.url)
        let sources = try list(includeAllInstalled: true).filter(item.owns)
        guard !sources.isEmpty else {
            throw InstallError.nothingRegistered(path: item.url.path)
        }
        return sources
    }
}
