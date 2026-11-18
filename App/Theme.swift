import SwiftUI
import AppKit

enum AppStyle: String, CaseIterable, Identifiable {
    case classic, ember

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Классический"
        case .ember: return "Чёрно-оранжевый"
        }
    }

    var iconResource: String {
        switch self {
        case .classic: return "AppIcon"
        case .ember: return "AppIcon-Ember"
        }
    }

    var icon: NSImage? { Bundle.main.image(forResource: iconResource) }

    var palette: Palette {
        switch self {
        case .classic: return .classic
        case .ember: return .ember
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

struct Palette {
    let style: AppStyle
    let text: Color
    let text2: Color
    let text3: Color
    let card: Color
    let cardStroke: Color
    let track: Color
    let pickerBackground: Color
    let accent: AnyShapeStyle
    let accentColor: Color
    let onAccent: Color
    let secondaryTint: Color
    let fanTint: Color
    let barFill: AnyShapeStyle
    let danger: Color
    let glow: Bool
    let numberDesign: Font.Design
    let numberWeight: Font.Weight
    let cardRadius: CGFloat
    let controlRadius: CGFloat
    let gaugeWidth: CGFloat

    static let classic = Palette(
        style: .classic,
        text: .white,
        text2: .white.opacity(0.7),
        text3: .white.opacity(0.55),
        card: .white.opacity(0.08),
        cardStroke: .white.opacity(0.12),
        track: .white.opacity(0.08),
        pickerBackground: .black.opacity(0.2),
        accent: AnyShapeStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.36, blue: 0.62),
                                                      Color(red: 0.98, green: 0.62, blue: 0.30)],
                                             startPoint: .leading, endPoint: .trailing)),
        accentColor: Color(red: 1.0, green: 0.4, blue: 0.6),
        onAccent: .white,
        secondaryTint: Color(red: 0.32, green: 0.86, blue: 0.98),
        fanTint: Color(red: 0.32, green: 0.86, blue: 0.98),
        barFill: AnyShapeStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.36, blue: 0.62),
                                                       Color(red: 0.98, green: 0.62, blue: 0.30)],
                                              startPoint: .leading, endPoint: .trailing)),
        danger: Color(red: 1, green: 0.6, blue: 0.6),
        glow: true,
        numberDesign: .rounded,
        numberWeight: .bold,
        cardRadius: 14,
        controlRadius: 100,
        gaugeWidth: 14
    )

    static let ember = Palette(
        style: .ember,
        text: Color(hex: 0xF4F3EF),
        text2: Color(hex: 0xA1A1AA),
        text3: Color(hex: 0x85858E),
        card: Color(hex: 0x111113),
        cardStroke: Color(hex: 0x232327),
        track: Color(hex: 0x232327),
        pickerBackground: Color(hex: 0x111113),
        accent: AnyShapeStyle(Color(hex: 0xFF6B3D)),
        accentColor: Color(hex: 0xFF6B3D),
        onAccent: Color(hex: 0x1A0A04),
        secondaryTint: Color(hex: 0xFF6B3D),
        fanTint: Color(hex: 0xD4D4D8),
        barFill: AnyShapeStyle(Color(hex: 0xF4F3EF)),
        danger: Color(hex: 0xFF7A7A),
        glow: false,
        numberDesign: .monospaced,
        numberWeight: .medium,
        cardRadius: 12,
        controlRadius: 8,
        gaugeWidth: 10
    )

    func numberFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: numberWeight, design: numberDesign)
    }

    func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .semibold, design: style == .ember ? .monospaced : .default)
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.classic
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

struct StyleBackground: View {
    let style: AppStyle

    var body: some View {
        switch style {
        case .classic:
            ZStack {
                LinearGradient(colors: [Color(red: 0.20, green: 0.11, blue: 0.42),
                                        Color(red: 0.33, green: 0.13, blue: 0.52),
                                        Color(red: 0.55, green: 0.17, blue: 0.52)],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color(red: 0.95, green: 0.35, blue: 0.75).opacity(0.35), .clear],
                               center: .init(x: 0.5, y: 0.28), startRadius: 10, endRadius: 220)
            }
        case .ember:
            Color(hex: 0x0B0B0C)
        }
    }
}
