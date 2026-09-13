import SwiftUI

struct VoiceAgentButton: View {
    @ObservedObject var manager: VoiceAgentManager

    let onToggleConversation: () -> Void
    let onToggleMute: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if !manager.lastTranscript.isEmpty {
                Text(manager.lastTranscript)
                    .font(.caption)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(
                            cornerRadius: 12
                        )
                    )
                    .frame(maxWidth: 260)
            }

            if let errorMessage = manager.errorMessage {
                Text(errorMessage)
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(
                            cornerRadius: 12
                        )
                    )
                    .frame(maxWidth: 260)
            }

            HStack(spacing: 10) {
                if manager.isConnected {
                    Button(action: onToggleMute) {
                        Image(
                            systemName:
                                manager.isMuted
                                ? "mic.slash.fill"
                                : "mic.fill"
                        )
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            manager.isMuted
                            ? Color.orange
                            : Color.blue,
                            in: Circle()
                        )
                    }
                    .accessibilityLabel(
                        manager.isMuted
                        ? "Activar micrófono"
                        : "Silenciar micrófono"
                    )
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text(manager.statusText)
                        .font(.caption.bold())

                    Text(
                        manager.isConnected
                        ? "Toca para terminar"
                        : "Toca para hablar"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    .regularMaterial,
                    in: Capsule()
                )

                Button(action: onToggleConversation) {
                    ZStack {
                        Circle()
                            .fill(statusColor)

                        if manager.isConnecting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(
                                systemName:
                                    manager.isConnected
                                    ? "phone.down.fill"
                                    : "waveform"
                            )
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 54, height: 54)
                    .shadow(radius: 7)
                }
                .accessibilityLabel(
                    manager.isConnected
                    ? "Terminar conversación"
                    : "Iniciar conversación"
                )
            }
        }
    }

    private var statusColor: Color {
        if manager.errorMessage != nil {
            return .red
        }

        if manager.isConnecting {
            return .orange
        }

        if manager.isAgentSpeaking {
            return .blue
        }

        if manager.isConnected {
            return .green
        }

        return .purple
    }
}
