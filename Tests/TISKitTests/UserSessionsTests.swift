import Testing

@testable import TISKit

// [spec:tis:req:session.console-user/test]
@Test func loginWindowAndNoUserMeanNoSession() {
    #expect(UserSessions.consoleUser(name: "loginwindow", uid: 0) == nil)
    #expect(UserSessions.consoleUser(name: nil, uid: 0) == nil)
    #expect(UserSessions.consoleUser(name: "", uid: 0) == nil)
    #expect(
        UserSessions.consoleUser(name: "ánde", uid: 502) == UserAccount(name: "ánde", uid: 502)
    )
}

// [spec:tis:req:session.console-user/test]
@Test func loggedInUsersComeFromSessionInfo() {
    let state: [String: Any] = [
        "Name": "brendan",
        "UID": 501,
        "SessionInfo": [
            ["kCGSSessionUserNameKey": "brendan", "kCGSSessionUserIDKey": 501],
            ["kCGSSessionUserNameKey": "ande", "kCGSSessionUserIDKey": 502],
            ["kCGSSessionIDKey": 260],
        ],
    ]
    #expect(
        UserSessions.accounts(fromConsoleUserState: state) == [
            UserAccount(name: "brendan", uid: 501), UserAccount(name: "ande", uid: 502),
        ]
    )
    #expect(UserSessions.accounts(fromConsoleUserState: [:]).isEmpty)
}

// [spec:tis:req:session.console-user/test]
@Test func consoleUserIsLoggedIn() {
    guard let console = UserSessions.consoleUser() else { return }
    #expect(UserSessions.loggedInUsers().contains(console))
}
