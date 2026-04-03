import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let footnote: String?
    let tint: Color
    let progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if let progress {
                GeometryReader { geometry in
                    let width = max(0, min(1, progress)) * geometry.size.width

                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(tint.opacity(0.12))

                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.55), tint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: width)
                    }
                }
                .frame(height: 6)
            }

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}
