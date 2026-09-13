import Foundation
import Combine
import CoreLocation

@MainActor
final class CourierViewModel: ObservableObject {
    @Published private(set) var lastEventText =
        "Preparando simulación…"

    @Published private(set) var courierCoordinate:
        CLLocationCoordinate2D?

    @Published private(set) var isPaused = false
    @Published private(set) var playbackSpeed = 1.0

    @Published private(set) var netEarnings = 125.0
    @Published private(set) var remainingMinutes = 45
    @Published private(set) var completedDeliveries = 2

    @Published private(set) var activeOrderId = "order-38"
    @Published private(set) var hasActiveOrder = true
    @Published private(set) var pickupName =
        "Centro de Monterrey"
    @Published private(set) var dropoffName = "San Pedro"
    @Published private(set) var orderPayout = 89.0
    
    @Published private(set) var offeredOrderId: String?
    @Published private(set) var offerPayout = 0.0
    @Published private(set) var offerPickupName = ""
    @Published private(set) var offerDropoffName = ""

    @Published private(set) var agentDecision: String?
    @Published private(set) var agentExplanation: String?
    @Published private(set) var agentConfidence: Double?
    
    @Published private(set) var isRaining = false
    @Published private(set) var surgeMultiplier: Double?
    
    @Published private(set) var closedRoadId: String?

    @Published private(set) var closedRoadCoordinates:
        [CLLocationCoordinate2D] = []

    @Published private(set) var arrivalMessage: String?

    @Published private(set) var streamStatusText =
        "Esperando eventos"

    @Published private(set) var hasSequenceGap = false

    @Published private(set) var activeRouteId: String?

    @Published private(set) var routeCoordinates:
        [CLLocationCoordinate2D] = []

    @Published private(set) var remainingRouteCoordinates:
        [CLLocationCoordinate2D] = []

    @Published private(set) var courierBearing:
        CLLocationDirection = 0

    private var routeProgressIndex = 0

    @Published private(set) var pickupLocation:
        CLLocationCoordinate2D?

    @Published private(set) var dropoffLocation:
        CLLocationCoordinate2D?

    private let transport: any EventTransport
    private let dev4GatewayClient: any Dev4GatewayClient

    private var activeRunId: String?
    private var lastProcessedSequence = 0
    private var processedEventIds: Set<String> = []
    private var sentArrivalActionIds: Set<String> = []

    init(
        transport: any EventTransport = MockTransport(),
        dev4GatewayClient: any Dev4GatewayClient =
            MockDev4GatewayClient()
    ) {
        self.transport = transport
        self.dev4GatewayClient = dev4GatewayClient
    }

    var hasRoute: Bool {
        routeCoordinates.count >= 2
    }

    var pickupCoordinate: CLLocationCoordinate2D {
        pickupLocation
        ?? routeCoordinates.first
        ?? CLLocationCoordinate2D(
            latitude: 25.6866,
            longitude: -100.3161
        )
    }

    var dropoffCoordinate: CLLocationCoordinate2D {
        dropoffLocation
        ?? routeCoordinates.last
        ?? CLLocationCoordinate2D(
            latitude: 25.6866,
            longitude: -100.3161
        )
    }

    func togglePause() {
        isPaused.toggle()
    }

    func setPlaybackSpeed(_ speed: Double) {
        guard [1.0, 5.0, 20.0].contains(speed) else {
            return
        }

        playbackSpeed = speed
    }

    func dismissOffer() {
        offeredOrderId = nil
        agentDecision = nil
        agentExplanation = nil
        agentConfidence = nil
    }
    
    func startSimulation() async {
        do {
            for try await event
                in transport.eventStream() {

                try await waitWhilePaused()
                try Task.checkCancellation()

                guard shouldProcess(event) else {
                    continue
                }

                lastEventText =
                    "Evento \(event.sequence): \(event.type)"

                try await process(event)

                print(lastEventText)

                if transport.shouldSimulateDelay {
                    try await sleepForCurrentSpeed(
                        baseSeconds: 3
                    )
                }
            }

            lastEventText = "Simulación finalizada"
        } catch is CancellationError {
            // La vista fue cerrada.
        } catch {
            lastEventText =
                "Error: \(error.localizedDescription)"
        }
    }

