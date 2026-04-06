import AppKit
import SwiftUI

struct AboutWindowView: View {
    @Environment(\.dismiss) private var dismiss
    let closeWindow: (() -> Void)?

    init(closeWindow: (() -> Void)? = nil) {
        self.closeWindow = closeWindow
    }

    private var versionLabel: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .windowBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 18) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 112, height: 112)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .shadow(color: .black.opacity(0.16), radius: 18, y: 8)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("MacPulse")
                                .font(.system(size: 32, weight: .bold, design: .rounded))

                            Text("Нативный центр состояния Mac в строке меню")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary.opacity(0.88))

                            Text("Следит за CPU, памятью, температурами, батареей и активными процессами без лишней нагрузки на систему.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 8) {
                                aboutBadge("Версия \(versionLabel)", tint: .blue)
                                aboutBadge("Локально", tint: .green)
                                aboutBadge("Нативно", tint: .orange)
                            }
                        }
                    }
                    .padding(22)
                    .background(heroBackground)

                    LazyVGrid(columns: aboutColumns, spacing: 14) {
                        aboutFeatureCard(
                            icon: "cpu",
                            title: "Живые метрики",
                            text: "CPU, память, температуры, диск и батарея обновляются бережно и без перегруза интерфейса."
                        )

                        aboutFeatureCard(
                            icon: "sparkles",
                            title: "Понятные выводы",
                            text: "Приложение не просто показывает цифры, а подсказывает, что происходит с Mac прямо сейчас."
                        )

                        aboutFeatureCard(
                            icon: "lock.shield",
                            title: "Локальная работа",
                            text: "Системные данные и история остаются на Mac и не отправляются во внешние сервисы."
                        )

                        aboutFeatureCard(
                            icon: "menubar.rectangle",
                            title: "Системный формат",
                            text: "Строка меню, компактный popover и центр управления оформлены как нативная часть macOS."
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Что внутри")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 10) {
                            aboutRow("История и события сохраняются локально между перезапусками.")
                            aboutRow("Безопасные действия с процессами выполняются только по явному запросу.")
                            aboutRow("Окно центра управления и окно приложения открываются повторно без дублей.")
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.regularMaterial)
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("© 2026 osin. Авторские права на приложение принадлежат автору.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("GitHub: github.com/moneyflipin/MacPulse")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button("GitHub") {
                            guard let url = URL(string: "https://github.com/moneyflipin/MacPulse") else { return }
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.bordered)

                        Button("Лицензия MIT") {
                            guard let url = URL(string: "https://github.com/moneyflipin/MacPulse/blob/main/LICENSE") else { return }
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Закрыть") {
                            if let closeWindow {
                                closeWindow()
                            } else {
                                dismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(26)
                .frame(minWidth: 620, idealWidth: 620, maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private let aboutColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    private var heroBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.18),
                        Color.teal.opacity(0.10),
                        Color.orange.opacity(0.10),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    private func aboutRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func aboutBadge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }

    private func aboutFeatureCard(icon: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )

            Text(title)
                .font(.headline)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
}
