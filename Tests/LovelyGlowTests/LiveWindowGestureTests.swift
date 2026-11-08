import Testing
@testable import LovelyGlowCore

struct LiveWindowGestureTests {
    @Test func optionMouseDownIsAResizeChord() {
        #expect(
            LiveWindowGesture.isOptionResize(optionDown: true, commandDown: false, mouseDown: true)
        )
        #expect(
            !LiveWindowGesture.isOptionResize(optionDown: true, commandDown: false, mouseDown: false)
        )
        #expect(
            !LiveWindowGesture.isOptionResize(optionDown: true, commandDown: true, mouseDown: true)
        )
        #expect(
            !LiveWindowGesture.isOptionResize(optionDown: false, commandDown: false, mouseDown: true)
        )
    }

    @Test func controlOptionIsALayoutModifier() {
        #expect(LiveWindowGesture.isLayoutModifier(controlDown: true, optionDown: true))
        #expect(!LiveWindowGesture.isLayoutModifier(controlDown: true, optionDown: false))
        #expect(!LiveWindowGesture.isLayoutModifier(controlDown: false, optionDown: true))
    }
}
