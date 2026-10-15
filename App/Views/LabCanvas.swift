import SwiftUI
import UIKit

struct LabCanvas: View {
    @Bindable var model: Playground

    var body: some View {
        Group {
            if isAdjustable {
                surface.accessibilityAdjustableAction { adjust($0) }
            } else {
                surface
            }
        }
    }

    private var surface: some View {
        GeometryReader { proxy in
            let drawing = Canvas { context, size in render(context, size: size) }
                .background(Ink.panel)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
            if [.grow, .spiral].contains(model.lab) {
                drawing.overlay {
                    HorizontalScrubSurface { location in drag(location, size: proxy.size) }
                        .accessibilityHidden(true)
                }
            } else if model.lab == .rotate {
                drawing.gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    drag(value.location, size: proxy.size)
                })
            } else if model.lab == .resonate {
                drawing.onTapGesture { model.primaryAction() }
            } else {
                drawing
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.lab.title) visualization")
        .accessibilityValue(accessibleValue)
        .accessibilityHint(accessibleHint)
        .accessibilityAction { model.primaryAction() }
        .accessibilityIdentifier("lab.canvas")
    }

    private func render(_ context: GraphicsContext, size: CGSize) {
        switch model.lab {
        case .grow: growth(context, size: size)
        case .resonate: resonance(context, size: size)
        case .rotate: rotation(context, size: size)
        case .spiral: spiral(context, size: size)
        case .bell: bell(context, size: size)
        case .compound: compounding(context, size: size)
        case .wait: waiting(context, size: size)
        case .tune, .shuffle: break
        }
    }

    private func growth(_ context: GraphicsContext, size: CGSize) {
        let top = max(1.3, exp(max(model.rate, 0) * 3) * 1.05)
        let plot = Plot(size, x: 0...3, y: 0...top)
        axes(context, plot, xTicks: [0, 1, 2, 3], yTicks: [0, top / 2, top])
        label("AMOUNT / START", context, at: CGPoint(x: plot.rect.minX, y: 12), color: Ink.muted, anchor: .leading)
        let curve = sampled(0...3, count: 160) { plot.point($0, exp(model.rate * $0)) }
        var area = curve
        area.addLine(to: plot.point(3, 0)); area.addLine(to: plot.point(0, 0)); area.closeSubpath()
        context.fill(area, with: .color(Ink.mint.opacity(0.07)))
        glow(curve, context, color: Ink.mint)
        let time = clamp(model.time, 0, 3)
        let amount = exp(model.rate * time)
        let point = plot.point(time, amount)
        var clipped = context
        clipped.clip(to: Path(plot.rect))
        line(clipped, from: plot.point(time, 0), to: point, color: Ink.mint.opacity(0.3), dash: [3, 4])
        let slope = model.rate * amount
        line(clipped, from: plot.point(time - 0.22, amount - slope * 0.22),
             to: plot.point(time + 0.22, amount + slope * 0.22), color: Ink.amber, dash: [3, 3])
        dot(point, context, color: Ink.mint)
        label("TIME", context, at: CGPoint(x: plot.rect.maxX, y: size.height - 8), anchor: .trailing)
    }

    private func resonance(_ context: GraphicsContext, size: CGSize) {
        let plot = Plot(size, x: 0...5, y: -1.15...1.15)
        axes(context, plot, xTicks: [0, 1, 2, 3, 4, 5], yTicks: [-1, 0, 1])
        label("Vibration slowed · 2.5 Hz", context, at: CGPoint(x: size.width / 2, y: 12))
        for sign in [-1.0, 1.0] {
            let envelope = sampled(0...5, count: 160) { plot.point($0, sign * exp(-model.decay * $0)) }
            context.stroke(envelope, with: .color(Ink.amber.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        let wave = sampled(0...5, count: 360) {
            plot.point($0, exp(-model.decay * $0) * cos(2 * .pi * 2.5 * $0))
        }
        glow(wave, context, color: Ink.mint, width: 1.8)
        let time = clamp(model.time, 0, 5)
        line(context, from: plot.point(time, -1.15), to: plot.point(time, 1.15), color: Ink.lilac.opacity(0.5), dash: [3, 4])
        dot(plot.point(time, exp(-model.decay * time) * cos(2 * .pi * 2.5 * time)), context, color: Ink.lilac)
        label("SECONDS", context, at: CGPoint(x: plot.rect.maxX, y: size.height - 8), anchor: .trailing)
    }

    private func rotation(_ context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = max(1, min(size.width - 72, size.height - 60) / 2)
        line(context, from: CGPoint(x: center.x - radius - 12, y: center.y),
             to: CGPoint(x: center.x + radius + 12, y: center.y), color: Ink.line)
        line(context, from: CGPoint(x: center.x, y: center.y - radius - 12),
             to: CGPoint(x: center.x, y: center.y + radius + 12), color: Ink.line)
        context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                       with: .color(Ink.lilac.opacity(0.2)), lineWidth: 1)
        let arc = sampled(0...max(0.001, model.angle), count: 128) {
            CGPoint(x: center.x + radius * cos($0), y: center.y - radius * sin($0))
        }
        glow(arc, context, color: Ink.lilac, width: 2.3)
        let point = CGPoint(x: center.x + radius * cos(model.angle), y: center.y - radius * sin(model.angle))
        let horizontal = CGPoint(x: point.x, y: center.y)
        line(context, from: center, to: point, color: Ink.lilac.opacity(0.6))
        line(context, from: center, to: horizontal, color: Ink.mint, width: 2.5)
        line(context, from: horizontal, to: point, color: Ink.amber, width: 2.5)
        dot(point, context, color: Ink.lilac)
        for (angle, name) in [(0.0, "0° · 1"), (.pi / 2, "90° · i"), (.pi, "180° · −1"), (3 * .pi / 2, "270° · −i")] {
            label(name, context, at: CGPoint(x: center.x + (radius + 22) * cos(angle), y: center.y - (radius + 18) * sin(angle)))
        }
        label("cos θ", context, at: CGPoint(x: 12, y: 13), color: Ink.mint, anchor: .leading)
        label("sin θ", context, at: CGPoint(x: size.width - 12, y: 13), color: Ink.amber, anchor: .trailing)
    }

    private func spiral(_ context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2 + 3)
        let fitRadius = max(1, min(size.width - 48, size.height - 52) / 2)
        let scale = fitRadius / exp(model.spiralGrowth * 4 * .pi)
        for fraction in [0.25, 0.5, 0.75, 1.0] {
            let radius = fitRadius * fraction
            context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                           with: .color(Ink.line.opacity(0.65)), lineWidth: 0.6)
        }
        let coordinate: (Double) -> CGPoint = { angle in
            let radius = scale * exp(model.spiralGrowth * angle)
            return CGPoint(x: center.x + radius * cos(angle), y: center.y - radius * sin(angle))
        }
        context.stroke(sampled(0...(4 * .pi), count: 320, coordinate), with: .color(Ink.mint.opacity(0.16)), lineWidth: 1.5)
        glow(sampled(0...max(0.001, model.spiralAngle), count: 240, coordinate), context, color: Ink.mint)
        dot(coordinate(model.spiralAngle), context, color: Ink.mint)
        dot(coordinate(0), context, color: Ink.amber, radius: 2.5)
        label("EQUAL TURNS · EQUAL RATIOS", context, at: CGPoint(x: size.width / 2, y: 12))
        label("0", context, at: CGPoint(x: 12, y: size.height - 9), anchor: .leading)
        label("2 turns", context, at: CGPoint(x: size.width - 12, y: size.height - 9), anchor: .trailing)
    }

    private func bell(_ context: GraphicsContext, size: CGSize) {
        let count = model.bellSamples.count
        let density = model.bins.map { count == 0 ? 0 : Double($0) / (Double(count) * 0.25) }
        let top = max(0.52, (density.max() ?? 0) * 1.15)
        let plot = Plot(size, x: -4...4, y: 0...top)
        axes(context, plot, xTicks: [-4, -2, 0, 2, 4], yTicks: [0, top / 2, top])
        if count > 0 {
            for index in density.indices {
                let left = plot.point(-4 + Double(index) * 0.25, density[index])
                let right = plot.point(-4 + Double(index + 1) * 0.25, 0)
                let rect = CGRect(x: left.x + 0.8, y: left.y, width: max(1, right.x - left.x - 1.6), height: max(0, right.y - left.y))
                context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(Ink.lilac.opacity(0.6)))
            }
        }
        let normal = sampled(-4...4, count: 180) { plot.point($0, exp(-$0 * $0 / 2) / sqrt(2 * .pi)) }
        glow(normal, context, color: Ink.mint, width: 1.8)
        label("PROBABILITY DENSITY", context, at: CGPoint(x: plot.rect.minX, y: 12), anchor: .leading)
        if count == 0 {
            label("Your samples will appear here", context, at: CGPoint(x: plot.rect.midX, y: plot.rect.maxY - 24), color: Ink.text)
        }
        label("SUM − 6", context, at: CGPoint(x: plot.rect.maxX, y: size.height - 8), anchor: .trailing)
    }

    private func compounding(_ context: GraphicsContext, size: CGSize) {
        let plot = Plot(size, x: 0...1, y: 0.85...2.95)
        axes(context, plot, xTicks: [0, 0.25, 0.5, 0.75, 1], yTicks: [1, 2, exp(1)])
        let continuous = sampled(0...1, count: 128) { plot.point($0, exp($0)) }
        context.stroke(continuous, with: .color(Ink.mint.opacity(0.65)), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3]))
        let steps = max(1, model.compoundSteps)
        let drawnSteps = min(steps, 256)
        var staircase = Path()
        staircase.move(to: plot.point(0, 1))
        var previousValue = 1.0
        for index in 1...drawnSteps {
            let actualStep = Int((Double(index) * Double(steps) / Double(drawnSteps)).rounded())
            let time = Double(actualStep) / Double(steps)
            let value = pow(1 + 1 / Double(steps), Double(actualStep))
            staircase.addLine(to: plot.point(time, previousValue))
            staircase.addLine(to: plot.point(time, value))
            previousValue = value
        }
        glow(staircase, context, color: Ink.amber, width: 2)
        dot(plot.point(1, previousValue), context, color: Ink.amber)
        dot(plot.point(1, exp(1)), context, color: Ink.mint, radius: 2.5)
        label("STEPS", context, at: CGPoint(x: plot.rect.minX, y: 12), color: Ink.amber, anchor: .leading)
        label("CONTINUOUS", context, at: CGPoint(x: plot.rect.maxX, y: 12), color: Ink.mint, anchor: .trailing)
        label(steps > 256 ? "YEAR · \(steps) STEPS, CONDENSED" : "ONE YEAR", context,
              at: CGPoint(x: plot.rect.maxX, y: size.height - 8), anchor: .trailing)
    }

    private func waiting(_ context: GraphicsContext, size: CGSize) {
        let rate = max(0.01, model.arrivalRate)
        let horizon = max(4, 4 / rate, model.sinceArrival * 1.1)
        let plot = Plot(size, x: 0...horizon, y: 0...1.05, bottom: 62)
        axes(context, plot, xTicks: [0, horizon / 2, horizon], yTicks: [0, 0.5, 1])
        let curve = sampled(0...horizon, count: 160) { plot.point($0, exp(-rate * $0)) }
        glow(curve, context, color: Ink.amber)
        let time = model.sinceArrival
        let point = plot.point(time, exp(-rate * time))
        line(context, from: plot.point(time, 0), to: point, color: Ink.amber.opacity(0.4), dash: [3, 4])
        dot(point, context, color: Ink.amber)
        label("CHANCE OF STILL WAITING", context, at: CGPoint(x: plot.rect.minX, y: 12), anchor: .leading)
        label("SECONDS", context, at: CGPoint(x: plot.rect.maxX, y: plot.rect.maxY + 28), anchor: .trailing)
        let stripY = size.height - 12
        line(context, from: CGPoint(x: plot.rect.minX, y: stripY), to: CGPoint(x: plot.rect.maxX, y: stripY), color: Ink.line)
        let start = max(0, model.waitingClock - horizon)
        for arrival in model.arrivals where arrival >= start {
            let x = plot.rect.minX + (arrival - start) / horizon * plot.rect.width
            dot(CGPoint(x: x, y: stripY), context, color: Ink.amber, radius: 2)
        }
        label("\(model.arrivalCount) arrivals · recent history", context,
              at: CGPoint(x: plot.rect.minX, y: stripY - 15), anchor: .leading)
    }

    private func drag(_ location: CGPoint, size: CGSize) {
        switch model.lab {
        case .grow:
            model.scrubTime(clamp((location.x - 38) / max(1, size.width - 54), 0, 1) * 3)
        case .rotate:
            let x = location.x - size.width / 2
            let y = -(location.y - size.height / 2)
            guard hypot(x, y) > 14 else { return }
            var angle = atan2(y, x)
            if angle < 0 { angle += 2 * .pi }
            let quarter = (angle / (.pi / 2)).rounded() * (.pi / 2)
            if abs(angle - quarter) < 0.06 { angle = quarter }
            model.setAngle(angle)
        case .spiral:
            model.setSpiral(clamp((location.x - 12) / max(1, size.width - 24), 0, 1) * 4 * .pi)
        default: break
        }
    }

    private var isAdjustable: Bool { [.grow, .resonate, .rotate, .spiral, .compound, .wait].contains(model.lab) }
    private var accessibleValue: String {
        switch model.lab {
        case .grow: "Time \(decimal(model.time)), amount \(decimal(model.amount)) times the start"
        case .resonate: "Decay \(decimal(model.decay)). \(model.readout) amplitude remains. Drawing slowed to 2.5 hertz."
        case .rotate: "\(decimal(model.angle * 180 / .pi, 1)) degrees. Cosine \(decimal(cos(model.angle))), sine \(decimal(sin(model.angle)))."
        case .spiral: "\(decimal(model.spiralAngle / (2 * .pi))) turns. Radius \(model.readout) the start."
        case .bell: "\(model.bellSamples.count) sums. Lilac bars show measured density, mint line shows the normal reference."
        case .compound: "\(model.compoundSteps) steps. Amount \(decimal(model.compoundValue, 5)); continuous limit \(decimal(exp(1), 5))."
        case .wait: "Rate \(decimal(model.arrivalRate)) per second. \(model.arrivalCount) arrivals. Still-waiting probability \(decimal(model.waitingSurvival * 100, 1)) percent."
        case .tune, .shuffle: model.readout
        }
    }
    private var accessibleHint: String {
        switch model.lab {
        case .grow: "Swipe up or down to change time. Double tap to play or pause."
        case .rotate: "Swipe up or down to turn. Double tap to play or pause."
        case .spiral: "Swipe up or down to unwind. Double tap to play or pause."
        case .resonate: "Double tap to pluck. Swipe up or down to change the decay rate."
        case .compound: "Swipe up to double the steps or down to halve them. Double tap to double."
        case .wait: "Swipe up or down to change the arrival rate and reset the clock. Double tap to play or pause."
        case .bell: "Double tap to add 100 samples."
        case .tune, .shuffle: model.lab.gestureHint
        }
    }
    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        let amount = direction == .increment ? 1.0 : -1.0
        switch model.lab {
        case .grow: model.scrubTime(clamp(model.time + amount * 0.1, 0, 3))
        case .rotate: model.setAngle(clamp(model.angle + amount * .pi / 12, 0, 2 * .pi))
        case .spiral: model.setSpiral(clamp(model.spiralAngle + amount * .pi / 4, 0, 4 * .pi))
        case .resonate: model.decay = clamp(model.decay + amount * 0.1, 0.2, 2); model.controlsChanged()
        case .compound: model.setSteps(amount > 0 ? min(4096, model.compoundSteps * 2) : max(1, model.compoundSteps / 2))
        case .wait: model.setArrivalRate(clamp(model.arrivalRate + amount * 0.1, 0.3, 3))
        default: break
        }
    }

    private struct Plot {
        let rect: CGRect
        let x: ClosedRange<Double>
        let y: ClosedRange<Double>
        init(_ size: CGSize, x: ClosedRange<Double>, y: ClosedRange<Double>, bottom: CGFloat = 36) {
            rect = CGRect(x: 38, y: 30, width: max(1, size.width - 54), height: max(1, size.height - 30 - bottom))
            self.x = x; self.y = y
        }
        func point(_ xValue: Double, _ yValue: Double) -> CGPoint {
            CGPoint(x: rect.minX + (xValue - x.lowerBound) / (x.upperBound - x.lowerBound) * rect.width,
                    y: rect.maxY - (yValue - y.lowerBound) / (y.upperBound - y.lowerBound) * rect.height)
        }
    }

    private func axes(_ context: GraphicsContext, _ plot: Plot, xTicks: [Double], yTicks: [Double]) {
        for value in yTicks {
            let point = plot.point(plot.x.lowerBound, value)
            line(context, from: point, to: CGPoint(x: plot.rect.maxX, y: point.y), color: Ink.line, dash: [2, 5])
            label(tick(value), context, at: CGPoint(x: plot.rect.minX - 8, y: point.y), anchor: .trailing)
        }
        for value in xTicks {
            let point = plot.point(value, plot.y.lowerBound)
            line(context, from: point, to: CGPoint(x: point.x, y: plot.rect.minY), color: Ink.line.opacity(0.65), dash: [2, 5])
            label(tick(value), context, at: CGPoint(x: point.x, y: plot.rect.maxY + 12))
        }
    }
    private func tick(_ value: Double) -> String {
        if abs(value - exp(1)) < 0.00001 { return "e" }
        if abs(value.rounded() - value) < 0.0001 { return decimal(value, 0) }
        return decimal(value, abs(value) < 1 ? 2 : 1)
    }
    private func sampled(_ range: ClosedRange<Double>, count: Int, _ point: (Double) -> CGPoint) -> Path {
        Path { path in
            for index in 0...count {
                let position = point(range.lowerBound + Double(index) / Double(count) * (range.upperBound - range.lowerBound))
                if index == 0 { path.move(to: position) } else { path.addLine(to: position) }
            }
        }
    }
    private func glow(_ path: Path, _ context: GraphicsContext, color: Color, width: CGFloat = 2.2) {
        context.stroke(path, with: .color(color.opacity(0.08)), lineWidth: width + 7)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
    private func line(_ context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color, width: CGFloat = 1, dash: [CGFloat] = []) {
        var path = Path(); path.move(to: from); path.addLine(to: to)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash))
    }
    private func dot(_ point: CGPoint, _ context: GraphicsContext, color: Color, radius: CGFloat = 4) {
        context.fill(Path(ellipseIn: CGRect(x: point.x - radius - 4, y: point.y - radius - 4, width: (radius + 4) * 2, height: (radius + 4) * 2)), with: .color(color.opacity(0.12)))
        context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
    }
    private func label(_ text: String, _ context: GraphicsContext, at point: CGPoint, color: Color = Ink.muted, anchor: UnitPoint = .center) {
        context.draw(Text(text).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(color), at: point, anchor: anchor)
    }
    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double { min(upper, max(lower, value)) }
}

/// Rejects vertical movement before the pan begins, rather than filtering it after
/// a SwiftUI drag has already claimed the touch sequence from the page's scroll view.
private struct HorizontalScrubSurface: UIViewRepresentable {
    var onScrub: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScrub: onScrub) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onScrub = onScrub
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        for recognizer in view.gestureRecognizers ?? [] {
            recognizer.delegate = nil
            view.removeGestureRecognizer(recognizer)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onScrub: (CGPoint) -> Void

        init(onScrub: @escaping (CGPoint) -> Void) { self.onScrub = onScrub }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        @objc func handlePan(_ pan: UIPanGestureRecognizer) {
            guard pan.state == .began || pan.state == .changed else { return }
            onScrub(pan.location(in: pan.view))
        }
    }
}
