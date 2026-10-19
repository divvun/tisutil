import ArgumentParser
import Testing

@testable import TISKit
@testable import TisutilCommands

// [spec:tis:req:cli.exit-codes/test]
@Test func exitCodeValuesAreFixed() {
    #expect(ExitStatus.allCases.map(\.rawValue) == [0, 1, 2, 64, 77])
}

// [spec:tis:req:cli.exit-codes/test]
@Test func tisErrorsMapToExitCodes() {
    #expect(ExitStatus(for: TISError.notFound(id: "x")) == .notFound)
    #expect(ExitStatus(for: TISError.noSourceForLanguage("se")) == .notFound)
    #expect(ExitStatus(for: TISError.status(-50, function: "TISSelectInputSource")) == .failure)
    #expect(ExitStatus(for: TISError.noResult(function: "TISCreateInputSourceList")) == .failure)
}

// [spec:tis:req:cli.exit-codes/test]
@Test func usageErrorsExitWith64() {
    #expect(ExitStatus(for: ValidationError("bad")) == .usage)
    do {
        _ = try Tisutil.parseAsRoot(["--no-such-flag"])
        Issue.record("parsing an unknown flag succeeded")
    } catch {
        #expect(ExitStatus(for: error) == .usage)
    }
}

// [spec:tis:req:cli.exit-codes/test]
@Test func helpListsEveryExitCode() {
    let help = Tisutil.helpMessage()
    for status in ExitStatus.allCases {
        #expect(help.contains("\(status.rawValue)"))
        #expect(help.contains(status.meaning))
    }
}
