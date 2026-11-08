import CoreGraphics
import Testing
@testable import LovelyGlowCore

struct GlowArrivalTests {
    @Test func instantSnapsAndSeamlessFadesIn() {
        #expect(GlowArrivalID.instant.duration == 0)
        #expect(GlowArrivalID.seamless.duration == 0.16)
        #expect(GlowArrivalID.progress(elapsed: 0, duration: 0) == 1)
        #expect(GlowArrivalID.progress(elapsed: 0, duration: 0.16) == 0)
        #expect(GlowArrivalID.progress(elapsed: 0.16, duration: 0.16) == 1)
        let early = GlowArrivalID.progress(elapsed: 0.04, duration: 0.16)
        #expect(early > 0.5)
        #expect(GlowArrivalID(configValue: "seamless") == .seamless)
        #expect(GlowArrivalID(configValue: "mystery") == .instant)
    }

    @Test func lerpKeepsTheRimOnAStraightPath() {
        let from = CGRect(x: 40, y: 80, width: 200, height: 120)
        let to = CGRect(x: 140, y: 180, width: 400, height: 240)
        #expect(OverlayGeometry.lerp(from, to, t: 0) == from)
        #expect(OverlayGeometry.lerp(from, to, t: 1) == to)
        let mid = OverlayGeometry.lerp(from, to, t: 0.5)
        #expect(abs(mid.minX - 90) < 0.01)
        #expect(abs(mid.minY - 130) < 0.01)
        #expect(abs(mid.width - 300) < 0.01)
        #expect(abs(mid.height - 180) < 0.01)
    }

    @Test func travelDrawableStaysTheSizeOfTheBiggerWindow() {
        let from = CGRect(x: 40, y: 80, width: 200, height: 120)
        let to = CGRect(x: 900, y: 400, width: 300, height: 180)
        let pad: CGFloat = 20
        let size = GlowTravel.drawableSize(from: from, to: to, pad: pad)
        #expect(size.width == 340)
        #expect(size.height == 220)
        let union = OverlayGeometry.slackFrame(windowCocoa: from, style: .default)
            .union(OverlayGeometry.slackFrame(windowCocoa: to, style: .default))
        #expect(size.width * size.height < union.width * union.height)
        let panel = GlowTravel.panelFrame(drawn: from, size: size)
        #expect(panel.size == size)
        #expect(abs(panel.midX - from.midX) < 0.01)
        #expect(abs(panel.midY - from.midY) < 0.01)
    }

    @Test func springMatchesAt120HzAnd60Hz() {
        let from = CGRect(x: 0, y: 0, width: 200, height: 120)
        let to = CGRect(x: 400, y: 80, width: 320, height: 200)
        let fast = simulate(from: from, to: to, dt: 1.0 / 120, steps: 14)
        let slow = simulate(from: from, to: to, dt: 1.0 / 60, steps: 7)
        #expect(abs(fast.rect.minX - slow.rect.minX) < 3)
        #expect(abs(fast.rect.minY - slow.rect.minY) < 3)
        #expect(abs(fast.rect.width - slow.rect.width) < 3)
        #expect(fast.rect.minX > from.minX + 80)
        #expect(fast.rect.minX < to.minX)
    }

    @Test func retargetKeepsVelocityInsteadOfRestarting() {
        let start = GlowTravelState.at(CGRect(x: 0, y: 0, width: 200, height: 120))
        var state = start
        let first = CGRect(x: 300, y: 0, width: 200, height: 120)
        for _ in 0..<8 {
            state = GlowTravel.step(state: state, target: first, dt: 1.0 / 120)
        }
        #expect(state.vx > 0)
        let coast = state.vx
        let second = CGRect(x: 700, y: 0, width: 200, height: 120)
        state = GlowTravel.step(state: state, target: second, dt: 1.0 / 120)
        #expect(state.vx > coast * 0.5)
    }

    @Test func sameBoundsDoesNotCountAsANewHop() {
        let from = CGRect(x: 40, y: 80, width: 200, height: 120)
        #expect(GlowTravel.drawableSize(from: from, to: from, pad: 20) == CGSize(width: 240, height: 160))
        var state = GlowTravelState.at(from)
        state = GlowTravel.step(state: state, target: from, dt: 1.0 / 120)
        #expect(GlowTravel.isSettled(state, target: from))
    }

    @Test func springDoesNotOvershootTheTarget() {
        let from = CGRect(x: 0, y: 0, width: 200, height: 120)
        let to = CGRect(x: 400, y: 80, width: 320, height: 200)
        var state = GlowTravelState.at(from)
        for _ in 0..<48 {
            state = GlowTravel.step(state: state, target: to, dt: 1.0 / 120)
            #expect(state.x <= to.minX + 2)
            #expect(state.y <= to.minY + 2)
        }
        #expect(GlowTravel.isSettled(state, target: to))
    }

    @Test func springSettlesOnTheTarget() {
        let from = CGRect(x: 40, y: 80, width: 200, height: 120)
        let to = CGRect(x: 180, y: 140, width: 240, height: 150)
        let settled = simulate(from: from, to: to, dt: 1.0 / 120, steps: 48)
        #expect(GlowTravel.isSettled(settled, target: to))
        #expect(abs(settled.rect.minX - to.minX) < 0.5)
        #expect(abs(settled.rect.width - to.width) < 0.5)
    }

    private func simulate(from: CGRect, to: CGRect, dt: Double, steps: Int) -> GlowTravelState {
        var state = GlowTravelState.at(from)
        for _ in 0..<steps {
            state = GlowTravel.step(state: state, target: to, dt: dt)
        }
        return state
    }
}
