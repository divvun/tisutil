import Carbon
import Testing

@testable import TISKit

// [spec:tis:req:kit.errors/test]
@Test func nonZeroStatusBecomesTypedError() {
    #expect(throws: TISError.status(OSStatus(paramErr), function: "TISSelectInputSource")) {
        try check(OSStatus(paramErr), "TISSelectInputSource")
    }
}

// [spec:tis:req:kit.errors/test]
@Test func zeroStatusDoesNotThrow() throws {
    try check(noErr, "TISEnableInputSource")
}

// [spec:tis:req:kit.errors/test]
@Test func errorDescriptionNamesFunctionAndStatus() {
    let error = TISError.status(-50, function: "TISDisableInputSource")
    #expect(error.description.contains("TISDisableInputSource"))
    #expect(error.description.contains("-50"))
}
