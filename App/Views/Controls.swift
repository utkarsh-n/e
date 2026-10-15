import SwiftUI
import EulerCore

struct ParameterSlider: View {
    let title: String
    let valueLabel: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step = 0.01
    var accent = Ink.mint
    var identifier: String = ""
    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer(minLength: 12)
                Text(valueLabel).font(.system(.subheadline, design: .monospaced)).foregroundStyle(accent)
                    .monospacedDigit().accessibilityIdentifier(identifier + "Value")
            }
            Slider(value: $value, in: range, step: step)
                .tint(accent).accessibilityLabel(title).accessibilityValue(valueLabel)
                .accessibilityIdentifier(identifier)
        }
    }
}

struct ExperimentControls: View {
    @Bindable var model: Playground
    var body: some View {
        MatteCard(accent: model.lab.accent) {
            HStack { InstrumentLabel("Dials", color: model.lab.accent); Spacer(); Text("Make a change.").font(.caption).foregroundStyle(Ink.muted) }
            controls
        }
    }
    @ViewBuilder private var controls: some View {
        switch model.lab {
        case .grow: growth
        case .resonate: resonance
        case .rotate: rotation
        case .tune: tuning
        case .spiral: spiral
        case .shuffle: shuffling
        case .bell: scatter
        case .compound: compounding
        case .wait: waiting
        }
    }
    private var growth: some View {
        VStack(spacing: 18) {
            Picker("Model", selection: Binding(get: { model.growthContext }, set: model.setContext)) {
                ForEach(GrowthContext.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("growthContext")
            ParameterSlider(title: "Proportional rate · k", valueLabel: decimal(model.rate), value: Binding(get: { model.rate }, set: { model.rate = $0; model.controlsChanged() }), range: model.growthContext == .growth ? -1.5...1.5 : -1.5 ... -0.05, accent: Ink.amber, identifier: "growthRate")
            ParameterSlider(title: "Time · t", valueLabel: decimal(model.time), value: Binding(get: { model.time }, set: model.scrubTime), range: 0...3, identifier: "growthTime")
            Button(action: model.findE) {
                HStack { Text("Find e").fontWeight(.semibold); Spacer(); Text("k = 1 · t = 1").font(.system(.caption, design: .monospaced)); Image(systemName: "arrow.up.right") }
                    .padding(12).background(Ink.mint.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).foregroundStyle(Ink.mint).accessibilityIdentifier("findE")
        }
    }
    private var resonance: some View {
        VStack(spacing: 18) {
            ParameterSlider(title: "Pitch", valueLabel: "\(Int(model.pitch)) Hz", value: Binding(get: { model.pitch }, set: { model.pitch = $0; model.controlsChanged() }), range: 110...880, step: 1, accent: Ink.amber, identifier: "pitch")
            ParameterSlider(title: "Decay rate · k", valueLabel: "\(decimal(model.decay)) /s", value: Binding(get: { model.decay }, set: { model.decay = $0; model.controlsChanged() }), range: 0.2...2, identifier: "decayRate")
            Toggle("Sound", isOn: Binding(get: { model.sensory.soundEnabled }, set: model.setSound))
                .tint(Ink.mint).accessibilityIdentifier("soundToggle")
            Text("Pluck to hear a tone and feel its amplitude shrink. Enabled Sound plays in Silent Mode through your selected audio output.")
                .font(.caption).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var rotation: some View {
        VStack(spacing: 18) {
            ParameterSlider(title: "Angle · θ", valueLabel: "\(decimal(model.angle / .pi))π rad", value: Binding(get: { model.angle }, set: model.setAngle), range: 0...2 * .pi, accent: Ink.lilac, identifier: "rotationAngle")
            HStack(spacing: 8) {
                ForEach(0..<5) { quarter in
                    Button { model.setAngle(Double(quarter) * .pi / 2) } label: {
                        Text(["0", "π/2", "π", "3π/2", "2π"][quarter])
                            .font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, minHeight: 44)
                            .background(Ink.raised, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).foregroundStyle(quarter == 2 ? Ink.amber : Ink.lilac)
                        .accessibilityLabel("Set angle to " + ["zero", "pi over two", "pi", "three pi over two", "two pi"][quarter])
                        .accessibilityIdentifier("angleDetent\(quarter)")
                }
            }
        }
    }
    private var tuning: some View {
        VStack(spacing: 16) {
            ParameterSlider(title: "Semitones above A3", valueLabel: "+\(Int(model.semitone))", value: Binding(get: { model.semitone }, set: { model.playKey(Int($0)) }), range: 0...12, step: 1, accent: Ink.amber, identifier: "semitones")
            Toggle("Sound", isOn: Binding(get: { model.sensory.soundEnabled }, set: model.setSound)).tint(Ink.amber).accessibilityIdentifier("soundToggle")
            Text("Enabled Sound plays in Silent Mode through your selected audio output.")
                .font(.caption).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
            HStack { Readout(label: "One step", value: "1.05946×", color: Ink.amber); Readout(label: "One octave", value: "2×", color: Ink.mint) }
        }
    }
    private var spiral: some View {
        VStack(spacing: 18) {
            ParameterSlider(title: "Expansion · b", valueLabel: decimal(model.spiralGrowth), value: Binding(get: { model.spiralGrowth }, set: { model.spiralGrowth = $0; model.controlsChanged() }), range: 0.02...0.3, accent: Ink.amber, identifier: "spiralGrowth")
            ParameterSlider(title: "Angle unwound", valueLabel: "\(decimal(model.spiralAngle / (2 * .pi))) turns", value: Binding(get: { model.spiralAngle }, set: model.setSpiral), range: 0...4 * .pi, identifier: "spiralAngle")
            Button("One full turn") { model.setSpiral(2 * .pi) }.buttonStyle(.bordered).tint(Ink.mint).accessibilityIdentifier("fullTurn")
        }
    }
    private var shuffling: some View {
        VStack(alignment: .leading, spacing: 18) {
            Stepper("\(model.hatCount) people", value: Binding(get: { model.hatCount }, set: model.setHatCount), in: 3...12)
                .accessibilityIdentifier("hatCount")
            HStack {
                Readout(label: "Measured", value: model.shuffleTrials == 0 ? "—" : "\(decimal(model.measuredNoMatch * 100, 1))%")
                Readout(label: "Exact · n = \(model.hatCount)", value: "\(decimal(model.exactNoMatch * 100, 2))%", color: Ink.amber)
                Readout(label: "Limit · 1/e", value: "36.79%", color: Ink.lilac)
            }
            Text("Changing the crowd starts a fresh set of trials.").font(.caption).foregroundStyle(Ink.muted)
        }
    }
    private var scatter: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Readout(label: "Contributions / sum", value: "12", color: Ink.amber); Readout(label: "Target variance", value: "1", color: Ink.lilac) }
            Text("Every sample adds 12 uniform values, then subtracts 6. Collect up to 10,000 samples; the shape gets steadier as you add more.").font(.subheadline).foregroundStyle(Ink.muted)
            if model.bellSamples.count >= 10000 { Label("Collection full. Reset to start again.", systemImage: "checkmark.circle").font(.caption).foregroundStyle(Ink.mint) }
        }
    }
    private var compounding: some View {
        VStack(spacing: 18) {
            ParameterSlider(title: "Reinvestments per year · n", valueLabel: "\(model.compoundSteps)", value: Binding(get: { log2(Double(model.compoundSteps)) }, set: { model.setSteps(Int(pow(2, $0))) }), range: 0...12, step: 1, accent: Ink.amber, identifier: "compoundSteps")
            HStack { Readout(label: "Each step grows by", value: "\(decimal(100 / Double(model.compoundSteps), 3))%", color: Ink.amber); Readout(label: "Continuous limit", value: "2.71828…", color: Ink.mint) }
        }
    }
    private var waiting: some View {
        VStack(spacing: 18) {
            ParameterSlider(title: "Average arrival rate · λ", valueLabel: "\(decimal(model.arrivalRate, 1)) /s", value: Binding(get: { model.arrivalRate }, set: model.setArrivalRate), range: 0.3...3, step: 0.1, accent: Ink.amber, identifier: "arrivalRate")
            HStack { Readout(label: "Arrivals", value: "\(model.arrivalCount)", color: Ink.amber); Readout(label: "Still waiting at this t", value: "\(decimal(model.waitingSurvival * 100, 1))%", color: Ink.mint) }
            Text("Changing λ restarts the clock. Feel the arrivals as short taps.").font(.caption).foregroundStyle(Ink.muted)
        }
    }
}

struct PianoKeys: View {
    @Bindable var model: Playground
    private let names = ["A", "A♯", "B", "C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A"]
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<13) { index in
                    let sharp = [1, 4, 6, 9, 11].contains(index)
                    let selected = index == Int(model.semitone)
                    Button { model.playKey(index) } label: {
                        VStack(spacing: 14) {
                            Spacer(minLength: 0)
                            if selected { Circle().fill(Ink.amber).frame(width: 6, height: 6) }
                            Text(names[index]).font(.system(size: 11, weight: .semibold, design: .monospaced))
                        }
                        .frame(width: 46, height: sharp ? 104 : 152).padding(.bottom, 14)
                        .background(selected ? Ink.amber.opacity(0.2) : sharp ? Ink.background : Ink.raised, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? Ink.amber : Ink.line))
                    }.buttonStyle(.plain).foregroundStyle(selected ? Ink.amber : Ink.text)
                        .accessibilityLabel("\(names[index]), \(index) semitones, \(decimal(EMath.frequency(semitones: Double(index)), 1)) hertz")
                        .accessibilityIdentifier("pianoKey\(index)")
                }
            }
            }.scrollIndicators(.hidden).accessibilityIdentifier("pianoKeyboard")
            HStack { InstrumentLabel("A3 · 220 Hz", color: Ink.amber); Spacer(); InstrumentLabel("A4 · 440 Hz", color: Ink.amber) }
            Text(model.sensory.soundEnabled ? "Tap a key. Every step uses the same ratio." : "Tap a key. Enable Sound below to hear the ratios.")
                .font(.caption).foregroundStyle(Ink.muted)
        }.padding(.vertical, 20)
    }
}

struct HatBoard: View {
    let model: Playground
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 4), spacing: 12) {
            ForEach(model.hats.indices, id: \.self) { index in
                let match = model.hats[index] == index
                VStack(spacing: 9) {
                    ZStack {
                        Image(systemName: "hat.widebrim.fill").font(.system(size: 38)).foregroundStyle(match ? Ink.amber : Ink.mint)
                        Text("\(model.hats[index] + 1)").font(.system(.caption2, design: .monospaced, weight: .bold)).foregroundStyle(Ink.background).offset(y: 5)
                    }
                    Text("PERSON \(index + 1)").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(Ink.muted)
                    Text(match ? "MATCH" : "different").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(match ? Ink.amber : Ink.mint)
                }.frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(match ? Ink.amber.opacity(0.08) : Ink.mint.opacity(0.04), in: RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(match ? Ink.amber.opacity(0.5) : Ink.line))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Person \(index + 1) has hat \(model.hats[index] + 1), \(match ? "a match" : "not a match")")
            }
        }.padding(.vertical, 12).accessibilityIdentifier("hatBoard")
    }
}
