import Foundation

/// The Cartesian coordinates of a complex number, including a point on the unit circle.
public struct ComplexPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        precondition(x.isFinite && y.isFinite, "Coordinates must be finite.")
        self.x = x
        self.y = y
    }
}

/// Stateless, portable mathematical models used by the app's experiments.
///
/// Invalid parameters are programming errors and trigger a precondition. Callers
/// should constrain editable values to the domains documented on each function.
/// Results retain normal IEEE 754 overflow/underflow behavior; the UI should use
/// bounded parameters and times when it needs finite coordinates or audio samples.
public enum EMath {
    /// `initial * exp(rate * time)`. Every input must be finite; signed rates and
    /// times are allowed so this also represents decay and reverse-time exploration.
    public static func exponential(initial: Double = 1, rate: Double, time: Double) -> Double {
        precondition(initial.isFinite && rate.isFinite && time.isFinite, "Inputs must be finite.")
        if initial == 0 { return 0 }
        return initial * exp(rate * time)
    }

    /// A damped sinusoid with frequency in cycles per time unit. Amplitude may be
    /// signed; decay, frequency, and time must be finite and nonnegative.
    public static func dampedSignal(
        amplitude: Double = 1,
        decay: Double,
        frequency: Double,
        time: Double
    ) -> Double {
        precondition(amplitude.isFinite, "Amplitude must be finite.")
        precondition(frequency.isFinite && frequency >= 0, "Frequency must be finite and nonnegative.")
        return amplitude * envelope(decay: decay, time: time) * cos(2 * .pi * frequency * time)
    }

    /// `exp(-decay * time)`, from 1 toward 0. Decay and time must be finite and
    /// nonnegative; a zero decay gives an undamped envelope.
    public static func envelope(decay: Double, time: Double) -> Double {
        precondition(decay.isFinite && decay >= 0 && time.isFinite && time >= 0,
                     "Decay and time must be finite and nonnegative.")
        return exp(-decay * time)
    }

    /// The unit phasor `exp(i * angle)`, with angle in radians.
    public static func phasor(angle: Double) -> ComplexPoint {
        precondition(angle.isFinite, "Angle must be finite.")
        return ComplexPoint(x: cos(angle), y: sin(angle))
    }

    /// Twelve-tone equal temperament: each 12 semitones doubles a positive base
    /// frequency. Fractional and negative semitones support smooth pitch exploration.
    public static func frequency(base: Double = 220, semitones: Double) -> Double {
        precondition(base.isFinite && base > 0 && semitones.isFinite,
                     "Base must be finite and positive; semitones must be finite.")
        return base * exp(semitones * log(2) / 12)
    }

    /// A logarithmic spiral's radius, `scale * exp(growth * angle)`.
    /// Scale must be finite and nonnegative; growth and angle may be signed.
    public static func spiralRadius(scale: Double = 1, growth: Double, angle: Double) -> Double {
        precondition(scale.isFinite && scale >= 0 && growth.isFinite && angle.isFinite,
                     "Scale must be finite and nonnegative; growth and angle must be finite.")
        if scale == 0 { return 0 }
        return scale * exp(growth * angle)
    }

    /// The exact finite-population derangement probability to Double precision.
    /// The empty assignment is a derangement, so `count == 0` returns 1.
    ///
    /// Dividing the recurrence `D_n = (n-1)(D_(n-1) + D_(n-2))` by `n!`
    /// avoids factorial overflow. Beyond 32 participants the correction is far
    /// below Double precision, so evaluation is bounded to 32 recurrence steps.
    public static func derangementProbability(count: Int) -> Double {
        precondition(count >= 0, "Count must be nonnegative.")
        if count == 0 { return 1 }
        if count == 1 { return 0 }

        var twoBack = 1.0
        var oneBack = 0.0
        for n in 2...min(count, 32) {
            let divisor = Double(n)
            let probability = ((divisor - 1) * oneBack + twoBack) / divisor
            twoBack = oneBack
            oneBack = probability
        }
        return oneBack
    }

    /// Counts `permutation[index] == index`, using zero-based participant IDs.
    /// Input must be a bijection of `0..<permutation.count`, as returned by shuffle.
    public static func fixedPoints(_ permutation: [Int]) -> Int {
        precondition(Set(permutation).count == permutation.count
                     && permutation.allSatisfy { $0 >= 0 && $0 < permutation.count },
                     "Input must be a permutation of zero-based indices.")
        return permutation.enumerated().reduce(0) { $0 + ($1.offset == $1.element ? 1 : 0) }
    }

    /// An unbiased Fisher–Yates shuffle of `0..<count` (count must be nonnegative).
    /// Swift's bounded integer draw uses rejection sampling rather than `% count`.
    public static func shuffle<R: RandomNumberGenerator>(count: Int, using generator: inout R) -> [Int] {
        precondition(count >= 0, "Count must be nonnegative.")
        var permutation = Array(0..<count)
        guard count > 1 else { return permutation }
        for index in stride(from: count - 1, through: 1, by: -1) {
            let partner = Int.random(in: 0...index, using: &generator)
            permutation.swapAt(index, partner)
        }
        return permutation
    }

    /// The Gaussian density. Inputs must be finite and sigma must be positive.
    /// This is a density (units of 1/x), not a probability at a single point.
    public static func normalDensity(x: Double, mean: Double = 0, sigma: Double = 1) -> Double {
        precondition(x.isFinite && mean.isFinite && sigma.isFinite && sigma > 0,
                     "Inputs must be finite and sigma must be positive.")
        let standardized = (x - mean) / sigma
        return exp(-0.5 * standardized * standardized) / sigma / sqrt(2 * .pi)
    }

    /// A standard normal sample using the Box–Muller transform.
    /// Two independent open uniforms ensure logarithms never see zero, even if
    /// a supplied generator returns only endpoint bit patterns.
    public static func normalSample<R: RandomNumberGenerator>(using generator: inout R) -> Double {
        let radius = sqrt(-2 * log(openUniform(using: &generator)))
        let angle = 2 * Double.pi * openUniform(using: &generator)
        return radius * cos(angle)
    }

    /// `(1 + 1/steps)^steps`, with positive integer steps.
    /// `log1p` preserves the small increment for very large step counts.
    public static func compound(steps: Int) -> Double {
        precondition(steps >= 1, "Steps must be positive.")
        let count = Double(steps)
        return exp(count * log1p(1 / count))
    }

    /// An exponential waiting time for a positive finite event rate, using
    /// the inverse CDF `-log(1-u)/rate`. The return is positive and finite for
    /// ordinary app rates; `log1p` protects precision for very small uniforms.
    public static func waitingTime<R: RandomNumberGenerator>(rate: Double, using generator: inout R) -> Double {
        precondition(rate.isFinite && rate > 0, "Rate must be finite and positive.")
        return -log1p(-openUniform(using: &generator)) / rate
    }

    /// The probability of waiting beyond time: `exp(-rate * time)`.
    /// Rate must be positive; time must be nonnegative; both must be finite.
    public static func waitingSurvival(rate: Double, time: Double) -> Double {
        precondition(rate.isFinite && rate > 0 && time.isFinite && time >= 0,
                     "Rate must be finite and positive; time must be finite and nonnegative.")
        return exp(-rate * time)
    }

    /// Midpoints of 2^52 equally sized bins. Using 52 random bits lets both
    /// extreme midpoints be represented exactly without rounding up to 1.
    private static func openUniform<R: RandomNumberGenerator>(using generator: inout R) -> Double {
        (Double(generator.next() >> 12) + 0.5) / 4_503_599_627_370_496
    }
}
