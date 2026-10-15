import Foundation
import XCTest
@testable import EulerCore

final class EMathTests: XCTestCase {
    func testExponentialInitialValueAndSemigroup() {
        for rate in [-0.8, 0, 0.4, 1.0] {
            XCTAssertEqual(EMath.exponential(initial: 3, rate: rate, time: 0), 3)
            let direct = EMath.exponential(initial: 3, rate: rate, time: 2.5)
            let staged = EMath.exponential(
                initial: EMath.exponential(initial: 3, rate: rate, time: 1),
                rate: rate,
                time: 1.5
            )
            XCTAssertEqual(direct, staged, accuracy: 1e-12)
        }
        XCTAssertEqual(EMath.exponential(initial: 0, rate: 1_000, time: 1_000), 0)
    }

    func testExponentialDerivativeIsProportionalToCurrentAmount() {
        let step = 1e-5
        for time in [0.0, 1, 3] {
            let rate = 0.7
            let derivative = (
                EMath.exponential(initial: 2, rate: rate, time: time + step)
                - EMath.exponential(initial: 2, rate: rate, time: time - step)
            ) / (2 * step)
            XCTAssertEqual(derivative, rate * EMath.exponential(initial: 2, rate: rate, time: time), accuracy: 1e-8)
        }
    }

    func testDecayHalfLifeAndMonotonicity() {
        let decay = 0.6
        let halfLife = log(2) / decay
        XCTAssertEqual(EMath.envelope(decay: decay, time: halfLife), 0.5, accuracy: 1e-14)
        XCTAssertEqual(EMath.envelope(decay: decay, time: 2 * halfLife), 0.25, accuracy: 1e-14)
        XCTAssertEqual(EMath.envelope(decay: 0, time: 100), 1)
        var previous = 1.0
        for index in 0...500 {
            let current = EMath.envelope(decay: decay, time: Double(index) / 20)
            XCTAssertTrue((0...1).contains(current))
            XCTAssertLessThanOrEqual(current, previous)
            previous = current
        }
    }

    func testDampedSignalStaysWithinEnvelopeAndHasCorrectPitch() {
        for index in 0...2_000 {
            let time = Double(index) / 2_000
            let signal = EMath.dampedSignal(amplitude: 2, decay: 0.9, frequency: 7, time: time)
            XCTAssertLessThanOrEqual(abs(signal), 2 * EMath.envelope(decay: 0.9, time: time) + 1e-14)
        }
        XCTAssertEqual(EMath.dampedSignal(decay: 0, frequency: 4, time: 0), 1)
        XCTAssertEqual(EMath.dampedSignal(decay: 0, frequency: 4, time: 0.0625), 0, accuracy: 1e-14)
        XCTAssertEqual(EMath.dampedSignal(decay: 0, frequency: 4, time: 0.125), -1, accuracy: 1e-14)
        XCTAssertEqual(EMath.dampedSignal(decay: 0, frequency: 4, time: 0.25), 1, accuracy: 1e-14)
    }

    func testPhasorNormPeriodicityAndEulerIdentity() {
        for index in -1_000...1_000 {
            let angle = Double(index) / 25
            let point = EMath.phasor(angle: angle)
            XCTAssertEqual(point.x * point.x + point.y * point.y, 1, accuracy: 1e-14)
            let turned = EMath.phasor(angle: angle + 2 * .pi)
            XCTAssertEqual(point.x, turned.x, accuracy: 1e-14)
            XCTAssertEqual(point.y, turned.y, accuracy: 1e-14)
        }
        let halfTurn = EMath.phasor(angle: .pi)
        XCTAssertEqual(halfTurn.x + 1, 0, accuracy: 1e-14)
        XCTAssertEqual(halfTurn.y, 0, accuracy: 1e-14)
    }

    func testPhasorCompositionIsComplexMultiplication() {
        let first = EMath.phasor(angle: 0.7)
        let second = EMath.phasor(angle: -2.1)
        let combined = EMath.phasor(angle: -1.4)
        XCTAssertEqual(first.x * second.x - first.y * second.y, combined.x, accuracy: 1e-14)
        XCTAssertEqual(first.x * second.y + first.y * second.x, combined.y, accuracy: 1e-14)
    }

    func testTuningOctavesAndEqualRatios() {
        XCTAssertEqual(EMath.frequency(semitones: 0), 220)
        XCTAssertEqual(EMath.frequency(semitones: 12), 440, accuracy: 1e-12)
        XCTAssertEqual(EMath.frequency(semitones: -12), 110, accuracy: 1e-12)
        let ratio = EMath.frequency(base: 1, semitones: 1)
        for note in -24...24 {
            let lower = EMath.frequency(semitones: Double(note))
            let higher = EMath.frequency(semitones: Double(note + 1))
            XCTAssertEqual(higher / lower, ratio, accuracy: 1e-14)
        }
        XCTAssertEqual(EMath.frequency(base: 1, semitones: 3.5) * EMath.frequency(base: 1, semitones: -3.5), 1, accuracy: 1e-14)
    }

