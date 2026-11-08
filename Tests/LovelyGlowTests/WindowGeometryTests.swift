import CoreGraphics
import Testing
@testable import LovelyGlowCore

struct WindowGeometryTests {
    @Test func cocoaAndCGRoundTripOnPrimaryDisplay() {
        let primaryHeight: CGFloat = 982
        let cg = CGRect(x: 120, y: 80, width: 640, height: 400)
        let cocoa = WindowGeometry.cocoaFrame(fromCG: cg, primaryHeight: primaryHeight)
        #expect(cocoa.origin.x == 120)
        #expect(cocoa.origin.y == primaryHeight - 80 - 400)
        #expect(cocoa.size == cg.size)
        #expect(WindowGeometry.cgBounds(fromCocoa: cocoa, primaryHeight: primaryHeight) == cg)
        let cocoaPoint = CGPoint(x: 140, y: cocoa.origin.y + 20)
        let cgPoint = WindowGeometry.cgPoint(fromCocoa: cocoaPoint, primaryHeight: primaryHeight)
        #expect(cgPoint.x == 140)
        #expect(cgPoint.y == cg.origin.y + cg.height - 20)
    }

    @Test func metalPixelsFlipAppKitYToTopLeft() {
        let viewHeight: CGFloat = 200
        let hole = CGRect(x: 10, y: 20, width: 100, height: 50)
        let metal = WindowGeometry.metalTopLeft(rect: hole, viewHeight: viewHeight)
        #expect(metal.origin.x == 10)
        #expect(metal.origin.y == 130)
        #expect(metal.size == hole.size)
    }

    @Test func statusBarWindowNumberDoesNotBecomeAWindowID() {
        #expect(WindowGeometry.cgWindowID(fromWindowNumber: 7) == 7)
        #expect(WindowGeometry.cgWindowID(fromWindowNumber: 0) == nil)
        #expect(WindowGeometry.cgWindowID(fromWindowNumber: -1) == nil)
        #expect(WindowGeometry.cgWindowID(fromWindowNumber: Int.min) == nil)
    }
}
