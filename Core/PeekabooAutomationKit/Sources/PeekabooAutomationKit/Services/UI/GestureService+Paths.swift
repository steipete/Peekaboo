import CoreGraphics
import Foundation
import PeekabooFoundation

extension GestureService {
    func linearPath(from start: CGPoint, to end: CGPoint, steps: Int) -> [CGPoint] {
        guard steps > 1 else { return [end] }
        return (1...steps).map { step in
            let progress = Double(step) / Double(steps)
            let x = start.x + ((end.x - start.x) * progress)
            let y = start.y + ((end.y - start.y) * progress)
            return CGPoint(x: x, y: y)
        }
    }

    func buildGesturePath(
        from start: CGPoint,
        to end: CGPoint,
        duration: Int,
        steps: Int,
        profile: MouseMovementProfile) -> HumanMousePath
    {
        let distance = hypot(end.x - start.x, end.y - start.y)
        switch profile {
        case .linear:
            return HumanMousePath(points: self.linearPath(from: start, to: end, steps: steps), duration: duration)
        case let .human(configuration):
            let generator = HumanMousePathGenerator(
                start: start,
                target: end,
                distance: distance,
                duration: duration,
                stepsHint: steps,
                configuration: configuration)
            return generator.generate()
        }
    }
}

extension MouseMovementProfile {
    var logDescription: String {
        switch self {
        case .linear:
            "linear"
        case .human:
            "human"
        }
    }
}

struct HumanMousePath {
    let points: [CGPoint]
    let duration: Int
}

struct HumanMousePathGenerator {
    let start: CGPoint
    let target: CGPoint
    let distance: CGFloat
    let duration: Int
    let stepsHint: Int
    let configuration: HumanMouseProfileConfiguration

    func generate() -> HumanMousePath {
        var rng = HumanMouseRandom(seed: self.configuration.randomSeed)
        var current = self.start
        var velocity = CGVector(dx: 0, dy: 0)
        var wind = CGVector(dx: 0, dy: 0)
        var samples: [CGPoint] = []

        let resolvedDuration = self.resolvedDuration()
        let minimumSamples = max(stepsHint, Int(Double(resolvedDuration) / 8.0))
        let settleRadius = max(self.configuration.settleRadius, min(self.distance * 0.08, 24))

        var overshootTarget: CGPoint?
        if Self.shouldOvershoot(
            distance: self.distance,
            probability: self.configuration.overshootProbability,
            rng: &rng)
        {
            overshootTarget = self.makeOvershootTarget(distance: self.distance, rng: &rng)
        }
        var currentTarget = overshootTarget ?? self.target
        var overshootConsumed = overshootTarget == nil

        // Wind/gravity integration gives human profile moves small curves while seeded tests stay deterministic.
        for _ in 0..<max(minimumSamples, 24) {
            let delta = CGVector(dx: currentTarget.x - current.x, dy: currentTarget.y - current.y)
            let distanceToTarget = max(0.001, hypot(delta.dx, delta.dy))
            let gravityMagnitude = Self.gravity(for: distanceToTarget)
            let gravity = CGVector(
                dx: (delta.dx / distanceToTarget) * gravityMagnitude,
                dy: (delta.dy / distanceToTarget) * gravityMagnitude)
            wind.dx = (wind.dx * 0.8) + (rng.nextSignedUnit() * Self.windMagnitude(for: distanceToTarget))
            wind.dy = (wind.dy * 0.8) + (rng.nextSignedUnit() * Self.windMagnitude(for: distanceToTarget))

            velocity.dx = (velocity.dx + wind.dx + gravity.dx) * 0.88
            velocity.dy = (velocity.dy + wind.dy + gravity.dy) * 0.88

            current.x += velocity.dx
            current.y += velocity.dy
            current = self.applyJitter(point: current, rng: &rng)
            samples.append(current)

            if distanceToTarget <= settleRadius {
                if overshootConsumed {
                    break
                } else {
                    currentTarget = self.target
                    overshootConsumed = true
                }
            }
        }

        samples.append(self.target)
        return HumanMousePath(points: samples, duration: resolvedDuration)
    }

    private func resolvedDuration() -> Int {
        if self.duration > 0 {
            return self.duration
        }

        let distanceFactor = log2(Double(self.distance) + 1) * 90
        let perPixel = Double(self.distance) * 0.45
        let estimate = 220 + distanceFactor + perPixel
        return min(max(Int(estimate), 250), 1600)
    }

    private func applyJitter(point: CGPoint, rng: inout HumanMouseRandom) -> CGPoint {
        let amplitude = Double(self.configuration.jitterAmplitude)
        return CGPoint(
            x: point.x + (rng.nextSignedUnit() * amplitude),
            y: point.y + (rng.nextSignedUnit() * amplitude))
    }

    private func makeOvershootTarget(distance: CGFloat, rng: inout HumanMouseRandom) -> CGPoint {
        let overshootFraction = rng.nextDouble(in: self.configuration.overshootFractionRange)
        let extraDistance = distance * CGFloat(overshootFraction)
        let direction = CGVector(dx: self.target.x - self.start.x, dy: self.target.y - self.start.y)
        let length = max(0.001, hypot(direction.dx, direction.dy))
        let normalized = CGVector(dx: direction.dx / length, dy: direction.dy / length)
        return CGPoint(
            x: self.target.x + (normalized.dx * extraDistance),
            y: self.target.y + (normalized.dy * extraDistance))
    }

    private static func shouldOvershoot(
        distance: CGFloat,
        probability: Double,
        rng: inout HumanMouseRandom) -> Bool
    {
        guard distance > 120 else { return false }
        return rng.nextDouble() < probability
    }

    private static func gravity(for distance: CGFloat) -> Double {
        let clamped = min(max(distance, 1), 800)
        return log(Double(clamped) + 2) * 1.8
    }

    private static func windMagnitude(for distance: CGFloat) -> Double {
        let normalized = min(max(distance / 400, 0.1), 1.0)
        return 0.6 * Double(normalized)
    }
}

private struct HumanMouseRandom: RandomNumberGenerator {
    private var generator: SeededGenerator

    init(seed: UInt64?) {
        let resolvedSeed = seed ?? UInt64(Date().timeIntervalSinceReferenceDate * 1_000_000)
        self.generator = SeededGenerator(seed: resolvedSeed)
    }

    mutating func next() -> UInt64 {
        self.generator.next()
    }

    mutating func nextDouble() -> Double {
        Double(self.next()) / Double(UInt64.max)
    }

    mutating func nextSignedUnit() -> Double {
        (self.nextDouble() * 2) - 1
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let value = self.nextDouble()
        return (value * (range.upperBound - range.lowerBound)) + range.lowerBound
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x123_4567_89AB_CDEF : seed
    }

    mutating func next() -> UInt64 {
        self.state &+= 0x9E37_79B9_7F4A_7C15
        var z = self.state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
