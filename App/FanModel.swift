import Foundation
import AppKit

struct FanReading: Identifiable {
    let id: Int
    let rpm: Double
    let minRPM: Double
    let maxRPM: Double
    var load: Double { maxRPM > minRPM ? max(0, min(1, (rpm - minRPM) / (maxRPM - minRPM))) : 0 }
}

final class FanModel: ObservableObject {
    @Published var temperature: Double?
    @Published var history: [Double] = []
    @Published var fans: [FanReading] = []
    @Published var helperRunning = false
    @Published var cooling = false
    @Published var helperError: String?
    @Published var busy = false
    @Published var config: FanConfig { didSet { if config != oldValue { scheduleSave() } } }
    @Published var helperOutdated = false
    @Published private(set) var isVisible = false
    @Published var style: AppStyle {
        didSet {
            guard style != oldValue else { return }
            UserDefaults.standard.set(style.rawValue, forKey: "appStyle")
            applyIcon()
        }
    }
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }
    var strings: Strings { language.strings }

    private let queue = DispatchQueue(label: "fancontrol.smc")
    private var thermal: Thermal?
    private var recent: [Double] = []
    private var timer: Timer?
    private var pendingSave: DispatchWorkItem?

    private func scheduleSave() {
        pendingSave?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.config.save() }
        pendingSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    init() {
        config = FanConfig.load()
        style = AppStyle(rawValue: UserDefaults.standard.string(forKey: "appStyle") ?? "") ?? .ember
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .en
        if style != .classic { DispatchQueue.main.async { self.applyIcon() } }
        schedule()
        refresh()
    }

    func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        if visible { recent.removeAll(); seedHistory = true }
        schedule()
        refresh()
    }

    private var seedHistory = true

    private func schedule() {
        timer?.invalidate()
        let interval: TimeInterval = isVisible ? 2 : 15
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() }
        t.tolerance = interval * 0.25
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func applyIcon() {
        let icon = style.icon
        NSApp.applicationIconImage = icon
        NSWorkspace.shared.setIcon(style == .classic ? nil : icon, forFile: Bundle.main.bundlePath, options: [])
    }

    func refresh() {
        let visible = isVisible
        queue.async { [weak self] in
            guard let self else { return }
            var raw: Double?
            var fans: [FanReading]?
            if visible {
                if self.thermal == nil { self.thermal = try? Thermal(smc: SMC()) }
                if let thermal = self.thermal {
                    raw = thermal.cpuTemperature()
                    fans = thermal.fans.map {
                        FanReading(id: $0.index, rpm: thermal.currentRPM($0), minRPM: $0.minRPM, maxRPM: $0.maxRPM)
                    }
                }
            }
            let status = DaemonStatus.load()
            DispatchQueue.main.async { self.apply(raw: raw, fans: fans, status: status) }
        }
    }

    private func apply(raw: Double?, fans: [FanReading]?, status: DaemonStatus?) {
        let alive = status?.isAlive ?? false
        if isVisible && seedHistory {
            seedHistory = false
            if alive, let h = status?.history, !h.isEmpty { history = h; recent = Array(h.suffix(5)) }
        }
        if let raw {
            recent.append(raw)
            if recent.count > 5 { recent.removeFirst() }
            let t = recent.reduce(0, +) / Double(recent.count)
            temperature = t
            history.append(t)
            if history.count > 90 { history.removeFirst(history.count - 90) }
        } else if alive, let t = status?.temperature {
            temperature = t
        }
        if let fans { self.fans = fans }
        helperRunning = alive
        helperOutdated = alive && status?.build != buildID
        cooling = alive && (status?.cooling ?? false)
        if alive { helperError = status?.error }
    }

    func installHelper() {
        guard let bin = Bundle.main.path(forResource: "fancontrold", ofType: nil),
              let plist = Bundle.main.path(forResource: SharedPaths.daemonLabel, ofType: "plist") else {
            helperError = strings.noHelperFiles; return
        }
        config.save()
        runPrivileged("""
        mkdir -p /Library/PrivilegedHelperTools '\(SharedPaths.dir.path)' && \
        chmod 777 '\(SharedPaths.dir.path)' && \
        launchctl bootout system/\(SharedPaths.daemonLabel) 2>/dev/null; sleep 1; \
        cp '\(bin)' \(SharedPaths.helperPath) && chown root:wheel \(SharedPaths.helperPath) && chmod 755 \(SharedPaths.helperPath) && \
        cp '\(plist)' \(SharedPaths.plistPath) && chown root:wheel \(SharedPaths.plistPath) && chmod 644 \(SharedPaths.plistPath) && \
        launchctl bootstrap system \(SharedPaths.plistPath)
        """)
    }

    func uninstallHelper() {
        runPrivileged("""
        launchctl bootout system/\(SharedPaths.daemonLabel) 2>/dev/null; \
        rm -f \(SharedPaths.plistPath) \(SharedPaths.helperPath) '\(SharedPaths.status.path)'
        """)
    }

    private func runPrivileged(_ shell: String) {
        busy = true
        let escaped = shell.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        DispatchQueue.global().async {
            var err: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&err)
            DispatchQueue.main.async {
                self.busy = false
                if let err, (err[NSAppleScript.errorNumber] as? Int) != -128 {
                    self.helperError = err[NSAppleScript.errorMessage] as? String ?? self.strings.actionFailed
                } else {
                    self.helperError = nil
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { self.refresh() }
            }
        }
    }
}
