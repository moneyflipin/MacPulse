import SwiftUI

struct ProcessTable: View {
    let title: String
    let subtitle: String
    let processes: [ProcessResource]
    var onOpenInMonitor: (() -> Void)? = nil
    var onActivate: ((ProcessResource) -> Void)? = nil
    var onReveal: ((ProcessResource) -> Void)? = nil
    var onTerminate: ((ProcessResource) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if processes.isEmpty {
                Text("Пока нет данных")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(processes) { process in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(process.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)

                                Text("PID \(process.pid)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Formatting.percent(process.cpuPercent, decimals: 1))
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .monospacedDigit()

                                Text(Formatting.bytes(process.memoryBytes))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }

                            if showsActions {
                                Menu {
                                    if let onOpenInMonitor {
                                        Button("Открыть Мониторинг системы") {
                                            onOpenInMonitor()
                                        }
                                    }

                                    if let onActivate {
                                        Button("Показать приложение") {
                                            onActivate(process)
                                        }
                                    }

                                    if let onReveal, process.executablePath != nil {
                                        Button("Показать файл") {
                                            onReveal(process)
                                        }
                                    }

                                    if let onTerminate {
                                        Divider()
                                        Button("Мягко завершить", role: .destructive) {
                                            onTerminate(process)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                            }
                        }
                        .padding(.vertical, 8)

                        if process.id != processes.last?.id {
                            Divider()
                        }
                    }
                }
            }
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

    private var showsActions: Bool {
        onOpenInMonitor != nil || onActivate != nil || onReveal != nil || onTerminate != nil
    }
}
