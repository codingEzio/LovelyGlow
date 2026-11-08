import Foundation
import LovelyGlowCore
import OSLog
import QuartzCore

/// Opt-in timing/state diagnostics. No titles, content, or screenshots.
@MainActor
enum MotionDiagnostics {
    private static let requested = ProcessInfo.processInfo.environment["LOVELYGLOW_DIAGNOSTICS"] == "1"
    // One short acceptance pass; never leave a diagnostic logging loop running.
    private static let deadline = CACurrentMediaTime() + 30
    static var enabled: Bool { requested && CACurrentMediaTime() < deadline }
    private static let logger = Logger(subsystem: "com.alex.LovelyGlow", category: "Motion")
    private static var started: CFTimeInterval?
    private static var previous: CFTimeInterval?
    private static var work: [Double] = []
    private static var gaps: [Double] = []
    private static var tracking: [Double] = []
    private static var rendering: [Double] = []

    static func decision(_ decision: FocusDecision) {
        guard enabled else { return }
        switch decision {
        case .hidden(let reason):
            logger.info("hidden reason=\(reason.rawValue, privacy: .public)")
            reset()  // Intentional hidden time is not a missed visible frame.
        case .visible(let presentation):
            logger.info(
                "visible window=\(presentation.focused?.window.cgWindowID ?? 0) targets=\(presentation.targets.count)")
        case .hold: break
        }
    }

    static func frame(start: CFTimeInterval, renderStart: CFTimeInterval, maximumHz: Int) {
        guard enabled else { return }
        if started == nil { started = start }
        if let previous { gaps.append((start - previous) * 1000) }
        previous = start
        work.append((CACurrentMediaTime() - start) * 1000)
        tracking.append((renderStart - start) * 1000)
        rendering.append((CACurrentMediaTime() - renderStart) * 1000)
        guard let started, start - started >= 1 else { return }
        let sorted = work.sorted()
        let p95 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        let hz = Double(work.count - 1) / (start - started)
        let trackingP95 = tracking.sorted()[min(tracking.count - 1, Int(Double(tracking.count) * 0.95))]
        let renderP95 = rendering.sorted()[min(rendering.count - 1, Int(Double(rendering.count) * 0.95))]
        logger.info(
            "frames observed_hz=\(hz) display_max_hz=\(maximumHz) work_p95_ms=\(p95) work_max_ms=\(sorted.last ?? 0) tracking_p95_ms=\(trackingP95) render_p95_ms=\(renderP95) max_gap_ms=\(gaps.max() ?? 0)"
        )
        reset()
    }

    private static func reset() {
        started = nil
        previous = nil
        work.removeAll(keepingCapacity: true)
        gaps.removeAll(keepingCapacity: true)
        tracking.removeAll(keepingCapacity: true)
        rendering.removeAll(keepingCapacity: true)
    }
}
