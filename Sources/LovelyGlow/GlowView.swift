import AppKit
import LovelyGlowCore
import QuartzCore

struct GlowViewSettings: Equatable {
    var style: GlowStyle
    var scheme: GlowSchemeID
    var animation: GlowAnimationID
    var speed: CGFloat
    var role: GlowTargetRole
    var arrival: GlowArrivalID
}

final class GlowView: NSView {
    var onFrame: ((CFTimeInterval, CFTimeInterval) -> Void)?

    private var currentLayout: OverlayLayout?
    private var settings = GlowViewSettings(
        style: .default,
        scheme: .violetBloom,
        animation: .orbitBreathe,
        speed: GlowMotion.defaultSpeed,
        role: .focused,
        arrival: .instant
    )
    private var metalLayer: CAMetalLayer?
    private var cachedVertices: [SIMD2<Float>] = []
    private var cachedHole = CGRect.null
    private var cachedBand: CGFloat = 0
    private var cachedViewSize = CGSize.zero
    private var arriveStartedAt: CFTimeInterval?
    private var frameLink: CADisplayLink?
    private let fallbackLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        if let device = GlowMetalRenderer.shared.device, GlowMetalRenderer.shared.isReady {
            let metal = CAMetalLayer()
            metal.device = device
            metal.pixelFormat = .bgra8Unorm
            metal.isOpaque = false
            metal.framebufferOnly = true
            metal.contentsGravity = .resize
            metal.presentsWithTransaction = false
            metal.maximumDrawableCount = 3
            metal.displaySyncEnabled = true
            layer = metal
            metalLayer = metal
        } else {
            layer = CALayer()
            layer?.backgroundColor = NSColor.clear.cgColor
            fallbackLayer.fillColor = nil
            fallbackLayer.lineJoin = .round
            fallbackLayer.lineCap = .round
            layer?.addSublayer(fallbackLayer)
        }
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override var isOpaque: Bool { false }

    var needsContinuousFrames: Bool { currentLayout != nil }

