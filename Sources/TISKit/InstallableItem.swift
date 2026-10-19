import Foundation

public enum InstallError: Error, Equatable, Sendable {
    case unrecognisedItem(path: String)
    case nothingRegistered(path: String)
}

extension InstallError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unrecognisedItem(let path):
            "\(path) is not a .keylayout file, a keyboard layout bundle or an input method"
        case .nothingRegistered(let path):
            "TIS registered \(path), but none of its input sources are installed"
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
        guard let data = try? Data(contentsOf: contents.appending(path: "Info.plist")),
            let info = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any],
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
