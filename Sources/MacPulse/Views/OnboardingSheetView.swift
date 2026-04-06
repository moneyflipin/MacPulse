import SwiftUI

struct OnboardingSheetView: View {
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var notificationCoordinator: NotificationCoordinator
    @ObservedObject var launchAtLoginController: LaunchAtLoginController
    let finish: () -> Void

    @State private var experienceMode: ExperienceMode
    @State private var monitoringProfile: MonitoringProfile
    @State private var notificationsEnabled: Bool
    @State private var launchAtLoginEnabled: Bool
    @State private var showControlCenterOnLaunch: Bool
    @State private var reportExportFormat: ReportExportFormat
    @State private var isApplying = false

    init(
        preferences: AppPreferences,
        notificationCoordinator: NotificationCoordinator,
        launchAtLoginController: LaunchAtLoginController,
        finish: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.notificationCoordinator = notificationCoordinator
        self.launchAtLoginController = launchAtLoginController
        self.finish = finish

        let configuration = preferences.configuration
        _experienceMode = State(initialValue: configuration.experienceMode)
        _monitoringProfile = State(initialValue: configuration.monitoringProfile)
        _notificationsEnabled = State(initialValue: configuration.notificationsEnabled)
        _launchAtLoginEnabled = State(initialValue: launchAtLoginController.state.isEnabledLike)
        _showControlCenterOnLaunch = State(initialValue: configuration.showControlCenterOnLaunch)
        _reportExportFormat = State(initialValue: configuration.reportExportFormat)
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .underWindowBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Добро пожаловать в MacPulse")
                            .font(.system(size: 28, weight: .bold, design: .rounded))

                        Text("Сразу настроим комфортный режим, уведомления и поведение окна, чтобы приложение ощущалось как нативный системный помощник.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Режим пользователя")
                            .font(.headline)

                        HStack(spacing: 12) {
                            ForEach(ExperienceMode.allCases) { mode in
                                Button {
                                    experienceMode = mode
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(mode.title)
                                            .font(.headline)
                                        Text(mode.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(experienceMode == mode ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(experienceMode == mode ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Профиль MacPulse")
                            .font(.headline)

                        Picker("Профиль", selection: $monitoringProfile) {
                            ForEach(MonitoringProfile.allCases) { profile in
                                Text(profile.title).tag(profile)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(monitoringProfile.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Поведение")
                            .font(.headline)

                        Toggle("Показывать важные уведомления о нагреве, swap и диске", isOn: $notificationsEnabled)
                        Toggle("Запускать MacPulse при входе в macOS", isOn: $launchAtLoginEnabled)
                        Toggle("Показывать центр управления при запуске приложения", isOn: $showControlCenterOnLaunch)

                        Picker("Формат отчета", selection: $reportExportFormat) {
                            ForEach(ReportExportFormat.allCases) { format in
                                Text(format.title).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Автозапуск лучше всего работает из собранного `.app`. Если macOS попросит подтверждение, MacPulse подскажет это после включения.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(notificationCoordinator.authorizationState.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Начать работу") {
                            Task {
                                await apply()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isApplying)
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 760, minHeight: 540)
    }

    private func apply() async {
        guard !isApplying else { return }
        isApplying = true
        defer { isApplying = false }

        var updated = preferences.configuration
        updated.experienceMode = experienceMode
        updated.monitoringProfile = monitoringProfile
        updated.notificationsEnabled = notificationsEnabled
        updated.showControlCenterOnLaunch = showControlCenterOnLaunch
        updated.reportExportFormat = reportExportFormat
        updated.hasCompletedOnboarding = true

        switch monitoringProfile {
        case .balanced:
            updated.menuBarMode = .balanced
        case .creator, .deepFocus:
            updated.menuBarMode = .detailed
        case .batterySaver:
            updated.menuBarMode = .minimal
        }

        if notificationsEnabled {
            let granted = await notificationCoordinator.requestAuthorizationIfNeeded()
            updated.notificationsEnabled = granted
        }

        preferences.configuration = updated
        await launchAtLoginController.setEnabled(launchAtLoginEnabled)
        finish()
    }
}
