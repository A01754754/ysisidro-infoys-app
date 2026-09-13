import SwiftUI

struct EnvironmentStatusView: View {
    let isRaining: Bool
    let surgeMultiplier: Double?

    let hasClosedRoad: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            if isRaining {
                statusBadge(
                    text: "Lluvia",
                    icon: "cloud.rain.fill",
                    color: .blue
                )
            }

            if let surgeMultiplier {
                statusBadge(
                    text: "Surge \(surgeMultiplier, default: "%.1f")×",
                    icon: "bolt.fill",
                    color: .orange
                )
            }
            
            if hasClosedRoad {
                statusBadge(
                    text: "Calle cerrada",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
            }
        }
    }

    private func statusBadge(
        text: String,
        icon: String,
        color: Color
    ) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                color,
                in: Capsule()
            )
    }
}

#Preview {
    EnvironmentStatusView(
        isRaining: true,
        surgeMultiplier: 1.5,
        hasClosedRoad: true
    )
}
