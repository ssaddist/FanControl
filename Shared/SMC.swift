import Foundation
import IOKit

enum SMCError: Error, CustomStringConvertible {
    case serviceNotFound
    case openFailed(kern_return_t)
    case callFailed(kern_return_t)
    case smcResult(UInt8)
    case unsupportedType(String)
    case badSize

    var description: String {
        switch self {
        case .serviceNotFound: return "AppleSMC не найден"
        case .openFailed(let r): return "не удалось открыть SMC (код \(r))"
        case .callFailed(let r): return "ошибка вызова SMC (код \(String(r, radix: 16)))"
        case .smcResult(let r): return "SMC вернул ошибку \(r)"
        case .unsupportedType(let t): return "неподдерживаемый тип данных '\(t)'"
        case .badSize: return "неверный размер данных"
        }
    }
}

func fourCC(_ s: String) -> UInt32 { s.utf8.reduce(0) { $0 << 8 | UInt32($1) } }
func fourCCString(_ v: UInt32) -> String {
    String(decoding: [24, 16, 8, 0].map { UInt8((v >> UInt32($0)) & 0xFF) }, as: UTF8.self)
}

final class SMC {

    private static let size = 80
    private enum Off {
        static let key = 0, dataSize = 28, dataType = 32, result = 40, cmd = 42, data32 = 44, bytes = 48
    }
    private enum Cmd: UInt8 { case readBytes = 5, writeBytes = 6, keyFromIndex = 8, keyInfo = 9 }

    struct KeyInfo { let size: Int; let type: String }

    private var conn: io_connect_t = 0
    private var infoCache: [String: KeyInfo] = [:]

    init() throws {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { throw SMCError.serviceNotFound }
        defer { IOObjectRelease(service) }
        let r = IOServiceOpen(service, mach_task_self_, 0, &conn)
        guard r == kIOReturnSuccess else { throw SMCError.openFailed(r) }
    }

    deinit { IOServiceClose(conn) }

    private static func put32(_ b: inout [UInt8], _ off: Int, _ v: UInt32) {
        for i in 0..<4 { b[off + i] = UInt8((v >> UInt32(8 * i)) & 0xFF) }
    }
    private static func get32(_ b: [UInt8], _ off: Int) -> UInt32 {
        (0..<4).reduce(0) { $0 | UInt32(b[off + $1]) << UInt32(8 * $1) }
    }

    private func call(_ input: [UInt8]) throws -> [UInt8] {
        var input = input
        var output = [UInt8](repeating: 0, count: Self.size)
        var outSize = Self.size
        let r = input.withUnsafeMutableBytes { inp in
            output.withUnsafeMutableBytes { out in
                IOConnectCallStructMethod(conn, 2, inp.baseAddress, Self.size, out.baseAddress, &outSize)
            }
        }
        guard r == kIOReturnSuccess else { throw SMCError.callFailed(r) }
        guard output[Off.result] == 0 else { throw SMCError.smcResult(output[Off.result]) }
        return output
    }

    private func request(_ key: String, _ cmd: Cmd) -> [UInt8] {
        var b = [UInt8](repeating: 0, count: Self.size)
        Self.put32(&b, Off.key, fourCC(key))
        b[Off.cmd] = cmd.rawValue
        return b
    }

    func keyInfo(_ key: String) throws -> KeyInfo {
        if let cached = infoCache[key] { return cached }
        let o = try call(request(key, .keyInfo))
        let info = KeyInfo(size: Int(Self.get32(o, Off.dataSize)), type: fourCCString(Self.get32(o, Off.dataType)))
        infoCache[key] = info
        return info
    }

    func read(_ key: String) throws -> (KeyInfo, [UInt8]) {
        let info = try keyInfo(key)
        var b = request(key, .readBytes)
        Self.put32(&b, Off.dataSize, UInt32(info.size))
        let o = try call(b)
        return (info, Array(o[Off.bytes ..< Off.bytes + min(info.size, 32)]))
    }

