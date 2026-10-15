import AVFoundation
import CoreHaptics
import Foundation
import Observation
import UIKit

/// One owner for optional sound and touch. The same exponential envelope drives both.
/// No microphone or audio render callback is needed: each note is a bounded PCM buffer.
@MainActor
@Observable
final class SensoryEngine {
    var hapticsEnabled = true {
        didSet {
            if !hapticsEnabled { stopHaptics() }
            #if DEBUG
            publishDeviceQA(event: "preference.haptics")
            #endif
        }
    }
    var soundEnabled = false {
        didSet {
            if !soundEnabled { stopAudio() }
            #if DEBUG
            publishDeviceQA(event: "preference.sound")
            #endif
        }
    }
    var strength = 0.65 {
        didSet {
            stopHaptics()
            #if DEBUG
            publishDeviceQA(event: "preference.strength")
            #endif
        }
    }
    var continuousFeelEnabled = true {
        didSet {
            if !continuousFeelEnabled { stopHaptics() }
            #if DEBUG
            publishDeviceQA(event: "preference.continuousFeel")
            #endif
        }
    }
    var statusMessage: String?
    let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    @ObservationIgnored private let selectionGenerator = UISelectionFeedbackGenerator()
    @ObservationIgnored private let impactGenerator = UIImpactFeedbackGenerator(style: .soft)
    @ObservationIgnored private let successGenerator = UINotificationFeedbackGenerator()
    @ObservationIgnored private var lastFeedbackTime = -Double.infinity
    @ObservationIgnored private var hapticEngine: CHHapticEngine?
    @ObservationIgnored private var hapticEngineID: UUID?
    @ObservationIgnored private var hapticPlayer: (any CHHapticPatternPlayer)?
    @ObservationIgnored private var audioEngine: AVAudioEngine?
    @ObservationIgnored private var audioPlayer: AVAudioPlayerNode?
    @ObservationIgnored private var activeBuffer: AVAudioPCMBuffer?
    @ObservationIgnored private var audioFinishTask: Task<Void, Never>?
    @ObservationIgnored private var audioGeneration = 0
    @ObservationIgnored private var ownsAudioSession = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    #if DEBUG
    // Observed so an accessibility snapshot refreshes after real control events.
    private(set) var deviceQASnapshotJSON = "{}"
    @ObservationIgnored private var deviceQAReport: DeviceQAReport?
    @ObservationIgnored private var deviceQARenderTask: Task<Void, Never>?
    @ObservationIgnored private var deviceQAHapticEndTask: Task<Void, Never>?
    @ObservationIgnored private var activeDiagnostic: FeedbackCheckReport?
    @ObservationIgnored private var diagnosticIsRunning = false
    #endif

    private static let sampleRate = 48_000.0
    private static let maximumGain = 0.18
    private static let startDelay = 0.045

