import Foundation

enum SharedPaths {
    static let dir = URL(fileURLWithPath: "/Users/Shared/FanControl", isDirectory: true)
    static let config = dir.appendingPathComponent("config.json")
    static let status = dir.appendingPathComponent("status.json")
    static let daemonLabel = "com.fancontrol.daemon"
    static let helperPath = "/Library/PrivilegedHelperTools/fancontrold"
    static let plistPath = "/Library/LaunchDaemons/com.fancontrol.daemon.plist"

    static func ensureDir() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o777])
    }
}

struct FanConfig: Codable, Equatable {
    enum Mode: String, Codable, CaseIterable { case system, smart, max }

    var mode: Mode = .smart
    var threshold: Double = 75
    var hysteresis: Double = 5
    var rpm: Double? = nil

    static let defaultSmartRPM = 5100.0
    var smartRPM: Double { rpm ?? Self.defaultSmartRPM }

    static func load() -> FanConfig {
        guard let data = try? Data(contentsOf: SharedPaths.config),
              let cfg = try? JSONDecoder().decode(FanConfig.self, from: data) else { return FanConfig() }
        return cfg
    }

    func save() {
        SharedPaths.ensureDir()
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: SharedPaths.config, options: .atomic)
            chmod(SharedPaths.config.path, 0o666)
        }
    }
}

struct DaemonStatus: Codable {
    var cooling: Bool
    var temperature: Double
    var updated: Date
    var error: String?
    var build: String? = nil
    var history: [Double]? = nil

    static let heartbeat: TimeInterval = 10
    var isAlive: Bool { Date().timeIntervalSince(updated) < Self.heartbeat * 3 }

    static func load() -> DaemonStatus? {
        guard let data = try? Data(contentsOf: SharedPaths.status) else { return nil }
        return try? JSONDecoder().decode(DaemonStatus.self, from: data)
    }

    func save() {
        SharedPaths.ensureDir()
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: SharedPaths.status, options: .atomic)
            chmod(SharedPaths.status.path, 0o644)
        }
    }
}
