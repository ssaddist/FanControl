import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case en, ru

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        }
    }

    var strings: Strings {
        switch self {
        case .en: return .en
        case .ru: return .ru
        }
    }
}

struct Strings {
    let subtitle: String
    let turnOnAt: String
    let fanSpeed: String
    let rpm: String
    let helperNeeded: String
    let installing: String
    let enableControl: String
    let updating: String
    let helperOutdated: String
    let helperActive: String
    let remove: String
    let removeHelp: String
    let quit: String
    let cpu: String
    let fansAtMax: String
    let maxMode: String
    let macOSControls: String
    let coolingPrefix: String
    let thresholdPrefix: String
    let fanShort: String
    let modeSystem: String
    let modeAuto: String
    let modeMax: String
    let noHelperFiles: String
    let actionFailed: String
    let settings: String
    let theme: String
    let language: String
    let themeEmber: String
    let themeClassic: String
    let version: String

    func cooling(_ rpm: Double) -> String { "\(coolingPrefix) · \(Int(rpm)) \(self.rpm)" }
    func threshold(_ t: Double) -> String { "\(thresholdPrefix) \(Int(t)) °C" }
    func fan(_ n: Int, upper: Bool) -> String { "\(upper ? fanShort.uppercased() : fanShort) \(n)" }

    func styleName(_ style: AppStyle) -> String {
        switch style {
        case .ember: return themeEmber
        case .classic: return themeClassic
        }
    }

    static let en = Strings(
        subtitle: "CPU cooling",
        turnOnAt: "Turn on at",
        fanSpeed: "Fan speed",
        rpm: "rpm",
        helperNeeded: "To control the fans, FanControl needs a helper with administrator rights. macOS will ask for your password once.",
        installing: "Installing…",
        enableControl: "Enable fan control",
        updating: "Updating…",
        helperOutdated: "Helper is outdated — update",
        helperActive: "Helper active",
        remove: "Remove",
        removeHelp: "Stop and remove the background service",
        quit: "Quit",
        cpu: "CPU",
        fansAtMax: "Fans at maximum",
        maxMode: "Max mode",
        macOSControls: "Controlled by macOS",
        coolingPrefix: "Cooling",
        thresholdPrefix: "Threshold",
        fanShort: "Fan",
        modeSystem: "System",
        modeAuto: "Auto",
        modeMax: "Max",
        noHelperFiles: "Helper files are missing from the app bundle",
        actionFailed: "Couldn't complete the action",
        settings: "Settings",
        theme: "Theme",
        language: "Language",
        themeEmber: "Ember",
        themeClassic: "Classic",
        version: "Version"
    )

    static let ru = Strings(
        subtitle: "Охлаждение процессора",
        turnOnAt: "Включать при",
        fanSpeed: "Обороты",
        rpm: "об/мин",
        helperNeeded: "Чтобы управлять вентиляторами, нужен помощник с правами администратора. macOS один раз спросит пароль.",
        installing: "Установка…",
        enableControl: "Включить управление",
        updating: "Обновление…",
        helperOutdated: "Помощник устарел — обновить",
        helperActive: "Помощник активен",
        remove: "Удалить",
        removeHelp: "Остановить и удалить фоновую службу",
        quit: "Выйти",
        cpu: "ПРОЦЕССОР",
        fansAtMax: "Вентиляторы на максимуме",
        maxMode: "Режим «Максимум»",
        macOSControls: "Управляет macOS",
        coolingPrefix: "Охлаждение",
        thresholdPrefix: "Порог",
        fanShort: "Вент.",
        modeSystem: "Система",
        modeAuto: "Авто",
        modeMax: "Максимум",
        noHelperFiles: "В пакете приложения нет файлов помощника",
        actionFailed: "Не удалось выполнить",
        settings: "Настройки",
        theme: "Тема",
        language: "Язык",
        themeEmber: "Чёрно-оранжевая",
        themeClassic: "Классическая",
        version: "Версия"
    )
}

private struct StringsKey: EnvironmentKey {
    static let defaultValue = Strings.en
}

extension EnvironmentValues {
    var strings: Strings {
        get { self[StringsKey.self] }
        set { self[StringsKey.self] = newValue }
    }
}
