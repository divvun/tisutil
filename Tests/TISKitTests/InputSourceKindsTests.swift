import Carbon
import Testing

@testable import TISKit

// [spec:tis:req:kit.category-type/test]
@Test func knownTypesRoundTripThroughTISValue() {
    for type in InputSourceType.known {
        #expect(InputSourceType(type.tisValue) == type)
        #expect(InputSourceType(type.name) == type)
    }
    for category in InputSourceCategory.known {
        #expect(InputSourceCategory(category.tisValue) == category)
        #expect(InputSourceCategory(category.name) == category)
    }
}

// [spec:tis:req:kit.category-type/test]
@Test func typeMapsTISConstants() {
    #expect(InputSourceType(kTISTypeKeyboardLayout as String) == .keyboardLayout)
    #expect(InputSourceType(kTISTypeKeyboardInputMode as String) == .inputMode)
    #expect(InputSourceCategory(kTISCategoryKeyboardInputSource as String) == .keyboard)
}

// [spec:tis:req:kit.category-type/test]
@Test func unknownValuesAreKeptVerbatim() {
    let type = InputSourceType("TISTypeSomethingNew")
    #expect(type == .unknown("TISTypeSomethingNew"))
    #expect(type.tisValue == "TISTypeSomethingNew")
    #expect(type.name == "TISTypeSomethingNew")

    let source = InputSource { key in
        key == kTISPropertyInputSourceType ? "TISTypeSomethingNew" as NSString : nil
    }
    #expect(source.type == .unknown("TISTypeSomethingNew"))
}