    func write(_ key: String, _ bytes: [UInt8]) throws {
        let info = try keyInfo(key)
        guard bytes.count == info.size else { throw SMCError.badSize }
        var b = request(key, .writeBytes)
        Self.put32(&b, Off.dataSize, UInt32(info.size))
        for (i, v) in bytes.enumerated() { b[Off.bytes + i] = v }
        _ = try call(b)
    }

    func keyCount() throws -> Int {
        let (_, d) = try read("#KEY")
        return Int(d.prefix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
    }

    func key(at index: Int) throws -> String {
        var b = [UInt8](repeating: 0, count: Self.size)
        b[Off.cmd] = Cmd.keyFromIndex.rawValue
        Self.put32(&b, Off.data32, UInt32(index))
        return fourCCString(Self.get32(try call(b), Off.key))
    }

    func readNumber(_ key: String) throws -> Double {
        let (info, d) = try read(key)
        func be(_ n: Int) -> UInt32 { d.prefix(n).reduce(UInt32(0)) { $0 << 8 | UInt32($1) } }
        switch info.type {
        case "flt ": return Double(Float(bitPattern: d.prefix(4).enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << UInt32(8 * $1.offset) }))
        case "ui8 ": return Double(d[0])
        case "ui16": return Double(be(2))
        case "ui32": return Double(be(4))
        case "fpe2": return Double(be(2)) / 4
        case "sp78": return Double(Int16(bitPattern: UInt16(be(2)))) / 256
        default: throw SMCError.unsupportedType(info.type)
        }
    }

    func writeNumber(_ key: String, _ value: Double) throws {
        let info = try keyInfo(key)
        switch info.type {
        case "flt ":
            let bits = Float(value).bitPattern
            try write(key, (0..<4).map { UInt8((bits >> UInt32(8 * $0)) & 0xFF) })
        case "fpe2":
            let v = UInt16(max(0, min(value * 4, 65535)))
            try write(key, [UInt8(v >> 8), UInt8(v & 0xFF)])
        case "ui8 ":
            try write(key, [UInt8(max(0, min(value, 255)))])
        default:
            throw SMCError.unsupportedType(info.type)
        }
    }
}

struct Fan { let index: Int; let minRPM: Double; let maxRPM: Double }

final class Thermal {
    let smc: SMC
    let cpuKeys: [String]
    let fans: [Fan]

    init(smc: SMC) throws {
        self.smc = smc

        var keys: [String] = []
        for i in 0..<(try smc.keyCount()) {
            guard let k = try? smc.key(at: i), k.hasPrefix("Tp") || k.hasPrefix("Te") else { continue }
            if let v = try? smc.readNumber(k), v > 5, v < 130 { keys.append(k) }
        }
        cpuKeys = keys

        let count = Int((try? smc.readNumber("FNum")) ?? 0)
        fans = (0..<count).map { i in
            Fan(index: i,
                minRPM: (try? smc.readNumber("F\(i)Mn")) ?? 0,
                maxRPM: (try? smc.readNumber("F\(i)Mx")) ?? 6000)
        }
    }

    func cpuTemperature() -> Double? {
        let values = cpuKeys.compactMap { try? smc.readNumber($0) }.filter { $0 > 5 && $0 < 130 }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    func currentRPM(_ fan: Fan) -> Double { (try? smc.readNumber("F\(fan.index)Ac")) ?? 0 }

    func setManual(_ fan: Fan, rpm: Double) throws {
        let mode = "F\(fan.index)Md"
        if (try? smc.write(mode, [1])) == nil {

            try? smc.write("Ftst", [1])
            var ok = false
            for _ in 0..<20 {
                if (try? smc.write(mode, [1])) != nil { ok = true; break }
                usleep(250_000)
            }
            if !ok { try smc.write(mode, [1]) }
        }
        try smc.writeNumber("F\(fan.index)Tg", min(max(rpm, fan.minRPM), fan.maxRPM))
    }

    func setAuto(_ fan: Fan) {
        try? smc.write("F\(fan.index)Md", [0])
    }

    func releaseAll() {
        fans.forEach(setAuto)
        try? smc.write("Ftst", [0])
    }
}
