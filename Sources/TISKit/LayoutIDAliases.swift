import Foundation

/// Pairs the two IDs of each keyboard layout in a bundle: the ID the bundle's
/// Info.plist declares (`KLInfo_<name>` → `TISInputSourceID`) and the ID TIS
/// generates, `<bundle ID>.keylayout.<name>` with some characters removed.
/// TIS reports either one from one call to the next.
// [spec:tis:req:kit.lookup+2]
public struct LayoutIDAliases: Equatable, Sendable {
    private var keysByDeclaredID: [String: String] = [:]
    private var bundleIDs: Set<String> = []

    public static let none = LayoutIDAliases()

    public init() {}

    /// `layouts` maps each `KLInfo_` layout name to the ID it declares.
    public mutating func add(bundleID: String, layouts: [String: String]) {
        bundleIDs.insert(bundleID)
        for (name, id) in layouts {
            keysByDeclaredID[id] = Self.key(bundleID: bundleID, name: name)
        }
    }

    // [spec:tis:req:kit.lookup+2]
    public static func scanning(_ directories: [URL]) -> LayoutIDAliases {
        var aliases = LayoutIDAliases()
        for directory in directories {
            let items =
                (try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: nil
                )) ?? []
            for bundle in items where bundle.pathExtension == "bundle" {
                guard let info = infoPlist(ofBundleAt: bundle),
                    let bundleID = info["CFBundleIdentifier"] as? String
                else {
                    continue
                }
                let layouts = info.reduce(into: [String: String]()) { layouts, entry in
                    guard entry.key.hasPrefix("KLInfo_"),
                        let id = (entry.value as? [String: Any])?["TISInputSourceID"] as? String
                    else {
                        return
                    }
                    layouts[String(entry.key.dropFirst("KLInfo_".count))] = id
                }
                if !layouts.isEmpty {
                    aliases.add(bundleID: bundleID, layouts: layouts)
                }
            }
        }
        return aliases
    }

    /// The layouts in `~/Library/Keyboard Layouts` and `/Library/Keyboard Layouts`.
    public static var installed: LayoutIDAliases {
        let home =
            FileManager.default.homeDirectory(forUser: UserAccount.effective.name)
            ?? FileManager.default.homeDirectoryForCurrentUser
        return scanning([
            home.appending(path: "Library/Keyboard Layouts"),
            URL(fileURLWithPath: "/Library/Keyboard Layouts"),
        ])
    }

    // [spec:tis:req:kit.lookup+2]
    public func areSameLayout(_ first: String, _ second: String) -> Bool {
        guard let firstKey = key(for: first), let secondKey = key(for: second) else {
            return false
        }
        return firstKey == secondKey
    }

    func key(for id: String) -> String? {
        if let key = keysByDeclaredID[id] {
            return key
        }
        for bundleID in bundleIDs {
            let prefix = bundleID + ".keylayout."
            if id.hasPrefix(prefix) {
                return Self.key(bundleID: bundleID, name: String(id.dropFirst(prefix.count)))
            }
        }
        return nil
    }

    /// TIS drops some characters from a layout name when it generates an ID
    /// (`Workman-P Extended` becomes `Workman-PExtended`), so names compare by
    /// letters and digits alone, without regard to case.
    static func key(bundleID: String, name: String) -> String {
        bundleID + "\n" + String(name.lowercased().filter { $0.isLetter || $0.isNumber })
    }
}

func infoPlist(ofBundleAt url: URL) -> [String: Any]? {
    guard let data = try? Data(contentsOf: url.appending(path: "Contents/Info.plist")) else {
        return nil
    }
    return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
}