    func testSpiralEqualAngleRatiosAndScaleRotationEquivalence() {
        let increment = 0.8
        let growth = 0.23
        let ratio = EMath.spiralRadius(growth: growth, angle: increment)
        for step in -20...20 {
            let angle = Double(step) / 3
            let first = EMath.spiralRadius(scale: 2, growth: growth, angle: angle)
            let second = EMath.spiralRadius(scale: 2, growth: growth, angle: angle + increment)
            XCTAssertEqual(second / first, ratio, accuracy: 1e-14)
        }
        let scaled = EMath.spiralRadius(scale: 2 * ratio, growth: growth, angle: 1.2)
        let rotated = EMath.spiralRadius(scale: 2, growth: growth, angle: 1.2 + increment)
        XCTAssertEqual(scaled, rotated, accuracy: 1e-14)
        XCTAssertEqual(EMath.spiralRadius(scale: 0, growth: 1_000, angle: 1_000), 0)
    }

    func testDerangementsAgainstExhaustivePermutations() {
        // Independent enumeration checks the finite population result, including
        // the empty permutation, rather than repeating the core recurrence.
        for count in 0...8 {
            var permutation = Array(0..<count)
            var total = 0
            var derangements = 0
            enumeratePermutations(&permutation, at: 0) { candidate in
                total += 1
                if !candidate.enumerated().contains(where: { $0.offset == $0.element }) {
                    derangements += 1
                }
            }
            XCTAssertEqual(EMath.derangementProbability(count: count), Double(derangements) / Double(total), accuracy: 1e-14)
        }
    }

    func testDerangementsConvergeWithoutFactorialOverflow() {
        XCTAssertEqual(EMath.derangementProbability(count: 1), 0)
        XCTAssertEqual(EMath.derangementProbability(count: 2), 0.5)
        XCTAssertEqual(EMath.derangementProbability(count: 3), 1.0 / 3, accuracy: 1e-14)
        for count in [20, 100, 1_000, Int.max] {
            XCTAssertEqual(EMath.derangementProbability(count: count), 1 / exp(1), accuracy: 1e-14)
        }
    }

    func testFixedPointsUsesZeroBasedAssignments() {
        XCTAssertEqual(EMath.fixedPoints([]), 0)
        XCTAssertEqual(EMath.fixedPoints([0]), 1)
        XCTAssertEqual(EMath.fixedPoints([0, 1, 2, 3]), 4)
        XCTAssertEqual(EMath.fixedPoints([1, 0, 3, 2]), 0)
        XCTAssertEqual(EMath.fixedPoints([0, 2, 1, 3]), 2)
    }

    func testShuffleAlwaysProducesBijections() {
        var generator = SeededGenerator(seed: 17)
        for count in 0...50 {
            for _ in 0..<100 {
                XCTAssertEqual(EMath.shuffle(count: count, using: &generator).sorted(), Array(0..<count))
            }
        }
    }

    func testShuffleSamplesAllFourPersonPermutationsEvenly() {
        var generator = SeededGenerator(seed: 0x1234)
        var frequencies: [[Int]: Int] = [:]
        let samples = 48_000
        for _ in 0..<samples {
            frequencies[EMath.shuffle(count: 4, using: &generator), default: 0] += 1
        }
        XCTAssertEqual(frequencies.count, 24)
        let expected = Double(samples) / 24
        let chiSquared = frequencies.values.reduce(0.0) { result, observed in
            let residual = Double(observed) - expected
            return result + residual * residual / expected
        }
        // A fixed seed makes this a reproducible bias regression check, not a
        // occasionally failing random test. A modulo-biased or partial shuffle
        // will also fail the permutation coverage or frequency check.
        XCTAssertLessThan(chiSquared, 60)
    }

    func testShuffleMatchesHatProbabilityAndExpectedFixedPointCount() {
        var generator = SeededGenerator(seed: 0xABCDEF)
        let samples = 40_000
        var none = 0
        var fixedTotal = 0
        for _ in 0..<samples {
            let fixed = EMath.fixedPoints(EMath.shuffle(count: 8, using: &generator))
            fixedTotal += fixed
            if fixed == 0 { none += 1 }
        }
        XCTAssertEqual(Double(none) / Double(samples), EMath.derangementProbability(count: 8), accuracy: 0.012)
        XCTAssertEqual(Double(fixedTotal) / Double(samples), 1, accuracy: 0.025)
    }

