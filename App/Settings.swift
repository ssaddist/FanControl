import SwiftUI
import AppKit
import Combine

final class SettingsWindow {
    static let shared = SettingsWindow()
    private var window: NSWindow?
    private var titleSub: AnyCancellable?

    func show(model: FanModel) {
        if window == nil {
            titleSub = model.$language.sink { [weak self] lang in self?.window?.title = lang.strings.settings }
            let host = NSHostingController(rootView: SettingsView().environmentObject(model))
            host.sizingOptions = .preferredContentSize
            let w = NSWindow(contentViewController: host)
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        window?.title = model.strings.settings
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: FanModel

    private var p: Palette { model.style.palette }
    private var s: Strings { model.strings }
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                if let icon = model.style.icon {
                    Image(nsImage: icon).resizable().frame(width: 40, height: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.settings).font(.system(size: 20, weight: .bold))
                    Text("FanControl · \(s.version) \(version)").font(.system(size: 11)).foregroundStyle(p.text3)
                }
            }

            section(s.theme) {
                HStack(spacing: 12) {
                    ForEach(AppStyle.allCases) { style in
                        ThemeCard(style: style, title: s.styleName(style), selected: model.style == style) {
                            model.style = style
                        }
                    }
                }
            }

            section(s.language) {
                LanguagePicker(language: $model.language)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .padding(.bottom, 24)
        .frame(width: 420, alignment: .leading)
        .foregroundStyle(p.text)
        .background(StyleBackground(style: model.style).ignoresSafeArea())
        .environment(\.palette, p)
        .environment(\.strings, s)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.25), value: model.style)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(p.label(10)).tracking(1.2).foregroundStyle(p.text3)
            content()
        }
    }
}

struct ThemeCard: View {
    let style: AppStyle
    let title: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.palette) private var p

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    StyleBackground(style: style)
                    if let icon = style.icon {
                        Image(nsImage: icon).resizable().frame(width: 44, height: 44)
                    }
                }
                .frame(height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white.opacity(0.08)))

                HStack {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(selected ? p.accentColor : p.text3)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: p.cardRadius + 2, style: .continuous).fill(p.card))
            .overlay(RoundedRectangle(cornerRadius: p.cardRadius + 2, style: .continuous)
                .stroke(selected ? p.accentColor : p.cardStroke, lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct LanguagePicker: View {
    @Binding var language: AppLanguage
    @Environment(\.palette) private var p

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, lang in
                if index > 0 { Rectangle().fill(p.cardStroke).frame(height: 1).padding(.leading, 14) }
                Button { language = lang } label: {
                    HStack {
                        Text(lang.nativeName).font(.system(size: 13, weight: .medium))
                        Spacer()
                        if language == lang {
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                                .foregroundStyle(p.accentColor)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(RoundedRectangle(cornerRadius: p.cardRadius, style: .continuous).fill(p.card))
        .overlay(RoundedRectangle(cornerRadius: p.cardRadius, style: .continuous).stroke(p.cardStroke))
    }
}
