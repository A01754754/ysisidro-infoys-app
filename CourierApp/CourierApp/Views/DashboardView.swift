import SwiftUI

struct DashboardView: View {
    let netEarnings: Double
    let remainingMinutes: Int
    let completedDeliveries: Int

    var body: some View {
        HStack(spacing: 8) {
            metric(
                title: "Ganancia",
                value: "$\(Int(netEarnings))",
                icon: "dollarsign.circle.fill",
                color: .green
            )

            metric(
                title: "Restante",
                value: "\(remainingMinutes) min",
                icon: "clock.fill",
                color: .orange
            )

            metric(
                title: "Entregas",
                value: "\(completedDeliveries)",
                icon: "checkmark.circle.fill",
                color: .blue
            )
        }
        .padding(12)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    private func metric(
        title: String,
        value: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DashboardView(
        netEarnings: 125,
        remainingMinutes: 45,
        completedDeliveries: 2
    )
    .padding()
}