    private func process(
        _ event: EventMetadata
    ) async throws {
        switch event.type {
        case "NEW_TRIP", "ROUTE_UPDATED":
            activeRouteId = event.payload.routeId

            let receivedRoute =
                (event.payload.coordinates ?? []).map {
                    CLLocationCoordinate2D(
                        latitude: $0.latitude,
                        longitude: $0.longitude
                    )
                }

            routeCoordinates = receivedRoute
            remainingRouteCoordinates = receivedRoute
            routeProgressIndex = 0

            if let pickup = event.payload.pickupCoordinate {
                pickupLocation = CLLocationCoordinate2D(
                    latitude: pickup.latitude,
                    longitude: pickup.longitude
                )
            } else if pickupLocation == nil {
                pickupLocation = receivedRoute.first
            }

            if let dropoff = event.payload.dropoffCoordinate {
                dropoffLocation = CLLocationCoordinate2D(
                    latitude: dropoff.latitude,
                    longitude: dropoff.longitude
                )
            } else if dropoffLocation == nil {
                dropoffLocation = receivedRoute.last
            }

            if let orderId = event.payload.orderId {
                activeOrderId = orderId
                hasActiveOrder = true
            }

            if let payout = event.payload.payoutMxn {
                orderPayout = payout
            }

            if let pickupName =
                event.payload.pickupName {

                self.pickupName = pickupName
            }

            if let dropoffName =
                event.payload.dropoffName {

                self.dropoffName = dropoffName
            }

        case "COURIER_MOVED":
            guard let latitude = event.payload.latitude,
                  let longitude = event.payload.longitude else {
                return
            }

            let destination = CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude
            )

            try await moveCourierSmoothly(
                to: destination
            )

            await notifyArrivalIfNeeded(
                at: destination
            )
        
        case "CLOSE_ROAD":
            closedRoadId = event.payload.roadId

            closedRoadCoordinates =
                (event.payload.coordinates ?? []).map {
                    CLLocationCoordinate2D(
                        latitude: $0.latitude,
                        longitude: $0.longitude
                    )
                }

        case "OPEN_ROAD":
            if event.payload.roadId == nil ||
                event.payload.roadId == closedRoadId {

                closedRoadId = nil
                closedRoadCoordinates = []
            }
            
        case "START_RAIN":
            isRaining = true

        case "STOP_RAIN":
            isRaining = false

        case "START_SURGE":
            surgeMultiplier =
                event.payload.surgeMultiplier ?? 1.0

        case "STOP_SURGE":
            surgeMultiplier = nil

        case "ORDER_OFFERED":
            offeredOrderId = event.payload.orderId
            offerPayout = event.payload.payoutMxn ?? 0
            offerPickupName =
                event.payload.pickupName ?? "Pickup"
            offerDropoffName =
                event.payload.dropoffName ?? "Entrega"

            agentDecision = nil
            agentExplanation = nil
            agentConfidence = nil

        case "AGENT_DECIDED":
            agentDecision = event.payload.decision
            agentExplanation = event.payload.explanation
            agentConfidence = event.payload.confidence

        case "ORDER_COMPLETED":
            guard event.payload.orderId ==
                    activeOrderId else {
                return
            }

            hasActiveOrder = false

            arrivalMessage =
                "DEV4 confirmó la entrega"

            activeRouteId = nil
            routeCoordinates = []
            remainingRouteCoordinates = []
            pickupLocation = nil
            dropoffLocation = nil

        default:
            break
        }
    }

    private func shouldProcess(
        _ event: EventMetadata
    ) -> Bool {
        if activeRunId == nil {
            activeRunId = event.runId
        } else if event.runId != activeRunId {
            guard event.type == "RUN_STARTED" else {
                streamStatusText =
                    "Evento de otra simulación ignorado"

                print(
                    "⚠️ Se ignoró \(event.eventId): "
                    + "run_id diferente"
                )

                return false
            }

            activeRunId = event.runId
            lastProcessedSequence = 0
            processedEventIds.removeAll()
            hasSequenceGap = false
        }

        if processedEventIds.contains(event.eventId) {
            streamStatusText =
                "Evento duplicado ignorado"

            print(
                "⚠️ Evento duplicado ignorado: "
                + event.eventId
            )

            return false
        }

        if event.sequence <= lastProcessedSequence {
            streamStatusText =
                "Evento atrasado ignorado"

            print(
                "⚠️ Secuencia atrasada ignorada: "
                + "\(event.sequence)"
            )

            return false
        }

        let expectedSequence =
            lastProcessedSequence + 1

        if lastProcessedSequence > 0,
           event.sequence != expectedSequence {

            hasSequenceGap = true

            streamStatusText =
                "Falta la secuencia \(expectedSequence)"

            print(
                "⚠️ Se esperaba la secuencia "
                + "\(expectedSequence), "
                + "pero llegó \(event.sequence)"
            )

            return false
        }

        processedEventIds.insert(event.eventId)
        lastProcessedSequence = event.sequence

        hasSequenceGap = false
        streamStatusText =
            "Sincronizado · secuencia \(event.sequence)"

        return true
    }

    private func waitWhilePaused() async throws {
        while isPaused {
            try Task.checkCancellation()

            try await Task.sleep(
                for: .milliseconds(100)
            )
        }
    }

    private func sleepForCurrentSpeed(
        baseSeconds: Double
    ) async throws {
        let adjustedSeconds =
            baseSeconds / playbackSpeed

        try await Task.sleep(
            for: .seconds(adjustedSeconds)
        )
    }

    private func moveCourierSmoothly(
        to destination: CLLocationCoordinate2D
    ) async throws {
        guard let origin = courierCoordinate else {
            courierCoordinate = destination

            let index =
                nearestRouteIndex(to: destination) ?? 0

            routeProgressIndex = index

            updateRemainingRoute(
                from: destination,
                destinationIndex: index
            )

            return
        }

        courierBearing = calculateBearing(
            from: origin,
            to: destination
        )

        let nearestIndex =
            nearestRouteIndex(to: destination)
            ?? routeProgressIndex

        let destinationIndex =
            max(routeProgressIndex, nearestIndex)

        let steps = 30

        for step in 1...steps {
            try await waitWhilePaused()
            try Task.checkCancellation()

            let progress =
                Double(step) / Double(steps)

            let latitude =
                origin.latitude
                + (destination.latitude - origin.latitude)
                * progress

            let longitude =
                origin.longitude
                + (destination.longitude - origin.longitude)
                * progress

            let currentCoordinate =
                CLLocationCoordinate2D(
                    latitude: latitude,
                    longitude: longitude
                )

            courierCoordinate = currentCoordinate

            updateRemainingRoute(
                from: currentCoordinate,
                destinationIndex: destinationIndex
            )

            let milliseconds =
                max(1, Int(25 / playbackSpeed))

            try await Task.sleep(
                for: .milliseconds(milliseconds)
            )
        }

        routeProgressIndex = destinationIndex

        if destinationIndex ==
            routeCoordinates.count - 1 {

            remainingRouteCoordinates = [destination]
        }
    }

    private func updateRemainingRoute(
        from currentCoordinate: CLLocationCoordinate2D,
        destinationIndex: Int
    ) {
        guard !routeCoordinates.isEmpty else {
            remainingRouteCoordinates = []
            return
        }

        let safeIndex = min(
            max(destinationIndex, 0),
            routeCoordinates.count - 1
        )

        let futureCoordinates = Array(
            routeCoordinates.dropFirst(safeIndex)
        )

        remainingRouteCoordinates =
            [currentCoordinate] + futureCoordinates
    }

    private func nearestRouteIndex(
        to coordinate: CLLocationCoordinate2D
    ) -> Int? {
        routeCoordinates.indices.min {
            firstIndex,
            secondIndex in

            squaredDistance(
                from: routeCoordinates[firstIndex],
                to: coordinate
            )
            <
            squaredDistance(
                from: routeCoordinates[secondIndex],
                to: coordinate
            )
        }
    }

    private func squaredDistance(
        from first: CLLocationCoordinate2D,
        to second: CLLocationCoordinate2D
    ) -> Double {
        let latitudeDifference =
            first.latitude - second.latitude

        let longitudeDifference =
            first.longitude - second.longitude

        return latitudeDifference * latitudeDifference
            + longitudeDifference * longitudeDifference
    }

    private func notifyArrivalIfNeeded(
        at coordinate: CLLocationCoordinate2D
    ) async {
        guard let dropoffLocation else {
            return
        }

        let courierLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        let destinationLocation = CLLocation(
            latitude: dropoffLocation.latitude,
            longitude: dropoffLocation.longitude
        )

        let distanceInMeters =
            courierLocation.distance(
                from: destinationLocation
            )

        guard distanceInMeters <= 20 else {
            return
        }

        let actionId =
            "arrival-\(activeOrderId)-dropoff"

        guard !sentArrivalActionIds.contains(
            actionId
        ) else {
            return
        }

        sentArrivalActionIds.insert(actionId)

        arrivalMessage =
            "Avisando llegada a DEV4…"

        let command = CourierArrivalCommand(
            actionId: actionId,
            orderId: activeOrderId,
            routeId: activeRouteId,
            basedOnSequence: lastProcessedSequence,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        do {
            try await dev4GatewayClient.sendArrival(
                command
            )

            arrivalMessage =
                "Llegada enviada a DEV4"
        } catch {
            sentArrivalActionIds.remove(actionId)

            arrivalMessage =
                "No se pudo avisar a DEV4: \(error.localizedDescription)"
        }
    }

    private func calculateBearing(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> CLLocationDirection {
        let originLatitude =
            origin.latitude * .pi / 180

        let destinationLatitude =
            destination.latitude * .pi / 180

        let longitudeDifference =
            (destination.longitude - origin.longitude)
            * .pi / 180

        let y =
            sin(longitudeDifference)
            * cos(destinationLatitude)

        let x =
            cos(originLatitude)
            * sin(destinationLatitude)
            - sin(originLatitude)
            * cos(destinationLatitude)
            * cos(longitudeDifference)

        let degrees =
            atan2(y, x) * 180 / .pi

        return (degrees + 360)
            .truncatingRemainder(dividingBy: 360)
    }
}