    func testNormalDensitySymmetryScaleAndUnitMass() {
        let center = EMath.normalDensity(x: 0)
        XCTAssertEqual(center, 0.3989422804014327, accuracy: 1e-14)
        for index in 0...100 {
            let x = Double(index) / 20
            XCTAssertEqual(EMath.normalDensity(x: x), EMath.normalDensity(x: -x), accuracy: 1e-14)
            XCTAssertEqual(EMath.normalDensity(x: 3 + 2 * x, mean: 3, sigma: 2) * 2, EMath.normalDensity(x: x), accuracy: 1e-14)
            XCTAssertLessThanOrEqual(EMath.normalDensity(x: x), center)
        }
        // Numerical quadrature checks normalization independently of the closed form.
        let step = 0.001
        let mass = (-8_000...8_000).reduce(0.0) { $0 + EMath.normalDensity(x: Double($1) * step) * step }
        XCTAssertEqual(mass, 1, accuracy: 1e-10)
    }

    func testNormalSamplesHaveStandardMomentsAndTails() {
        var generator = SeededGenerator(seed: 0x9876)
        let samples = 100_000
        var total = 0.0
        var squares = 0.0
        var positive = 0
        var tails = 0
        var previous = 0.0
        var serialProducts = 0.0
        for index in 0..<samples {
            let value = EMath.normalSample(using: &generator)
            XCTAssertTrue(value.isFinite)
            total += value
            squares += value * value
            if value > 0 { positive += 1 }
            if abs(value) > 2 { tails += 1 }
            if index > 0 { serialProducts += previous * value }
            previous = value
        }
        let mean = total / Double(samples)
        let variance = squares / Double(samples) - mean * mean
        XCTAssertEqual(mean, 0, accuracy: 0.015)
        XCTAssertEqual(variance, 1, accuracy: 0.03)
        XCTAssertEqual(Double(positive) / Double(samples), 0.5, accuracy: 0.008)
        XCTAssertEqual(Double(tails) / Double(samples), 0.0455002639, accuracy: 0.003)
        XCTAssertEqual(serialProducts / Double(samples - 1), 0, accuracy: 0.02)
    }

    func testSamplingEndpointGeneratorsStayFinite() {
        for bits in [UInt64.min, UInt64.max] {
            var generator = ConstantGenerator(bits: bits)
            XCTAssertTrue(EMath.normalSample(using: &generator).isFinite)
            let wait = EMath.waitingTime(rate: 2, using: &generator)
            XCTAssertTrue(wait.isFinite)
            XCTAssertGreaterThan(wait, 0)
        }
    }

    func testCompoundingConvergesMonotonicallyAndRetainsLargeStepPrecision() {
        XCTAssertEqual(EMath.compound(steps: 1), 2, accuracy: 1e-14)
        var previous = 1.0
        for steps in [1, 2, 4, 10, 100, 1_000, 10_000, 1_000_000, 1_000_000_000_000] {
            let value = EMath.compound(steps: steps)
            XCTAssertGreaterThan(value, previous)
            XCTAssertLessThanOrEqual(value, exp(1))
            XCTAssertLessThan(exp(1) - value, exp(1) / Double(steps))
            previous = value
        }
        XCTAssertEqual(EMath.compound(steps: Int.max), exp(1), accuracy: 1e-14)
    }

    func testWaitingSurvivalIsMemoryless() {
        XCTAssertEqual(EMath.waitingSurvival(rate: 2, time: 0), 1)
        let conditional = EMath.waitingSurvival(rate: 0.6, time: 7) / EMath.waitingSurvival(rate: 0.6, time: 3)
        XCTAssertEqual(conditional, EMath.waitingSurvival(rate: 0.6, time: 4), accuracy: 1e-14)
        XCTAssertEqual(EMath.waitingSurvival(rate: 2, time: 0.5), 1 / exp(1), accuracy: 1e-14)
    }

    func testWaitingSamplesHaveCorrectMeanAndSurvival() {
        var generator = SeededGenerator(seed: 0x3210)
        let samples = 100_000
        var total = 0.0
        var survivors = 0
        for _ in 0..<samples {
            let value = EMath.waitingTime(rate: 2, using: &generator)
            XCTAssertGreaterThan(value, 0)
            total += value
            if value > 0.5 { survivors += 1 }
        }
        XCTAssertEqual(total / Double(samples), 0.5, accuracy: 0.008)
        XCTAssertEqual(Double(survivors) / Double(samples), EMath.waitingSurvival(rate: 2, time: 0.5), accuracy: 0.008)
    }

    private func enumeratePermutations(_ values: inout [Int], at index: Int, visit: ([Int]) -> Void) {
        if index == values.count {
            visit(values)
            return
        }
        for candidate in index..<values.count {
            values.swapAt(index, candidate)
            enumeratePermutations(&values, at: index + 1, visit: visit)
            values.swapAt(index, candidate)
        }
    }
}

private struct ConstantGenerator: RandomNumberGenerator {
    let bits: UInt64
    mutating func next() -> UInt64 { bits }
}

/// SplitMix64 supplies a reproducible test stream without changing production RNGs.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
