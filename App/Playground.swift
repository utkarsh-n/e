import SwiftUI
import EulerCore

enum GrowthContext: String, CaseIterable, Identifiable {
    case growth = "Growth", atoms = "Atoms", chai = "Chai"
    var id: String { rawValue }
}

@MainActor @Observable
final class Playground {
    var lab: LabKind = .grow
    var running = false
    private var growthTime = 1.0
    private var resonanceTime = 0.0
    var time: Double {
        get { lab == .resonate ? resonanceTime : growthTime }
        set { if lab == .resonate { resonanceTime = newValue } else { growthTime = newValue } }
    }
    var rate = 1.0
    var growthContext: GrowthContext = .growth
    var decay = 0.9
    var pitch = 220.0
    var angle = Double.pi / 4
    var semitone = 0.0
    var spiralGrowth = 0.16
    var spiralAngle = Double.pi * 2
    var compoundSteps = 4
    var hatCount = 8
    var hats = Array(0..<8)
    var shuffleTrials = 0
    var noMatchTrials = 0
    var bellSamples: [Double] = []
    var arrivalRate = 1.0
    var arrivals: [Double] = []
    var arrivalCount = 0
    var waitingClock = 0.0
    var sinceArrival = 0.0
    var latestDiscovery: LabKind?
    var discoveries: Set<String>
    let sensory = SensoryEngine()
    @ObservationIgnored let preferences: UserDefaults
    @ObservationIgnored private var rng = SystemRandomNumberGenerator()
    @ObservationIgnored private var nextArrival = 0.0
    @ObservationIgnored private var lastMilestone = 0
    @ObservationIgnored private var noteHasBeenPlucked = false
    @ObservationIgnored private var spiralHasBeenUnwound = false

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("--ui-testing")
        #if DEBUG
        let deviceQA = arguments.contains("--device-qa")
        #else
        let deviceQA = false
        #endif
        preferences = deviceQA ? UserDefaults(suiteName: "com.utkarsh.euler.device-qa")!
            : testing ? UserDefaults(suiteName: "com.utkarsh.euler.tests")! : .standard
        if testing { preferences.removePersistentDomain(forName: "com.utkarsh.euler.tests") }
        if deviceQA && !arguments.contains("--device-qa-preserve-preferences") {
            preferences.removePersistentDomain(forName: "com.utkarsh.euler.device-qa")
        }
        discoveries = Set(preferences.stringArray(forKey: "e.discoveries") ?? [])
        sensory.hapticsEnabled = !testing && (preferences.object(forKey: "e.haptics") as? Bool ?? true)
        sensory.soundEnabled = !testing && (preferences.object(forKey: "e.sound") as? Bool ?? deviceQA)
        sensory.strength = preferences.object(forKey: "e.strength") as? Double ?? 0.65
        sensory.continuousFeelEnabled = preferences.object(forKey: "e.continuousFeel") as? Bool ?? true
        if let index = arguments.firstIndex(of: "--lab"), arguments.indices.contains(index + 1),
           let kind = LabKind(rawValue: arguments[index + 1]) { lab = kind }
        nextArrival = EMath.waitingTime(rate: arrivalRate, using: &rng)
    }

    var amount: Double { EMath.exponential(rate: rate, time: time) }
    var envelope: Double { EMath.envelope(decay: decay, time: time) }
    var frequency: Double { EMath.frequency(semitones: semitone) }
    var point: ComplexPoint { EMath.phasor(angle: angle) }
    var fixedPoints: Int { EMath.fixedPoints(hats) }
    var measuredNoMatch: Double { shuffleTrials == 0 ? 0 : Double(noMatchTrials) / Double(shuffleTrials) }
    var exactNoMatch: Double { EMath.derangementProbability(count: hatCount) }
    var compoundValue: Double { EMath.compound(steps: compoundSteps) }
    var waitingSurvival: Double { EMath.waitingSurvival(rate: arrivalRate, time: sinceArrival) }
    var bins: [Int] {
        var result = Array(repeating: 0, count: 32)
        for sample in bellSamples {
            let index = Int(floor((sample + 4) / 0.25))
            if result.indices.contains(index) { result[index] += 1 }
        }
        return result
    }
    var readout: String {
        switch lab {
        case .grow: growthContext == .chai ? "\(decimal(22 + 68 * amount, 1))°" : decimal(amount, 5)
        case .resonate: "\(decimal(envelope * 100, 1))%"
        case .rotate: "\(decimal(angle / .pi, 2))π"
        case .tune: "\(decimal(frequency, 1))"
        case .spiral: "\(decimal(EMath.spiralRadius(growth: spiralGrowth, angle: spiralAngle), 2))×"
        case .shuffle: "\(fixedPoints)"
        case .bell: "\(bellSamples.count)"
        case .compound: decimal(compoundValue, 5)
        case .wait: "\(decimal(sinceArrival, 2))s"
        }
    }
    var readoutLabel: String {
        switch lab {
        case .grow: growthContext == .chai ? "Chai temperature · room 22°C" : growthContext == .atoms ? "Expected surviving fraction" : "Times the starting amount"
        case .resonate: "Amplitude remaining"
        case .rotate: "Angle · radians"
        case .tune: "Frequency · Hz"
        case .spiral: "Radius / starting radius"
        case .shuffle: "Hats returned to their owners"
        case .bell: "Sums collected"
        case .compound: "Amount after one year"
        case .wait: "Since the last arrival"
        }
    }
    var observation: String {
        switch lab {
        case .grow:
            if growthContext == .chai { return "The temperature gap is now \(decimal(68 * amount, 1))°C. The room stays at 22°C; cooling slows as the gap shrinks." }
            if abs(rate - 1) < 0.005 && abs(time - 1) < 0.01 { return "There it is. One time unit at k = 1 gives e = 2.71828… times the starting amount." }
            if abs(rate) < 0.005 { return "No proportional change. k = 0 keeps the amount at 1." }
            return rate > 0 ? "More amount means faster growth. It doubles every \(decimal(log(2) / rate)) time units." : "Less remains, so less disappears each moment. Half remains every \(decimal(log(2) / -rate)) time units."
        case .resonate: return "The pitch stays at \(Int(pitch)) Hz while the envelope fades. Half the amplitude remains after \(decimal(log(2) / decay)) seconds."
        case .rotate:
            if abs(angle - .pi) < 0.04 { return "A half-turn lands at −1. eⁱπ + 1 = 0. Growth became rotation." }
            return "The point is (\(decimal(point.x)), \(decimal(point.y))). Its distance from the center stays exactly 1."
        case .tune: return "\(Int(semitone)) semitones multiply 220 Hz by \(decimal(frequency / 220, 5)). Each key uses the same 1.05946… ratio."
        case .spiral: return "One full turn multiplies the radius by \(decimal(exp(spiralGrowth * 2 * .pi)))—the same ratio on every turn."
        case .shuffle:
            if shuffleTrials == 0 { return "The hats begin with their owners. Shuffle to give every arrangement an equal chance." }
            return "\(noMatchTrials) of \(shuffleTrials) shuffles had no matches. The finite-crowd chance is \(decimal(exactNoMatch * 100, 2))%; your measured result will fluctuate."
        case .bell: return "Each sample is the sum of 12 independent small surprises. The lilac bars are measured density; the mint curve is the ideal normal density."
        case .compound: return "\(compoundSteps) reinvestments give \(decimal(compoundValue, 5)). The gap to e is \(decimal(exp(1) - compoundValue, 5))."
        case .wait: return "\(arrivalCount) arrivals so far. At λ = \(decimal(arrivalRate, 1)), the average wait is \(decimal(1 / arrivalRate))s. The next arrival can happen at any time."
        }
    }

    func select(_ kind: LabKind) {
        stop()
        lab = kind
        latestDiscovery = nil
        sensory.selection()
    }
    func stop() { running = false; sensory.stop() }
    func pause() { stop(); sensory.selection() }
    func controlsChanged() {
        stop()
        if lab == .resonate { time = 0; noteHasBeenPlucked = false }
        sensory.selection(); checkDiscovery()
    }
    func scrubTime(_ value: Double) { stop(); time = value; sensory.selection(); checkDiscovery() }
    func setAngle(_ value: Double) {
        stop()
        let oldAngle = angle
        angle = min(max(value, 0), 2 * .pi)
        let quarterTurn = Double.pi / 2
        let boundary = (angle / quarterTurn).rounded() * quarterTurn
        let entersDetent = abs(angle - boundary) < 0.025 && abs(oldAngle - boundary) >= 0.025
        let crossesBoundary = floor(oldAngle / quarterTurn) != floor(angle / quarterTurn)
        if entersDetent || crossesBoundary { sensory.impact(intensity: 0.55) }
        checkDiscovery()
    }
    func setSpiral(_ value: Double) { stop(); spiralAngle = value; spiralHasBeenUnwound = true; sensory.selection(); checkDiscovery() }
    func setContext(_ context: GrowthContext) {
        stop(); growthContext = context; time = 0
        rate = context == .growth ? 1 : context == .atoms ? -0.7 : -0.8
        sensory.selection()
    }
    func findE() { stop(); growthContext = .growth; rate = 1; time = 1; checkDiscovery(); sensory.impact(intensity: 0.7) }
    func playKey(_ key: Int) {
        stop(); semitone = Double(key)
        sensory.playTone(frequency: frequency)
        sensory.impact(intensity: 0.2 + Double(key) / 24)
        checkDiscovery()
    }
    func shuffle(_ count: Int = 1) {
        stop()
        for _ in 0..<count {
            hats = EMath.shuffle(count: hatCount, using: &rng)
            shuffleTrials += 1
            if EMath.fixedPoints(hats) == 0 { noMatchTrials += 1 }
        }
        sensory.impact(intensity: fixedPoints == 0 ? 0.7 : 0.3)
        checkDiscovery()
    }
    func setHatCount(_ count: Int) {
        stop(); hatCount = count; hats = Array(0..<count)
        shuffleTrials = 0; noMatchTrials = 0; sensory.selection()
    }
    func drop(_ count: Int = 100) {
        stop()
        let allowed = min(count, 10000 - bellSamples.count)
        for _ in 0..<max(0, allowed) {
            let sum = (0..<12).reduce(0.0) { total, _ in total + Double.random(in: 0..<1, using: &rng) }
            bellSamples.append(sum - 6)
        }
        sensory.impact(intensity: 0.3); checkDiscovery()
    }
    func setSteps(_ value: Int) { stop(); compoundSteps = value; sensory.selection(); checkDiscovery() }
    func setArrivalRate(_ value: Double) {
        stop(); arrivalRate = value; resetWaiting(); sensory.selection()
    }
    func primaryAction() {
        switch lab {
        case .shuffle: shuffle()
        case .bell: drop()
        case .compound: setSteps(min(4096, compoundSteps * 2))
        case .tune: playKey(Int(semitone))
        case .resonate:
            stop(); time = 0; running = true; lastMilestone = 0; noteHasBeenPlucked = true
            sensory.playDecay(frequency: pitch, decay: decay, duration: 5)
        default:
            if running { pause(); return }
            if lab == .grow && time >= 3 { time = 0 }
            if lab == .rotate && angle >= 2 * .pi { angle = 0 }
            if lab == .spiral && spiralAngle >= 4 * .pi { spiralAngle = 0 }
            running = true
            lastMilestone = milestone
            sensory.selection()
        }
    }
    var primaryTitle: String {
        switch lab {
        case .resonate: "Pluck again"
        case .shuffle: "Shuffle hats"
        case .bell: "Drop 100"
        case .compound: "Double the steps"
        case .tune: "Play note"
        default: running ? "Pause" : "Play"
        }
    }
    var primarySymbol: String {
        switch lab {
        case .resonate: "waveform"
        case .shuffle: "shuffle"
        case .bell: "plus"
        case .compound: "plus.forwardslash.minus"
        case .tune: "speaker.wave.2"
        default: running ? "pause.fill" : "play.fill"
        }
    }
    private var milestone: Int {
        switch lab {
        case .grow: Int(floor(abs(rate) * time / log(2)))
        case .resonate: Int(floor(decay * time / log(2)))
        case .rotate: Int(floor(angle / (.pi / 2)))
        case .spiral: Int(floor(spiralAngle / (.pi / 2)))
        default: 0
        }
    }
    func advance(_ delta: Double) {
        guard running else { return }
        let dt = min(max(delta, 0), 0.1)
        switch lab {
        case .grow: time = min(3, time + dt); if time >= 3 { running = false }
        case .resonate: time = min(5, time + dt); if time >= 5 { stop() }
        case .rotate: angle = min(2 * .pi, angle + dt * 0.8); if angle >= 2 * .pi { running = false }
        case .spiral: spiralHasBeenUnwound = true; spiralAngle = min(4 * .pi, spiralAngle + dt * 1.2); if spiralAngle >= 4 * .pi { running = false }
        case .wait:
            waitingClock += dt; sinceArrival += dt
            while waitingClock >= nextArrival {
                arrivals.append(nextArrival)
                arrivalCount += 1
                if arrivals.count > 200 { arrivals.removeFirst() }
                nextArrival += EMath.waitingTime(rate: arrivalRate, using: &rng)
                sensory.impact(intensity: 0.6)
            }
            if let last = arrivals.last { sinceArrival = waitingClock - last }
        default: running = false
        }
        if milestone != lastMilestone {
            lastMilestone = milestone
            if lab != .resonate { sensory.impact(intensity: 0.45) }
        }
        checkDiscovery()
    }
    func reset() {
        stop(); latestDiscovery = nil
        switch lab {
        case .grow: time = 0; rate = 1; growthContext = .growth
        case .resonate: time = 0; pitch = 220; decay = 0.9; noteHasBeenPlucked = false
        case .rotate: angle = 0
        case .tune: semitone = 0
        case .spiral: spiralAngle = 0; spiralGrowth = 0.16; spiralHasBeenUnwound = false
        case .shuffle: hats = Array(0..<hatCount); shuffleTrials = 0; noMatchTrials = 0
        case .bell: bellSamples = []
        case .compound: compoundSteps = 1
        case .wait: resetWaiting()
        }
        sensory.selection()
    }
    private func resetWaiting() {
        arrivals = []; arrivalCount = 0; waitingClock = 0; sinceArrival = 0
        nextArrival = EMath.waitingTime(rate: arrivalRate, using: &rng)
    }
    func step() {
        stop(); running = true; advance(lab == .wait ? 0.1 : 0.08); running = false
        sensory.selection()
    }
    func checkDiscovery() {
        let achieved: Bool
        switch lab {
        case .grow: achieved = growthContext == .growth && abs(rate - 1) < 0.005 && abs(time - 1) < 0.02
        case .resonate: achieved = noteHasBeenPlucked && time >= log(2) / decay && time < 5
        case .rotate: achieved = abs(angle - .pi) < 0.04
        case .tune: achieved = Int(semitone) == 12
        case .spiral: achieved = spiralHasBeenUnwound && spiralAngle >= 2 * .pi
        case .shuffle: achieved = shuffleTrials >= 100
        case .bell: achieved = bellSamples.count >= 500
        case .compound: achieved = compoundSteps >= 512
        case .wait: achieved = arrivalCount >= 20
        }
        guard achieved, !discoveries.contains(lab.rawValue) else { return }
        discoveries.insert(lab.rawValue)
        preferences.set(Array(discoveries).sorted(), forKey: "e.discoveries")
        latestDiscovery = lab
        sensory.success()
    }
    func setHaptics(_ enabled: Bool) {
        sensory.hapticsEnabled = enabled; preferences.set(enabled, forKey: "e.haptics")
        if enabled { sensory.selection() }
    }
    func setSound(_ enabled: Bool) {
        sensory.soundEnabled = enabled; preferences.set(enabled, forKey: "e.sound")
        sensory.selection()
    }
    func setStrength(_ value: Double) {
        stop(); sensory.strength = value; preferences.set(value, forKey: "e.strength")
        sensory.impact(intensity: 0.8)
    }
    func setContinuousFeel(_ enabled: Bool) {
        stop(); sensory.continuousFeelEnabled = enabled; preferences.set(enabled, forKey: "e.continuousFeel")
        sensory.selection()
    }
}
