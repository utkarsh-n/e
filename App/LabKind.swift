import SwiftUI

enum LabKind: String, CaseIterable, Identifiable {
    case grow, resonate, rotate, tune, spiral, shuffle, bell, compound, wait
    var id: String { rawValue }
    var index: Int { Self.allCases.firstIndex(of: self)! + 1 }
    var title: String {
        switch self {
        case .grow: "Grow & fade"
        case .resonate: "A fading note"
        case .rotate: "Imaginary turns"
        case .tune: "Equal steps"
        case .spiral: "A growing spiral"
        case .shuffle: "The hat surprise"
        case .bell: "Order in randomness"
        case .compound: "Becoming e"
        case .wait: "The waiting game"
        }
    }
    var shortTitle: String {
        switch self {
        case .grow: "Grow"
        case .resonate: "Resonate"
        case .rotate: "Rotate"
        case .tune: "Tune"
        case .spiral: "Spiral"
        case .shuffle: "Shuffle"
        case .bell: "Scatter"
        case .compound: "Compound"
        case .wait: "Wait"
        }
    }
    var symbol: String {
        switch self {
        case .grow: "chart.line.uptrend.xyaxis"
        case .resonate: "waveform"
        case .rotate: "rotate.right"
        case .tune: "pianokeys"
        case .spiral: "hurricane"
        case .shuffle: "shuffle"
        case .bell: "chart.bar.xaxis"
        case .compound: "plus.forwardslash.minus"
        case .wait: "clock"
        }
    }
    var accent: Color {
        switch self {
        case .rotate, .bell: Ink.lilac
        case .tune, .compound, .wait: Ink.amber
        default: Ink.mint
        }
    }
    var subtitle: String {
        switch self {
        case .grow: "Change in proportion to what is already there."
        case .resonate: "One vibration. An exponential goodbye."
        case .rotate: "Growth takes a turn into another dimension."
        case .tune: "A keyboard built from ratios, not additions."
        case .spiral: "Turning and growing, together."
        case .shuffle: "No growth. No waves. Still e."
        case .bell: "Small surprises add up to a familiar shape."
        case .compound: "Make the steps smaller. Meet a constant."
        case .wait: "Random arrivals have an exponential clock."
        }
    }
    var gestureHint: String {
        switch self {
        case .grow: "Drag across the curve to move through time."
        case .resonate: "Tap the wave to pluck. Feel it fade."
        case .rotate: "Drag the glowing point around the circle."
        case .tune: "Tap a key. Hear equal ratios."
        case .spiral: "Drag horizontally to unwind the spiral."
        case .shuffle: "Shuffle the hats. Look for a match."
        case .bell: "Drop a batch. Watch a bell emerge."
        case .compound: "Split one year into smaller growth steps."
        case .wait: "Start the clock. Arrivals are unpredictable."
        }
    }
    var formula: String {
        switch self {
        case .grow: "A(t) = A₀ eᵏᵗ"
        case .resonate: "s(t) = A e⁻ᵏᵗ cos(2πft)"
        case .rotate: "eⁱᶿ = cos θ + i sin θ"
        case .tune: "f(n) = f₀ · exp[n ln(2)/12]"
        case .spiral: "r = a eᵇᶿ"
        case .shuffle: "P(no matches) → 1/e"
        case .bell: "p(x) = exp(−x²/2) / √(2π)"
        case .compound: "(1 + 1/n)ⁿ → e"
        case .wait: "P(T > t) = e⁻λᵗ"
        }
    }
    var explanation: String {
        switch self {
        case .grow: "The change per moment is k times the current amount. More means a bigger change. With k = 1, one time unit multiplies the amount by e. A negative k makes the amount shrink instead."
        case .resonate: "The cosine makes the vibration. The exponential makes its envelope shrink. Linear damping gives this ideal model: change the decay rate to hear and feel the same pitch disappear sooner."
        case .rotate: "Multiplying by e raised to an imaginary angle turns a point without changing its distance from the origin. The horizontal and vertical coordinates are cosine and sine. At π radians, the point reaches −1: eⁱπ + 1 = 0."
        case .tune: "Each semitone multiplies frequency by 2^(1/12), about 1.05946. Twelve equal steps double it. The octave ratio 2 defines the tuning; e expresses the same relationship using the natural logarithm."
        case .spiral: "Every equal angle multiplies the radius by the same factor. For a full turn, the multiplier is e²πᵇ. A logarithmic spiral keeps its shape when scaled, up to rotation."
        case .shuffle: "Each shuffle is a uniformly random permutation. A matching hat is a fixed point. The exact chance of no matches is the alternating sum 1 − 1 + 1/2! − 1/3! + … through n. As the crowd grows, that approaches 1/e."
        case .bell: "Add twelve independent uniform contributions, center the sum, and its variance is 1. Repeating that builds an approximate standard bell curve. The exact normal density uses e to suppress values far from its center."
        case .compound: "Start with 1 and a nominal growth rate of 100% per year. Divide the year into n equal steps and reinvest each time: (1 + 1/n)ⁿ. More steps bring the result toward e, the continuous compounding limit."
        case .wait: "If arrivals are independent with a constant average rate λ, the waiting time is exponential. The chance of still waiting after t is e⁻λᵗ. Waiting longer does not change the distribution of the remaining wait."
        }
    }
    var caveat: String {
        switch self {
        case .grow: "Growth assumes no resource limit. Atom counts are modeled as an expected fraction. For chai, the decaying amount is its temperature difference from the room, with a constant room temperature and cooling coefficient."
        case .resonate: "The drawn vibration is slowed to 2.5 cycles per second so you can see it. Audio uses the selected frequency. Real instruments can have many modes, each with a different decay. Haptics illustrate the envelope rather than reproduce audible pitch."
        case .rotate: "Angles are in radians. The circle has radius 1; i is the imaginary unit, with i² = −1. No physical quantity is being measured."
        case .tune: "This is twelve-tone equal temperament with A3 = 220 Hz. Real instruments and other tuning systems can use different ratios."
        case .spiral: "This is an ideal mathematical spiral. Natural shells and plants need not follow this equation exactly. The displayed curve automatically fits the available space."
        case .shuffle: "Measured chance comes from your actual trials and will fluctuate. The exact finite-crowd chance and limiting value 1/e are shown separately. Every hat is equally likely to occupy every position."
        case .bell: "The histogram is a probability density: counts divided by sample count and bin width. The mint reference is the standard normal density; the twelve-uniform sum is only an approximation. Tails outside ±4 are omitted from the plot and still included in the denominator."
        case .compound: "This is a mathematical compounding model, with no fees, deposits, or changing rates. It is a demonstration of a limit."
        case .wait: "The clock simulates a Poisson process using exponential waiting times. λ is in arrivals per simulated second. The survival curve is a probability, not a prediction for the next event."
        }
    }
    var sourceURL: URL {
        switch self {
        case .grow, .compound: URL(string: "https://dlmf.nist.gov/4.2.iii")!
        case .resonate: URL(string: "https://openstax.org/books/university-physics-volume-1/pages/15-5-damped-oscillations")!
        case .rotate: URL(string: "https://dlmf.nist.gov/4.2")!
        case .tune: URL(string: "https://newt.phys.unsw.edu.au/jw/notes.html")!
        case .spiral: URL(string: "https://mathworld.wolfram.com/LogarithmicSpiral.html")!
        case .shuffle: URL(string: "https://www.cs.princeton.edu/courses/archive/fall04/cos341/exponential_generating_functions4.pdf")!
        case .bell: URL(string: "https://www.itl.nist.gov/div898/handbook/eda/section3/eda3661.htm")!
        case .wait: URL(string: "https://www.itl.nist.gov/div898/handbook/eda/section3/eda3667.htm")!
        }
    }
    var discoveryTitle: String {
        switch self {
        case .grow: "One unit. Exactly e."
        case .resonate: "Half the vibration remains."
        case .rotate: "Five constants. One half-turn."
        case .tune: "Twelve steps. Twice the pitch."
        case .spiral: "A turn is a multiplier."
        case .shuffle: "The shuffled-hat surprise."
        case .bell: "Randomness has a shape."
        case .compound: "Small steps become e."
        case .wait: "A clock without memory."
        }
    }
    var challenge: String {
        switch self {
        case .grow: "Set k to 1 and time to 1."
        case .resonate: "Pluck a note and reach its half-life."
        case .rotate: "Turn to π radians."
        case .tune: "Play the twelfth semitone."
        case .spiral: "Unwind at least one full turn."
        case .shuffle: "Run at least 100 uniform shuffles."
        case .bell: "Drop at least 500 sums of small surprises."
        case .compound: "Compound at least 512 times in one year."
        case .wait: "Observe at least 20 random arrivals."
        }
    }
}
