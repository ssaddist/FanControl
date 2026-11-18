import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: FanModel

    private var p: Palette { model.style.palette }

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
        .foregroundStyle(p.text)
        .frame(width: 340)
        .background(StyleBackground(style: model.style))
        .environment(\.palette, p)
        .animation(.easeInOut(duration: 0.25), value: model.style)
        .preferredColorScheme(.dark)
        .background(WindowVisibilityReader { model.setVisible($0) })
        .onAppear { model.setVisible(true) }
        .onDisappear { model.setVisible(false) }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let icon = model.style.icon {
                Image(nsImage: icon).resizable().frame(width: 36, height: 36)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("FanControl").font(.system(size: 15, weight: .bold, design: p.style == .ember ? .default : .rounded))
                Text("Охлаждение процессора").font(.system(size: 11)).foregroundStyle(p.text3)
            }
            Spacer()
            StyleSwitcher(style: $model.style)
        }
    }

    private var thresholdSlider: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Включать при").font(.system(size: 12)).foregroundStyle(p.text2)
                Spacer()
                Text("\(Int(model.config.threshold)) °C")
                    .font(p.numberFont(13)).monospacedDigit()
            }
            Slider(value: $model.config.threshold, in: 50...95, step: 1)
                .tint(p.accentColor)
            HStack {
                Text("Обороты").font(.system(size: 12)).foregroundStyle(p.text2)
                Spacer()
                Text("\(Int(model.config.smartRPM)) об/мин")
                    .font(p.numberFont(13)).monospacedDigit()
            }
            .padding(.top, 4)
            Slider(value: Binding(get: { model.config.smartRPM }, set: { model.config.rpm = $0 }),
                   in: ((model.fans.first?.minRPM ?? 2300) / 100).rounded(.up) * 100...(model.fans.first?.maxRPM ?? 6800), step: 100)
                .tint(p.secondaryTint)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: p.cardRadius, style: .continuous).fill(p.card))
        .overlay(RoundedRectangle(cornerRadius: p.cardRadius, style: .continuous).stroke(p.style == .ember ? p.cardStroke : .clear))
        .opacity(model.config.mode == .smart ? 1 : 0.4)
        .disabled(model.config.mode != .smart)
    }

    @ViewBuilder private var helperSection: some View {
        if !model.helperRunning {
            VStack(spacing: 8) {
                Text("Чтобы управлять вентиляторами, нужен помощник с правами администратора. macOS один раз спросит пароль.")
                    .font(.system(size: 11)).foregroundStyle(p.text2)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                PrimaryButton(title: model.busy ? "Установка…" : "Включить управление", busy: model.busy,
                              action: model.installHelper)
            }
        }
        if model.helperOutdated {
            PrimaryButton(title: model.busy ? "Обновление…" : "Помощник устарел — обновить", busy: model.busy,
                          systemImage: "arrow.triangle.2.circlepath", action: model.installHelper)
        }
        if let err = model.helperError {
            Text(err).font(.system(size: 11)).foregroundStyle(p.danger)
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
        .font(.system(size: 11)).foregroundStyle(p.text3)
    }
}

