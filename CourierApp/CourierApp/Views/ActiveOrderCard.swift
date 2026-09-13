import SwiftUI

struct ActiveOrderCard: View {
    let orderId: String
    let pickupName: String
    let dropoffName: String
    let payoutMXN: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    "Pedido activo",
                    systemImage: "shippingbox.fill"
                )
                .font(.headline)

                Spacer()

                Text("$\(Int(payoutMXN)) MXN")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            Text(orderId)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            locationRow(
                icon: "arrow.up.circle.fill",
                color: .green,
                title: "Recoger en",
                location: pickupName
            )

            locationRow(
                icon: "arrow.down.circle.fill",
                color: .red,
                title: "Entregar en",
                location: dropoffName
            )
        }
        .padding(16)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20)
        )
        .shadow(radius: 8)
    }

    private func locationRow(
        icon: String,
        color: Color,
        title: String,
        location: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(location)
                    .font(.subheadline.bold())
            }
        }
    }
}

#Preview {
    ActiveOrderCard(
        orderId: "order-38",
        pickupName: "Centro de Monterrey",
        dropoffName: "San Pedro",
        payoutMXN: 89
    )
    .padding()
}
