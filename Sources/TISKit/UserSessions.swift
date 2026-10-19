import Foundation
import SystemConfiguration

public struct UserAccount: Hashable, Sendable {
    public var name: String
    public var uid: uid_t

    public init(name: String, uid: uid_t) {
        self.name = name
        self.uid = uid
    }

    public static func named(_ name: String) -> UserAccount? {
        guard let entry = getpwnam(name) else { return nil }
        return UserAccount(name: String(cString: entry.pointee.pw_name), uid: entry.pointee.pw_uid)
    }

    /// The account of the effective user, which is what TIS acts for.
    public static var effective: UserAccount {
        let uid = geteuid()
        let name = getpwuid(uid).map { String(cString: $0.pointee.pw_name) } ?? String(uid)
        return UserAccount(name: name, uid: uid)
    }
}

public enum UserSessions {
    // [spec:tis:req:session.console-user]
    public static func consoleUser() -> UserAccount? {
        var uid: uid_t = 0
        let name = SCDynamicStoreCopyConsoleUser(nil, &uid, nil) as String?
        return consoleUser(name: name, uid: uid)
    }

    // [spec:tis:req:session.console-user]
    static func consoleUser(name: String?, uid: uid_t) -> UserAccount? {
        guard let name, !name.isEmpty, name != "loginwindow" else { return nil }
        return UserAccount(name: name, uid: uid)
    }

    /// Every user with a GUI login session, including users switched away
    /// from with fast user switching.
    public static func loggedInUsers() -> [UserAccount] {
        guard let store = SCDynamicStoreCreate(nil, "tisutil" as CFString, nil, nil),
            let state = SCDynamicStoreCopyValue(store, "State:/Users/ConsoleUser" as CFString)
                as? [String: Any]
        else {
            return []
        }
        return accounts(fromConsoleUserState: state)
    }

    static func accounts(fromConsoleUserState state: [String: Any]) -> [UserAccount] {
        let sessions = state["SessionInfo"] as? [[String: Any]] ?? []
        return sessions.compactMap { session in
            guard let name = session["kCGSSessionUserNameKey"] as? String,
                let uid = session["kCGSSessionUserIDKey"] as? Int
            else {
                return nil
            }
            return UserAccount(name: name, uid: uid_t(uid))
        }
    }
}
