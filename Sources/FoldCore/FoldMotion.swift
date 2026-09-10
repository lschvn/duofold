import Foundation

public enum FoldStyle: String, CaseIterable, Codable, Sendable {
    case silk = "Silk", shade = "Shade", frost = "Frost"
    public var index: Float { switch self { case .silk: return 0; case .shade: return 1; case .frost: return 2 } }
}

public struct FoldConfiguration: Codable, Equatable, Sendable {
    public var style: FoldStyle = .silk
    public var clearAngle: Double = 100
    public var closedAngle: Double = 8
    public var perspective: Double = 0.65
    public var blur: Double = 0.65
    public var shadow: Double = 0.45
    public var response: Double = 0.055
    public init() {}
    public func progress(angle: Double) -> Double {
        guard angle.isFinite else { return 0 }
        let end = max(20, min(140, clearAngle))
        let start = max(0, min(end - 10, closedAngle))
        return min(1, max(0, (end - angle) / (end - start)))
    }
}

/// Closed-form critically damped tracking. Time-based, so 60/120 Hz behave alike.
/// No elastic overshoot: reversing a physical hinge must never bounce the desktop.
public struct FoldSpring: Sendable {
    public private(set) var value: Double = 0
    public private(set) var velocity: Double = 0
    public init() {}
    public mutating func reset(_ value: Double = 0) {
        self.value = min(1, max(0, value)); velocity = 0
    }
    @discardableResult public mutating func step(target: Double, dt: Double, response: Double) -> Double {
        guard target.isFinite, dt.isFinite, dt > 0 else { return value }
        let target = min(1, max(0, target))
        let dt = min(dt, 0.1), omega = 2 / max(0.012, response)
        let displacement = value - target, impulse = velocity + omega * displacement
        let decay = exp(-omega * dt)
        value = target + (displacement + impulse * dt) * decay
        velocity = (velocity - omega * impulse * dt) * decay
        if value < 0 || value > 1 { value = min(1, max(0, value)); velocity = 0 }
        if abs(value - target) < 0.00001 && abs(velocity) < 0.0001 { value = target; velocity = 0 }
        return value
    }
}

public enum LidReport {
    /// Apple's orientation report 1: report id, little-endian whole degrees.
    public static func angle(bytes: [UInt8]) -> Double? {
        guard bytes.count >= 3, bytes[0] == 1 else { return nil }
        let value = Int(bytes[1]) | (Int(bytes[2]) << 8)
        guard (0...180).contains(value) else { return nil }
        return Double(value)
    }
}
