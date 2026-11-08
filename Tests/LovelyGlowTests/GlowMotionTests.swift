import CoreGraphics
import Testing
@testable import LovelyGlowCore

struct GlowMotionTests {
    @Test func orbitTravelsAndWraps() {
        let start = GlowAnimationRegistry.evaluate(id: .orbit, time: 0, speed: 1, reducedMotion: false)
        let half = GlowAnimationRegistry.evaluate(id: .orbit, time: 3, speed: 1, reducedMotion: false)
        let full = GlowAnimationRegistry.evaluate(id: .orbit, time: 6, speed: 1, reducedMotion: false)
        #expect(abs(start.travel - 0) < 0.001)
        #expect(abs(half.travel - 0.5) < 0.001)
        #expect(abs(full.travel - 0) < 0.001)
        #expect(start.comet > 0)
    }

    @Test func fasterSpeedShortensTheOrbit() {
        let slow = GlowAnimationRegistry.evaluate(id: .orbit, time: 3, speed: 1, reducedMotion: false)
        let fast = GlowAnimationRegistry.evaluate(id: .orbit, time: 3, speed: 2, reducedMotion: false)
        #expect(abs(slow.travel - 0.5) < 0.001)
        #expect(abs(fast.travel - 0) < 0.001)
    }

    @Test func breatheOscillatesWithoutTravel() {
        let low = GlowAnimationRegistry.evaluate(id: .breathe, time: 0, speed: 1, reducedMotion: false)
        let high = GlowAnimationRegistry.evaluate(id: .breathe, time: 2.5, speed: 1, reducedMotion: false)
        #expect(low.travel == 0)
        #expect(low.comet == 0)
        #expect(high.breathe > low.breathe)
    }

    @Test func cometIsTighterThanOrbit() {
        let orbit = GlowAnimationRegistry.evaluate(id: .orbit, time: 1, speed: 1, reducedMotion: false)
        let comet = GlowAnimationRegistry.evaluate(id: .comet, time: 1, speed: 1, reducedMotion: false)
        #expect(comet.comet > orbit.comet)
    }

    @Test func chosenMotionPlaysEvenWhenTheSystemAsksForReduceMotion() {
        let moving = GlowAnimationRegistry.evaluate(id: .orbit, time: 3, speed: 1, reducedMotion: true)
        #expect(abs(moving.travel - 0.5) < 0.001)
        #expect(!GlowAnimationID.still.loops)
        #expect(GlowAnimationID.orbit.loops)
    }

    @Test func everyPluginIsRegisteredOnce() {
        let ids = GlowAnimationRegistry.plugins.map(\.id)
        #expect(Set(ids).count == GlowAnimationID.allCases.count)
        #expect(Set(ids) == Set(GlowAnimationID.allCases))
    }
}

struct PerimeterTests {
    private let hole = CGRect(x: 100, y: 80, width: 400, height: 240)
    private let radius: CGFloat = 16

    @Test func orbitStartsAtMidLeftAndHitsEachSide() {
        let left = Perimeter.phase(point: CGPoint(x: hole.minX, y: hole.midY), hole: hole, radius: radius)
        let bottom = Perimeter.phase(point: CGPoint(x: hole.midX, y: hole.minY), hole: hole, radius: radius)
        let right = Perimeter.phase(point: CGPoint(x: hole.maxX, y: hole.midY), hole: hole, radius: radius)
        let top = Perimeter.phase(point: CGPoint(x: hole.midX, y: hole.maxY), hole: hole, radius: radius)
        #expect(abs(left) < 0.03)
        #expect(bottom > left)
        #expect(right > bottom)
        #expect(top > right)
        #expect(bottom > 0.15 && bottom < 0.35)
        #expect(right > 0.4 && right < 0.6)
        #expect(top > 0.65 && top < 0.85)
    }
}

struct GlowSchemeTests {
    @Test func researchedSchemesStayDistinct() {
        #expect(GlowSchemeCatalog.all.map(\.id).count == GlowSchemeID.allCases.count - 1)
        for scheme in GlowSchemeCatalog.all {
            #expect(scheme.light.base != scheme.dark.base, "\(scheme.id.rawValue) should shift for dark")
            #expect(!scheme.source.isEmpty)
            #expect(scheme.light.highlight != scheme.light.base)
        }
    }

    @Test func customSchemeUsesTheDocumentColors() {
        let custom = GlowStyle.default.derivedPalette(isDark: true)
        let named = GlowSchemeCatalog.palette(id: .cyberNeon, isDark: true, custom: custom)
        let fallback = GlowSchemeCatalog.palette(id: .custom, isDark: true, custom: custom)
        #expect(named.base != custom.base)
        #expect(fallback == custom)
    }
}