import Combine
import Foundation
import SwiftUI

enum ExperienceMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case basic
    case smart
    case pro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic:
            "Базовый"
        case .smart:
            "Умный"
        case .pro:
            "Профи"
        }
    }

    var description: String {
        switch self {
        case .basic:
            "Только самые важные экраны и понятные подсказки"
        case .smart:
            "Баланс между советами, историей и диагностикой"
        case .pro:
            "Полный доступ к сенсорам, трендам и глубоким деталям"
        }
    }
}

enum MenuBarMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case minimal
    case balanced
    case detailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimal:
            "Минимум"
        case .balanced:
            "Баланс"
        case .detailed:
            "Подробно"
        }
    }

    var description: String {
        switch self {
        case .minimal:
            "Только главная загрузка CPU"
        case .balanced:
            "CPU, температура и батарея"
        case .detailed:
            "CPU, память, температура и батарея"
        }
    }
}

enum MenuBarPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case followMode
    case cpuOnly
    case cpuTemperature
    case cpuMemoryBattery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followMode:
            "По режиму"
        case .cpuOnly:
            "Только CPU"
        case .cpuTemperature:
            "CPU + темп."
        case .cpuMemoryBattery:
            "CPU + RAM + батарея"
        }
    }

    var description: String {
        switch self {
        case .followMode:
            "Состав строки зависит от информативности"
        case .cpuOnly:
            "Почти незаметная строка с одной метрикой"
        case .cpuTemperature:
            "Самый полезный повседневный набор"
        case .cpuMemoryBattery:
            "Сильный набор для частого контроля ресурсов"
        }
    }
}

enum MenuBarDisplayStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case iconsAndText
    case iconsOnly
    case textOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iconsAndText:
            "Иконки и текст"
        case .iconsOnly:
            "Только иконки"
        case .textOnly:
            "Только текст"
        }
    }
}

enum MonitoringProfile: String, CaseIterable, Codable, Identifiable, Sendable {
    case balanced
    case creator
    case batterySaver
    case deepFocus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced:
            "Работа"
        case .creator:
            "Создание"
        case .batterySaver:
            "От батареи"
        case .deepFocus:
            "Диагностика"
        }
    }

    var description: String {
        switch self {
        case .balanced:
            "Стандартный повседневный профиль"
        case .creator:
            "Больше истории и агрессивнее обновление"
        case .batterySaver:
            "Бережный режим для автономной работы"
        case .deepFocus:
            "Максимум деталей для поиска проблемы"
        }
    }

    var badge: String {
        switch self {
        case .balanced:
            "rectangle.grid.2x2"
        case .creator:
            "sparkles.rectangle.stack"
        case .batterySaver:
            "leaf"
        case .deepFocus:
            "stethoscope"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            "Системная"
        case .light:
            "Светлая"
        case .dark:
            "Темная"
        }
    }

    var description: String {
        switch self {
        case .system:
            "Подстраиваться под macOS"
        case .light:
            "Всегда светлая палитра"
        case .dark:
            "Всегда темная палитра"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

enum RefreshRateOption: String, CaseIterable, Codable, Identifiable, Sendable {
    case fast
    case balanced
    case calm
    case saver

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast:
            "Быстро"
        case .balanced:
            "Норма"
        case .calm:
            "Спокойно"
        case .saver:
            "Экономно"
        }
    }

    var description: String {
        switch self {
        case .fast:
            "Обновление каждые 2 сек"
        case .balanced:
            "Обновление каждые 3 сек"
        case .calm:
            "Обновление каждые 5 сек"
        case .saver:
            "Обновление каждые 10 сек"
        }
    }

    var seconds: Double {
        switch self {
        case .fast:
            2
        case .balanced:
            3
        case .calm:
            5
        case .saver:
            10
        }
    }
}

