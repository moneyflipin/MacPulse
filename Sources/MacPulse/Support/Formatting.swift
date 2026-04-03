import Foundation

enum Formatting {
    static func percent(_ value: Double, decimals: Int = 0) -> String {
        String(format: "%.\(decimals)f%%", value)
    }

    static func temperature(_ value: Double) -> String {
        String(format: "%.0fC", value)
    }

    static func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary)
    }

    static func relativeBatteryTime(_ minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return "\(remainingMinutes) мин"
        }

        if remainingMinutes == 0 {
            return "\(hours) ч"
        }

        return "\(hours) ч \(remainingMinutes) мин"
    }

    static func timestamp(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func progress(from value: Double, range: ClosedRange<Double> = 0 ... 100) -> Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        return (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
