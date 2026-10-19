import ArgumentParser
import Testing

@testable import TISKit
@testable import TISUtilCommands

private let root = UserAccount(name: "root", uid: 0)
private let brendan = UserAccount(name: "brendan", uid: 501)
private let ande = UserAccount(name: "ande", uid: 502)
private let away = UserAccount(name: "away", uid: 503)

private func context(
    runningAs: UserAccount,
    console: UserAccount? = brendan,
    loggedIn: [UserAccount] = [brendan, ande]
) -> SessionContext {
    let accounts = [root, brendan, ande, away]
    return SessionContext(
        runningAs: runningAs,
        console: console,
        loggedIn: loggedIn,
        account: { name in accounts.first { $0.name == name } }
    )
}

// [spec:tis:req:session.reexec/test]
@Test func userRunsCommandsInPlace() throws {
    #expect(try route(user: nil, in: context(runningAs: brendan)) == .here)
    #expect(try route(user: "brendan", in: context(runningAs: brendan)) == .here)
}

// [spec:tis:req:session.reexec/test]
@Test func rootReexecutesAsTheConsoleUser() throws {
    #expect(try route(user: nil, in: context(runningAs: root)) == .reexec(as: brendan))
    #expect(throws: SessionError.noSession(nil)) {
        try route(user: nil, in: context(runningAs: root, console: nil))
    }
    #expect(try route(user: nil, in: context(runningAs: root, console: root)) == .here)
}

// [spec:tis:req:session.reexec/test]
@Test func rootReexecutesAsAnotherLoggedInUser() throws {
    #expect(try route(user: "ande", in: context(runningAs: root)) == .reexec(as: ande))
    #expect(throws: SessionError.noSession("away")) {
        try route(user: "away", in: context(runningAs: root))
    }
    #expect(throws: SessionError.unknownUser("nobody-here")) {
        try route(user: "nobody-here", in: context(runningAs: root))
    }
}

// [spec:tis:req:session.reexec/test]
@Test func reexecRunsAsTheUserInTheirBootstrapNamespace() {
    #expect(
        reexecArguments(
            as: ande, executable: "/usr/local/bin/tisutil", arguments: ["list", "--json"])
            == [
                "asuser", "502", "/usr/bin/sudo", "-u", "ande", "--", "/usr/local/bin/tisutil",
                "list", "--json",
            ]
    )
}

// [spec:tis:req:session.privilege/test]
@Test func otherUsersNeedRoot() {
    #expect(throws: SessionError.notPermitted("ande")) {
        try route(user: "ande", in: context(runningAs: brendan))
    }
    #expect(ExitStatus(for: SessionError.notPermitted("ande")) == .noPermission)
    #expect(ExitStatus(for: SessionError.noSession(nil)) == .noPermission)
    #expect(ExitStatus(for: SessionError.unknownUser("x")) == .usage)
}

// [spec:tis:req:session.reexec/test]
@Test func everyInputSourceCommandTakesUser() throws {
    for arguments in [
        ["list"], ["current"], ["show", "x"], ["enable", "x"], ["disable", "x"], ["select", "x"],
        ["deselect", "x"],
    ] {
        let command = try #require(
            try TISUtil.parseAsRoot(arguments + ["--user", "ande"]) as? any InputSourceCommand
        )
        #expect(command.session.user == "ande")
    }
}