    init() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(
                forName: AVAudioSession.interruptionNotification, object: nil, queue: nil,
                using: Self.interruptionHandler(for: self)
            ),
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil,
                using: Self.mediaResetHandler(for: self)
            ),
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil,
                using: Self.routeChangeHandler(for: self)
            ),
        ]
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--device-qa") {
            deviceQAReport = DeviceQAReport(supportsHaptics: supportsHaptics)
            publishDeviceQA(event: "initialized")
        }
        #endif
    }

    isolated deinit {
        audioFinishTask?.cancel()
        #if DEBUG
        deviceQARenderTask?.cancel()
        deviceQAHapticEndTask?.cancel()
        #endif
        audioPlayer?.stop()
        audioEngine?.stop()
        try? hapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        hapticEngine?.stop(completionHandler: nil)
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        if ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// Coalesces slider updates into distinct ticks instead of a continuous buzz.
    func selection() {
        guard admitFeedback(minimumGap: 0.06) else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
        #if DEBUG
        recordDeviceQATransient(kind: "selection")
        #endif
    }

    func impact(intensity: Double = 0.5) {
        guard intensity.isFinite, admitFeedback(minimumGap: 0.035) else { return }
        let actualIntensity = Self.clamp(intensity, 0, 1) * hapticStrength
        impactGenerator.impactOccurred(intensity: CGFloat(actualIntensity))
        impactGenerator.prepare()
        #if DEBUG
        recordDeviceQATransient(kind: "impact", intensity: actualIntensity)
        #endif
    }

    func success() {
        // A discovery is rare and should take priority over its control tick.
        guard admitFeedback(minimumGap: 0) else { return }
        successGenerator.notificationOccurred(.success)
        successGenerator.prepare()
        #if DEBUG
        recordDeviceQATransient(kind: "success")
        #endif
    }

    /// Strike a note and feel its e^(-decay*t) envelope fade. Frequency is heard as
    /// pitch; the haptic motor represents the envelope, not the audio frequency.
    func playDecay(frequency: Double, decay: Double, duration: Double = 4) {
        guard canPlay, frequency.isFinite, decay.isFinite, duration.isFinite else { return }
        let length = Self.clamp(duration, 0.08, 8)
        let rate = Self.clamp(decay, 0, 10)
        stop()
        statusMessage = nil

        // Finish engine setup and buffer generation before choosing a shared start.
        let audioReady = soundEnabled && prepareAudio(frequency: frequency, decay: rate, duration: length)
        let hapticsReady = hapticsEnabled && continuousFeelEnabled && prepareDecayHaptics(decay: rate, duration: length)
        let hostStart = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: Self.startDelay)
        if audioReady { startAudio(hostTime: hostStart, duration: length, kind: "decay") }
        if hapticsReady, let hapticEngine {
            do {
                if let hapticPlayer {
                    try hapticPlayer.start(atTime: hapticEngine.currentTime + Self.startDelay)
                    #if DEBUG
                    activeDiagnostic?.hapticPlayerStartSucceeded = true
                    recordDeviceQAContinuousStart(duration: length)
                    #endif
                } else {
                    #if DEBUG
                    recordDiagnosticFailure(NSError(domain: "e.FeedbackCheck", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "No haptic player was available to start."]), stage: "hapticPlayer.start")
                    #endif
                }
            } catch {
                #if DEBUG
                recordDiagnosticFailure(error, stage: "hapticPlayer.start")
                #endif
                stopHaptics()
                selection()
                statusMessage = "Touch feedback is unavailable right now. Try again."
            }
        } else if hapticsEnabled {
            selection()
        }
    }

    /// A short equal-temperament note. It plays only after sound is explicitly on.
    func playTone(frequency: Double, duration: Double = 0.35) {
        guard soundEnabled, canPlay, frequency.isFinite, duration.isFinite else { return }
        let length = Self.clamp(duration, 0.05, 2)
        stopAudio()
        statusMessage = nil
        guard prepareAudio(frequency: frequency, decay: 0, duration: length) else { return }
        let start = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: Self.startDelay)
        startAudio(hostTime: start, duration: length, kind: "tone")
    }

    func stop() {
        #if DEBUG
        deviceQAReport?.stopCount += 1
        #endif
        stopHaptics()
        stopAudio()
        #if DEBUG
        publishDeviceQA(event: "stop")
        #endif
    }

    /// Call when the app's scene becomes inactive or enters the background.
    /// Playback never resumes automatically after an interruption.
    func suspend() {
        #if DEBUG
        deviceQAReport?.suspendCount += 1
        #endif
        stop()
        lastFeedbackTime = -Double.infinity
        #if DEBUG
        publishDeviceQA(event: "suspend")
        #endif
    }

    private var canPlay: Bool { UIApplication.shared.applicationState == .active }
    private var hapticStrength: Double { strength.isFinite ? Self.clamp(strength, 0.15, 1) : 0.65 }

    private func admitFeedback(minimumGap: Double) -> Bool {
        guard hapticsEnabled, canPlay else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFeedbackTime >= minimumGap else { return false }
        lastFeedbackTime = now
        return true
    }

    private func prepareDecayHaptics(decay: Double, duration: Double) -> Bool {
        guard hapticsEnabled, continuousFeelEnabled, supportsHaptics else { return false }
        do {
            let engine = try CHHapticEngine()
            let engineID = UUID()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = Self.hapticResetHandler(for: self, engineID: engineID)
            engine.stoppedHandler = Self.hapticStoppedHandler(for: self, engineID: engineID)
            hapticEngine = engine
            hapticEngineID = engineID
            try engine.start()
            #if DEBUG
            activeDiagnostic?.hapticEngineStarted = true
            deviceQAReport?.hapticEngineStartCount += 1
            publishDeviceQA(event: "hapticEngine.start")
            #endif

            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(0.65 * hapticStrength)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.22),
                ],
                relativeTime: 0, duration: duration
            )
            // A sampled curve preserves the exponential shape and ends gently even
            // for slow decay. Core Haptics linearly interpolates these control points.
            // Use consecutive windows of <=16 points, Core Haptics' documented
            // curve limit. Adjacent windows meet at an identical endpoint.
            let envelopes: [CHHapticParameterCurve] = stride(from: 0, to: 64, by: 15).map { start in
                let end = min(start + 15, 64)
                let windowStart = duration * Double(start) / 64
                let points: [CHHapticParameterCurve.ControlPoint] = (start...end).map { index in
                    let time = duration * Double(index) / 64
                    let release = min(1, max(0, (duration - time) / 0.06))
                    return .init(relativeTime: time - windowStart, value: Float(exp(-decay * time) * release))
                }
                return CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl, controlPoints: points, relativeTime: windowStart
                )
            }
            let pattern = try CHHapticPattern(events: [event], parameterCurves: envelopes)
            hapticPlayer = try engine.makePlayer(with: pattern)
            #if DEBUG
            activeDiagnostic?.hapticPlayerCreated = hapticPlayer != nil
            #endif
            return true
        } catch {
            #if DEBUG
            recordDiagnosticFailure(error, stage: "haptics.prepare")
            #endif
            stopHaptics()
            statusMessage = "Touch feedback is unavailable right now. Try again."
            return false
        }
    }

    private func stopHaptics() {
        #if DEBUG
        deviceQAHapticEndTask?.cancel()
        deviceQAHapticEndTask = nil
        do { try hapticPlayer?.stop(atTime: CHHapticTimeImmediate) }
        catch { recordDiagnosticFailure(error, stage: "hapticPlayer.stop") }
        #else
        try? hapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        #endif
        hapticPlayer = nil
        hapticEngine?.stop(completionHandler: nil)
        hapticEngine = nil
        hapticEngineID = nil
        #if DEBUG
        deviceQAReport?.hapticActive = false
        publishDeviceQA(event: "haptics.stop")
        #endif
    }

    private func prepareAudio(frequency: Double, decay: Double, duration: Double) -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            // Explicit Sound opt-in permits notes in Silent Mode. Playback retains
            // the user's chosen output route and mixes with existing audio.
            try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
            #if DEBUG
            activeDiagnostic?.audioSessionCategory = session.category.rawValue
            activeDiagnostic?.audioSessionOptions = session.categoryOptions.rawValue
            deviceQAReport?.audioSessionCategory = session.category.rawValue
            deviceQAReport?.audioSessionOptions = session.categoryOptions.rawValue
            #endif
            try session.setActive(true)
            ownsAudioSession = true
            #if DEBUG
            activeDiagnostic?.audioSessionActivated = true
            activeDiagnostic?.audioRoute = session.currentRoute.outputs.map { $0.portType.rawValue }
            activeDiagnostic?.audioOutputVolume = Double(session.outputVolume)
            deviceQAReport?.audioSessionActivated = true
            deviceQAReport?.audioRoute = session.currentRoute.outputs.map { $0.portType.rawValue }
            deviceQAReport?.audioOutputVolume = Double(session.outputVolume)
            #endif

            guard let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1) else {
                throw PlaybackError.bufferUnavailable
            }
            if audioEngine == nil {
                let engine = AVAudioEngine()
                let player = AVAudioPlayerNode()
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                audioEngine = engine
                audioPlayer = player
            }
            let frameCount = AVAudioFrameCount((duration * Self.sampleRate).rounded())
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
                  let samples = buffer.floatChannelData?[0] else {
                throw PlaybackError.bufferUnavailable
            }
            buffer.frameLength = frameCount
            let pitch = Self.clamp(frequency, 20, 8_000)
            #if DEBUG
            var bufferPeak: Float = 0
            #endif
            for frame in 0..<Int(frameCount) {
                let time = Double(frame) / Self.sampleRate
                let attack = min(1, time / 0.008)
                let release = min(1, max(0, (duration - time) / 0.024))
                let envelope = exp(-decay * time) * attack * release
                samples[frame] = Float(Self.maximumGain * envelope * sin(2 * .pi * pitch * time))
                #if DEBUG
                if activeDiagnostic != nil || deviceQAReport != nil { bufferPeak = max(bufferPeak, abs(samples[frame])) }
                #endif
            }
            #if DEBUG
            activeDiagnostic?.audioBufferPeak = Double(bufferPeak)
            activeDiagnostic?.audioPlayerVolume = audioPlayer.map { Double($0.volume) }
            activeDiagnostic?.mainMixerOutputVolume = audioEngine.map { Double($0.mainMixerNode.outputVolume) }
            deviceQAReport?.audioBufferPeak = Double(bufferPeak)
            deviceQAReport?.audioPlayerVolume = audioPlayer.map { Double($0.volume) } ?? 0
            deviceQAReport?.mainMixerOutputVolume = audioEngine.map { Double($0.mainMixerNode.outputVolume) } ?? 0
            deviceQAReport?.lastAudioFrequency = pitch
            deviceQAReport?.lastAudioDecay = decay
            #endif
            activeBuffer = buffer
            if let audioPlayer {
                audioPlayer.scheduleBuffer(buffer, completionHandler: nil)
                #if DEBUG
                activeDiagnostic?.audioBufferScheduled = true
                deviceQAReport?.audioBufferScheduledCount += 1
                #endif
            }
            if audioEngine?.isRunning == false { try audioEngine?.start() }
            #if DEBUG
            activeDiagnostic?.audioEngineRunning = audioEngine?.isRunning ?? false
            publishDeviceQA(event: "audio.prepare")
            #endif
            return true
        } catch {
            #if DEBUG
            recordDiagnosticFailure(error, stage: "audio.prepare")
            #endif
            stopAudio()
            statusMessage = "Sound is unavailable right now. Try again."
            return false
        }
    }

    private func startAudio(hostTime: UInt64, duration: Double, kind: String) {
        guard let audioPlayer else { return }
        let start = AVAudioTime(hostTime: hostTime)
        do {
            if #available(iOS 27, *) {
                try audioPlayer.playAudio(at: start)
            } else {
                audioPlayer.play(at: start)
            }
            #if DEBUG
            activeDiagnostic?.audioPlayerStartRequested = true
            activeDiagnostic?.audioPlayerIsPlaying = audioPlayer.isPlaying
            #endif
            audioGeneration += 1
            let generation = audioGeneration
            #if DEBUG
            recordDeviceQAAudioStart(kind: kind, duration: duration, generation: generation)
            #endif
            audioFinishTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(duration + Self.startDelay + 0.05)) }
                catch { return }
                guard let self, self.audioGeneration == generation else { return }
                self.stopAudio()
            }
        } catch {
            #if DEBUG
            recordDiagnosticFailure(error, stage: "audioPlayer.start")
            #endif
            stopAudio()
            statusMessage = "Sound is unavailable right now. Try again."
        }
    }

    private func stopAudio() {
        #if DEBUG
        if audioPlayer?.isPlaying == true || audioEngine?.isRunning == true {
            deviceQAReport?.audioStopCount += 1
        }
        deviceQARenderTask?.cancel()
        deviceQARenderTask = nil
        #endif
        audioGeneration += 1
        audioFinishTask?.cancel()
        audioFinishTask = nil
        audioPlayer?.stop()
        audioEngine?.pause()
        activeBuffer = nil
        if ownsAudioSession {
            #if DEBUG
            do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
            catch { recordDiagnosticFailure(error, stage: "audioSession.deactivate") }
            #else
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
            ownsAudioSession = false
        }
        #if DEBUG
        publishDeviceQA(event: "audio.stop")
        #endif
    }

    private func invalidateAudio() {
        stopAudio()
        audioEngine?.stop()
        audioPlayer = nil
        audioEngine = nil
    }

    private enum PlaybackError: Error { case bufferUnavailable }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(upper, max(lower, value))
    }

    #if DEBUG
    /// Device QA observes the production APIs. A UIKit call or accepted Core
    /// Haptics start is not proof of a sensation; advancing samples prove audio
    /// processing, not audibility. Only --device-qa enables this bookkeeping.
    private struct DeviceQAReport: Codable {
        var schemaVersion = 1
        var startedAt = Date().ISO8601Format()
        var updatedAt = Date().ISO8601Format()
        var eventSequence = 0
        var lastEvent = "initialized"
        var applicationActive = false
        var hapticsEnabled = true
        var soundEnabled = false
        var continuousFeelEnabled = true
        var strength = 0.65
        var supportsHaptics: Bool
        var selectionExecutedCount = 0
        var impactExecutedCount = 0
        var successExecutedCount = 0
        var transientHapticStartCount = 0
        var hapticEngineStartCount = 0
        var hapticPatternStartCount = 0
        var continuousHapticStartCount = 0
        // Accepted continuous pattern within its scheduled interval; earlier
        // explicit stops and engine callbacks clear it. Not motor telemetry.
        var hapticActive = false
        var lastHapticKind = "none"
        var lastHapticIntensity = 0.0
        var lastHapticIntensityIsConfigurable = false
        var audioStartCount = 0
        var toneAudioStartCount = 0
        var decayAudioStartCount = 0
        var audioRenderCount = 0
        var toneRenderAdvancedCount = 0
        var decayRenderAdvancedCount = 0
        var audioRenderProbeCompletedCount = 0
        var audioStopCount = 0
        var audioBufferScheduledCount = 0
        // AVAudioPlayerNode.isPlaying && AVAudioEngine.isRunning.
        var audioActive = false
        var audioEngineRunning = false
        var audioPlayerIsPlaying = false
        var lastAudioFrequency = 0.0
        var lastAudioDecay = 0.0
        var lastAudioKind = "none"
        var audioRenderSampleStart: Int64?
        var audioRenderSampleEnd: Int64?
        var lastAudioRenderAdvanced = false
        var audioSessionCategory = ""
        var audioSessionOptions: UInt = 0
        var audioSessionActivated = false
        var audioSessionOwned = false
        var audioRoute: [String] = []
        var audioOutputVolume = 0.0
        var audioBufferPeak = 0.0
        var audioPlayerVolume = 0.0
        var mainMixerOutputVolume = 0.0
        var stopCount = 0
        var suspendCount = 0
        var statusMessage: String?
        var failures: [FeedbackCheckFailure] = []
    }

    private func recordDeviceQATransient(kind: String, intensity: Double? = nil) {
        guard deviceQAReport != nil else { return }
        switch kind {
        case "selection": deviceQAReport?.selectionExecutedCount += 1
        case "impact": deviceQAReport?.impactExecutedCount += 1
        case "success": deviceQAReport?.successExecutedCount += 1
        default: return
        }
        deviceQAReport?.transientHapticStartCount += 1
        deviceQAReport?.lastHapticKind = kind
        deviceQAReport?.lastHapticIntensity = intensity ?? 0
        deviceQAReport?.lastHapticIntensityIsConfigurable = intensity != nil
        publishDeviceQA(event: "haptic.\(kind).requested")
    }

    private func recordDeviceQAContinuousStart(duration: Double) {
        guard deviceQAReport != nil else { return }
        deviceQAReport?.hapticPatternStartCount += 1
        deviceQAReport?.continuousHapticStartCount += 1
        deviceQAReport?.hapticActive = true
        deviceQAReport?.lastHapticKind = "decay"
        deviceQAReport?.lastHapticIntensity = 0.65 * hapticStrength
        deviceQAReport?.lastHapticIntensityIsConfigurable = true
        publishDeviceQA(event: "haptic.pattern.startAccepted")
        deviceQAHapticEndTask?.cancel()
        let engineID = hapticEngineID
        deviceQAHapticEndTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(Self.startDelay + duration)) }
            catch { return }
            guard let self, self.hapticEngineID == engineID else { return }
            self.deviceQAReport?.hapticActive = false
            self.publishDeviceQA(event: "haptic.pattern.scheduledIntervalEnded")
        }
    }

    private func recordDeviceQAAudioStart(kind: String, duration: Double, generation: Int) {
        guard deviceQAReport != nil else { return }
        deviceQAReport?.audioStartCount += 1
        if kind == "tone" { deviceQAReport?.toneAudioStartCount += 1 }
        else { deviceQAReport?.decayAudioStartCount += 1 }
        deviceQAReport?.lastAudioKind = kind
        deviceQAReport?.audioRenderSampleStart = nil
        deviceQAReport?.audioRenderSampleEnd = nil
        deviceQAReport?.lastAudioRenderAdvanced = false
        publishDeviceQA(event: "audio.\(kind).startAccepted")
        deviceQARenderTask?.cancel()
        deviceQARenderTask = Task { @MainActor [weak self] in
            // Both probes fit even the shortest permitted real note. For the
            // standard 0.35 s tone these occur around 80 ms and 185 ms.
            do {
                try await Task.sleep(for: .seconds(Self.startDelay + min(0.035, duration * 0.15)))
                guard let self, self.audioGeneration == generation else { return }
                let first = self.diagnosticAudioSamplePosition()
                self.deviceQAReport?.audioRenderSampleStart = first
                try await Task.sleep(for: .seconds(min(0.1, duration * 0.3)))
                guard self.audioGeneration == generation else { return }
                let second = self.diagnosticAudioSamplePosition()
                let advanced = first != nil && second != nil && second! > first!
                self.deviceQAReport?.audioRenderSampleEnd = second
                self.deviceQAReport?.lastAudioRenderAdvanced = advanced
                self.deviceQAReport?.audioRenderProbeCompletedCount += 1
                if advanced {
                    self.deviceQAReport?.audioRenderCount += 1
                    if kind == "tone" { self.deviceQAReport?.toneRenderAdvancedCount += 1 }
                    else { self.deviceQAReport?.decayRenderAdvancedCount += 1 }
                }
                self.publishDeviceQA(event: "audio.\(kind).renderProbe")
            } catch { /* An intentional stop cancels the probe. */ }
        }
    }

    private func publishDeviceQA(event: String) {
        guard var report = deviceQAReport else { return }
        report.hapticsEnabled = hapticsEnabled
        report.soundEnabled = soundEnabled
        report.continuousFeelEnabled = continuousFeelEnabled
        report.strength = strength.isFinite ? strength : 0.65
        report.applicationActive = canPlay
        report.audioEngineRunning = audioEngine?.isRunning ?? false
        report.audioPlayerIsPlaying = audioPlayer?.isPlaying ?? false
        report.audioActive = report.audioEngineRunning && report.audioPlayerIsPlaying
        report.audioSessionOwned = ownsAudioSession
        report.statusMessage = statusMessage
        report.eventSequence += 1
        report.lastEvent = event
        report.updatedAt = Date().ISO8601Format()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(report)
            deviceQASnapshotJSON = String(decoding: data, as: UTF8.self)
            let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: true)
            try data.write(to: documents.appendingPathComponent("device-qa-feedback.json"), options: .atomic)
        } catch {
            let failure = error as NSError
            report.failures.append(FeedbackCheckFailure(stage: "deviceQA.report.write", domain: failure.domain,
                                                       code: failure.code, message: failure.localizedDescription))
            report.failures = Array(report.failures.suffix(20))
            if let data = try? encoder.encode(report) {
                deviceQASnapshotJSON = String(decoding: data, as: UTF8.self)
            }
        }
        deviceQAReport = report
    }

    /// An explicit development cue. Facts describe engine requests and rendering,
    /// not whether a person heard a speaker or felt the phone's haptic motor.
    func runDiagnosticCue() async {
        guard !diagnosticIsRunning else { return }
        diagnosticIsRunning = true
        let previous = (sound: soundEnabled, haptics: hapticsEnabled,
                        continuous: continuousFeelEnabled, strength: strength)
        activeDiagnostic = FeedbackCheckReport(applicationActive: canPlay, supportsHaptics: supportsHaptics)
        defer {
            stop()
            soundEnabled = previous.sound
            hapticsEnabled = previous.haptics
            continuousFeelEnabled = previous.continuous
            strength = previous.strength
            activeDiagnostic?.settingsRestored = true
            activeDiagnostic?.completedAt = Date().ISO8601Format()
            activeDiagnostic?.statusMessage = statusMessage
            let report = activeDiagnostic
            activeDiagnostic = nil
            diagnosticIsRunning = false
            if let report { saveDiagnosticReport(report) }
        }
        guard canPlay else {
            recordDiagnosticFailure(NSError(domain: "e.FeedbackCheck", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The app was not active; no cue was requested."]), stage: "application.active")
            return
        }
        do {
            try Task.checkCancellation()
            soundEnabled = true
            hapticsEnabled = true
            continuousFeelEnabled = true
            strength = 0.65
            playDecay(frequency: 220, decay: 0.9, duration: 2)
            try await Task.sleep(for: .milliseconds(150))
            let first = diagnosticAudioSamplePosition()
            activeDiagnostic?.audioRenderSampleStart = first
            try await Task.sleep(for: .milliseconds(350))
            let second = diagnosticAudioSamplePosition()
            activeDiagnostic?.audioRenderSampleEnd = second
            activeDiagnostic?.audioRenderAdvanced = first != nil && second != nil && second! > first!
            activeDiagnostic?.audioEngineRunningAtRenderCheck = audioEngine?.isRunning ?? false
            try await Task.sleep(for: .milliseconds(1650))
            activeDiagnostic?.cueWaitCompleted = true
        } catch {
            activeDiagnostic?.cancelled = error is CancellationError
            recordDiagnosticFailure(error, stage: "diagnostic.wait")
        }
    }

    private struct FeedbackCheckReport: Codable {
        var startedAt = Date().ISO8601Format()
        var completedAt: String?
        var applicationActive: Bool
        var supportsHaptics: Bool
        var frequencyHz = 220.0
        var decayPerSecond = 0.9
        var durationSeconds = 2.0
        var audioSessionCategory: String?
        var audioSessionOptions: UInt?
        var audioSessionActivated = false
        var audioRoute: [String] = []
        var audioOutputVolume: Double?
        var audioEngineRunning = false
        var audioBufferScheduled = false
        var audioBufferPeak: Double?
        var audioPlayerVolume: Double?
        var mainMixerOutputVolume: Double?
        var audioPlayerStartRequested = false
        var audioPlayerIsPlaying = false
        var audioRenderSampleStart: Int64?
        var audioRenderSampleEnd: Int64?
        var audioRenderAdvanced = false
        var audioEngineRunningAtRenderCheck = false
        var hapticEngineStarted = false
        var hapticPlayerCreated = false
        var hapticPlayerStartSucceeded = false
        var cueWaitCompleted = false
        var cancelled = false
        var settingsRestored = false
        var statusMessage: String?
        var failures: [FeedbackCheckFailure] = []
    }

    private struct FeedbackCheckFailure: Codable {
        let stage: String
        let domain: String
        let code: Int
        let message: String
    }

    private func diagnosticAudioSamplePosition() -> Int64? {
        guard let audioPlayer, let renderTime = audioPlayer.lastRenderTime,
              let playerTime = audioPlayer.playerTime(forNodeTime: renderTime), playerTime.isSampleTimeValid else { return nil }
        return playerTime.sampleTime
    }

    private func recordDiagnosticFailure(_ error: Error, stage: String) {
        guard activeDiagnostic != nil || deviceQAReport != nil else { return }
        let failure = error as NSError
        let entry = FeedbackCheckFailure(stage: stage, domain: failure.domain,
                                        code: failure.code, message: failure.localizedDescription)
        activeDiagnostic?.failures.append(entry)
        deviceQAReport?.failures.append(entry)
        if let failures = deviceQAReport?.failures {
            deviceQAReport?.failures = Array(failures.suffix(20))
        }
        publishDeviceQA(event: "failure.\(stage)")
    }

    private func saveDiagnosticReport(_ report: FeedbackCheckReport) {
        var final = report
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: true)
            try encoder.encode(final).write(to: documents.appendingPathComponent("feedback-check.json"), options: .atomic)
        } catch {
            let failure = error as NSError
            final.failures.append(FeedbackCheckFailure(stage: "report.write", domain: failure.domain,
                                                      code: failure.code, message: failure.localizedDescription))
        }
        if let data = try? encoder.encode(final) {
            print("E_FEEDBACK_CHECK \(String(decoding: data, as: UTF8.self))")
        }
    }
    #endif

    // SDK callbacks arrive on system queues. Construct the callbacks outside the
    // main actor and transfer only Sendable values before touching service state.
    nonisolated private static func interruptionHandler(for owner: SensoryEngine) -> @Sendable (Notification) -> Void {
        { [weak owner] notification in
            guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak owner] in
                guard let owner else { return }
                let wasPlaying = owner.ownsAudioSession || owner.hapticPlayer != nil
                owner.suspend()
                if wasPlaying { owner.statusMessage = "Playback paused. Play again when you are ready." }
                #if DEBUG
                owner.publishDeviceQA(event: "lifecycle.audioInterruption")
                #endif
            }
        }
    }

    nonisolated private static func mediaResetHandler(for owner: SensoryEngine) -> @Sendable (Notification) -> Void {
        { [weak owner] _ in
            Task { @MainActor [weak owner] in
                owner?.stopHaptics()
                owner?.invalidateAudio()
                #if DEBUG
                owner?.publishDeviceQA(event: "lifecycle.mediaServicesReset")
                #endif
            }
        }
    }

    nonisolated private static func routeChangeHandler(for owner: SensoryEngine) -> @Sendable (Notification) -> Void {
        { [weak owner] notification in
            guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue ||
                    reason == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue else { return }
            Task { @MainActor [weak owner] in
                owner?.invalidateAudio()
                #if DEBUG
                owner?.publishDeviceQA(event: "lifecycle.audioRouteChanged")
                #endif
            }
        }
    }

    nonisolated private static func hapticResetHandler(for owner: SensoryEngine, engineID: UUID) -> @Sendable () -> Void {
        { [weak owner] in
            Task { @MainActor [weak owner] in
                guard let owner, owner.hapticEngineID == engineID else { return }
                owner.stopHaptics()
                #if DEBUG
                owner.publishDeviceQA(event: "lifecycle.hapticEngineReset")
                #endif
            }
        }
    }

    nonisolated private static func hapticStoppedHandler(for owner: SensoryEngine, engineID: UUID) -> @Sendable (CHHapticEngine.StoppedReason) -> Void {
        { [weak owner] _ in
            Task { @MainActor [weak owner] in
                guard let owner, owner.hapticEngineID == engineID else { return }
                owner.hapticPlayer = nil
                #if DEBUG
                owner.deviceQAHapticEndTask?.cancel()
                owner.deviceQAHapticEndTask = nil
                owner.deviceQAReport?.hapticActive = false
                owner.publishDeviceQA(event: "lifecycle.hapticEngineStopped")
                #endif
            }
        }
    }
}
