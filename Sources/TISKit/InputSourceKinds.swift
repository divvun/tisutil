import Carbon

/// An enumeration over one family of TIS string constants.
///
/// `tisValue` is the constant's string as TIS reports it. `name` is the short
/// form tisutil prints and accepts. Values that were not known at build time
/// are kept in `unknown`, so a newer macOS cannot make a source unreadable.
public protocol TISConstant: Hashable, Sendable {
    static var known: [Self] { get }
    static func unknown(_ value: String) -> Self
    var tisValue: String { get }
    var name: String { get }
}

extension TISConstant {
    /// Accepts either the short name or the raw TIS value.
    public init(_ value: String) {
        self = Self.known.first { $0.name == value || $0.tisValue == value } ?? .unknown(value)
    }
}

// [spec:tis:req:kit.category-type]
public enum InputSourceCategory: TISConstant {
    case keyboard
    case palette
    case ink
    case unknown(String)

    public static let known: [Self] = [.keyboard, .palette, .ink]

    public var tisValue: String {
        switch self {
        case .keyboard: kTISCategoryKeyboardInputSource as String
        case .palette: kTISCategoryPaletteInputSource as String
        case .ink: kTISCategoryInkInputSource as String
        case .unknown(let value): value
        }
    }

    public var name: String {
        switch self {
        case .keyboard: "keyboard"
        case .palette: "palette"
        case .ink: "ink"
        case .unknown(let value): value
        }
    }
}

// [spec:tis:req:kit.category-type]
public enum InputSourceType: TISConstant {
    case keyboardLayout
    case inputMethod
    case inputMethodWithModes
    case inputMode
    case characterPalette
    case keyboardViewer
    case ink
    case unknown(String)

    public static let known: [Self] = [
        .keyboardLayout, .inputMethod, .inputMethodWithModes, .inputMode,
        .characterPalette, .keyboardViewer, .ink,
    ]

    public var tisValue: String {
        switch self {
        case .keyboardLayout: kTISTypeKeyboardLayout as String
        case .inputMethod: kTISTypeKeyboardInputMethodWithoutModes as String
        case .inputMethodWithModes: kTISTypeKeyboardInputMethodModeEnabled as String
        case .inputMode: kTISTypeKeyboardInputMode as String
        case .characterPalette: kTISTypeCharacterPalette as String
        case .keyboardViewer: kTISTypeKeyboardViewer as String
        case .ink: kTISTypeInk as String
        case .unknown(let value): value
        }
    }

    public var name: String {
        switch self {
        case .keyboardLayout: "keyboard-layout"
        case .inputMethod: "input-method"
        case .inputMethodWithModes: "input-method-with-modes"
        case .inputMode: "input-mode"
        case .characterPalette: "character-palette"
        case .keyboardViewer: "keyboard-viewer"
        case .ink: "ink"
        case .unknown(let value): value
        }
    }
}
