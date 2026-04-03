import SwiftUI

struct SparklineCard: View {
    let title: String
    let value: String
    let subtitle: String
    let footnote: String
    let points: [Double]
    let tint: Color
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.08))

                VStack(spacing: 0) {
                    ForEach(0 ..< 3, id: \.self) { _ in
                        Divider()
                            .overlay(tint.opacity(0.12))
                        Spacer()
                    }
                }
                .padding(.vertical, 10)

                SparklineShape(points: points, range: range)
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0.55), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
            }
            .frame(height: 96)

            Text(footnote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct SparklineShape: Shape {
    let points: [Double]
    let range: ClosedRange<Double>

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let values = points.isEmpty ? [range.lowerBound, range.upperBound] : points
        guard values.count > 1 else {
            let y = yPosition(for: values[0], in: rect)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            return path
        }

        let stepX = rect.width / CGFloat(max(values.count - 1, 1))

        for (index, value) in values.enumerated() {
            let point = CGPoint(
                x: rect.minX + (CGFloat(index) * stepX),
                y: yPosition(for: value, in: rect)
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }

    private func yPosition(for value: Double, in rect: CGRect) -> CGFloat {
        let progress = Formatting.progress(from: value, range: range)
        return rect.maxY - (CGFloat(progress) * rect.height)
    }
}
