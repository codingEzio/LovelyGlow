import AppKit
import LovelyGlowCore
import Metal
import QuartzCore

struct GlowUniforms {
    var base: SIMD4<Float>
    var highlight: SIMD4<Float>
    var warmth: SIMD4<Float>
    var resolution: SIMD2<Float>
    var holeOrigin: SIMD2<Float>
    var holeSize: SIMD2<Float>
    var holeRadius: Float
    var lineWidth: Float
    var spread: Float
    var opacity: Float
    var travel: Float
    var breathe: Float
    var comet: Float
    var sheen: Float
    var reduceTransparency: Float
    var focusWeight: Float
    var occluderCount: Float
    var arrive: Float
    var occluder0: SIMD4<Float>
    var occluder1: SIMD4<Float>
    var occluder2: SIMD4<Float>
    var occluder3: SIMD4<Float>
    var occluder4: SIMD4<Float>
    var occluder5: SIMD4<Float>
    var occluder6: SIMD4<Float>
    var occluder7: SIMD4<Float>
}

struct GlowFrame {
    var layout: OverlayLayout
    var style: GlowStyle
    var scheme: GlowSchemeID
    var animation: GlowAnimationID
    var speed: CGFloat
    var role: GlowTargetRole
    var time: TimeInterval
    var presentTime: TimeInterval
    var arrive: CGFloat
    var reducedMotion: Bool
    var reduceTransparency: Bool
    var isDark: Bool
    var viewSize: CGSize
    var scale: CGFloat
}

@MainActor
final class GlowMetalRenderer {
    static let shared = GlowMetalRenderer()

    let device: MTLDevice?
    private let queue: MTLCommandQueue?
    private let pipeline: MTLRenderPipelineState?

    private init() {
        let device = MTLCreateSystemDefaultDevice()
        self.device = device
        queue = device?.makeCommandQueue()
        pipeline = GlowMetalRenderer.makePipeline(device: device)
    }

    var isReady: Bool { device != nil && queue != nil && pipeline != nil }

    func render(layer: CAMetalLayer, frame: GlowFrame, vertices: [SIMD2<Float>]) {
        guard isReady,
            let queue,
            let pipeline,
            !vertices.isEmpty,
            frame.viewSize.width > 1,
            frame.viewSize.height > 1,
            let drawable = layer.nextDrawable()
        else { return }

        let vertexBytes = vertices.count * MemoryLayout<SIMD2<Float>>.stride
        guard let command = queue.makeCommandBuffer() else { return }

        var uniforms = makeUniforms(frame: frame)
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = drawable.texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        guard let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        encoder.setRenderPipelineState(pipeline)
        // The rim has only a few quads. Copy them into this command buffer;
        // never overwrite geometry still being read by a prior GPU frame.
        encoder.setVertexBytes(vertices, length: vertexBytes, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GlowUniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        encoder.endEncoding()
        if frame.presentTime > 0 {
            command.present(drawable, atTime: frame.presentTime)
        } else {
            command.present(drawable)
        }
        command.commit()
    }

    static func ringVertices(hole: CGRect, band: CGFloat, viewSize: CGSize) -> [SIMD2<Float>] {
        guard viewSize.width > 1, viewSize.height > 1, band > 0 else { return [] }
        func clip(_ point: CGPoint) -> SIMD2<Float> {
            SIMD2(
                Float(point.x / viewSize.width * 2 - 1),
                Float(point.y / viewSize.height * 2 - 1)
            )
        }
        func quad(_ rect: CGRect) -> [SIMD2<Float>] {
            guard rect.width > 0.25, rect.height > 0.25 else { return [] }
            let bottomLeft = clip(CGPoint(x: rect.minX, y: rect.minY))
            let bottomRight = clip(CGPoint(x: rect.maxX, y: rect.minY))
            let topLeft = clip(CGPoint(x: rect.minX, y: rect.maxY))
            let topRight = clip(CGPoint(x: rect.maxX, y: rect.maxY))
            return [bottomLeft, bottomRight, topLeft, bottomRight, topRight, topLeft]
        }
        // One fill covers the hole’s inner corner fillets. Four edge strips wrap
        // the bounding box as a rectangle and miss macOS continuous corners.
        return quad(OverlayGeometry.rimFill(hole: hole, band: band))
    }

    private func makeUniforms(frame: GlowFrame) -> GlowUniforms {
        let scale = max(frame.scale, 1)
        let palette = frame.style.palette(isDark: frame.isDark, scheme: frame.scheme)
        let motion = GlowAnimationRegistry.evaluate(
            id: frame.animation,
            time: frame.time,
            speed: frame.speed,
            reducedMotion: frame.reducedMotion
        )
        let metalHole = WindowGeometry.metalTopLeft(rect: frame.layout.holeFrame, viewHeight: frame.viewSize.height)
        let occluders = frame.layout.occluders.prefix(8).map { rect in
            let metal = WindowGeometry.metalTopLeft(rect: rect, viewHeight: frame.viewSize.height)
            return SIMD4<Float>(
                Float(metal.minX * scale),
                Float(metal.minY * scale),
                Float(metal.width * scale),
                Float(metal.height * scale)
            )
        }
        func packed(_ index: Int) -> SIMD4<Float> {
            index < occluders.count ? occluders[index] : .zero
        }
        return GlowUniforms(
            base: palette.base.simd,
            highlight: palette.highlight.simd,
            warmth: palette.warmth.simd,
            resolution: SIMD2(Float(frame.viewSize.width * scale), Float(frame.viewSize.height * scale)),
            holeOrigin: SIMD2(Float(metalHole.minX * scale), Float(metalHole.minY * scale)),
            holeSize: SIMD2(Float(metalHole.width * scale), Float(metalHole.height * scale)),
            holeRadius: Float(frame.layout.holeRadius * scale),
            lineWidth: Float(max(frame.style.lineWidth, 1.2) * scale),
            spread: Float(max(frame.style.spread, 2) * scale),
            opacity: Float(frame.style.opacity),
            travel: Float(motion.travel),
            breathe: Float(motion.breathe),
            comet: Float(motion.comet),
            sheen: Float(motion.sheen),
            reduceTransparency: frame.reduceTransparency ? 1 : 0,
            focusWeight: frame.role == .focused ? 1 : 0.72,
            occluderCount: Float(occluders.count),
            arrive: Float(min(max(frame.arrive, 0), 1)),
            occluder0: packed(0),
            occluder1: packed(1),
            occluder2: packed(2),
            occluder3: packed(3),
            occluder4: packed(4),
            occluder5: packed(5),
            occluder6: packed(6),
            occluder7: packed(7)
        )
    }

    private static func makePipeline(device: MTLDevice?) -> MTLRenderPipelineState? {
        guard let device else { return nil }
        do {
            let library = try device.makeLibrary(source: GlowShaderSource.metal, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "glow_vertex")
            descriptor.fragmentFunction = library.makeFunction(name: "glow_fragment")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            return nil
        }
    }
}

extension RGBAColor {
    fileprivate var simd: SIMD4<Float> {
        SIMD4(Float(red), Float(green), Float(blue), Float(alpha))
    }
}
