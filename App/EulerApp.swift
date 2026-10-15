import SwiftUI

@main
struct EulerApp: App {
    var body: some Scene {
        WindowGroup { EulerRootView().preferredColorScheme(.dark) }
    }
}

enum AppSheet: String, Identifiable {
    case dials, notes, settings
    var id: String { rawValue }
}

struct EulerRootView: View {
    @State private var model = Playground()
    @State private var tab = 0
    @State private var sheet: AppSheet?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if DEBUG
    @State private var hasRunFeedbackCheck = false
    #endif
    private var animating: Bool { model.running && tab == 0 && sheet == nil && scenePhase == .active }
    var body: some View {
        TabView(selection: $tab) {
            Tab("Play", systemImage: "hand.draw", value: 0) {
                NavigationStack {
                    ExperimentView(model: model)
                        .toolbar {
                            ToolbarItem(placement: .principal) {
                                HStack(spacing: 8) {
                                    Text("e").font(.system(size: 34, weight: .medium, design: .serif).italic()).foregroundStyle(Ink.mint)
                                    Text("2.71828…").font(.system(.caption, design: .monospaced)).foregroundStyle(Ink.muted)
                                }.accessibilityLabel("e, the natural playground")
                            }
                            ToolbarItemGroup(placement: .topBarLeading) {
                                Button("Dials") { model.stop(); sheet = .dials }
                                    .accessibilityIdentifier("dials")
                                Button { tab = 1 } label: { Image(systemName: "square.grid.2x2") }
                                    .accessibilityLabel("Choose experiment").accessibilityIdentifier("chooseExperiment")
                            }
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                Button { model.stop(); sheet = .notes } label: { Image(systemName: "info") }
                                    .accessibilityLabel("Why e appears").accessibilityIdentifier("fieldNotes")
                                Button { model.stop(); sheet = .settings } label: { Image(systemName: "slider.horizontal.3") }
                                    .accessibilityLabel("Sensory settings").accessibilityIdentifier("settings")
                            }
                        }.navigationBarTitleDisplayMode(.inline)
                }
            }
            Tab("Connections", systemImage: "square.grid.2x2", value: 1) {
                NavigationStack {
                    ConnectionsView(model: model) { kind in model.select(kind); tab = 0 }
                        .navigationTitle("Connections").navigationBarTitleDisplayMode(.inline)
                }
            }
            Tab("Discoveries", systemImage: "sparkles", value: 2) {
                NavigationStack {
                    DiscoveriesView(model: model) { kind in model.select(kind); tab = 0 }
                        .navigationTitle("Discoveries").navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .tint(Ink.mint).foregroundStyle(Ink.text)
        .overlay(alignment: .topLeading) {
            #if DEBUG
            if sheet == nil { deviceQABadge }
            #endif
        }
        .sheet(item: $sheet) { destination in
            Group {
                switch destination {
                case .dials: DialsSheet(model: model)
                case .notes: FieldNotesView(lab: model.lab)
                case .settings: SensorySettingsView(model: model)
                }
            }.overlay(alignment: .topLeading) { deviceQABadge }
        }
        .onChange(of: tab) { _, _ in model.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.running = false; model.sensory.suspend() }
        }
        .task(id: scenePhase) {
            #if DEBUG
            guard scenePhase == .active, !hasRunFeedbackCheck,
                  ProcessInfo.processInfo.arguments.contains("--feedback-check") else { return }
            do { try await Task.sleep(for: .milliseconds(700)) }
            catch { return }
            guard !Task.isCancelled, scenePhase == .active else { return }
            hasRunFeedbackCheck = true
            await model.sensory.runDiagnosticCue()
            #endif
        }
        .task(id: animating) {
            guard animating else { return }
            var last = ContinuousClock.now
            while !Task.isCancelled && animating {
                do { try await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 33)) }
                catch { return }
                let now = ContinuousClock.now
                let components = last.duration(to: now).components
                let dt = Double(components.seconds) + Double(components.attoseconds) / 1e18
                last = now
                model.advance(dt)
            }
        }
    }
    @ViewBuilder private var deviceQABadge: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--device-qa") {
            Text("Device QA").font(.system(size: 1)).opacity(0.01)
                .accessibilityLabel("Device QA")
                .accessibilityValue(deviceQAState)
                .accessibilityIdentifier("deviceQASnapshot")
                .allowsHitTesting(false)
        }
        #endif
    }
    #if DEBUG
    /// Read-only observability for signed physical UI tests. Interactions still
    /// travel through the visible controls, and production preferences are isolated.
    private var deviceQAState: String {
        var state = (try? JSONSerialization.jsonObject(with: Data(model.sensory.deviceQASnapshotJSON.utf8))) as? [String: Any] ?? [:]
        state.merge([
            "lab": model.lab.rawValue, "running": model.running,
            "time": model.time, "rate": model.rate, "growthContext": model.growthContext.rawValue,
            "decay": model.decay, "pitch": model.pitch, "angle": model.angle,
            "semitone": model.semitone, "spiralGrowth": model.spiralGrowth,
            "spiralAngle": model.spiralAngle, "compoundSteps": model.compoundSteps,
            "hatCount": model.hatCount, "shuffleTrials": model.shuffleTrials,
            "noMatchTrials": model.noMatchTrials, "bellSampleCount": model.bellSamples.count,
            "arrivalRate": model.arrivalRate, "arrivalCount": model.arrivalCount,
            "waitingClock": model.waitingClock, "sinceArrival": model.sinceArrival,
            "discoveryCount": model.discoveries.count, "applicationActive": scenePhase == .active,
        ], uniquingKeysWith: { _, new in new })
        guard let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
    #endif
}

