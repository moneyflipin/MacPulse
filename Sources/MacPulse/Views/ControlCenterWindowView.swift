import AppKit
import SwiftUI

private enum ControlCenterSection: String, CaseIterable, Identifiable {
    case overview
    case insights
    case trends
    case processes
    case battery
    case menuBar
    case sensors
    case appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            "Обзор"
        case .insights:
            "Инсайты"
        case .trends:
            "Тренды"
        case .processes:
            "Процессы"
        case .battery:
            "Батарея"
        case .menuBar:
            "Menu Bar"
        case .sensors:
            "Сенсоры"
        case .appearance:
            "Внешний вид"
        }
    }

    var subtitle: String {
        switch self {
        case .overview:
            "Главные метрики и состояние MacBook"
        case .insights:
            "Умные выводы и быстрые действия"
        case .trends:
            "История, причины и события"
        case .processes:
            "Нагрузка по приложениям и профили"
        case .battery:
            "Здоровье батареи и рекомендации"
        case .menuBar:
            "Что видеть в верхней строке"
        case .sensors:
            "Температуры и группы датчиков"
        case .appearance:
            "Режимы, тема и поведение"
        }
    }

    var icon: String {
        switch self {
        case .overview:
            "rectangle.grid.2x2"
        case .insights:
            "sparkles"
        case .trends:
            "waveform.path.ecg"
        case .processes:
            "list.bullet.rectangle"
        case .battery:
            "battery.100percent"
        case .menuBar:
            "menubar.rectangle"
        case .sensors:
            "thermometer.variable"
        case .appearance:
            "circle.lefthalf.filled"
        }
    }
}