enum SensorListMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case important
    case expanded
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .important:
            "Ключевые"
        case .expanded:
            "Расширенно"
        case .all:
            "Все"
        }
    }

    var description: String {
        switch self {
        case .important:
            "Самые полезные датчики по группам"
        case .expanded:
            "Больше деталей без перегруза"
        case .all:
            "Показывать весь список"
        }
    }

    var perGroupLimit: Int? {
        switch self {
        case .important:
            2
        case .expanded:
            4
        case .all:
            nil
        }
    }
}

enum TrendWindow: String, CaseIterable, Codable, Identifiable, Sendable {
    case short
    case medium
    case long

    var id: String { rawValue }

    var title: String {
        switch self {
        case .short:
            "10 мин"
        case .medium:
            "30 мин"
        case .long:
            "60 мин"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .short:
            10 * 60
        case .medium:
            30 * 60
        case .long:
            60 * 60
        }
    }
}

struct AppConfiguration: Codable, Equatable, Sendable {
    var experienceMode: ExperienceMode = .smart
    var menuBarMode: MenuBarMode = .balanced
    var menuBarPreset: MenuBarPreset = .followMode
    var menuBarDisplayStyle: MenuBarDisplayStyle = .iconsAndText
    var monitoringProfile: MonitoringProfile = .balanced
    var refreshRate: RefreshRateOption = .balanced
    var adaptiveRefresh = true
    var sensorListMode: SensorListMode = .expanded
    var trendWindow: TrendWindow = .medium
    var showRawSensorNames = false
    var appearanceMode: AppearanceMode = .system
}

@MainActor
final class AppPreferences: ObservableObject {
    @Published var configuration: AppConfiguration {
        didSet {
            persist()
        }
    }

    private let defaults: UserDefaults
    private let storageKey = "MacPulse.configuration"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if
            let data = defaults.data(forKey: storageKey),
            let configuration = try? JSONDecoder().decode(AppConfiguration.self, from: data)
        {
            self.configuration = configuration
        } else {
            self.configuration = AppConfiguration()
        }
    }

    func binding<Value>(_ keyPath: WritableKeyPath<AppConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: { self.configuration[keyPath: keyPath] },
            set: { newValue in
                var updated = self.configuration
                updated[keyPath: keyPath] = newValue
                self.configuration = updated
            }
        )
    }

    func reset() {
        configuration = AppConfiguration()
    }

    func apply(profile: MonitoringProfile) {
        var updated = configuration
        updated.monitoringProfile = profile

        switch profile {
        case .balanced:
            updated.experienceMode = .smart
            updated.menuBarMode = .balanced
            updated.menuBarPreset = .followMode
            updated.menuBarDisplayStyle = .iconsAndText
            updated.refreshRate = .balanced
            updated.adaptiveRefresh = true
            updated.sensorListMode = .expanded
            updated.trendWindow = .medium
        case .creator:
            updated.experienceMode = .pro
            updated.menuBarMode = .detailed
            updated.menuBarPreset = .cpuMemoryBattery
            updated.menuBarDisplayStyle = .iconsAndText
            updated.refreshRate = .fast
            updated.adaptiveRefresh = true
            updated.sensorListMode = .all
            updated.trendWindow = .long
        case .batterySaver:
            updated.experienceMode = .basic
            updated.menuBarMode = .minimal
            updated.menuBarPreset = .cpuTemperature
            updated.menuBarDisplayStyle = .iconsAndText
            updated.refreshRate = .saver
            updated.adaptiveRefresh = true
            updated.sensorListMode = .important
            updated.trendWindow = .short
        case .deepFocus:
            updated.experienceMode = .pro
            updated.menuBarMode = .detailed
            updated.menuBarPreset = .followMode
            updated.menuBarDisplayStyle = .iconsAndText
            updated.refreshRate = .fast
            updated.adaptiveRefresh = false
            updated.sensorListMode = .all
            updated.trendWindow = .long
        }

        configuration = updated
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