struct StyleSwitcher: View {
    @Binding var style: AppStyle
    @Environment(\.palette) private var p

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppStyle.allCases) { s in
                Button { style = s } label: {
                    swatch(s)
                        .frame(width: 18, height: 18)
                        .padding(3)
                        .overlay(Circle().stroke(style == s ? p.text : p.text3.opacity(0.4), lineWidth: style == s ? 1.5 : 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(s.title)
                .accessibilityLabel("Стиль: \(s.title)")
            }
        }
    }

    @ViewBuilder private func swatch(_ s: AppStyle) -> some View {
        switch s {
        case .classic:
            Circle().fill(LinearGradient(colors: [Color(red: 0.36, green: 0.14, blue: 0.56), Color(red: 1.0, green: 0.36, blue: 0.62)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
        case .ember:
            ZStack {
                Circle().fill(Color(hex: 0x0B0B0C))
                Circle().stroke(Color(hex: 0x303036))
                Circle().fill(Color(hex: 0xFF6B3D)).frame(width: 7, height: 7)
            }
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var busy = false
    var systemImage: String? = nil
    let action: () -> Void
    @Environment(\.palette) private var p

    var body: some View {
        Button(action: action) {
            HStack {
                if busy { ProgressView().controlSize(.small) }
                if let systemImage, !busy { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(p.onAccent)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: p.controlRadius, style: .continuous).fill(p.accent))
            .shadow(color: p.glow ? p.accentColor.opacity(0.5) : .clear, radius: 10, y: 3)
        }
        .buttonStyle(.plain).disabled(busy)
    }
}

struct TemperatureGauge: View {
    let temperature: Double?
    let threshold: Double
    let cooling: Bool
    let mode: FanConfig.Mode
    let rpm: Double
    @Environment(\.palette) private var p

    private let minT = 30.0, maxT = 105.0
    private let arc = 0.75

    private func fraction(_ t: Double) -> Double { max(0, min(1, (t - minT) / (maxT - minT))) }

    private static func classicColor(_ t: Double) -> Color {
        switch t {
        case ..<55: return Color(red: 0.35, green: 0.90, blue: 0.75)
        case ..<70: return Color(red: 0.98, green: 0.85, blue: 0.35)
        case ..<85: return Color(red: 1.00, green: 0.58, blue: 0.30)
        default: return Color(red: 1.00, green: 0.33, blue: 0.40)
        }
    }

    private var fillStyle: AnyShapeStyle {
        switch p.style {
        case .classic:
            return AnyShapeStyle(AngularGradient(colors: [p.fanTint, Color(red: 0.35, green: 0.9, blue: 0.7),
                                                          Color(red: 0.98, green: 0.85, blue: 0.35),
                                                          Color(red: 1, green: 0.5, blue: 0.3), Color(red: 1, green: 0.3, blue: 0.45)],
                                                 center: .center, startAngle: .degrees(0), endAngle: .degrees(270)))
        case .ember:
            return cooling ? p.accent : AnyShapeStyle(p.text)
        }
    }

    private var statusText: String {
        if cooling { return mode == .max ? "Вентиляторы на максимуме" : "Охлаждение · \(Int(rpm)) об/мин" }
        switch mode {
        case .smart: return "Порог \(Int(threshold)) °C"
        case .max: return "Режим «Максимум»"
        case .system: return "Управляет macOS"
        }
    }

    var body: some View {
        let t = temperature ?? minT
        ZStack {
            Circle().trim(from: 0, to: arc)
                .stroke(p.track, style: StrokeStyle(lineWidth: p.gaugeWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle().trim(from: 0, to: arc * fraction(t))
                .stroke(fillStyle, style: StrokeStyle(lineWidth: p.gaugeWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
                .shadow(color: p.glow ? Self.classicColor(t).opacity(0.7) : .clear, radius: 10)
                .animation(.easeInOut(duration: 0.8), value: t)

            Circle().fill(p.style == .ember ? p.accentColor : .white)
                .frame(width: p.style == .ember ? 12 : 8, height: p.style == .ember ? 12 : 8)
                .shadow(color: p.glow ? .white : .clear, radius: 4)
                .offset(y: -80)
                .rotationEffect(.degrees(-135 + 270 * fraction(threshold)))
                .opacity(mode == .smart ? 1 : 0)
                .animation(.spring, value: threshold)

            VStack(spacing: 2) {
                Text("ПРОЦЕССОР").font(p.label()).tracking(1.5)
                    .foregroundStyle(p.text3)
                Text(temperature.map { String(format: "%.0f°", $0) } ?? "—")
                    .font(p.numberFont(52)).monospacedDigit()
                    .tracking(p.style == .ember ? -2 : 0)
                    .contentTransition(.numericText())
                    .animation(.default, value: Int(t))
                HStack(spacing: 5) {
                    if p.style == .ember {
                        Circle().fill(cooling ? p.accentColor : Color(hex: 0x55555D)).frame(width: 6, height: 6)
                    }
                    Text(statusText)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .font(.system(size: 11))
                .foregroundStyle(cooling ? (p.style == .ember ? p.accentColor : p.fanTint) : p.text2)
                .frame(maxWidth: 136)
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
    @Environment(\.palette) private var p

    var body: some View {
        GeometryReader { geo in
            let lo = min(values.min() ?? 40, threshold) - 3
            let hi = max(values.max() ?? 80, threshold) + 3
            let y = { (v: Double) in geo.size.height * (1 - (v - lo) / (hi - lo)) }
            let step = geo.size.width / CGFloat(max(1, 89))
            let pts = values.enumerated().map { CGPoint(x: geo.size.width - CGFloat(values.count - 1 - $0.offset) * step, y: y($0.element)) }
            ZStack(alignment: .top) {
                if p.style == .ember {
                    Rectangle().fill(p.accentColor.opacity(0.14))
                        .frame(height: max(0, y(threshold)))
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                Path { path in path.move(to: .init(x: 0, y: y(threshold))); path.addLine(to: .init(x: geo.size.width, y: y(threshold))) }
                    .stroke(p.style == .ember ? p.accentColor.opacity(0.45) : .white.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                if pts.count > 1 {
                    if p.style == .classic {
                        Path { path in
                            path.move(to: .init(x: pts[0].x, y: geo.size.height)); pts.forEach { path.addLine(to: $0) }
                            path.addLine(to: .init(x: pts.last!.x, y: geo.size.height))
                        }
                        .fill(LinearGradient(colors: [p.accentColor.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                    }
                    Path { path in path.addLines(pts) }
                        .stroke(p.style == .ember ? AnyShapeStyle(p.text) : p.accent,
                                style: StrokeStyle(lineWidth: p.style == .ember ? 1.5 : 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

struct FanCard: View {
    let fan: FanReading
    @Environment(\.palette) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SpinningFan(rpm: fan.rpm)
                Spacer()
                Text(p.style == .ember ? "ВЕНТ. \(fan.id + 1)" : "Вент. \(fan.id + 1)")
                    .font(p.style == .ember ? p.label() : .system(size: 10, weight: .medium))
                    .tracking(p.style == .ember ? 1 : 0)
                    .foregroundStyle(p.text3)
            }
            Text("\(Int(fan.rpm))").font(p.numberFont(20)).monospacedDigit()
            + Text(" об/мин").font(.system(size: 10)).foregroundColor(p.text3)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(p.track)
                    Capsule().fill(p.barFill).frame(width: max(6, g.size.width * fan.load))
                        .animation(.easeInOut(duration: 0.8), value: fan.load)
                }
            }
            .frame(height: p.style == .ember ? 4 : 5)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: p.cardRadius, style: .continuous).fill(p.card))
        .overlay(RoundedRectangle(cornerRadius: p.cardRadius, style: .continuous).stroke(p.cardStroke))
    }
}

struct SpinningFan: View {
    let rpm: Double
    @EnvironmentObject var model: FanModel
    @Environment(\.palette) private var p

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !model.isVisible)) { ctx in
            Image(systemName: "fanblades.fill")
                .font(.system(size: 18))
                .foregroundStyle(p.fanTint)
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
    @Environment(\.palette) private var p

    private let items: [(FanConfig.Mode, String, String)] = [
        (.system, "Система", "apple.logo"),
        (.smart, "Авто", "thermometer.medium"),
        (.max, "Максимум", "wind"),
    ]

    var body: some View {
        let outer = RoundedRectangle(cornerRadius: p.controlRadius, style: .continuous)
        let inner = RoundedRectangle(cornerRadius: max(0, p.controlRadius - 3), style: .continuous)
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
                    .foregroundStyle(mode == item.0 ? p.onAccent : p.text2)
                    .background {
                        if mode == item.0 {
                            inner.fill(p.accent).matchedGeometryEffect(id: "sel", in: ns)
                                .shadow(color: p.glow ? p.accentColor.opacity(0.45) : .clear, radius: 6)
                        }
                    }
                    .contentShape(inner)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(outer.fill(p.pickerBackground))
        .overlay(outer.stroke(p.cardStroke))
    }
}