    override func layout() {
        super.layout()
        syncDrawable()
        if frameLink == nil {
            render(time: CACurrentMediaTime(), presentTime: 0)
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        cachedHole = .null
        syncDrawable()
        if frameLink == nil {
            render(time: CACurrentMediaTime(), presentTime: 0)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if frameLink == nil {
            render(time: CACurrentMediaTime(), presentTime: 0)
        }
    }

    func apply(layout: OverlayLayout, settings: GlowViewSettings) {
        currentLayout = layout
        self.settings = settings
        cachedHole = .null
        if frameLink == nil {
            render(time: CACurrentMediaTime(), presentTime: 0)
        }
    }

    func updateSettings(_ settings: GlowViewSettings) {
        self.settings = settings
        cachedHole = .null
        if frameLink == nil {
            render(time: CACurrentMediaTime(), presentTime: 0)
        }
    }

    func playArrive(reducedMotion: Bool) {
        arriveStartedAt = reducedMotion || settings.arrival == .instant ? nil : CACurrentMediaTime()
        if frameLink == nil {
            render(time: CACurrentMediaTime(), presentTime: 0)
        }
    }

    func clearArrive() {
        arriveStartedAt = nil
    }

    func setDisplayLinkEnabled(_ enabled: Bool) {
        if enabled {
            startDisplayLink()
        } else {
            stopDisplayLink()
        }
    }

    func render(time: CFTimeInterval, presentTime: CFTimeInterval) {
        guard let currentLayout, bounds.width > 1, bounds.height > 1 else { return }
        if let metalLayer {
            renderMetal(layout: currentLayout, time: time, presentTime: presentTime, layer: metalLayer)
        } else {
            renderFallback(layout: currentLayout)
        }
    }

    private func startDisplayLink() {
        guard frameLink == nil else { return }
        let link = displayLink(target: self, selector: #selector(displayTick(_:)))
        let maximum = Float(window?.screen?.maximumFramesPerSecond ?? NSScreen.main?.maximumFramesPerSecond ?? 120)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: min(80, maximum), maximum: maximum, preferred: maximum)
        link.add(to: .main, forMode: .common)
        frameLink = link
    }

    private func stopDisplayLink() {
        frameLink?.invalidate()
        frameLink = nil
    }

    @objc private func displayTick(_ link: CADisplayLink) {
        let start = MotionDiagnostics.enabled ? CACurrentMediaTime() : 0
        let maximum = window?.screen?.maximumFramesPerSecond ?? NSScreen.main?.maximumFramesPerSecond ?? 120
        if link.preferredFrameRateRange.maximum != Float(maximum) {
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: Float(min(80, maximum)), maximum: Float(maximum), preferred: Float(maximum))
        }
        let time = link.targetTimestamp
        onFrame?(time, link.targetTimestamp - link.timestamp)
        guard frameLink === link else { return }
        let renderStart = MotionDiagnostics.enabled ? CACurrentMediaTime() : 0
        render(time: time, presentTime: time)
        if settings.role == .focused {
            MotionDiagnostics.frame(start: start, renderStart: renderStart, maximumHz: maximum)
        }
    }

    private func syncDrawable() {
        guard let metalLayer else { return }
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        metalLayer.contentsScale = scale
        let width = max(bounds.width, 1) * scale
        let height = max(bounds.height, 1) * scale
        if metalLayer.drawableSize != CGSize(width: width, height: height) {
            metalLayer.drawableSize = CGSize(width: width, height: height)
        }
    }

    private func renderMetal(
        layout: OverlayLayout, time: CFTimeInterval, presentTime: CFTimeInterval, layer: CAMetalLayer
    ) {
        let band = max(settings.style.spread, 2) + max(settings.style.lineWidth, 1.2) + 6
        if cachedHole != layout.holeFrame || cachedBand != band || cachedViewSize != bounds.size {
            cachedVertices = GlowMetalRenderer.ringVertices(
                hole: layout.holeFrame,
                band: band,
                viewSize: bounds.size
            )
            cachedHole = layout.holeFrame
            cachedBand = band
            cachedViewSize = bounds.size
        }
        let reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let arrive: CGFloat
        if settings.arrival == .instant || reducedMotion || arriveStartedAt == nil {
            arrive = 1
        } else if let arriveStartedAt {
            arrive = GlowArrivalID.progress(
                elapsed: time - arriveStartedAt,
                duration: settings.arrival.duration
            )
        } else {
            arrive = 1
        }
        GlowMetalRenderer.shared.render(
            layer: layer,
            frame: GlowFrame(
                layout: layout,
                style: settings.style,
                scheme: settings.scheme,
                animation: settings.animation,
                speed: settings.speed,
                role: settings.role,
                time: time,
                presentTime: presentTime,
                arrive: arrive,
                reducedMotion: reducedMotion,
                reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
                isDark: effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua,
                viewSize: bounds.size,
                scale: layer.contentsScale
            ),
            vertices: cachedVertices
        )
    }

    private func renderFallback(layout: OverlayLayout) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let palette = settings.style.palette(
            isDark: effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua,
            scheme: settings.scheme
        )
        fallbackLayer.frame = bounds
        fallbackLayer.path = OverlayGeometry.strokePath(
            hole: layout.holeFrame,
            holeRadius: layout.holeRadius,
            lineWidth: settings.style.lineWidth
        )
        fallbackLayer.lineWidth = settings.style.lineWidth
        fallbackLayer.strokeColor = palette.base.nsColor.withAlphaComponent(settings.style.opacity).cgColor
        fallbackLayer.shadowColor = palette.highlight.nsColor.cgColor
        fallbackLayer.shadowRadius = 3
        fallbackLayer.shadowOpacity = Float(settings.style.opacity * 0.7)
        fallbackLayer.shadowOffset = .zero
    }
}

extension RGBAColor {
    fileprivate var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
