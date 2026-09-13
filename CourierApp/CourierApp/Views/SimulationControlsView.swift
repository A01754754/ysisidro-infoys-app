import SwiftUI

struct SimulationControlsView: View {
    let isPaused: Bool
    let speed: Double
    let onTogglePause: () -> Void
    let onSelectSpeed: (Double) -> Void

    private let availableSpeeds = [
        1.0,
        5.0,
        20.0
    ]

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTogglePause) {
                Label(
                    isPaused ? "Continuar" : "Pausar",
                    systemImage:
                        isPaused
                        ? "play.fill"
                        : "pause.fill"
                )
                .font(.subheadline.bold())
            }

            Divider()
                .frame(height: 24)

            ForEach(
                availableSpeeds,
                id: \.self
            ) { value in
                Button {
                    onSelectSpeed(value)
                } label: {
                    Text("\(Int(value))×")
                        .font(.subheadline.bold())
                        .foregroundStyle(
                            value == speed
                            ? Color.white
                            : Color.primary
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            value == speed
                            ? Color.blue
                            : Color.gray.opacity(0.2),
                            in: Capsule()
                        )
                }
            }
        }
        .padding(12)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }
}

#Preview {
    SimulationControlsView(
        isPaused: false,
        speed: 1,
        onTogglePause: {},
        onSelectSpeed: { _ in }
    )
    .padding()
}
