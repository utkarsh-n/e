import Foundation
import XCTest

/// Signed-device QA. All actions use visible controls and the isolated DEBUG
/// --device-qa preferences. Counters prove accepted API requests and observed audio rendering;
/// they do not establish that a person heard a speaker or felt a haptic motor.
final class EulerDeviceQATests: XCTestCase {
    @MainActor
    func testDeviceGrowContextsSlidersScrubbingAndTransport() throws {
        let app = try launch("grow")
        let baseline = state(app)
        expectHero(app, "2.71828")
        feedback(app, "Growth reset") { tap(app.buttons["reset"], in: app) }
        expectHero(app, "1.00000")
        feedback(app, "Growth single step") { tap(app.buttons["step"], in: app) }
        XCTAssertEqual(state(app).number("time"), 0.08, accuracy: 0.0001)
        expectHero(app, "1.08329")

        feedback(app, "Growth rate slider") { adjust("growthRate", to: 1, in: app) }
        feedback(app, "Growth time slider") { adjust("growthTime", to: 1, in: app) }
        XCTAssertEqual(state(app).number("rate"), 1.5, accuracy: 0.01)
        expectHero(app, "90.01713")
        feedback(app, "Atom context") { tap(app.segmentedControls["growthContext"].buttons["Atoms"], in: app) }
        expectHero(app, "1.00000")
        feedback(app, "Atom decay time") { adjust("growthTime", to: 1, in: app) }
        expectHero(app, "0.12246")
        feedback(app, "Chai context") { tap(app.segmentedControls["growthContext"].buttons["Chai"], in: app) }
        expectHero(app, "90.0°")
        feedback(app, "Chai cooling time") { adjust("growthTime", to: 1, in: app) }
        expectHero(app, "28.2°")
        feedback(app, "Return to growth") { tap(app.segmentedControls["growthContext"].buttons["Growth"], in: app) }

        let canvas = app.descendants(matching: .any)["lab.canvas"].firstMatch
        reveal(canvas, in: app)
        feedback(app, "Horizontal curve scrub") {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
        }
        XCTAssertGreaterThan(state(app).number("time"), 2)
        let scrubbed = state(app).number("time")
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertEqual(state(app).number("time"), scrubbed, accuracy: 0.0001, "Vertical page scrolling must not scrub time.")
        feedback(app, "Find e preset") { tap(app.buttons["findE"], in: app) }
        expectHero(app, "2.71828")
        XCTAssertEqual(state(app).integer("discoveryCount"), 1)

        feedback(app, "Reset growth before playback") { tap(app.buttons["reset"], in: app) }
        // Grow finishes after three seconds. Its fixed transport is already
        // visible; scroll geometry queries would consume the pause window.
        let beforePlay = state(app)
        let transport = app.buttons["primaryAction"]
        transport.tap()
        let playing = waitState(app, "Growth advances and Play delivers touch", timeout: 5) {
            $0.flag("running") && $0.number("time") > 0.15
                && $0.integer("transientHapticStartCount") > beforePlay.integer("transientHapticStartCount")
        }
        XCTAssertTrue(playing.flag("running"))
        XCTAssertTrue(transport.label.contains("Pause"), "The visible control must still offer Pause before tapping.")
        transport.tap()
        let paused = waitState(app, "A deliberate Pause stops growth and delivers touch", timeout: 5) {
            !$0.flag("running") && !$0.flag("audioActive") && !$0.flag("hapticActive")
                && $0.integer("transientHapticStartCount") > playing.integer("transientHapticStartCount")
        }
        XCTAssertLessThan(paused.number("time"), 3, "Pause must happen before the natural endpoint.")
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let stillPaused = state(app)
        XCTAssertFalse(stillPaused.flag("running"))
        XCTAssertEqual(stillPaused.number("time"), paused.number("time"), accuracy: 0.0001)
        recordDelta("Growth play", beforePlay, playing)
        recordDelta("Growth pause before the endpoint", playing, stillPaused)
        capture("Grow — contexts, scrub and e", app)
        assertNoAudio(since: baseline, in: app)
    }

    @MainActor
    func testDeviceResonancePitchDecayCanvasPluckAndStop() throws {
        let app = try launch("resonate")
        expectHero(app, "100.0%")
        tap(app.buttons["dials"], in: app)
        feedback(app, "Resonance pitch dial") { adjust("pitch", to: 1, in: app) }
        feedback(app, "Resonance decay dial") { adjust("decayRate", to: 1, in: app) }
        tap(app.buttons["Done"], in: app)
        let configured = state(app)
        XCTAssertEqual(configured.number("pitch"), 880, accuracy: 1)
        XCTAssertEqual(configured.number("decay"), 2, accuracy: 0.01)
        XCTAssertEqual(configured.integer("discoveryCount"), 0, "Editing dials must not discover an unplayed half-life.")
        let before = state(app)
        tap(app.descendants(matching: .any)["lab.canvas"].firstMatch, in: app)
        let played = waitState(app, "A pluck starts audio and continuous touch", timeout: 8) {
            $0.integer("audioStartCount") > before.integer("audioStartCount")
                && $0.integer("audioRenderCount") > before.integer("audioRenderCount")
                && $0.integer("continuousHapticStartCount") > before.integer("continuousHapticStartCount")
        }
        XCTAssertEqual(played.number("lastAudioFrequency"), 880, accuracy: 1)
        XCTAssertEqual(played.number("lastAudioDecay"), 2, accuracy: 0.01)
        waitState(app, "A real pluck crosses its half-life", timeout: 8) { $0.integer("discoveryCount") == 1 }
        recordDelta("Canvas pluck delivery", before, state(app))
        // Re-pluck through the transport too, then exercise its explicit stop.
        let repeated = state(app)
        tap(app.buttons["primaryAction"], in: app)
        waitState(app, "Transport re-plucks", timeout: 5) { $0.integer("audioStartCount") > repeated.integer("audioStartCount") }
        feedback(app, "Stop note") { tap(app.buttons["stopNote"], in: app) }
        assertStopped(app)
        capture("Resonate — plucked envelope", app)
        feedback(app, "Resonance reset") { tap(app.buttons["reset"], in: app) }
        expectHero(app, "100.0%")
        XCTAssertEqual(state(app).number("pitch"), 220, accuracy: 0.01)
        XCTAssertEqual(state(app).number("decay"), 0.9, accuracy: 0.01)
    }

