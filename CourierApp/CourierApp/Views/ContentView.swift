import SwiftUI
import MapboxMaps
import CoreLocation

struct ContentView: View {
    @StateObject private var viewModel =
        CourierViewModel()

    @StateObject private var voiceAgentManager =
        VoiceAgentManager()

    @State private var viewport: Viewport =
        .camera(
            center: CLLocationCoordinate2D(
                latitude: 25.6866,
                longitude: -100.3161
            ),
            zoom: 13,
            bearing: 0,
            pitch: 0
        )

    @State private var followsCourier = true

    var body: some View {
        ZStack(alignment: .top) {
            courierMap
            topPanel

            if viewModel.hasActiveOrder {
                bottomOrderCard
            }

            cameraFollowButton
            voiceControls
            offerOverlay
        }
        .task {
            await viewModel.startReceivingCourierState()
        }
        .onDisappear {
            Task {
                await voiceAgentManager.endConversation()
            }
        }
    }

    // MARK: - Mapa

    private var courierMap: some View {
        Map(viewport: $viewport) {
            if viewModel.hasRoute {
                if viewModel.remainingRouteCoordinates.count >= 2 {
                    routeAnnotation
                }

                if !viewModel.isReceivingDev2State {
                    pickupAnnotation
                    dropoffAnnotation
                }
            }

            if viewModel.isReceivingDev2State,
               let destination =
                viewModel.currentDestinationCoordinate {

                currentDestinationAnnotation(
                    at: destination
                )
            }

            if viewModel.closedRoadCoordinates.count >= 2 {
                closedRoadAnnotation
            }

            if let coordinate =
                viewModel.courierCoordinate {

                MapViewAnnotation(
                    coordinate: coordinate
                ) {
                    courierMarker
                }
                .allowOverlap(true)
            }
        }
        .ignoresSafeArea()
        .onReceive(
            viewModel.$courierCoordinate
        ) { coordinate in
            guard followsCourier,
                  let coordinate else {
                return
            }

            viewport = .camera(
                center: coordinate,
                zoom: 16.5,
                bearing: viewModel.courierBearing,
                pitch: 50
            )
        }
    }