struct ExperimentView: View {
    @Bindable var model: Playground
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        InstrumentLabel("Experiment \(String(format: "%02d", model.lab.index)) / 09", color: model.lab.accent)
                        Spacer()
                        Circle().fill(model.lab.accent).frame(width: 5, height: 5)
                        InstrumentLabel(model.running ? "Running" : "Your move", color: model.lab.accent)
                    }
                    Text(model.lab.title).font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .accessibilityIdentifier("experimentTitle")
                    Text(model.lab.subtitle).font(.subheadline).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
                }
                hero
                ExperimentControls(model: model)
                MatteCard(accent: model.lab.accent) {
                    InstrumentLabel("Follow the change", color: model.lab.accent)
                    Text(model.observation).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("observation")
                    Text(model.lab.formula).font(.system(.title3, design: .serif)).foregroundStyle(model.lab.accent)
                }
                if let discovery = model.latestDiscovery {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles").foregroundStyle(Ink.amber)
                        VStack(alignment: .leading, spacing: 5) {
                            InstrumentLabel("Connection discovered", color: Ink.amber)
                            Text(discovery.discoveryTitle).font(.subheadline.weight(.medium))
                        }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Ink.amber.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                        .accessibilityIdentifier("discoveryBanner")
                }
            }.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 24)
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background { AppBackground() }.scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) { ExperimentTransport(model: model) }
    }
    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            InstrumentLabel(model.readoutLabel, color: model.lab.accent)
            Text(model.readout).font(.system(size: 52, weight: .medium, design: .rounded)).monospacedDigit()
                .foregroundStyle(model.lab.accent).lineLimit(1).minimumScaleFactor(0.45)
                .accessibilityIdentifier("heroReadout")
            Group {
                if model.lab == .tune { PianoKeys(model: model) }
                else if model.lab == .shuffle { HatBoard(model: model) }
                else { LabCanvas(model: model).frame(height: 248) }
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "hand.draw").foregroundStyle(model.lab.accent)
                Text(model.lab.gestureHint).foregroundStyle(Ink.muted)
            }.font(.caption).padding(.top, 4)
        }.padding(20).background(Ink.panel, in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(model.lab.accent.opacity(0.2)))
    }
}


struct ExperimentTransport: View {
    let model: Playground
    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 10) {
                Button(action: model.reset) { Image(systemName: "arrow.counterclockwise").frame(width: 30, height: 34) }
                    .buttonStyle(.glass).accessibilityLabel("Reset experiment").accessibilityIdentifier("reset")
                if model.lab == .shuffle {
                    Button("100×") { model.shuffle(100) }.frame(minHeight: 44).buttonStyle(.glass)
                        .accessibilityLabel("Run 100 shuffles").accessibilityIdentifier("batchShuffles")
                } else if model.lab == .bell {
                    Button("500×") { model.drop(500) }.frame(minHeight: 44).buttonStyle(.glass)
                        .disabled(model.bellSamples.count >= 10000).accessibilityLabel("Drop 500 samples").accessibilityIdentifier("batchSamples")
                } else if model.lab == .resonate && model.running {
                    Button(action: model.pause) { Image(systemName: "pause.fill").frame(width: 30, height: 34) }
                        .buttonStyle(.glass).accessibilityLabel("Stop note")
                        .accessibilityIdentifier("stopNote")
                } else if [.grow, .rotate, .spiral, .wait].contains(model.lab) {
                    Button(action: model.step) { Image(systemName: "forward.frame").frame(width: 30, height: 34) }
                        .buttonStyle(.glass).accessibilityLabel("Step forward").accessibilityIdentifier("step")
                }
                Button(action: model.primaryAction) {
                    Label(model.primaryTitle, systemImage: model.primarySymbol)
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 34)
                }.buttonStyle(.glassProminent).tint(model.lab.accent).foregroundStyle(Ink.background)
                    .disabled(model.lab == .bell && model.bellSamples.count >= 10000 || model.lab == .compound && model.compoundSteps >= 4096)
                    .accessibilityIdentifier("primaryAction")
            }.padding(.horizontal, 20).padding(.vertical, 12).frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
        }.background(Ink.background.opacity(0.9))
    }
}