    @MainActor
    func testDeviceRotationDetentsTwoDimensionalDragAndTransport() throws {
        let app = try launch("rotate")
        let baseline = state(app)
        for quarter in 0...4 {
            feedback(app, "Rotation detent \(quarter)") { tap(app.buttons["angleDetent\(quarter)"], in: app) }
            XCTAssertEqual(state(app).number("angle"), Double(quarter) * .pi / 2, accuracy: 0.0001)
        }
        feedback(app, "Rotation slider minimum") { adjust("rotationAngle", to: 0, in: app) }
        expectHero(app, "0.00π")
        let canvas = app.descendants(matching: .any)["lab.canvas"].firstMatch
        reveal(canvas, in: app)
        feedback(app, "Circle two-dimensional drag") {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)))
        }
        XCTAssertEqual(state(app).number("angle"), .pi / 2, accuracy: 0.08)
        feedback(app, "Euler identity detent") { tap(app.buttons["angleDetent2"], in: app) }
        expectHero(app, "1.00π")
        XCTAssertTrue(app.staticTexts["observation"].label.contains("eⁱπ + 1 = 0"))
        XCTAssertEqual(state(app).integer("discoveryCount"), 1)
        feedback(app, "Rotation step") { tap(app.buttons["step"], in: app) }
        XCTAssertGreaterThan(state(app).number("angle"), .pi)
        feedback(app, "Reset rotation before playback") { tap(app.buttons["reset"], in: app) }
        feedback(app, "Rotation play") { tap(app.buttons["primaryAction"], in: app) }
        waitState(app, "Rotation advances", timeout: 5) { $0.number("angle") > 0.2 }
        feedback(app, "Rotation pause") { tap(app.buttons["primaryAction"], in: app) }
        assertStopped(app)
        capture("Rotate — radians and detents", app)
        feedback(app, "Rotation reset") { tap(app.buttons["reset"], in: app) }
        expectHero(app, "0.00π")
        assertNoAudio(since: baseline, in: app)
    }

    @MainActor
    func testDeviceTuningKeysSliderReplayAndLocalSoundGate() throws {
        let app = try launch("tune")
        for key in 0...12 {
            let button = app.buttons["pianoKey\(key)"]
            revealPianoKey(button, in: app)
            let before = state(app)
            tap(button, in: app)
            let played = waitState(app, "Key \(key) starts its audio and touch", timeout: 5) {
                $0.integer("audioStartCount") > before.integer("audioStartCount")
                    && $0.integer("audioRenderCount") > before.integer("audioRenderCount")
                    && $0.integer("transientHapticStartCount") > before.integer("transientHapticStartCount")
            }
            XCTAssertEqual(played.number("semitone"), Double(key), accuracy: 0.0001)
            XCTAssertEqual(played.number("lastAudioFrequency"), 220 * pow(2, Double(key) / 12), accuracy: 0.01)
            recordDelta("Piano key \(key)", before, played)
        }
        expectHero(app, "440.0")
        XCTAssertEqual(state(app).integer("discoveryCount"), 1)
        let replay = state(app)
        tap(app.buttons["primaryAction"], in: app)
        waitState(app, "Replay starts selected note", timeout: 5) { $0.integer("audioStartCount") > replay.integer("audioStartCount") }
        feedback(app, "Tuning semitone slider") { adjust("semitones", to: 0, in: app) }
        expectHero(app, "220.0")
        setSwitch("soundToggle", to: false, in: app)
        let silent = state(app)
        feedback(app, "Silent key retains touch") { adjust("semitones", to: 1, in: app) }
        expectHero(app, "440.0")
        XCTAssertEqual(state(app).integer("audioStartCount"), silent.integer("audioStartCount"))
        XCTAssertFalse(state(app).flag("audioActive"))
        capture("Tune — octave, audible keys and local sound gate", app)
        feedback(app, "Tuning reset") { tap(app.buttons["reset"], in: app) }
        expectHero(app, "220.0")
    }

    @MainActor
    func testDeviceSpiralExpansionAnglePresetScrubbingAndTransport() throws {
        let app = try launch("spiral")
        let baseline = state(app)
        feedback(app, "Spiral reset") { tap(app.buttons["reset"], in: app) }
        expectHero(app, "1.00×")
        feedback(app, "Spiral expansion slider") { adjust("spiralGrowth", to: 1, in: app) }
        XCTAssertEqual(state(app).number("spiralGrowth"), 0.3, accuracy: 0.01)
        feedback(app, "One full turn preset") { tap(app.buttons["fullTurn"], in: app) }
        expectHero(app, "6.59×")
        XCTAssertEqual(state(app).integer("discoveryCount"), 1)
        feedback(app, "Spiral angle slider") { adjust("spiralAngle", to: 0, in: app) }
        expectHero(app, "1.00×")
        let canvas = app.descendants(matching: .any)["lab.canvas"].firstMatch
        reveal(canvas, in: app)
        feedback(app, "Horizontal spiral unwind") {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)))
        }
        XCTAssertGreaterThan(state(app).number("spiralAngle"), 2 * .pi)
        let unwound = state(app).number("spiralAngle")
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertEqual(state(app).number("spiralAngle"), unwound, accuracy: 0.0001)
        feedback(app, "Spiral step") { tap(app.buttons["step"], in: app) }
        XCTAssertGreaterThan(state(app).number("spiralAngle"), unwound)
        feedback(app, "Reset spiral before playback") { tap(app.buttons["reset"], in: app) }
        feedback(app, "Spiral play") { tap(app.buttons["primaryAction"], in: app) }
        waitState(app, "Spiral advances", timeout: 5) { $0.number("spiralAngle") > 0.15 }
        feedback(app, "Spiral pause") { tap(app.buttons["primaryAction"], in: app) }
        assertStopped(app)
        capture("Spiral — equal angles multiply radius", app)
        assertNoAudio(since: baseline, in: app)
    }

    @MainActor
    func testDeviceHatCrowdSingleAndBatchTrialsAndReset() throws {
        let app = try launch("shuffle")
        let baseline = state(app)
        for people in stride(from: 7, through: 3, by: -1) {
            feedback(app, "Hat crowd \(people)") { tap(app.buttons["hatCount-Decrement"], in: app) }
            XCTAssertEqual(state(app).integer("hatCount"), people)
            expectHero(app, "\(people)")
        }
        feedback(app, "Single hat shuffle") { tap(app.buttons["primaryAction"], in: app) }
        XCTAssertEqual(state(app).integer("shuffleTrials"), 1)
        feedback(app, "Batch of 100 hat shuffles") { tap(app.buttons["batchShuffles"], in: app) }
        let shuffled = state(app)
        XCTAssertEqual(shuffled.integer("shuffleTrials"), 101)
        XCTAssertTrue((0...101).contains(shuffled.integer("noMatchTrials")))
        XCTAssertTrue(app.staticTexts["observation"].label.contains("finite-crowd chance is 33.33%"))
        XCTAssertEqual(shuffled.integer("discoveryCount"), 1)
        capture("Shuffle — actual trials and finite crowd", app)
        feedback(app, "Incrementing crowd clears trials") { tap(app.buttons["hatCount-Increment"], in: app) }
        XCTAssertEqual(state(app).integer("shuffleTrials"), 0)
        expectHero(app, "4")
        feedback(app, "Hat reset") { tap(app.buttons["reset"], in: app) }
        expectHero(app, "4")
        assertNoAudio(since: baseline, in: app)
    }

    @MainActor
    func testDeviceBellSingleBatchCapacityAndReset() throws {
        let app = try launch("bell")
        let baseline = state(app)
        feedback(app, "Drop 100 sums") { tap(app.buttons["primaryAction"], in: app) }
        expectHero(app, "100")
        feedback(app, "Drop 500 sums") { tap(app.buttons["batchSamples"], in: app) }
        expectHero(app, "600")
        XCTAssertEqual(state(app).integer("discoveryCount"), 1)
        for batch in 1...19 {
            feedback(app, "Bell capacity batch \(batch)") { tap(app.buttons["batchSamples"], in: app) }
            XCTAssertEqual(state(app).integer("bellSampleCount"), min(10_000, 600 + batch * 500))
        }
        XCTAssertEqual(state(app).integer("bellSampleCount"), 10_000)
        XCTAssertFalse(app.buttons["batchSamples"].isEnabled)
        XCTAssertFalse(app.buttons["primaryAction"].isEnabled)
        capture("Bell — density and 10000 sample capacity", app)
        feedback(app, "Bell reset") { tap(app.buttons["reset"], in: app) }
        expectHero(app, "0")
        XCTAssertTrue(app.buttons["batchSamples"].isEnabled)
        assertNoAudio(since: baseline, in: app)
    }

    @MainActor
    func testDeviceCompoundingSliderDoublingLimitAndReset() throws {
        let app = try launch("compound")
        let baseline = state(app)
        feedback(app, "Compound slider maximum") { adjust("compoundSteps", to: 1, in: app) }
        XCTAssertEqual(state(app).integer("compoundSteps"), 4096)
        expectHero(app, "2.71795")
        XCTAssertFalse(app.buttons["primaryAction"].isEnabled)
        feedback(app, "Compound slider minimum") { adjust("compoundSteps", to: 0, in: app) }
        expectHero(app, "2.00000")
        for steps in [2, 4, 8, 16, 32, 64, 128, 256, 512] {
            feedback(app, "Double compound steps to \(steps)") { tap(app.buttons["primaryAction"], in: app) }
            waitState(app, "Steps reach \(steps)", timeout: 5) { $0.integer("compoundSteps") == steps }
        }
        expectHero(app, "2.71563")
        XCTAssertEqual(state(app).integer("discoveryCount"), 1)
        XCTAssertTrue(app.staticTexts["observation"].label.contains("gap to e is 0.00265"))
        capture("Compound — 512 steps approach e", app)
        feedback(app, "Compound reset") { tap(app.buttons["reset"], in: app) }
        expectHero(app, "2.00000")
        assertNoAudio(since: baseline, in: app)
    }

    @MainActor
    func testDeviceWaitingRateStepsRealArrivalsPauseAndReset() throws {
        let app = try launch("wait")
        let baseline = state(app)
        feedback(app, "Waiting rate slider maximum") { adjust("arrivalRate", to: 1, in: app) }
        XCTAssertEqual(state(app).number("arrivalRate"), 3, accuracy: 0.01)
        XCTAssertEqual(state(app).integer("arrivalCount"), 0)
        feedback(app, "Waiting single step") { tap(app.buttons["step"], in: app) }
        XCTAssertEqual(state(app).number("waitingClock"), 0.1, accuracy: 0.0001)
        XCTAssertFalse(state(app).flag("running"))
        let beforePlay = state(app)
        feedback(app, "Waiting play") { tap(app.buttons["primaryAction"], in: app) }
        let observed = waitState(app, "Observe 20 actual random arrivals", timeout: 35) { $0.integer("arrivalCount") >= 20 }
        XCTAssertGreaterThan(observed.number("waitingClock"), 0.1)
        XCTAssertGreaterThanOrEqual(observed.number("sinceArrival"), 0)
        XCTAssertLessThanOrEqual(observed.number("sinceArrival"), observed.number("waitingClock"))
        XCTAssertGreaterThan(observed.integer("transientHapticStartCount"), beforePlay.integer("transientHapticStartCount"))
        XCTAssertEqual(observed.integer("discoveryCount"), 1)
        feedback(app, "Waiting pause") { tap(app.buttons["primaryAction"], in: app) }
        assertStopped(app)
        capture("Wait — real arrivals and memoryless clock", app)
        feedback(app, "Waiting rate change resets events") { adjust("arrivalRate", to: 0, in: app) }
        XCTAssertEqual(state(app).number("arrivalRate"), 0.3, accuracy: 0.01)
        XCTAssertEqual(state(app).integer("arrivalCount"), 0)
        XCTAssertEqual(state(app).number("waitingClock"), 0, accuracy: 0.0001)
        feedback(app, "Waiting reset") { tap(app.buttons["reset"], in: app) }
        expectHero(app, "0.00s")
        assertNoAudio(since: baseline, in: app)
    }

    @MainActor
    func testDeviceSensorySettingsGatesStrengthAndPreferencesPersist() throws {
        let app = try launch("resonate")
        openSettings(app)
        setSwitch("continuousFeelToggle", to: false, in: app)
        setSwitch("settingsSoundToggle", to: false, in: app)
        setSwitch("hapticsToggle", to: false, in: app)
        XCTAssertFalse(app.switches["continuousFeelToggle"].isEnabled)
        XCTAssertFalse(app.sliders["touchStrength"].isEnabled)
        captureScreen("Settings — feedback off disables touch controls", app)
        closeSettings(app)
        let off = state(app)
        XCTAssertFalse(off.flag("soundEnabled"))
        XCTAssertFalse(off.flag("hapticsEnabled"))
        tap(app.buttons["primaryAction"], in: app)
        waitState(app, "The visual note still progresses with feedback off", timeout: 8) { $0.number("time") >= 1 }
        let visualOnly = state(app)
        XCTAssertEqual(visualOnly.integer("audioStartCount"), off.integer("audioStartCount"))
        XCTAssertEqual(visualOnly.integer("hapticPatternStartCount"), off.integer("hapticPatternStartCount"))
        XCTAssertEqual(visualOnly.integer("transientHapticStartCount"), off.integer("transientHapticStartCount"))
        tap(app.buttons["stopNote"], in: app)

        openSettings(app)
        setSwitch("hapticsToggle", to: true, in: app)
        setSwitch("settingsSoundToggle", to: true, in: app)
        adjust("touchStrength", to: 1, in: app)
        closeSettings(app)
        let discrete = state(app)
        XCTAssertEqual(discrete.number("strength"), 1, accuracy: 0.01)
        XCTAssertFalse(discrete.flag("continuousFeelEnabled"))
        tap(app.buttons["primaryAction"], in: app)
        let audioOnlyEnvelope = waitState(app, "Audio and discrete touch work without a continuous pattern", timeout: 8) {
            $0.integer("audioStartCount") > discrete.integer("audioStartCount")
                && $0.integer("transientHapticStartCount") > discrete.integer("transientHapticStartCount")
        }
        XCTAssertEqual(audioOnlyEnvelope.integer("continuousHapticStartCount"), discrete.integer("continuousHapticStartCount"))
        recordDelta("Continuous feel off", discrete, audioOnlyEnvelope)
        tap(app.buttons["stopNote"], in: app)
        openSettings(app)
        setSwitch("continuousFeelToggle", to: true, in: app)
        closeSettings(app)
        let continuous = state(app)
        tap(app.buttons["primaryAction"], in: app)
        let strongest = waitState(app, "Re-enabling continuous feel starts a real pattern", timeout: 8) {
            $0.integer("continuousHapticStartCount") > continuous.integer("continuousHapticStartCount")
        }
        XCTAssertEqual(strongest.text("lastHapticKind"), "decay")
        XCTAssertTrue(strongest.flag("lastHapticIntensityIsConfigurable"))
        XCTAssertEqual(strongest.number("lastHapticIntensity"), 0.65, accuracy: 0.000001)
        recordDelta("Full strength starts an intensity 0.65 decay pattern", continuous, strongest)
        tap(app.buttons["stopNote"], in: app)

        openSettings(app)
        adjust("touchStrength", to: 0, in: app)
        closeSettings(app)
        let soft = state(app)
        tap(app.buttons["primaryAction"], in: app)
        let softPlayed = waitState(app, "Minimum strength changes the configured decay intensity", timeout: 8) {
            $0.integer("continuousHapticStartCount") > soft.integer("continuousHapticStartCount")
        }
        XCTAssertEqual(softPlayed.text("lastHapticKind"), "decay")
        XCTAssertTrue(softPlayed.flag("lastHapticIntensityIsConfigurable"))
        XCTAssertEqual(softPlayed.number("lastHapticIntensity"), 0.0975, accuracy: 0.000001)
        recordDelta("Minimum strength starts an intensity 0.0975 decay pattern", soft, softPlayed)
        tap(app.buttons["stopNote"], in: app)
        openSettings(app)
        setSwitch("continuousFeelToggle", to: false, in: app)
        setSwitch("settingsSoundToggle", to: false, in: app)
        setSwitch("hapticsToggle", to: false, in: app)
        closeSettings(app)
        let saved = state(app)
        app.terminate()
        app.launchArguments.append("--device-qa-preserve-preferences")
        app.launch()
        XCTAssertTrue(app.staticTexts["deviceQASnapshot"].waitForExistence(timeout: 10))
        let restored = state(app)
        XCTAssertFalse(restored.flag("soundEnabled"))
        XCTAssertFalse(restored.flag("hapticsEnabled"))
        XCTAssertFalse(restored.flag("continuousFeelEnabled"))
        XCTAssertEqual(restored.number("strength"), 0.15, accuracy: 0.01)
        XCTAssertEqual(restored.integer("discoveryCount"), saved.integer("discoveryCount"))
        XCTAssertGreaterThan(restored.integer("discoveryCount"), 0)
        capture("Preferences and discoveries survive relaunch", app)
    }

    @MainActor
    func testDeviceBackgroundTabsAndSheetsStopPlayback() throws {
        let app = try launch("resonate")
        let initial = state(app)
        tap(app.buttons["primaryAction"], in: app)
        waitState(app, "Start a note before backgrounding", timeout: 8) { $0.integer("audioStartCount") > initial.integer("audioStartCount") }
        XCUIDevice.shared.press(.home)
        app.activate()
        assertStopped(app)
        XCTAssertGreaterThan(state(app).integer("suspendCount"), initial.integer("suspendCount"))

        let again = state(app)
        tap(app.buttons["primaryAction"], in: app)
        waitState(app, "Start another note before switching tabs", timeout: 8) { $0.integer("audioStartCount") > again.integer("audioStartCount") }
        app.tabBars.buttons["Connections"].tap()
        assertStopped(app)
        tap(app.buttons["connection_tune"], in: app)
        let key = app.buttons["pianoKey0"]
        revealPianoKey(key, in: app)
        let tone = state(app)
        tap(key, in: app)
        waitState(app, "A selected keyboard note starts", timeout: 5) { $0.integer("audioStartCount") > tone.integer("audioStartCount") }
        openSettings(app)
        closeSettings(app)
        assertStopped(app)
        capture("Background, tabs and settings leave feedback stopped", app)
    }

    @MainActor
    func testDeviceConnectionsNavigateNineExperimentsAndReadFieldNotes() throws {
        let app = try launch("grow")
        let baseline = state(app)
        let experiments: [(lab: String, title: String, formula: String, note: String)] = [
            ("grow", "Grow & fade", "A(t) = A₀ eᵏᵗ", "The change per moment is k times the current amount."),
            ("resonate", "A fading note", "s(t) = A e⁻ᵏᵗ cos(2πft)", "The cosine makes the vibration."),
            ("rotate", "Imaginary turns", "eⁱᶿ = cos θ + i sin θ", "Multiplying by e raised to an imaginary angle"),
            ("tune", "Equal steps", "f(n) = f₀ · exp[n ln(2)/12]", "Each semitone multiplies frequency by 2^(1/12)"),
            ("spiral", "A growing spiral", "r = a eᵇᶿ", "Every equal angle multiplies the radius by the same factor."),
            ("shuffle", "The hat surprise", "P(no matches) → 1/e", "Each shuffle is a uniformly random permutation."),
            ("bell", "Order in randomness", "p(x) = exp(−x²/2) / √(2π)", "Add twelve independent uniform contributions"),
            ("compound", "Becoming e", "(1 + 1/n)ⁿ → e", "Start with 1 and a nominal growth rate of 100% per year."),
            ("wait", "The waiting game", "P(T > t) = e⁻λᵗ", "If arrivals are independent with a constant average rate λ")
        ]
        for experiment in experiments {
            app.tabBars.buttons["Connections"].tap()
            if !app.navigationBars["Connections"].exists {
                XCTAssertTrue(app.navigationBars["Connections"].waitForExistence(timeout: 5))
            }
            tapNavigationControl(app.buttons["connection_\(experiment.lab)"], in: app)
            waitState(app, "Connections selects \(experiment.title)", timeout: 5) { $0.text("lab") == experiment.lab }
            if app.staticTexts["experimentTitle"].label != experiment.title {
                let title = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "exists == true AND label == %@", experiment.title),
                    object: app.staticTexts["experimentTitle"]
                )
                XCTAssertEqual(XCTWaiter.wait(for: [title], timeout: 5), .completed)
            }
            XCTAssertEqual(app.staticTexts["experimentTitle"].label, experiment.title)
            capture("Connections — \(experiment.title) overview", app)
            tapNavigationControl(app.buttons["fieldNotes"], in: app)
            if !app.navigationBars["Field notes"].exists {
                XCTAssertTrue(app.navigationBars["Field notes"].waitForExistence(timeout: 5))
            }
            if !app.buttons["notesDone"].exists {
                XCTAssertTrue(app.buttons["notesDone"].waitForExistence(timeout: 5))
            }

            let formulas = app.staticTexts.matching(NSPredicate(format: "label == %@", experiment.formula))
            if !formulas.firstMatch.exists { XCTAssertTrue(formulas.firstMatch.waitForExistence(timeout: 5)) }
            XCTAssertTrue(formulas.allElementsBoundByIndex.contains { $0.isHittable },
                          "The opened Field notes sheet must visibly display \(experiment.formula).")
            let explanation = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", experiment.note)).firstMatch
            if !explanation.exists {
                XCTAssertTrue(explanation.waitForExistence(timeout: 5), "The selected experiment's explanation must be readable.")
            }
            XCTAssertTrue(explanation.label.hasPrefix(experiment.note))
            XCTAssertEqual(state(app).text("lab"), experiment.lab)
            if experiment.lab == "rotate" { capture("Connections — Field notes for imaginary turns", app) }
            closeFieldNotes(app)
            XCTAssertEqual(state(app).text("lab"), experiment.lab)
            XCTAssertEqual(app.staticTexts["experimentTitle"].label, experiment.title)
        }
        capture("Connections — all nine experiments navigated", app)
        assertNoAudio(since: baseline, in: app)
        XCTAssertEqual(state(app).integer("discoveryCount"), 0, "Reading Field notes alone must not award discoveries.")
    }

    // MARK: - Physical test support

    @MainActor
    private func tapNavigationControl(_ element: XCUIElement, in app: XCUIApplication) {
        if !element.exists { XCTAssertTrue(element.waitForExistence(timeout: 5)) }
        if !element.isHittable { reveal(element, in: app) }
        XCTAssertTrue(element.isEnabled)
        element.tap()
    }

    @MainActor
    private func closeFieldNotes(_ app: XCUIApplication) {
        let done = app.buttons["notesDone"]
        tapNavigationControl(done, in: app)
        if done.waitForNonExistence(timeout: 3) { return }
        // A foreground interruption can land exactly between target lookup and
        // delivery. Retry this reversible close once after returning to e.
        if app.state != .runningForeground { app.activate() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(done.exists && done.isHittable, "A close retry must still target the visible Field notes sheet.")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "Field notes must close after the single bounded retry.")
    }

    @MainActor
    private func launch(_ lab: String) throws -> XCUIApplication {
        #if targetEnvironment(simulator)
        throw XCTSkip("EulerDeviceQATests requires a signed physical iPhone run.")
        #else
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--device-qa", "--lab", lab, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["heroReadout"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["deviceQASnapshot"].waitForExistence(timeout: 10))
        let baseline = state(app)
        XCTAssertEqual(baseline.text("lab"), lab)
        XCTAssertTrue(baseline.flag("supportsHaptics"), "This suite requires an iPhone with Core Haptics support.")
        XCTAssertTrue(baseline.flag("soundEnabled"))
        XCTAssertTrue(baseline.flag("hapticsEnabled"))
        XCTAssertTrue(baseline.flag("continuousFeelEnabled"))
        XCTAssertEqual(baseline.integer("discoveryCount"), 0)
        return app
        #endif
    }

    @MainActor
    private func state(_ app: XCUIApplication) -> DeviceQAState {
        let element = app.staticTexts["deviceQASnapshot"].firstMatch
        XCTAssertTrue(element.exists, "DEBUG QA snapshot must be accessible on the current screen.")
        let raw = element.value as? String ?? element.label
        guard let dictionary = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any] else {
            XCTFail("Invalid device QA JSON: \(raw)")
            return DeviceQAState(raw: raw, values: [:])
        }
        guard let failures = dictionary["failures"] as? [[String: Any]] else {
            XCTFail("Missing feedback NSError failures array in QA snapshot: \(raw)")
            return DeviceQAState(raw: raw, values: dictionary)
        }
        XCTAssertTrue(failures.isEmpty, "Actual feedback requests reported \(failures.count) NSError failures: \(failures)")
        return DeviceQAState(raw: raw, values: dictionary)
    }

    @MainActor
    @discardableResult
    private func waitState(_ app: XCUIApplication, _ description: String, timeout: TimeInterval = 8,
                           condition: (DeviceQAState) -> Bool) -> DeviceQAState {
        let deadline = Date().addingTimeInterval(timeout)
        var latest = state(app)
        while !condition(latest) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            latest = state(app)
        }
        XCTAssertTrue(condition(latest), "\(description). Last snapshot: \(latest.raw)")
        return latest
    }

    @MainActor
    private func feedback(_ app: XCUIApplication, _ description: String, action: () -> Void) {
        let before = state(app)
        action()
        let after = waitState(app, "\(description) delivers touch", timeout: 5) {
            $0.integer("transientHapticStartCount") > before.integer("transientHapticStartCount")
                || $0.integer("continuousHapticStartCount") > before.integer("continuousHapticStartCount")
        }
        recordDelta(description, before, after)
    }

    @MainActor
    private func assertNoAudio(since baseline: DeviceQAState, in app: XCUIApplication) {
        let after = state(app)
        XCTAssertEqual(after.integer("audioStartCount"), baseline.integer("audioStartCount"),
                       "This experiment must not start audio, even with Sound enabled.")
        XCTAssertEqual(after.integer("audioRenderCount"), baseline.integer("audioRenderCount"))
        XCTAssertFalse(after.flag("audioActive"))
    }

    @MainActor
    private func assertStopped(_ app: XCUIApplication) {
        waitState(app, "Playback and animation stop", timeout: 8) {
            !$0.flag("running") && !$0.flag("audioActive") && !$0.flag("hapticActive")
        }
    }

    @MainActor
    private func expectHero(_ app: XCUIApplication, _ label: String) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label == %@", label),
            object: app.staticTexts["heroReadout"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, "Expected hero \(label).")
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let inSheet = app.buttons["notesDone"].exists || app.buttons["settingsDone"].exists || app.navigationBars["Dials"].exists
        let pages = app.scrollViews.allElementsBoundByIndex
        let page = (inSheet ? pages.last { $0.isHittable } : pages.first { $0.isHittable }) ?? app.scrollViews.firstMatch
        let requiresUnobscuredFrame = element.elementType == .slider || element.elementType == .switch
            || element.identifier == "lab.canvas" || element.identifier == "pianoKeyboard"
        let isConnectionCard = element.identifier.hasPrefix("connection_")
        for _ in 0..<12 {
            var viewport = page.frame.intersection(app.windows.firstMatch.frame)
            if let navigation = app.navigationBars.allElementsBoundByIndex.last(where: { $0.isHittable }) {
                let top = max(viewport.minY, navigation.frame.maxY)
                viewport = CGRect(x: viewport.minX, y: top, width: viewport.width, height: max(0, viewport.maxY - top))
            }
            if !inSheet, app.buttons["primaryAction"].exists {
                let bottom = min(viewport.maxY, app.buttons["primaryAction"].frame.minY - 12)
                viewport.size.height = max(0, bottom - viewport.minY)
            }
            if !inSheet, app.tabBars.firstMatch.exists {
                let bottom = min(viewport.maxY, app.tabBars.firstMatch.frame.minY - 12)
                viewport.size.height = max(0, bottom - viewport.minY)
            }
            let frame = element.frame
            let fullyVisible = frame.minY >= viewport.minY + 6 && frame.maxY <= viewport.maxY - 6
            if element.isHittable && (!requiresUnobscuredFrame || fullyVisible) { return }
            XCTAssertGreaterThan(viewport.height, 80, "The active scroll view must have an unobscured drag area.")
            let upwards = frame.midY > viewport.midY
            let window = app.windows.firstMatch
            let origin = window.coordinate(withNormalizedOffset: .zero)
            let gutterX = (isConnectionCard ? viewport.midX : viewport.minX + max(4, viewport.width * 0.02)) - window.frame.minX
            let lowY = viewport.maxY - 20 - window.frame.minY
            let highY = viewport.minY + 20 - window.frame.minY
            origin.withOffset(CGVector(dx: gutterX, dy: upwards ? lowY : highY))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: gutterX, dy: upwards ? highY : lowY)))
        }
        captureScreen("Unreachable control — \(element.identifier)", app)
        XCTFail("Control must be reachable in the unobscured page viewport without dragging the plot.")
    }

    @MainActor
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        reveal(element, in: app)
        XCTAssertTrue(element.isEnabled)
        element.tap()
    }

    @MainActor
    private func adjust(_ identifier: String, to value: CGFloat, in app: XCUIApplication) {
        let matches = app.sliders.matching(identifier: identifier)
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 5))
        // A presented Dials sheet and its covered page can expose the same ID.
        let slider = matches.allElementsBoundByIndex.first { $0.isHittable } ?? matches.firstMatch
        reveal(slider, in: app)
        XCTAssertTrue(slider.isEnabled)
        let before = state(app)
        let geometry = sliderGeometry(identifier, state: before)
        let destination = min(1, max(0, Double(value)))
        let expected = geometry.lower + destination * (geometry.upper - geometry.lower)
        let frame = slider.frame
        XCTAssertGreaterThan(frame.width, 40, "A real slider track must be visible before dragging its thumb.")
        XCTAssertGreaterThan(frame.height, 0)
        captureScreen("\(identifier) — unobscured slider before thumb drag", app)
        let geometryEvidence: [String: Any] = [
            "identifier": identifier, "frame": String(describing: frame),
            "primaryActionFrame": app.buttons["primaryAction"].exists ? String(describing: app.buttons["primaryAction"].frame) : "absent",
            "modelPosition": geometry.position, "rangeMinimum": geometry.lower, "rangeMaximum": geometry.upper,
            "targetPosition": expected, "baseline": before.values
        ]
        if let data = try? JSONSerialization.data(withJSONObject: geometryEvidence, options: [.sortedKeys]) {
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "\(identifier) — pre-drag geometry"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        // Native controls retain spoken unit values (Hz, radians, percent). Those
        // are not normalized coordinates, so XCTest's percentage-based helper
        // cannot infer the thumb position. Drag the real thumb from the model's
        // read-only position instead. Endpoints extend to the track's outer edge
        // so UIKit clamps exactly to its minimum or maximum.
        for thumbInset in [CGFloat(16), 20, 12] {
            let current = sliderGeometry(identifier, state: state(app))
            if abs(current.position - expected) <= 0.000001 { break }
            let fraction = min(1, max(0, (current.position - current.lower) / (current.upper - current.lower)))
            let trackWidth = frame.width - 2 * thumbInset
            let startX = thumbInset + CGFloat(fraction) * trackWidth
            let endX: CGFloat = destination == 0 ? 1
                : destination == 1 ? frame.width - 1
                : thumbInset + CGFloat(destination) * trackWidth
            let origin = slider.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: startX, dy: frame.height / 2))
                .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: endX, dy: frame.height / 2)))
        }
        let after = waitState(app, "\(identifier) reaches the requested value through a physical thumb drag", timeout: 5) {
            abs(self.sliderGeometry(identifier, state: $0).position - expected) <= 0.000001
        }
        recordDelta("\(identifier) thumb drag to normalized position \(destination)", before, after)
    }

    @MainActor
    private func sliderGeometry(_ identifier: String, state snapshot: DeviceQAState)
        -> (position: Double, lower: Double, upper: Double) {
        switch identifier {
        case "growthRate":
            return (snapshot.number("rate"), -1.5, snapshot.text("growthContext") == "Growth" ? 1.5 : -0.05)
        case "growthTime": return (snapshot.number("time"), 0, 3)
        case "pitch": return (snapshot.number("pitch"), 110, 880)
        case "decayRate": return (snapshot.number("decay"), 0.2, 2)
        case "rotationAngle": return (snapshot.number("angle"), 0, 2 * .pi)
        case "semitones": return (snapshot.number("semitone"), 0, 12)
        case "spiralGrowth": return (snapshot.number("spiralGrowth"), 0.02, 0.3)
        case "spiralAngle": return (snapshot.number("spiralAngle"), 0, 4 * .pi)
        case "compoundSteps": return (log2(snapshot.number("compoundSteps")), 0, 12)
        case "arrivalRate": return (snapshot.number("arrivalRate"), 0.3, 3)
        case "touchStrength": return (snapshot.number("strength"), 0.15, 1)
        default:
            XCTFail("No physical thumb geometry defined for \(identifier)")
            return (.nan, 0, 1)
        }
    }

    @MainActor
    private func revealPianoKey(_ key: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(key.waitForExistence(timeout: 5))
        let keyboard = app.scrollViews["pianoKeyboard"]
        reveal(keyboard, in: app)
        for _ in 0..<8 {
            if key.isHittable { return }
            if key.frame.midX < keyboard.frame.midX { keyboard.swipeRight() }
            else { keyboard.swipeLeft() }
        }
        XCTAssertTrue(key.isHittable)
    }

    @MainActor
    private func setSwitch(_ identifier: String, to enabled: Bool, in app: XCUIApplication) {
        let control = app.switches[identifier]
        reveal(control, in: app)
        captureScreen("\(identifier) — unobscured switch before thumb tap", app)
        let geometryEvidence: [String: Any] = [
            "identifier": identifier, "frame": String(describing: control.frame),
            "primaryActionFrame": app.buttons["primaryAction"].exists ? String(describing: app.buttons["primaryAction"].frame) : "absent",
            "nativeValue": control.value as? String ?? "unavailable", "targetEnabled": enabled,
            "baseline": state(app).values
        ]
        if let data = try? JSONSerialization.data(withJSONObject: geometryEvidence, options: [.sortedKeys]) {
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "\(identifier) — pre-tap switch geometry"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        if (control.value as? String == "1") != enabled {
            // SwiftUI can expose the label and thumb as one wide AX element.
            // Hit the trailing native switch rather than the row's center.
            control.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", enabled ? "1" : "0"), object: control
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, "\(identifier) must change its native switch value.")
        let field: String
        switch identifier {
        case "soundToggle", "settingsSoundToggle": field = "soundEnabled"
        case "hapticsToggle": field = "hapticsEnabled"
        case "continuousFeelToggle": field = "continuousFeelEnabled"
        default:
            XCTFail("No model field defined for switch \(identifier)")
            return
        }
        waitState(app, "\(identifier) changes its persisted model preference", timeout: 5) { $0.flag(field) == enabled }
    }

    @MainActor
    private func openSettings(_ app: XCUIApplication) {
        tap(app.buttons["settings"], in: app)
        XCTAssertTrue(app.switches["hapticsToggle"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func closeSettings(_ app: XCUIApplication) {
        tap(app.buttons["settingsDone"], in: app)
        XCTAssertTrue(app.staticTexts["deviceQASnapshot"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func capture(_ name: String, _ app: XCUIApplication) {
        let snapshot = state(app)
        let attachment = XCTAttachment(data: Data(snapshot.raw.utf8), uniformTypeIdentifier: "public.json")
        attachment.name = name + " — delivery state"
        attachment.lifetime = .keepAlways
        add(attachment)
        captureScreen(name, app)
    }

    @MainActor
    private func captureScreen(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func recordDelta(_ name: String, _ before: DeviceQAState, _ after: DeviceQAState) {
        let dictionary: [String: Any] = ["action": name, "baseline": before.values, "after": after.values]
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]) else { return }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name + " — baseline and actual delivery"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private struct DeviceQAState {
    let raw: String
    let values: [String: Any]

    func number(_ key: String) -> Double {
        guard let value = values[key] as? NSNumber else {
            XCTFail("Missing numeric QA field \(key)")
            return .nan
        }
        return value.doubleValue
    }
    func integer(_ key: String) -> Int {
        let value = number(key)
        return value.isFinite ? Int(value) : -1
    }
    func flag(_ key: String) -> Bool {
        guard let value = values[key] as? Bool else {
            XCTFail("Missing Boolean QA field \(key)")
            return false
        }
        return value
    }
    func text(_ key: String) -> String {
        guard let value = values[key] as? String else {
            XCTFail("Missing text QA field \(key)")
            return ""
        }
        return value
    }
}