    private func currentDestinationAnnotation(
        at coordinate: CLLocationCoordinate2D
    ) -> some MapContent {
        MapViewAnnotation(coordinate: coordinate) {
            VStack(spacing: 3) {
                Image(systemName: destinationIcon)
                    .foregroundStyle(.white)
                    .padding(9)
                    .background(
                        destinationColor,
                        in: Circle()
                    )

                Text(destinationLabel)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        .ultraThinMaterial,
                        in: Capsule()
                    )
            }
        }
        .allowOverlap(true)
    }

    private var isPickupDestination: Bool {
        let type = viewModel.currentDestinationType?
            .lowercased()

        return type == "pick" || type == "pickup"
    }

    private var destinationIcon: String {
        isPickupDestination
            ? "shippingbox.fill"
            : "house.fill"
    }

    private var destinationColor: Color {
        isPickupDestination ? .green : .red
    }

    private var destinationLabel: String {
        isPickupDestination ? "Pickup" : "Entrega"
    }

    // MARK: - Ruta del courier

    private var courierMarker: some View {
        ZStack {
            Circle()
                .fill(.blue)
                .frame(width: 38, height: 38)

            Image(systemName: "motorcycle")
                .foregroundStyle(.black)
                .font(.system(size: 19))
        }
        .overlay {
            Circle()
                .stroke(.white, lineWidth: 3)
        }
    }

    // MARK: - Ruta

    private var routeAnnotation: some MapContent {
        PolylineAnnotationGroup {
            PolylineAnnotation(
                id: "remaining-route",
                lineCoordinates:
                    viewModel.remainingRouteCoordinates
            )
            .lineColor("#1677FF")
            .lineWidth(7)
        }
        .lineCap(.round)
    }

    private var closedRoadAnnotation: some MapContent {
        PolylineAnnotationGroup {
            PolylineAnnotation(
                id: "closed-road",
                lineCoordinates:
                    viewModel.closedRoadCoordinates
            )
            .lineColor("#FF3B30")
            .lineWidth(10)
        }
        .lineCap(.round)
    }

    // MARK: - Pickup

    private var pickupAnnotation: some MapContent {
        MapViewAnnotation(
            coordinate: viewModel.pickupCoordinate
        ) {
            VStack(spacing: 3) {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.white)
                    .padding(9)
                    .background(
                        .green,
                        in: Circle()
                    )

                Text("Pickup")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        .ultraThinMaterial,
                        in: Capsule()
                    )
            }
        }
        .allowOverlap(true)
    }

    // MARK: - Entrega

    private var dropoffAnnotation: some MapContent {
        MapViewAnnotation(
            coordinate: viewModel.dropoffCoordinate
        ) {
            VStack(spacing: 3) {
                Image(systemName: "house.fill")
                    .foregroundStyle(.white)
                    .padding(9)
                    .background(
                        .red,
                        in: Circle()
                    )

                Text("Entrega")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        .ultraThinMaterial,
                        in: Capsule()
                    )
            }
        }
        .allowOverlap(true)
    }

    // MARK: - Panel superior

    private var topPanel: some View {
        VStack(spacing: 8) {
            DashboardView(
                netEarnings:
                    viewModel.netEarnings,
                remainingMinutes:
                    viewModel.remainingMinutes,
                completedDeliveries:
                    viewModel.completedDeliveries
            )

            Text(viewModel.lastEventText)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    .ultraThinMaterial,
                    in: Capsule()
                )

            if let courierId = viewModel.courierId,
               let courierStatus = viewModel.courierStatus {

                Label(
                    "\(courierId) · \(courierStatus)",
                    systemImage:
                        viewModel.isControlledByAgent
                        ? "cpu.fill"
                        : "person.fill"
                )
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    .ultraThinMaterial,
                    in: Capsule()
                )
            }

            Label(
                viewModel.streamStatusText,
                systemImage:
                    viewModel.hasSequenceGap
                    ? "exclamationmark.triangle.fill"
                    : "checkmark.shield.fill"
            )
            .font(.caption.bold())
            .foregroundStyle(
                viewModel.hasSequenceGap
                ? Color.orange
                : Color.green
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                .ultraThinMaterial,
                in: Capsule()
            )

            if let arrivalMessage =
                viewModel.arrivalMessage {

                Label(
                    arrivalMessage,
                    systemImage:
                        viewModel.hasActiveOrder
                        ? "antenna.radiowaves.left.and.right"
                        : "checkmark.circle.fill"
                )
                .font(.subheadline.bold())
                .foregroundStyle(
                    viewModel.hasActiveOrder
                    ? Color.orange
                    : Color.green
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    .regularMaterial,
                    in: Capsule()
                )
            }
            
            if viewModel.isRaining ||
                viewModel.surgeMultiplier != nil ||
                !viewModel.closedRoadCoordinates.isEmpty {

                EnvironmentStatusView(
                    isRaining: viewModel.isRaining,
                    surgeMultiplier: viewModel.surgeMultiplier,
                    hasClosedRoad:
                        !viewModel.closedRoadCoordinates.isEmpty
                )
            }

            if !viewModel.isReceivingDev2State {
                SimulationControlsView(
                    isPaused: viewModel.isPaused,
                    speed: viewModel.playbackSpeed,
                    onTogglePause:
                        viewModel.togglePause,
                    onSelectSpeed:
                        viewModel.setPlaybackSpeed
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    // MARK: - Seguimiento de cámara

    private var cameraFollowButton: some View {
        HStack {
            Spacer()

            Button {
                followsCourier.toggle()

                if followsCourier,
                   let coordinate =
                    viewModel.courierCoordinate {

                    viewport = .camera(
                        center: coordinate,
                        zoom: 16.5,
                        bearing:
                            viewModel.courierBearing,
                        pitch: 50
                    )
                }
            } label: {
                Image(
                    systemName:
                        followsCourier
                        ? "location.fill"
                        : "location"
                )
                .font(.title3.bold())
                .foregroundStyle(
                    followsCourier
                    ? Color.white
                    : Color.blue
                )
                .frame(width: 48, height: 48)
                .background(
                    followsCourier
                    ? Color.blue
                    : Color.white,
                    in: Circle()
                )
                .shadow(radius: 6)
            }
        }
        .frame(
            maxHeight: .infinity,
            alignment: .center
        )
        .padding(.trailing, 16)
    }

    // MARK: - Asistente de voz

    private var voiceControls: some View {
        VoiceAgentButton(
            manager: voiceAgentManager,
            onToggleConversation: {
                Task {
                    await voiceAgentManager
                        .toggleConversation(
                            courierViewModel: viewModel
                        )
                }
            },
            onToggleMute: {
                Task {
                    await voiceAgentManager.toggleMute()
                }
            }
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .bottomTrailing
        )
        .padding(.trailing, 16)
        .padding(
            .bottom,
            viewModel.hasActiveOrder ? 210 : 24
        )
    }

    // MARK: - Pedido activo

    @ViewBuilder
    private var bottomOrderCard: some View {
        if viewModel.isReceivingDev2State,
           let destinationId =
            viewModel.currentDestinationId,
           let destinationType =
            viewModel.currentDestinationType,
           let coordinate =
            viewModel.currentDestinationCoordinate {

            CurrentDestinationCard(
                destinationId: destinationId,
                destinationType: destinationType,
                coordinate: coordinate
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottom
            )
        } else {
            ActiveOrderCard(
                orderId: viewModel.activeOrderId,
                pickupName: viewModel.pickupName,
                dropoffName: viewModel.dropoffName,
                payoutMXN: viewModel.orderPayout
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottom
            )
        }
    }

    // MARK: - Oferta y decisión

    @ViewBuilder
    private var offerOverlay: some View {
        if let orderId =
            viewModel.offeredOrderId {

            OfferDecisionCard(
                orderId: orderId,
                payoutMXN:
                    viewModel.offerPayout,
                pickupName:
                    viewModel.offerPickupName,
                dropoffName:
                    viewModel.offerDropoffName,
                decision:
                    viewModel.agentDecision,
                explanation:
                    viewModel.agentExplanation,
                confidence:
                    viewModel.agentConfidence,
                onDismiss:
                    viewModel.dismissOffer
            )
            .padding(.horizontal, 24)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .center
            )
        }
    }
}

#Preview {
    ContentView()
}
