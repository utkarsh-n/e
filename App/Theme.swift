import SwiftUI

enum Ink {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.075)
    static let panel = Color(red: 0.072, green: 0.095, blue: 0.12)
    static let raised = Color(red: 0.115, green: 0.14, blue: 0.17)
    static let mint = Color(red: 0.48, green: 0.96, blue: 0.77)
    static let amber = Color(red: 1, green: 0.74, blue: 0.39)
    static let lilac = Color(red: 0.76, green: 0.69, blue: 1)
    static let text = Color(red: 0.94, green: 0.96, blue: 0.97)
    static let muted = Color(red: 0.65, green: 0.71, blue: 0.76)
    static let line = Color.white.opacity(0.10)
}

struct InstrumentLabel: View {
    let text: String
    var color = Ink.muted
    init(_ text: String, color: Color = Ink.muted) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased()).font(.system(.caption2, design: .monospaced, weight: .semibold))
            .tracking(1.6).foregroundStyle(color)
    }
}

struct MatteCard<Content: View>: View {
    var accent = Ink.line
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.panel, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(accent.opacity(0.35)))
    }
}

struct Readout: View {
    let label: String
    let value: String
    var color = Ink.mint
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            InstrumentLabel(label)
            Text(value).font(.system(.title3, design: .monospaced, weight: .medium))
                .monospacedDigit().foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }
}

struct AppBackground: View {
    var body: some View {
        Ink.background.ignoresSafeArea().overlay {
            Canvas { context, size in
                for x in stride(from: 12.0, to: size.width, by: 24) {
                    for y in stride(from: 12.0, to: size.height, by: 24) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)), with: .color(Ink.muted.opacity(0.1)))
                    }
                }
            }.allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

func decimal(_ value: Double, _ digits: Int = 2) -> String {
    value.formatted(.number.precision(.fractionLength(digits)))
}