struct ControlCenterWindowView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var preferences: AppPreferences

    @State private var selection: ControlCenterSection? = .overview
    @State private var processPendingTermination: ProcessResource?

    private let overviewColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .background(VisualEffectBackground(material: .windowBackground))
        .preferredColorScheme(preferences.configuration.appearanceMode.colorScheme)
        .macPulseWindowStyle()
        .onAppear(perform: ensureSelection)
        .onChange(of: preferences.configuration.experienceMode) { _, _ in
            ensureSelection()
        }
        .alert(
            "Мягко завершить \(processPendingTermination?.name ?? "приложение")?",
            isPresented: terminateAlertBinding
        ) {
            Button("Отмена", role: .cancel) {
                processPendingTermination = nil
            }

            Button("Завершить", role: .destructive) {
                if let processPendingTermination {
                    _ = SystemActionCenter.terminate(process: processPendingTermination)
                }
                processPendingTermination = nil
            }
        } message: {
            Text("MacPulse попробует обычное завершение приложения без принудительного убийства процесса.")
        }
    }

    private var sidebar: some View {
        ZStack {
            VisualEffectBackground(material: .sidebar)
                .ignoresSafeArea()

            List(availableSections, selection: $selection) { section in
                VStack(alignment: .leading, spacing: 4) {
                    Label(section.title, systemImage: section.icon)
                        .font(.headline)

                    Text(section.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .tag(section)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Сейчас в строке")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                MenuBarStatusView(snapshot: monitor.snapshot, preferences: preferences)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.regularMaterial)
                    )
            }
            .padding(14)
            .background(.bar)
        }
    }

    private var detail: some View {
        ZStack {
            VisualEffectBackground(material: .underWindowBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    detailHeader
                    selectedContent
                }
                .padding(22)
            }
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MacPulse")
                        .font(.system(size: 26, weight: .bold, design: .rounded))

                    Text("Центр управления menu bar монитором")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        _ = SystemActionCenter.exportReport(monitor.makeHealthReport())
                    } label: {
                        Label("Экспорт", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            await monitor.refreshNow(forceAll: true)
                        }
                    } label: {
                        Label("Обновить", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Выход", systemImage: "power")
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 8) {
                summaryBadge("CPU \(liveValue(Formatting.percent(monitor.snapshot.cpu.usagePercent)))")
                summaryBadge("Память \(liveValue(Formatting.percent(monitor.snapshot.memory.usagePercent)))")
                summaryBadge(monitor.snapshot.memory.pressureLevel.title)
                summaryBadge(isAwaitingFirstSnapshot ? "Подключаемся" : monitor.snapshot.thermal.condition.title)
                if let battery = monitor.snapshot.battery {
                    summaryBadge("Батарея \(liveValue(Formatting.percent(battery.percentage)))")
                }
            }

            HStack(spacing: 8) {
                InsightChip(
                    title: preferences.configuration.experienceMode.title,
                    systemImage: "slider.horizontal.3",
                    tint: .blue
                )

                InsightChip(
                    title: preferences.configuration.monitoringProfile.title,
                    systemImage: preferences.configuration.monitoringProfile.badge,
                    tint: .orange
                )
            }

            monitoringHealthBanner
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selection ?? .overview {
        case .overview:
            overviewView
        case .insights:
            insightsView
        case .trends:
            trendsView
        case .processes:
            processesView
        case .battery:
            batteryView
        case .menuBar:
            menuBarView
        case .sensors:
            sensorsView
        case .appearance:
            appearanceView
        }
    }

    private var overviewView: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionSurface(title: "Состояние системы", subtitle: monitor.snapshot.summarySentence) {
                LazyVGrid(columns: overviewColumns, spacing: 14) {
                    MetricCard(
                        title: "CPU",
                        value: liveValue(Formatting.percent(monitor.snapshot.cpu.usagePercent)),
                        subtitle: "\(monitor.snapshot.cpu.coreCount) ядер",
                        footnote: isAwaitingFirstSnapshot
                            ? "Первые показания появятся сразу после удачного опроса."
                            : "Пользователь \(Formatting.percent(monitor.snapshot.cpu.userPercent)) • Система \(Formatting.percent(monitor.snapshot.cpu.systemPercent))",
                        tint: .blue,
                        progress: Formatting.progress(from: monitor.snapshot.cpu.usagePercent)
                    )

                    MetricCard(
                        title: "Температура",
                        value: liveTemperature(monitor.snapshot.thermal.primaryTemperatureCelsius),
                        subtitle: isAwaitingFirstSnapshot ? "Ждем датчики" : monitor.snapshot.thermal.condition.title,
                        footnote: isAwaitingFirstSnapshot ? "Температурные сенсоры догружаются отдельно от частых метрик." : monitor.snapshot.thermal.condition.summary,
                        tint: .orange,
                        progress: monitor.snapshot.thermal.primaryTemperatureCelsius.map { Formatting.progress(from: $0, range: 30 ... 105) }
                    )

                    MetricCard(
                        title: "Память",
                        value: liveBytes(monitor.snapshot.memory.usedBytes),
                        subtitle: "из \(Formatting.bytes(monitor.snapshot.memory.totalBytes))",
                        footnote: isAwaitingFirstSnapshot
                            ? "Ждем первый валидный снимок памяти macOS."
                            : "Свободно \(Formatting.bytes(monitor.snapshot.memory.availableBytes)) • Swap \(Formatting.bytes(monitor.snapshot.memory.swapUsedBytes))",
                        tint: memoryTint,
                        progress: Formatting.progress(from: monitor.snapshot.memory.usagePercent)
                    )

                    MetricCard(
                        title: "Диск",
                        value: isAwaitingFirstSnapshot ? "—" : "\(Formatting.bytes(monitor.snapshot.disk.freeBytes)) свободно",
                        subtitle: isAwaitingFirstSnapshot ? "Подключаем том" : "из \(Formatting.bytes(monitor.snapshot.disk.totalBytes))",
                        footnote: isAwaitingFirstSnapshot ? "Если файловая система ответит не сразу, останутся последние удачные значения." : "Занято \(Formatting.percent(monitor.snapshot.disk.usedPercent, decimals: 1))",
                        tint: .purple,
                        progress: Formatting.progress(from: monitor.snapshot.disk.usedPercent)
                    )

                    if let battery = monitor.snapshot.battery {
                        MetricCard(
                            title: "Батарея",
                            value: liveValue(Formatting.percent(battery.percentage)),
                            subtitle: battery.powerSourceName,
                            footnote: batteryFootnote(for: battery),
                            tint: batteryCoach?.severity.tint ?? .pink,
                            progress: Formatting.progress(from: battery.percentage)
                        )
                    }

                    MetricCard(
                        title: "Опрос",
                        value: monitor.activeRefreshDescription,
                        subtitle: preferences.configuration.refreshRate.title,
                        footnote: preferences.configuration.adaptiveRefresh
                            ? "Частота корректируется на батарее и в low power mode"
                            : "Фиксированная частота обновления",
                        tint: .gray,
                        progress: nil
                    )
                }
            }

            sectionSurface(title: "Smart Insights", subtitle: "Сейчас происходит не просто набор цифр, а понятная картина состояния Mac") {
                insightRows(monitor.insights)
            }

            sectionSurface(title: "Быстрые helpers", subtitle: "Безопасные действия, которые помогают быстро разобраться с нагрузкой") {
                cleanupHelperGrid
            }

            sectionSurface(title: "Память по категориям", subtitle: "Теперь с учетом swap и давления на память") {
                LazyVGrid(columns: overviewColumns, spacing: 14) {
                    MetricCard(
                        title: "Приложения",
                        value: liveBytes(monitor.snapshot.memory.appBytes),
                        subtitle: "Активная память процессов",
                        footnote: "Основной рабочий объем запущенных приложений",
                        tint: .blue,
                        progress: Formatting.progress(from: percentage(part: monitor.snapshot.memory.appBytes, total: monitor.snapshot.memory.totalBytes))
                    )

                    MetricCard(
                        title: "Wired",
                        value: liveBytes(monitor.snapshot.memory.wiredBytes),
                        subtitle: "Системная несбрасываемая память",
                        footnote: "Часть памяти, которую macOS старается не выгружать",
                        tint: .orange,
                        progress: Formatting.progress(from: percentage(part: monitor.snapshot.memory.wiredBytes, total: monitor.snapshot.memory.totalBytes))
                    )

                    MetricCard(
                        title: "Кэш",
                        value: liveBytes(monitor.snapshot.memory.cachedBytes),
                        subtitle: "Файловый и системный кэш",
                        footnote: "Может быстро освобождаться при необходимости",
                        tint: .green,
                        progress: Formatting.progress(from: percentage(part: monitor.snapshot.memory.cachedBytes, total: monitor.snapshot.memory.totalBytes))
                    )

                    MetricCard(
                        title: "Swap",
                        value: liveBytes(monitor.snapshot.memory.swapUsedBytes),
                        subtitle: "Диск как расширение RAM",
                        footnote: "Pressure: \(monitor.snapshot.memory.pressureLevel.title)",
                        tint: memoryTint,
                        progress: Formatting.progress(from: monitor.snapshot.memory.swapUsagePercent)
                    )
                }
            }

            LazyVGrid(columns: overviewColumns, spacing: 14) {
                ProcessTable(
                    title: "Лидеры по CPU",
                    subtitle: "Процессы, которые сильнее всего грузят процессор",
                    processes: monitor.snapshot.processes.topCPU,
                    onOpenInMonitor: { SystemActionCenter.openActivityMonitor() },
                    onActivate: { _ = SystemActionCenter.activate(process: $0) },
                    onReveal: { _ = SystemActionCenter.reveal(process: $0) },
                    onTerminate: { processPendingTermination = $0 }
                )

                ProcessTable(
                    title: "Лидеры по памяти",
                    subtitle: "Процессы с самым большим resident memory footprint",
                    processes: monitor.snapshot.processes.topMemory,
                    onOpenInMonitor: { SystemActionCenter.openActivityMonitor() },
                    onActivate: { _ = SystemActionCenter.activate(process: $0) },
                    onReveal: { _ = SystemActionCenter.reveal(process: $0) },
                    onTerminate: { processPendingTermination = $0 }
                )
            }

            trendsSummarySurface
        }
    }

    private var insightsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionSurface(title: "Текущие выводы", subtitle: "MacPulse объясняет, что происходит с системой прямо сейчас") {
                insightRows(monitor.insights)
            }

            sectionSurface(title: "One-click cleanup", subtitle: "Только безопасные и полезные действия без агрессивной очистки") {
                cleanupHelperGrid
            }

            sectionSurface(title: "Цветовая логика", subtitle: "Палитра построена как в системных интерфейсах macOS") {
                HStack(spacing: 10) {
                    InsightChip(title: "Все спокойно", systemImage: InsightSeverity.healthy.systemImage, tint: InsightSeverity.healthy.tint)
                    InsightChip(title: "Нужен взгляд", systemImage: InsightSeverity.warning.systemImage, tint: InsightSeverity.warning.tint)
                    InsightChip(title: "Нужна реакция", systemImage: InsightSeverity.critical.systemImage, tint: InsightSeverity.critical.tint)
                }
            }
        }
    }

    private var trendsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionSurface(title: "История", subtitle: "Мини-графики и причины помогают понять не только текущее состояние, но и контекст") {
                Picker("Окно", selection: preferences.binding(\.trendWindow)) {
                    ForEach(TrendWindow.allCases) { window in
                        Text(window.title).tag(window)
                    }
                }
                .pickerStyle(.segmented)
            }

            LazyVGrid(columns: overviewColumns, spacing: 14) {
                SparklineCard(
                    title: "CPU",
                    value: Formatting.percent(monitor.snapshot.cpu.usagePercent),
                    subtitle: "Среднее \(Formatting.percent(average(historyPoints.map(\.cpuUsage)) ?? 0))",
                    footnote: trendCaption,
                    points: compact(historyPoints.map(\.cpuUsage)),
                    tint: .blue,
                    range: 0 ... 100
                )

                SparklineCard(
                    title: "Память",
                    value: Formatting.percent(monitor.snapshot.memory.usagePercent),
                    subtitle: "Pressure \(monitor.snapshot.memory.pressureLevel.title.lowercased())",
                    footnote: trendCaption,
                    points: compact(historyPoints.map(\.memoryUsage)),
                    tint: memoryTint,
                    range: 0 ... 100
                )

                SparklineCard(
                    title: "Swap",
                    value: Formatting.bytes(monitor.snapshot.memory.swapUsedBytes),
                    subtitle: "Макс \(Formatting.bytes(maxSwapUsage))",
                    footnote: "Рост swap часто объясняет микролаги даже при нормальном CPU",
                    points: compact(historyPoints.map(\.swapUsage)),
                    tint: .purple,
                    range: 0 ... 100
                )

                SparklineCard(
                    title: "Температура",
                    value: monitor.snapshot.thermal.primaryTemperatureCelsius.map(Formatting.temperature) ?? "нет",
                    subtitle: average(historyPoints.compactMap(\.primaryTemperature)).map { "Среднее \(Formatting.temperature($0))" } ?? "Ждем больше данных",
                    footnote: "Основной температурный профиль MacBook",
                    points: compact(historyPoints.compactMap(\.primaryTemperature)),
                    tint: .orange,
                    range: 30 ... 105
                )
            }

            sectionSurface(title: "События и причины", subtitle: "Ключевые изменения, которые объясняют пики нагрузки") {
                if eventHistory.isEmpty {
                    Text("Пока нет заметных событий за выбранное окно.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(eventHistory) { event in
                            eventRow(event)
                            if event.id != eventHistory.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var processesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: overviewColumns, spacing: 14) {
                ProcessTable(
                    title: "Лидеры по CPU",
                    subtitle: "Быстрый вход в процессы, которые прямо сейчас сильнее всего грузят систему",
                    processes: monitor.snapshot.processes.topCPU,
                    onOpenInMonitor: { SystemActionCenter.openActivityMonitor() },
                    onActivate: { _ = SystemActionCenter.activate(process: $0) },
                    onReveal: { _ = SystemActionCenter.reveal(process: $0) },
                    onTerminate: { processPendingTermination = $0 }
                )

                ProcessTable(
                    title: "Лидеры по памяти",
                    subtitle: "Если Mac начинает подтормаживать, смотри в первую очередь сюда",
                    processes: monitor.snapshot.processes.topMemory,
                    onOpenInMonitor: { SystemActionCenter.openActivityMonitor() },
                    onActivate: { _ = SystemActionCenter.activate(process: $0) },
                    onReveal: { _ = SystemActionCenter.reveal(process: $0) },
                    onTerminate: { processPendingTermination = $0 }
                )
            }

            sectionSurface(title: "Профили приложений", subtitle: "Сессия показывает, какие приложения стабильно создают нагрузку") {
                if monitor.appProfiles.isEmpty {
                    Text("Профили появятся после нескольких циклов наблюдения за приложениями.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: overviewColumns, spacing: 14) {
                        ForEach(monitor.appProfiles.prefix(8)) { profile in
                            profileCard(profile)
                        }
                    }
                }
            }
        }
    }

    private var batteryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            guard let battery = monitor.snapshot.battery else {
                return AnyView(
                    sectionSurface(title: "Батарея", subtitle: "На этом Mac не удалось получить данные батареи") {
                        Text("Встроенная батарея недоступна или отсутствует.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                )
            }

            return AnyView(
                VStack(alignment: .leading, spacing: 16) {
                    if let coach = batteryCoach {
                        sectionSurface(title: "Battery Coach", subtitle: coach.summary) {
                            LazyVGrid(columns: overviewColumns, spacing: 14) {
                                MetricCard(
                                    title: coach.headline,
                                    value: "\(coach.score)/100",
                                    subtitle: battery.powerSourceName,
                                    footnote: batteryFootnote(for: battery),
                                    tint: coach.severity.tint,
                                    progress: Double(coach.score) / 100
                                )

                                SparklineCard(
                                    title: "Заряд",
                                    value: Formatting.percent(battery.percentage),
                                    subtitle: battery.healthState,
                                    footnote: "История уровня заряда за \(preferences.configuration.trendWindow.title)",
                                    points: compact(historyPoints.compactMap(\.batteryPercentage)),
                                    tint: coach.severity.tint,
                                    range: 0 ... 100
                                )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(coach.recommendations, id: \.self) { recommendation in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(coach.severity.tint)
                                        Text(recommendation)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    sectionSurface(title: "Показатели батареи", subtitle: "Заряд, ресурс, циклы и температура") {
                        LazyVGrid(columns: overviewColumns, spacing: 14) {
                            MetricCard(
                                title: "Заряд",
                                value: Formatting.percent(battery.percentage),
                                subtitle: battery.powerSourceName,
                                footnote: battery.timeRemainingMinutes.flatMap(Formatting.relativeBatteryTime) ?? "Время пока не определено",
                                tint: .pink,
                                progress: Formatting.progress(from: battery.percentage)
                            )

                            MetricCard(
                                title: "Ресурс",
                                value: battery.healthPercent.map { Formatting.percent($0, decimals: 0) } ?? "нет",
                                subtitle: "Износ \(battery.wearPercent.map { Formatting.percent($0, decimals: 0) } ?? "нет")",
                                footnote: battery.cycleCount.map { "\($0) циклов" } ?? "Циклы недоступны",
                                tint: batteryCoach?.severity.tint ?? .green,
                                progress: (battery.healthPercent ?? 0) / 100
                            )
                        }
                    }
                }
            )
        }
    }

    private var menuBarView: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionSurface(title: "Превью строки", subtitle: "Так индикаторы будут выглядеть в верхнем баре macOS") {
                MenuBarStatusView(snapshot: monitor.snapshot, preferences: preferences)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            }

            sectionSurface(title: "Информативность", subtitle: preferences.configuration.menuBarMode.description) {
                Picker("Информативность", selection: preferences.binding(\.menuBarMode)) {
                    ForEach(MenuBarMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            sectionSurface(title: "Пресет строки", subtitle: preferences.configuration.menuBarPreset.description) {
                Picker("Пресет", selection: preferences.binding(\.menuBarPreset)) {
                    ForEach(MenuBarPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Стиль", selection: preferences.binding(\.menuBarDisplayStyle)) {
                    ForEach(MenuBarDisplayStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }

            sectionSurface(title: "Поведение", subtitle: "Готовые варианты под разные привычки") {
                Text("Можно оставить управление через `Минимум / Баланс / Подробно`, а можно задать конкретный пресет: только CPU, CPU + температура или CPU + память + батарея. Стиль отдельно управляет тем, нужны ли иконки, текст или оба варианта сразу.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sensorsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionSurface(title: "Показ датчиков", subtitle: preferences.configuration.sensorListMode.description) {
                Picker("Сенсоры", selection: preferences.binding(\.sensorListMode)) {
                    ForEach(SensorListMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Показывать технические raw-имена сенсоров", isOn: preferences.binding(\.showRawSensorNames))
            }

            if groupedSensors.isEmpty {
                sectionSurface(title: "Список сенсоров", subtitle: "На этой модели часть датчиков может быть скрыта системой") {
                    Text("Температурные HID-сенсоры сейчас не вернули данные.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(groupedSensors, id: \.group) { group in
                    sectionSurface(title: group.group.title, subtitle: "\(group.sensors.count) датчиков в группе") {
                        VStack(spacing: 0) {
                            ForEach(group.sensors) { sensor in
                                SensorRow(
                                    sensor: sensor,
                                    showsRawName: preferences.configuration.showRawSensorNames
                                )

                                if sensor.id != group.sensors.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var appearanceView: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionSurface(title: "Режим для пользователя", subtitle: preferences.configuration.experienceMode.description) {
                Picker("Режим интерфейса", selection: preferences.binding(\.experienceMode)) {
                    ForEach(ExperienceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            sectionSurface(title: "Профили MacPulse", subtitle: preferences.configuration.monitoringProfile.description) {
                LazyVGrid(columns: overviewColumns, spacing: 14) {
                    ForEach(MonitoringProfile.allCases) { profile in
                        Button {
                            preferences.apply(profile: profile)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(profile.title, systemImage: profile.badge)
                                    .font(.headline)

                                Text(profile.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text(profile == preferences.configuration.monitoringProfile ? "Активен" : "Нажми, чтобы применить")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(profile == preferences.configuration.monitoringProfile ? Color.accentColor : .secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.regularMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(profile == preferences.configuration.monitoringProfile ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            sectionSurface(title: "Тема", subtitle: preferences.configuration.appearanceMode.description) {
                Picker("Тема", selection: preferences.binding(\.appearanceMode)) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            sectionSurface(title: "Частота обновления", subtitle: preferences.configuration.refreshRate.description) {
                Picker("Частота", selection: preferences.binding(\.refreshRate)) {
                    ForEach(RefreshRateOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Адаптивное замедление на батарее и в low power mode", isOn: preferences.binding(\.adaptiveRefresh))
            }

            sectionSurface(title: "Визуальный стиль", subtitle: "Системные материалы и цветовая логика как у macOS") {
                Text("Зеленый цвет значит, что вмешательство не требуется. Оранжевый — лучше посмотреть. Красный — уже есть причина для действия. Базовый режим оставляет только самые важные экраны, а Профи открывает весь набор.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trendsSummarySurface: some View {
        sectionSurface(title: "Быстрая динамика", subtitle: "Короткий срез последних значений") {
            LazyVGrid(columns: overviewColumns, spacing: 14) {
                SparklineCard(
                    title: "CPU",
                    value: Formatting.percent(monitor.snapshot.cpu.usagePercent),
                    subtitle: "За \(preferences.configuration.trendWindow.title)",
                    footnote: trendCaption,
                    points: compact(historyPoints.map(\.cpuUsage)),
                    tint: .blue,
                    range: 0 ... 100
                )

                SparklineCard(
                    title: "Температура",
                    value: monitor.snapshot.thermal.primaryTemperatureCelsius.map(Formatting.temperature) ?? "нет",
                    subtitle: monitor.snapshot.hottestSensor?.name ?? "Основной датчик",
                    footnote: monitor.snapshot.hottestSensor.map { "Самый горячий: \($0.name) \(Formatting.temperature($0.valueCelsius))" } ?? "Пока нет доступных датчиков",
                    points: compact(historyPoints.compactMap(\.primaryTemperature)),
                    tint: .orange,
                    range: 30 ... 105
                )
            }
        }
    }

    private func sectionSurface<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func summaryBadge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }

    private var monitoringHealthBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: monitor.snapshot.health.state.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(healthTint)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(monitor.snapshot.health.state.title)
                    .font(.subheadline.weight(.semibold))

                Text(monitor.snapshot.health.statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Опрос \(monitor.activeRefreshDescription)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(lastSuccessfulRefreshCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(healthTint.opacity(0.18), lineWidth: 1)
        )
    }

    private var cleanupHelperGrid: some View {
        LazyVGrid(columns: overviewColumns, spacing: 14) {
            ForEach(monitor.cleanupHelpers) { helper in
                Button {
                    run(helper: helper)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(helper.title, systemImage: helper.systemImage)
                            .font(.headline)
                            .foregroundStyle(helper.severity.tint)

                        Text(helper.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(helper.severity.tint.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(helper.severity.tint.opacity(0.18), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func insightRows(_ insights: [SmartInsight]) -> some View {
        VStack(spacing: 10) {
            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.severity.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(insight.severity.tint)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.subheadline.weight(.semibold))

                        Text(insight.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Text(insight.severity.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(insight.severity.tint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(insight.severity.tint.opacity(0.08))
                )
            }
        }
    }

    private func eventRow(_ event: SystemEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.systemImage)
                .foregroundStyle(event.severity.tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(Formatting.timestamp(event.timestamp))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(event.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
    }

    private func profileCard(_ profile: AppResourceProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(profile.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(Formatting.timestamp(profile.lastSeen))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                InsightChip(title: "avg \(Formatting.percent(profile.averageCPU, decimals: 1))", systemImage: "cpu", tint: .blue)
                InsightChip(title: "peak \(Formatting.percent(profile.peakCPU, decimals: 1))", systemImage: "waveform.path.ecg", tint: .orange)
            }

            Text("Peak RAM \(Formatting.bytes(profile.peakMemoryBytes)) • Avg RAM \(Formatting.bytes(profile.averageMemoryBytes))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Показать") {
                    _ = SystemActionCenter.activate(
                        process: ProcessResource(
                            pid: profile.latestPID,
                            name: profile.displayName,
                            cpuPercent: profile.averageCPU,
                            memoryBytes: profile.peakMemoryBytes,
                            executablePath: profile.executablePath
                        )
                    )
                }
                .buttonStyle(.bordered)

                if profile.executablePath != nil {
                    Button("Файл") {
                        _ = SystemActionCenter.reveal(
                            process: ProcessResource(
                                pid: profile.latestPID,
                                name: profile.displayName,
                                cpuPercent: profile.averageCPU,
                                memoryBytes: profile.peakMemoryBytes,
                                executablePath: profile.executablePath
                            )
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func ensureSelection() {
        if !availableSections.contains(selection ?? .overview) {
            selection = availableSections.first
        }
    }

    private func run(helper: CleanupHelper) {
        switch helper.kind {
        case .openActivityMonitor:
            SystemActionCenter.openActivityMonitor()
        case .activateTopApp:
            if let process = helper.targetProcess {
                _ = SystemActionCenter.activate(process: process)
            }
        case .terminateTopApp:
            processPendingTermination = helper.targetProcess
        case .revealTopExecutable:
            if let process = helper.targetProcess {
                _ = SystemActionCenter.reveal(process: process)
            }
        case .exportReport:
            _ = SystemActionCenter.exportReport(monitor.makeHealthReport())
        }
    }

    private var availableSections: [ControlCenterSection] {
        switch preferences.configuration.experienceMode {
        case .basic:
            [.overview, .battery, .menuBar, .appearance]
        case .smart:
            [.overview, .insights, .trends, .processes, .battery, .menuBar, .appearance]
        case .pro:
            ControlCenterSection.allCases
        }
    }

    private var terminateAlertBinding: Binding<Bool> {
        Binding(
            get: { processPendingTermination != nil },
            set: { newValue in
                if !newValue {
                    processPendingTermination = nil
                }
            }
        )
    }

    private var historyPoints: [MetricHistoryPoint] {
        monitor.historyPoints(for: preferences.configuration.trendWindow)
    }

    private var eventHistory: [SystemEvent] {
        monitor.eventHistory(for: preferences.configuration.trendWindow)
    }

    private var batteryCoach: BatteryCoachSummary? {
        monitor.batteryCoach
    }

    private var trendCaption: String {
        "\(historyPoints.count) точек • шаг \(monitor.activeRefreshDescription)"
    }

    private var maxSwapUsage: UInt64 {
        let values = historyPoints.map { UInt64(Double(monitor.snapshot.memory.swapTotalBytes) * ($0.swapUsage / 100)) }
        return values.max() ?? monitor.snapshot.memory.swapUsedBytes
    }

    private var groupedSensors: [(group: SensorGroup, sensors: [SensorReading])] {
        let grouped = Dictionary(grouping: monitor.snapshot.thermal.sensors, by: \.group)

        return grouped.keys
            .sorted { $0.sortOrder > $1.sortOrder }
            .compactMap { group in
                guard var sensors = grouped[group], !sensors.isEmpty else {
                    return nil
                }

                sensors.sort { $0.valueCelsius > $1.valueCelsius }

                if let limit = preferences.configuration.sensorListMode.perGroupLimit {
                    sensors = Array(sensors.prefix(limit))
                }

                return (group, sensors)
            }
    }

    private func batteryFootnote(for battery: BatteryStats) -> String {
        var parts: [String] = [battery.healthState]

        if let health = battery.healthPercent {
            parts.append("Ресурс \(String(format: "%.1f%%", health))")
        }

        if let wear = battery.wearPercent {
            parts.append("Износ \(String(format: "%.1f%%", wear))")
        }

        if let cycleCount = battery.cycleCount {
            parts.append("\(cycleCount) циклов")
        }

        if let timeRemaining = Formatting.relativeBatteryTime(battery.timeRemainingMinutes) {
            parts.append(timeRemaining)
        }

        if let temperature = battery.temperatureCelsius {
            parts.append(Formatting.temperature(temperature))
        }

        return parts.joined(separator: " • ")
    }

    private func average(_ values: [Double]) -> Double? {
        Formatting.average(values)
    }

    private var isAwaitingFirstSnapshot: Bool {
        monitor.snapshot.health.lastSuccessfulUpdate == nil
    }

    private var memoryTint: Color {
        switch monitor.snapshot.memory.pressureLevel {
        case .normal:
            .green
        case .elevated:
            .orange
        case .high, .critical:
            .red
        }
    }

    private var healthTint: Color {
        switch monitor.snapshot.health.state {
        case .bootstrapping:
            .blue
        case .live:
            .green
        case .degraded:
            .orange
        }
    }

    private var lastSuccessfulRefreshCaption: String {
        guard let lastSuccessfulUpdate = monitor.snapshot.health.lastSuccessfulUpdate else {
            return "Ждем первые данные"
        }

        return "Успешно \(Formatting.timestamp(lastSuccessfulUpdate))"
    }

    private func liveValue(_ value: String) -> String {
        isAwaitingFirstSnapshot ? "—" : value
    }

    private func liveBytes(_ value: UInt64) -> String {
        isAwaitingFirstSnapshot ? "—" : Formatting.bytes(value)
    }

    private func liveTemperature(_ value: Double?) -> String {
        guard !isAwaitingFirstSnapshot else { return "—" }
        return value.map(Formatting.temperature) ?? "нет"
    }

    private func percentage(part: UInt64, total: UInt64) -> Double {
        guard total > 0 else { return 0 }
        return (Double(part) / Double(total)) * 100
    }

    private func compact(_ values: [Double], targetCount: Int = 80) -> [Double] {
        guard values.count > targetCount, targetCount > 0 else { return values }

        let stride = Double(values.count - 1) / Double(targetCount - 1)
        return (0 ..< targetCount).map { index in
            let sourceIndex = Int((Double(index) * stride).rounded())
            return values[min(sourceIndex, values.count - 1)]
        }
    }
}
