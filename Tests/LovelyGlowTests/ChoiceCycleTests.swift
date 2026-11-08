import Testing
@testable import LovelyGlowCore

struct ChoiceCycleTests {
    @Test func lookAndMotionWrapAround() {
        #expect(ChoiceCycle.step(GlowSchemeID.violetBloom, in: GlowSchemeID.allCases, by: 1) == .auroraTeal)
        #expect(ChoiceCycle.step(GlowSchemeID.custom, in: GlowSchemeID.allCases, by: 1) == .violetBloom)
        #expect(ChoiceCycle.step(GlowSchemeID.violetBloom, in: GlowSchemeID.allCases, by: -1) == .custom)
        #expect(
            ChoiceCycle.step(GlowAnimationID.orbitBreathe, in: GlowAnimationID.allCases, by: 1) == .still
        )
        #expect(ChoiceCycle.step(GlowAnimationID.still, in: GlowAnimationID.allCases, by: -1) == .orbitBreathe)
    }
}
