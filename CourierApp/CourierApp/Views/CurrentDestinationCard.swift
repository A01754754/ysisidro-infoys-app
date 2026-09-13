import CoreLocation
import SwiftUI

struct CurrentDestinationCard: View {
    let destinationId: String
    let destinationType: String
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    title,
                    systemImage: icon
                )
                .font(.headline)
                .foregroundStyle(color)

                Spacer()

                Text(destinationType.uppercased())
                    .font(.caption.bold())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        color.opacity(0.15),
                        in: Capsule()
                    )
            }

            Text(destinationId)
                .font(.subheadline.bold())

            Label(
                coordinateText,
                systemImage: "location.fill"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20)
        )
        .shadow(radius: 8)
    }

    private var normalizedType: String {
        destinationType.lowercased()
    }

    private var isPickup: Bool {
        normalizedType == "pick"
            || normalizedType == "pickup"
    }

    private var title: String {
        isPickup ? "Próxima recolección" : "Próxima entrega"
    }

    private var icon: String {
        isPickup ? "shippingbox.fill" : "house.fill"
    }

    private var color: Color {
        isPickup ? .green : .red
    }

    private var coordinateText: String {
        String(
            format: "%.6f, %.6f",
            coordinate.latitude,
            coordinate.longitude
        )
    }
}
