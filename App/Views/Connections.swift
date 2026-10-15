import SwiftUI

struct ConnectionsView: View {
    let model: Playground
    var onSelect: (LabKind) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    InstrumentLabel("One constant · nine ways in", color: Ink.mint)
                    Text("Somewhere in\neverything.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Grow it. Hear it. Turn it. Find it hiding in chance.")
                        .font(.subheadline).foregroundStyle(Ink.muted)
                }.padding(.bottom, 4)
                ForEach(LabKind.allCases) { lab in
                    Button { onSelect(lab) } label: {
                        MatteCard(accent: lab.accent) {
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: lab.symbol).font(.title2).foregroundStyle(lab.accent)
                                    .frame(width: 42, height: 48).background(lab.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 8) {
                                    InstrumentLabel("\(String(format: "%02d", lab.index)) · \(lab.shortTitle)", color: lab.accent)
                                    Text(lab.title).font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(Ink.text)
                                    Text(lab.subtitle).font(.subheadline).foregroundStyle(Ink.muted).multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: model.discoveries.contains(lab.rawValue) ? "checkmark.circle.fill" : "arrow.up.right")
                                    .font(.caption).foregroundStyle(lab.accent).padding(.top, 8)
                            }
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("connection_\(lab.rawValue)")
                        .accessibilityLabel("Explore \(lab.title). \(lab.subtitle)")
                }
                MatteCard(accent: Ink.amber) {
                    InstrumentLabel("Why this number?", color: Ink.amber)
                    Text("e = 2.718281828459…").font(.system(.title2, design: .serif)).foregroundStyle(Ink.mint)
                    Text("e is the base where an exponential's rate of change equals its own value. That makes it the natural language of proportional change—and, unexpectedly, of rotations and randomness.").font(.subheadline).foregroundStyle(Ink.muted)
                }
            }.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }.background { AppBackground() }.scrollIndicators(.hidden)
    }
}

struct DiscoveriesView: View {
    let model: Playground
    var onSelect: (LabKind) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 9) {
                    InstrumentLabel("Connections you've made", color: Ink.amber)
                    Text("Make it click.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Small experiments. Real moments of understanding.").font(.subheadline).foregroundStyle(Ink.muted)
                }
                MatteCard(accent: Ink.amber) {
                    HStack { InstrumentLabel("Your discoveries", color: Ink.amber); Spacer(); Text("\(model.discoveries.count) / 9").font(.system(.title3, design: .monospaced)).foregroundStyle(Ink.amber).accessibilityIdentifier("discoveryCount") }
                    ProgressView(value: Double(model.discoveries.count), total: 9).tint(Ink.amber)
                        .accessibilityLabel("Discoveries completed")
                    Text("A connection saves when you reach its moment in the experiment.").font(.caption).foregroundStyle(Ink.muted)
                }
                ForEach(LabKind.allCases) { lab in
                    let earned = model.discoveries.contains(lab.rawValue)
                    Button { onSelect(lab) } label: {
                        MatteCard(accent: earned ? lab.accent : Ink.line) {
                            HStack(alignment: .top, spacing: 15) {
                                Image(systemName: earned ? "sparkles" : "circle.dotted").foregroundStyle(earned ? Ink.amber : Ink.muted).font(.title3)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(lab.discoveryTitle).font(.system(.headline, design: .rounded)).foregroundStyle(earned ? Ink.text : Ink.muted)
                                    Text(earned ? lab.explanation : lab.challenge).font(.subheadline).foregroundStyle(Ink.muted).multilineTextAlignment(.leading)
                                    Text(earned ? "Explore again →" : "Try \(lab.shortTitle) →").font(.caption.weight(.semibold)).foregroundStyle(lab.accent)
                                }
                            }
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("discovery_\(lab.rawValue)")
                }
            }.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }.background { AppBackground() }.scrollIndicators(.hidden)
    }
}

struct FieldNotesView: View {
    let lab: LabKind
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    InstrumentLabel("Why e appears", color: lab.accent)
                    Text(lab.title).font(.system(.largeTitle, design: .rounded, weight: .bold))
                    MatteCard(accent: lab.accent) {
                        Text(lab.formula).font(.system(.title2, design: .serif)).foregroundStyle(lab.accent)
                        Text(lab.explanation).font(.body).fixedSize(horizontal: false, vertical: true)
                    }
                    MatteCard(accent: Ink.amber) {
                        InstrumentLabel("What this model assumes", color: Ink.amber)
                        Text(lab.caveat).font(.subheadline).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    Link(destination: lab.sourceURL) {
                        Label("Read the source", systemImage: "arrow.up.right.square").font(.subheadline.weight(.medium)).padding(.vertical, 10)
                    }.foregroundStyle(lab.accent)
                    Text("Try this: \(lab.challenge)").font(.subheadline).foregroundStyle(Ink.muted)
                }.padding(22).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }.background { AppBackground() }
                .navigationTitle("Field notes").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("notesDone") } }
        }.presentationDetents([.large]).presentationDragIndicator(.visible)
    }
}

struct SensorySettingsView: View {
    @Bindable var model: Playground
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Touch feedback", isOn: Binding(get: { model.sensory.hapticsEnabled }, set: model.setHaptics))
                        .accessibilityIdentifier("hapticsToggle")
                    Toggle("Continuous feel", isOn: Binding(get: { model.sensory.continuousFeelEnabled }, set: model.setContinuousFeel))
                        .disabled(!model.sensory.hapticsEnabled).accessibilityIdentifier("continuousFeelToggle")
                    ParameterSlider(title: "Touch strength", valueLabel: "\(Int(model.sensory.strength * 100))%", value: Binding(get: { model.sensory.strength }, set: model.setStrength), range: 0.15...1, step: 0.05, identifier: "touchStrength")
                        .disabled(!model.sensory.hapticsEnabled)
                    Toggle("Sound", isOn: Binding(get: { model.sensory.soundEnabled }, set: model.setSound))
                        .accessibilityIdentifier("settingsSoundToggle")
                } header: { Text("Feel the change") } footer: {
                    Text("Clicks mark meaningful steps. A plucked note can fade under your fingers. Enabled Sound plays in Silent Mode through your selected audio output, only when you pluck or press a key.")
                }
                if !model.sensory.supportsHaptics {
                    Section {
                        Label("This device has no haptic engine", systemImage: "hand.raised")
                        Text("You can still explore every experiment visually and hear the notes.").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if let message = model.sensory.statusMessage {
                    Section("Feedback status") { Text(message) }
                }
                Section("A natural playground") {
                    HStack(alignment: .center, spacing: 16) {
                        Text("e").font(.system(size: 64, weight: .medium, design: .serif).italic()).foregroundStyle(Ink.mint)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("2.718281828459…").font(.system(.subheadline, design: .monospaced))
                            Text("Touch the mathematics.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Text("Supports VoiceOver and Reduce Motion. Sliders and buttons provide alternatives to canvas gestures.").font(.caption).foregroundStyle(.secondary)
                }
            }.tint(Ink.mint).navigationTitle("Sensory settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("settingsDone") } }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}

struct DialsSheet: View {
    @Bindable var model: Playground
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(model.lab.title).font(.system(.title2, design: .rounded, weight: .bold))
                    ExperimentControls(model: model)
                    Text(model.observation).font(.subheadline).foregroundStyle(Ink.muted)
                }.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }.background { AppBackground() }.navigationTitle("Dials").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}
