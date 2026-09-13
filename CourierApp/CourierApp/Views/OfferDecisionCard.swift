import SwiftUI

struct OfferDecisionCard: View {
    let orderId: String
    let payoutMXN: Double
    let pickupName: String
    let dropoffName: String
    let decision: String?
    let explanation: String?
    let confidence: Double?
    let onDismiss: () -> Void
    

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    "Nueva oferta",
                    systemImage: "bell.badge.fill"
                )
                .font(.headline)

                Spacer()

                Text("$\(Int(payoutMXN)) MXN")
                    .font(.title3.bold())
                    .foregroundStyle(.green)
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(orderId)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Label(pickupName, systemImage: "shippingbox.fill")
                .foregroundStyle(.green)

            Label(dropoffName, systemImage: "house.fill")
                .foregroundStyle(.red)

            Divider()

            if let decision {
                let accepted = decision == "accept_order"

                Label(
                    accepted
                        ? "Pedido aceptado"
                        : "Pedido rechazado",
                    systemImage:
                        accepted
                        ? "checkmark.circle.fill"
                        : "xmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(
                    accepted ? Color.green : Color.red
                )

                if let explanation {
                    Text(explanation)
                        .font(.subheadline)
                }

                if let confidence {
                    HStack {
                        Text("Confianza")

                        Spacer()

                        Text(
                            confidence,
                            format: .percent.precision(
                                .fractionLength(0)
                            )
                        )
                        .bold()
                    }
                    .font(.caption)

                    ProgressView(value: confidence)
                        .tint(accepted ? .green : .red)
                }
            } else {
                HStack {
                    ProgressView()

                    Text("Esperando decisión del agente…")
                        .font(.subheadline)
                }
            }
        }
        .padding(16)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 20)
        )
        .shadow(radius: 12)
    }
}
