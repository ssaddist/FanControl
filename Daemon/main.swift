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
var recent: [Double] = []
var lastMode: FanConfig.Mode? = nil

func shutdown() {
    if cooling { thermal.releaseAll(); log("Вентиляторы возвращены в автоматический режим") }
    exit(0)
}
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGINT, SIGTERM, SIGHUP] {
    signal(sig, SIG_IGN)
    let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    src.setEventHandler { shutdown() }
    src.resume()
    signalSources.append(src)
}

let timer = DispatchSource.makeTimerSource(queue: .main)
timer.schedule(deadline: .now(), repeating: opts.interval)
timer.setEventHandler {
    let cfg = opts.daemon ? FanConfig.load() : opts.config
    var lastError: String? = nil

    guard let raw = thermal.cpuTemperature() else { log("Не удалось прочитать температуру"); return }

    recent.append(raw)
    if recent.count > max(1, Int(10 / opts.interval)) { recent.removeFirst() }
    let t = recent.reduce(0, +) / Double(recent.count)

    if cfg.mode != lastMode { log("Режим: \(cfg.mode.rawValue)"); lastMode = cfg.mode }

    let shouldCool: Bool
    switch cfg.mode {
    case .system: shouldCool = false
    case .max: shouldCool = true
    case .smart:
        if !cooling && t > cfg.threshold { shouldCool = true }
        else if cooling && t < cfg.threshold - cfg.hysteresis
                    && Date().timeIntervalSince(coolingSince) >= minCoolingTime { shouldCool = false }
        else { shouldCool = cooling }
    }

    if shouldCool != cooling {
        log(String(format: "CPU %.1f °C — %@", t, shouldCool ? "включаю вентиляторы" : "вентиляторы в авто-режиме"))
        if !shouldCool { thermal.releaseAll() } else { coolingSince = Date() }
        cooling = shouldCool
    }

    if cooling {

        for f in thermal.fans {
            do { try thermal.setManual(f, rpm: cfg.mode == .max ? f.maxRPM : cfg.smartRPM) }
            catch { lastError = "Вентилятор \(f.index): \(error)"; log(lastError!) }
        }
    }

    if opts.daemon {
        DaemonStatus(cooling: cooling, temperature: t, updated: Date(), error: lastError, build: buildID).save()
    }
}
timer.resume()
dispatchMain()
