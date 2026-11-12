import Foundation

struct Options {
    var config = FanConfig()
    var interval = 2.0
    var statusOnly = false
    var daemon = false
}

func fatal(_ msg: String) -> Never {
    FileHandle.standardError.write("Ошибка: \(msg)\n".data(using: .utf8)!)
    exit(1)
}

func log(_ msg: String) {
    let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
    print("[\(f.string(from: Date()))] \(msg)")
}

func parseOptions() -> Options {
    var o = Options()
    var args = CommandLine.arguments.dropFirst().makeIterator()
    func num(_ name: String) -> Double {
        guard let s = args.next(), let v = Double(s) else { fatal("для \(name) нужно число") }
        return v
    }
    while let a = args.next() {
        switch a {
        case "--threshold", "-t": o.config.threshold = num(a)
        case "--hysteresis": o.config.hysteresis = num(a)
        case "--interval", "-i": o.interval = max(0.5, num(a))
        case "--rpm": o.config.rpm = num(a)
        case "--status", "-s": o.statusOnly = true
        case "--daemon": o.daemon = true
        case "--help", "-h":
            print("""
            Использование: sudo fancontrold [опции]
              -t, --threshold N    порог включения, °C (по умолчанию 75)
                  --hysteresis N   вентиляторы вернутся в авто при T < порог − N (по умолчанию 5)
              -i, --interval S     период опроса, сек (по умолчанию 2)
                  --rpm N          обороты при охлаждении (по умолчанию 5100)
              -s, --status         показать температуру и вентиляторы и выйти (без sudo)
                  --daemon         брать настройки из \(SharedPaths.config.path)
            """)
            exit(0)
        default: fatal("неизвестный аргумент \(a), см. --help")
        }
    }
    return o
}

setvbuf(stdout, nil, _IOLBF, 0)
let opts = parseOptions()

let thermal: Thermal
do { thermal = try Thermal(smc: try SMC()) } catch { fatal("\(error)") }
guard !thermal.cpuKeys.isEmpty else { fatal("не найдено ни одного датчика температуры CPU") }
guard !thermal.fans.isEmpty else { fatal("в этом Mac нет вентиляторов") }

if opts.statusOnly {
    print(String(format: "CPU: %.1f °C (датчиков: %d)", thermal.cpuTemperature() ?? .nan, thermal.cpuKeys.count))
    for f in thermal.fans {
        print(String(format: "Вентилятор %d: %.0f об/мин (диапазон %.0f–%.0f)",
                     f.index, thermal.currentRPM(f), f.minRPM, f.maxRPM))
    }
    exit(0)
}

guard geteuid() == 0 else { fatal("для управления вентиляторами нужны права root — запустите через sudo") }
if opts.daemon { SharedPaths.ensureDir(); chmod(SharedPaths.dir.path, 0o777) }

log("Старт: датчиков CPU \(thermal.cpuKeys.count), вентиляторов \(thermal.fans.count)" + (opts.daemon ? ", режим демона" : ""))

thermal.releaseAll()

var cooling = false
var coolingSince = Date.distantPast
let minCoolingTime: TimeInterval = 60
let smoothingWindow: TimeInterval = 10
var samples: [(time: Date, value: Double)] = []
var history: [Double] = []
var lastMode: FanConfig.Mode? = nil
var lastHistorySample = Date.distantPast
var lastStatusWrite = Date.distantPast
var lastStatusCooling: Bool? = nil
var lastStatusError: String? = nil

var cfg = opts.config
var configStamp: Date? = nil
func reloadConfigIfChanged() {
    guard opts.daemon else { return }
    let stamp = (try? FileManager.default.attributesOfItem(atPath: SharedPaths.config.path))?[.modificationDate] as? Date
    if stamp != configStamp || configStamp == nil {
        configStamp = stamp
        cfg = FanConfig.load()
    }
}

let queue = DispatchQueue(label: "fancontrold", qos: .utility)

func shutdown() {
    if cooling { thermal.releaseAll(); log("Вентиляторы возвращены в автоматический режим") }
    exit(0)
}
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGINT, SIGTERM, SIGHUP] {
    signal(sig, SIG_IGN)
    let src = DispatchSource.makeSignalSource(signal: sig, queue: queue)
    src.setEventHandler { shutdown() }
    src.resume()
    signalSources.append(src)
}

func nextInterval(_ t: Double) -> TimeInterval {
    if cooling { return opts.interval }
    switch cfg.mode {
    case .max: return opts.interval
    case .system: return 10
    case .smart: return t < cfg.threshold - 10 ? 5 : opts.interval
    }
}

let timer = DispatchSource.makeTimerSource(queue: queue)
timer.setEventHandler {
    reloadConfigIfChanged()
    var lastError: String? = nil
    let now = Date()

    guard let raw = thermal.cpuTemperature() else {
        log("Не удалось прочитать температуру")
        timer.schedule(deadline: .now() + opts.interval, leeway: .seconds(1))
        return
    }

    samples.append((now, raw))
    samples.removeAll { now.timeIntervalSince($0.time) > smoothingWindow }
    let t = samples.map(\.value).reduce(0, +) / Double(samples.count)

    if now.timeIntervalSince(lastHistorySample) >= 1.9 {
        lastHistorySample = now
        history.append((t * 10).rounded() / 10)
        if history.count > 90 { history.removeFirst(history.count - 90) }
    }

    if cfg.mode != lastMode { log("Режим: \(cfg.mode.rawValue)"); lastMode = cfg.mode }

    let shouldCool: Bool
    switch cfg.mode {
    case .system: shouldCool = false
    case .max: shouldCool = true
    case .smart:
        if !cooling && t > cfg.threshold { shouldCool = true }
        else if cooling && t < cfg.threshold - cfg.hysteresis
                    && now.timeIntervalSince(coolingSince) >= minCoolingTime { shouldCool = false }
        else { shouldCool = cooling }
    }

    if shouldCool != cooling {
        log(String(format: "CPU %.1f °C — %@", t, shouldCool ? "включаю вентиляторы" : "вентиляторы в авто-режиме"))
        if !shouldCool { thermal.releaseAll() } else { coolingSince = now }
        cooling = shouldCool
    }

    if cooling {
        for f in thermal.fans {
            do { try thermal.setManual(f, rpm: cfg.mode == .max ? f.maxRPM : cfg.smartRPM) }
            catch { lastError = "Вентилятор \(f.index): \(error)"; log(lastError!) }
        }
    }

    if opts.daemon && (now.timeIntervalSince(lastStatusWrite) >= DaemonStatus.heartbeat
                       || lastStatusCooling != cooling || lastStatusError != lastError) {
        lastStatusWrite = now
        lastStatusCooling = cooling
        lastStatusError = lastError
        DaemonStatus(cooling: cooling, temperature: t, updated: now, error: lastError,
                     build: buildID, history: history).save()
    }

    timer.schedule(deadline: .now() + nextInterval(t), leeway: .seconds(1))
}
timer.schedule(deadline: .now(), leeway: .seconds(1))
timer.resume()
dispatchMain()
