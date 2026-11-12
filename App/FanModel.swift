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
        queue.async { [weak self] in
            self?.thermal = try? Thermal(smc: SMC())
            DispatchQueue.main.async { self?.refresh() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        queue.async { [weak self] in
            guard let self, let thermal = self.thermal else { return }
            let raw = thermal.cpuTemperature()
            let fans = thermal.fans.map {
                FanReading(id: $0.index, rpm: thermal.currentRPM($0), minRPM: $0.minRPM, maxRPM: $0.maxRPM)
            }
            let status = DaemonStatus.load()
            DispatchQueue.main.async { self.apply(raw: raw, fans: fans, status: status) }
        }
    }

    private func apply(raw: Double?, fans: [FanReading], status: DaemonStatus?) {
        if let raw {
            recent.append(raw)
            if recent.count > 5 { recent.removeFirst() }
            let t = recent.reduce(0, +) / Double(recent.count)
            temperature = t
            history.append(t)
            if history.count > 90 { history.removeFirst() }
        }
        self.fans = fans
        let alive = status.map { Date().timeIntervalSince($0.updated) < 10 } ?? false
        helperRunning = alive
        helperOutdated = alive && status?.build != buildID
        cooling = alive && (status?.cooling ?? false)
        if alive { helperError = status?.error }
    }

    func installHelper() {
        guard let bin = Bundle.main.path(forResource: "fancontrold", ofType: nil),
              let plist = Bundle.main.path(forResource: SharedPaths.daemonLabel, ofType: "plist") else {
            helperError = "В пакете приложения нет файлов помощника"; return
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
                    self.helperError = err[NSAppleScript.errorMessage] as? String ?? "Не удалось выполнить"
                } else {
                    self.helperError = nil
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { self.refresh() }
            }
        }
    }
}
