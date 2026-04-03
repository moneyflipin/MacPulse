import SwiftUI

struct SensorRow: View {
    let sensor: SensorReading
    let showsRawName: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sensor.name)
                    .font(.subheadline.weight(.semibold))

                if showsRawName, sensor.name != sensor.rawName {
                    Text(sensor.rawName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(Formatting.temperature(sensor.valueCelsius))
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 6)
    }
}
