import AppKit
import QuartzCore

/// Continue ticking while the overlay is hidden; a window-bound link can stop
/// delivering frames there and never notice the next lid movement.
@MainActor final class FoldDisplayClock: NSObject {
    private var link: CADisplayLink?
    private let onFrame: () -> Void
    init(screen: NSScreen, onFrame: @escaping () -> Void) {
        self.onFrame = onFrame
        super.init()
        let link = screen.displayLink(target: self, selector: #selector(frame))
        let maximum = Float(screen.maximumFramesPerSecond)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: min(60, maximum), maximum: maximum, preferred: maximum)
        self.link = link
        link.add(to: .main, forMode: .common)
    }
    @objc private func frame(_ link: CADisplayLink) { onFrame() }
    func stop() { link?.invalidate(); link = nil }
}
