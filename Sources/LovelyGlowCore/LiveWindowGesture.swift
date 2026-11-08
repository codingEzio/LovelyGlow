import Foundation

/// Keyboard + mouse chords that change a window frame without a focus change.
public enum LiveWindowGesture {
    /// Option/Alt plus a mouse button, used by Easy Move+Resize, BetterTouchTool,
    /// and similar “hold Option to resize” tools. Command+Option stays an app chord.
    public static func isOptionResize(optionDown: Bool, commandDown: Bool, mouseDown: Bool) -> Bool {
        optionDown && mouseDown && !commandDown
    }

    public static func isLayoutModifier(controlDown: Bool, optionDown: Bool) -> Bool {
        controlDown && optionDown
    }
}
