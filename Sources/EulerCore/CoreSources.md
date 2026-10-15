# EulerCore mathematical models

`EMath` is a portable Swift library with no UI, audio, or haptic dependencies.
Angles use radians. Frequencies are cycles per time unit; when time is seconds,
frequency is hertz. Rates and time must use reciprocal units.

## Models and sources

| Experiment | Core relationship | Source and interpretation |
| --- | --- | --- |
| Growth and decay | `amount(t) = initial × exp(rate × t)` | The derivative is `rate × amount`. The [NIST Digital Library of Mathematical Functions, exponential definitions](https://dlmf.nist.gov/4.2.iii) gives the exponential function and its properties. Population growth requires proportional growth without resource limits; an atom decay model describes expected surviving amount. |
| Fading sound | `s(t) = A × exp(−decay × t) × cos(2πft)` | [OpenStax University Physics, damped oscillations](https://openstax.org/books/university-physics-volume-1/pages/15-5-damped-oscillations) gives an exponentially shrinking sinusoidal envelope for an underdamped linear oscillator. Here `f` is the resulting oscillation frequency, controlled independently for exploration, rather than the undamped natural frequency. Actual instruments contain multiple modes. |
| Rotation | `exp(iθ) = cos(θ) + i sin(θ)` | [NIST DLMF, equation 4.2.24](https://dlmf.nist.gov/4.2.E24). The real exponent controls magnitude; the imaginary exponent controls angle. The unit circle has magnitude 1, and a half-turn reaches −1. |
| Tuning | `f(n) = f₀ × exp(n ln(2)/12)` | [UNSW Music Acoustics, note frequencies](https://newt.phys.unsw.edu.au/jw/notes.html) defines twelve equal frequency ratios per 2:1 octave. The base is 220 Hz by default. This rewriting follows `2^x = exp(x ln 2)`; the octave ratio 2 defines the tuning. |
| Logarithmic spiral | `r(θ) = a × exp(bθ)` | Direct application of the exponential relationship above to polar radius. Increasing the angle by a fixed `Δθ` multiplies the radius by `exp(bΔθ)`, independent of the starting angle. Scaling the curve is equivalent to an angle shift when `b ≠ 0`. |
| Shuffled hats | `P(no fixed points) = Dₙ / n!` | [Diaconis, Fulman, and Guralnick, On Fixed Points of Permutations](https://dornsife.usc.edu/jason-fulman/wp-content/uploads/sites/224/2023/06/dfgfinal.pdf) discusses the fixed-point limit: the zero-match probability approaches `1/e`. The core computes the finite population result, which is not generally exactly `1/e`. |
| Bell curve | `p(x) = exp(−(x−μ)²/(2σ²)) / (σ√(2π))` | [NIST/SEMATECH, normal distribution](https://www.itl.nist.gov/div898/handbook/eda/section3/eda3661.htm). The returned value is a density, not probability at one point. Summed independent finite-variance contributions can approach this form after centering and scaling; the direct normal sampler produces a reference distribution. |
| Random waiting | `P(T > t) = exp(−rate × t)` | [NIST/SEMATECH, exponential distribution](https://itl.nist.gov/div898/handbook/eda/section3/eda3667.htm) gives survival and inverse CDF. A constant event rate makes waiting memoryless; mean wait is `1/rate`. |

The normal sampler uses the Box–Muller transformation, originally described by
[Box and Muller (1958), A Note on the Generation of Random Normal Deviates](https://doi.org/10.1214/aoms/1177706645).
The [R Core random-number documentation](https://stat.ethz.ch/R-manual/R-devel/RHOME/library/base/html/Random.html)
also identifies the method and its original publication. This implementation is
stateless: it uses one coordinate of each transformed pair and makes two draws
per output sample.

Compounding illustrates the limit `e = lim(n→∞) (1 + 1/n)^n`. The implementation
evaluates `exp(n × log1p(1/n))` so that the increment survives for large integer
counts. This is algebraically the same expression at finite `n`.

## Numerical and input contract

Every `Double` argument must be finite. Invalid arguments trigger `precondition`
because app controls are responsible for enforcing their domains:

- `exponential`: any signed finite initial value, rate, and time.
- `dampedSignal` and `envelope`: nonnegative decay and time; signal frequency is
  nonnegative and amplitude may be signed.
- `phasor`: any finite angle.
- `frequency`: positive base frequency; semitones may be signed or fractional.
- `spiralRadius`: nonnegative scale; growth and angle may be signed.
- `derangementProbability` and `shuffle`: nonnegative count. Zero participants
  produce the empty assignment, whose no-match probability is 1.
- `fixedPoints`: a bijection of the zero-based indices `0..<count`.
- `normalDensity`: positive sigma; finite position and mean.
- `compound`: at least one step.
- `waitingTime` and `waitingSurvival`: positive rate; survival time is nonnegative.

The deterministic analytical functions preserve ordinary floating-point overflow
and underflow. App parameters and plotting windows should be bounded when finite
coordinates are needed. Initial zero and spiral scale zero return zero even when
the exponential factor would overflow.

Derangements use a positive probability recurrence to avoid factorial overflow:
`p₀ = 1`, `p₁ = 0`, `pₙ = ((n−1)pₙ₋₁ + pₙ₋₂)/n`. Evaluation stops at 32
participants because the subsequent finite-population correction is below Double
precision. Fisher–Yates samples every allowed partner uniformly through Swift's
bounded integer draw, without a modulo reduction.

Normal and waiting samplers map the top 52 random bits to the midpoints of `2^52`
equal bins. The resulting uniform lies strictly between 0 and 1, including for
all-zero or all-one generator output. This prevents logarithmic singularities
without a rejection loop. The sample algorithms assume successive generator
outputs supply independent uniform random bits. Production calls can use
`SystemRandomNumberGenerator`; fixed seeds appear only in tests.

## Verification

The tests cover proportional derivatives, semigroup behavior, half-lives,
sinusoidal pitch and envelopes, unit circle geometry, complex multiplication,
octaves and equal tuning ratios, spiral scaling, exhaustive permutation counts
through eight participants, shuffle coverage and fixed-point statistics, Gaussian
unit mass and sampled moments/tails, compounding convergence, and exponential
memorylessness plus sampled waiting statistics. Sampling endpoint tests verify
that logarithms remain finite.
