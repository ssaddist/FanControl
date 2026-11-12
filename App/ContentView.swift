import SwiftUI

enum Theme {
    static let bgTop = Color(red: 0.20, green: 0.11, blue: 0.42)
    static let bgMid = Color(red: 0.33, green: 0.13, blue: 0.52)
    static let bgBottom = Color(red: 0.55, green: 0.17, blue: 0.52)
    static let card = Color.white.opacity(0.08)
    static let stroke = Color.white.opacity(0.12)
    static let accent = LinearGradient(colors: [Color(red: 1.0, green: 0.36, blue: 0.62), Color(red: 0.98, green: 0.62, blue: 0.30)],
                                       startPoint: .leading, endPoint: .trailing)
    static let cool = Color(red: 0.32, green: 0.86, blue: 0.98)

    static func tempColor(_ t: Double) -> Color {
        switch t {
        case ..<55: return Color(red: 0.35, green: 0.90, blue: 0.75)
        case ..<70: return Color(red: 0.98, green: 0.85, blue: 0.35)
        case ..<85: return Color(red: 1.00, green: 0.58, blue: 0.30)
        default: return Color(red: 1.00, green: 0.33, blue: 0.40)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: FanModel

    var body: some View {
        VStack(spacing: 16) {
            header
            TemperatureGauge(temperature: model.temperature, threshold: model.config.threshold,
                             cooling: model.cooling, mode: model.config.mode, rpm: model.config.smartRPM)
            Sparkline(values: model.history, threshold: model.config.threshold)
                .frame(height: 34)
            HStack(spacing: 10) {
                ForEach(model.fans) { FanCard(fan: $0) }
            }
            ModePicker(mode: $model.config.mode)
            thresholdSlider
            helperSection
            footer
        }
        .padding(18)
        .foregroundStyle(.white)
        .frame(width: 340)
        .background(background)
        .preferredColorScheme(.dark)
        .background(WindowVisibilityReader { model.setVisible($0) })
        .onAppear { model.setVisible(true) }
        .onDisappear { model.setVisible(false) }
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgMid, Theme.bgBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(red: 0.95, green: 0.35, blue: 0.75).opacity(0.35), .clear],
                           center: .init(x: 0.5, y: 0.28), startRadius: 10, endRadius: 220)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text("FanControl").font(.system(size: 15, weight: .bold, design: .rounded))
                Text("Охлаждение процессора").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
    }

    private var thresholdSlider: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Включать при").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("\(Int(model.config.threshold)) °C")
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            Slider(value: $model.config.threshold, in: 50...95, step: 1)
                .tint(Color(red: 1.0, green: 0.45, blue: 0.55))
            HStack {
                Text("Обороты").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("\(Int(model.config.smartRPM)) об/мин")
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            .padding(.top, 4)
            Slider(value: Binding(get: { model.config.smartRPM }, set: { model.config.rpm = $0 }),
                   in: ((model.fans.first?.minRPM ?? 2300) / 100).rounded(.up) * 100...(model.fans.first?.maxRPM ?? 6800), step: 100)
                .tint(Theme.cool)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        .opacity(model.config.mode == .smart ? 1 : 0.4)
        .disabled(model.config.mode != .smart)
    }

    @ViewBuilder private var helperSection: some View {
        if !model.helperRunning {
            VStack(spacing: 8) {
                Text("Чтобы управлять вентиляторами, нужен помощник с правами администратора. macOS один раз спросит пароль.")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Button(action: model.installHelper) {
                    HStack {
                        if model.busy { ProgressView().controlSize(.small) }
                        Text(model.busy ? "Установка…" : "Включить управление")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Capsule().fill(Theme.accent))
                    .shadow(color: Color(red: 1, green: 0.4, blue: 0.6).opacity(0.5), radius: 10, y: 3)
                }
                .buttonStyle(.plain).disabled(model.busy)
            }
        }
        if model.helperOutdated {
            Button(action: model.installHelper) {
                HStack {
                    if model.busy { ProgressView().controlSize(.small) }
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(model.busy ? "Обновление…" : "Помощник устарел — обновить")
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(.plain).disabled(model.busy)
        }
        if let err = model.helperError {
            Text(err).font(.system(size: 11)).foregroundStyle(Color(red: 1, green: 0.6, blue: 0.6))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            if model.helperRunning {
                Label("Помощник активен", systemImage: "checkmark.shield.fill")
                Button("Удалить", action: model.uninstallHelper)
                    .buttonStyle(.plain).underline()
                    .help("Остановить и удалить фоновую службу")
            }
            Spacer()
            Button("Выйти") { NSApp.terminate(nil) }.buttonStyle(.plain)
        }
        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
    }
}

struct TemperatureGauge: View {
    let temperature: Double?
    let threshold: Double
    let cooling: Bool
    let mode: FanConfig.Mode
    let rpm: Double

    private let minT = 30.0, maxT = 105.0
    private let arc = 0.75

    private func fraction(_ t: Double) -> Double { max(0, min(1, (t - minT) / (maxT - minT))) }

    var body: some View {
        let t = temperature ?? minT
        let color = Theme.tempColor(t)
        ZStack {
            Circle().trim(from: 0, to: arc)
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle().trim(from: 0, to: arc * fraction(t))
                .stroke(AngularGradient(colors: [Theme.cool, Color(red: 0.35, green: 0.9, blue: 0.7),
                                                 Color(red: 0.98, green: 0.85, blue: 0.35),
                                                 Color(red: 1, green: 0.5, blue: 0.3), Color(red: 1, green: 0.3, blue: 0.45)],
                                        center: .center, startAngle: .degrees(0), endAngle: .degrees(270)),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(135))
                .shadow(color: color.opacity(0.7), radius: 10)
                .animation(.easeInOut(duration: 0.8), value: t)

            Circle().fill(.white).frame(width: 8, height: 8)
                .shadow(color: .white, radius: 4)
                .offset(y: -80)
                .rotationEffect(.degrees(-135 + 270 * fraction(threshold)))
                .opacity(mode == .smart ? 1 : 0)
                .animation(.spring, value: threshold)

            VStack(spacing: 2) {
                Text("ПРОЦЕССОР").font(.system(size: 10, weight: .semibold)).tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))
                Text(temperature.map { String(format: "%.0f°", $0) } ?? "—")
                    .font(.system(size: 52, weight: .bold, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.default, value: Int(t))
                Text(cooling ? (mode == .max ? "Вентиляторы на максимуме" : "Охлаждение · \(Int(rpm)) об/мин") : mode == .smart ? "Порог \(Int(threshold)) °C" : mode == .max ? "Режим «Максимум»" : "Управляет macOS")
                    .font(.system(size: 11)).foregroundStyle(cooling ? Theme.cool : .white.opacity(0.6))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: 130)
            }
        }
        .frame(width: 176, height: 176)
        .padding(.top, 4)
        .padding(.bottom, -18)
    }
}

struct Sparkline: View {
    let values: [Double]
    let threshold: Double

    var body: some View {
        GeometryReader { geo in
            let lo = min(values.min() ?? 40, threshold) - 3
            let hi = max(values.max() ?? 80, threshold) + 3
            let y = { (v: Double) in geo.size.height * (1 - (v - lo) / (hi - lo)) }
            let step = geo.size.width / CGFloat(max(1, 89))
            let pts = values.enumerated().map { CGPoint(x: geo.size.width - CGFloat(values.count - 1 - $0.offset) * step, y: y($0.element)) }
            ZStack {
                Path { p in p.move(to: .init(x: 0, y: y(threshold))); p.addLine(to: .init(x: geo.size.width, y: y(threshold))) }
                    .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                if pts.count > 1 {
                    Path { p in
                        p.move(to: .init(x: pts[0].x, y: geo.size.height)); pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: .init(x: pts.last!.x, y: geo.size.height))
                    }
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.45, blue: 0.6).opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                    Path { p in p.addLines(pts) }
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

struct FanCard: View {
    let fan: FanReading

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SpinningFan(rpm: fan.rpm)
                Spacer()
                Text("Вент. \(fan.id + 1)").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55))
            }
            Text("\(Int(fan.rpm))").font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit()
            + Text(" об/мин").font(.system(size: 10)).foregroundColor(.white.opacity(0.55))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(Theme.accent).frame(width: max(6, g.size.width * fan.load))
                        .animation(.easeInOut(duration: 0.8), value: fan.load)
                }
            }
            .frame(height: 5)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke))
    }
}

struct SpinningFan: View {
    let rpm: Double
    @EnvironmentObject var model: FanModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !model.isVisible)) { ctx in
            Image(systemName: "fanblades.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.cool)
                .rotationEffect(.degrees(rotation(at: ctx.date)))
        }
    }

    private func rotation(at date: Date) -> Double {
        (date.timeIntervalSinceReferenceDate * rpm / 1000 * 360).truncatingRemainder(dividingBy: 360)
    }
}

struct WindowVisibilityReader: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView { Tracker(onChange: onChange) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Tracker: NSView {
        let onChange: (Bool) -> Void
        private var observer: NSObjectProtocol?

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            guard let window else { onChange(false); return }
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak self] _ in
                guard let self, let window = self.window else { return }
                self.onChange(window.occlusionState.contains(.visible))
            }
        }

        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    }
}

struct ModePicker: View {
    @Binding var mode: FanConfig.Mode
    @Namespace private var ns

    private let items: [(FanConfig.Mode, String, String)] = [
        (.system, "Система", "apple.logo"),
        (.smart, "Авто", "thermometer.medium"),
        (.max, "Максимум", "wind"),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.0) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { mode = item.0 }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: item.2).font(.system(size: 11))
                        Text(item.1).font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .foregroundStyle(mode == item.0 ? .white : .white.opacity(0.6))
                    .background {
                        if mode == item.0 {
                            Capsule().fill(Theme.accent).matchedGeometryEffect(id: "sel", in: ns)
                                .shadow(color: Color(red: 1, green: 0.4, blue: 0.6).opacity(0.45), radius: 6)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.2)))
        .overlay(Capsule().stroke(Theme.stroke))
    }
}
