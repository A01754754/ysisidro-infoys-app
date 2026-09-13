import Foundation
import Combine
import CoreLocation

@MainActor
final class CourierViewModel: ObservableObject {
    @Published private(set) var lastEventText =
        "Preparando simulación…"

    @Published private(set) var courierCoordinate:
        CLLocationCoordinate2D?

    @Published private(set) var courierId: String?
    @Published private(set) var isControlledByAgent = false
    @Published private(set) var courierStatus: String?
    @Published private(set) var isReceivingDev2State = false
    @Published private(set) var activeOrderCount = 0
    @Published private(set) var acceptedTripAnnouncement:
        AcceptedTripAnnouncement?

    @Published private(set) var currentDestinationId: String?
    @Published private(set) var currentDestinationType: String?
    @Published private(set) var currentDestinationCoordinate:
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
    private let courierStateTransport:
        any CourierStateTransport
    private let dev4GatewayClient: any Dev4GatewayClient

    private var activeRunId: String?
    private var lastProcessedSequence = 0
    private var processedEventIds: Set<String> = []
    private var sentArrivalActionIds: Set<String> = []
    private var dev2OrdersById: [String: Dev2Order] = [:]
    private var announcedOrderIds: Set<String> = []
    private var didEnsureSimulationRunning = false
    private var lastAgentError: String?
    private var agentPending = false

    init(
        transport: (any EventTransport)? = nil,
        courierStateTransport:
            (any CourierStateTransport)? = nil,
        dev4GatewayClient: (any Dev4GatewayClient)? = nil
    ) {
        self.transport = transport ?? MockTransport()
        self.courierStateTransport =
            courierStateTransport
            ?? Self.makeDefaultCourierStateTransport()
        self.dev4GatewayClient =
            dev4GatewayClient ?? MockDev4GatewayClient()
    }

    private static func makeDefaultCourierStateTransport()
        -> any CourierStateTransport {
        if let baseURL = AppConfiguration.dev2BaseURL {
            return Dev2SSECourierStateTransport(
                baseURL: baseURL
            )
        }

        return BundledCourierStateTransport()
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

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
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

    func makeVoiceState() -> CourierVoiceState {
        CourierVoiceState(
            lastEvent: lastEventText,
            streamStatus: streamStatusText,
            isPaused: isPaused,
            playbackSpeed: playbackSpeed,
            courierLatitude: courierCoordinate?.latitude,
            courierLongitude: courierCoordinate?.longitude,
            courierId: courierId,
            controlledByAgent: isControlledByAgent,
            courierStatus: courierStatus,
            activeRouteId: activeRouteId,
            currentDestinationId: currentDestinationId,
            currentDestinationType: currentDestinationType,
            currentDestinationLatitude:
                currentDestinationCoordinate?.latitude,
            currentDestinationLongitude:
                currentDestinationCoordinate?.longitude,
            activeOrderId:
                hasActiveOrder ? activeOrderId : nil,
            pickupName:
                hasActiveOrder
                ? pickupName
                : nil,
            dropoffName:
                hasActiveOrder
                ? dropoffName
                : nil,
            orderPayoutMxn:
                hasActiveOrder
                ? orderPayout
                : nil,
            offeredOrderId: offeredOrderId,
            agentDecision: agentDecision,
            agentExplanation: agentExplanation,
            agentConfidence: agentConfidence,
            netEarningsMxn: netEarnings,
            remainingMinutes: remainingMinutes,
            completedDeliveries: completedDeliveries,
            isRaining: isRaining,
            surgeMultiplier: surgeMultiplier,
            closedRoadId: closedRoadId,
            arrivalMessage: arrivalMessage
        )
    }

    func startReceivingCourierState() async {
        isReceivingDev2State = true
        hasActiveOrder = false
        activeRouteId = nil
        routeCoordinates = []
        remainingRouteCoordinates = []
        streamStatusText = "Conectando con DEV2…"

        do {
            for try await message
                in courierStateTransport.eventStream() {
                try await waitWhilePaused()
                try Task.checkCancellation()
                try await process(message)
            }
        } catch is CancellationError {
            // La vista fue cerrada.
        } catch {
            lastEventText =
                "Error DEV2: \(error.localizedDescription)"
            streamStatusText = "DEV2 desconectado"
        }
    }

    private func process(_ message: Dev2StreamMessage) async throws {
        switch message {
        case .connected:
            streamStatusText = "Conectado con DEV2"
            await ensureSimulationRunning()

        case let .reconnecting(error):
            streamStatusText = "Reconectando con DEV2…"
            lastEventText = "Conexión DEV2 interrumpida: \(error)"

        case let .snapshot(snapshot):
            try await apply(snapshot)

        case let .courierPositions(couriers, simulatedTime):
            if let courier = couriers.first(where: \.controlledByAgent) {
                try await apply(courier, simulatedTime: simulatedTime)
            }

        case let .agentDecisionApplied(decision):
            lastAgentError = nil
            agentPending = false
            apply(decision)
            if let snapshot = try? await courierStateTransport.fetchSnapshot() {
                try await apply(snapshot)
            }

        case let .agentDecisionFailed(error):
            lastAgentError = error
            agentPending = false
            lastEventText = "La decisión del agente falló: \(error)"

        case let .agentWaiting(reason):
            agentPending = true
            lastEventText = "El courier espera al agente: \(reason)"

        case .refreshSnapshot:
            if let snapshot = try? await courierStateTransport.fetchSnapshot() {
                try await apply(snapshot)
            }
        }
    }

    private func ensureSimulationRunning() async {
        guard !didEnsureSimulationRunning else { return }

        do {
            let snapshot = try await courierStateTransport.fetchSnapshot()
            if snapshot.isRunning {
                didEnsureSimulationRunning = true
                try await apply(snapshot)
                return
            }

            try await courierStateTransport.startSimulation()
            didEnsureSimulationRunning = true
            lastEventText = "Simulación iniciada"
            if let started = try? await courierStateTransport.fetchSnapshot() {
                try await apply(started)
            }
        } catch {
            lastEventText =
                "No se pudo iniciar la simulación: \(error.localizedDescription)"
        }
    }

    private func apply(_ snapshot: Dev2SimulationSnapshot) async throws {
        if !snapshot.isRunning, snapshot.orders.isEmpty {
            announcedOrderIds.removeAll()
            acceptedTripAnnouncement = nil
        }

        dev2OrdersById = Dictionary(
            uniqueKeysWithValues: snapshot.orders.map { ($0.orderId, $0) }
        )
        completedDeliveries = snapshot.orders.filter {
            ["delivered", "completed", "entregado"].contains($0.status.lowercased())
        }.count
        let weatherType = snapshot.weather?.type.lowercased() ?? ""
        isRaining = ["rain", "rainy", "storm", "lluvia", "tormenta"]
            .contains(weatherType)
        surgeMultiplier = snapshot.weather?.newOrderPaymentMultiplier
        lastAgentError = snapshot.agent?.lastError
        agentPending = snapshot.agent?.pending ?? false

        guard let courier = snapshot.controlledCourier else {
            lastEventText = "DEV2 no envió un courier controlado por el agente."
            return
        }

        try await apply(courier, simulatedTime: snapshot.simulatedTime)
    }

    private func apply(
        _ state: Dev2CourierState,
        simulatedTime: String?
    ) async throws {
        courierId = state.courierId
        isControlledByAgent = state.controlledByAgent
        courierStatus = state.courierStatus
        activeOrderCount = state.activeOrderCount
        netEarnings = state.accumulatedEarningsMXN

        let receivedRoute = state.currentRoute.map(
            \.coordinate
        )

        if let destination = state.currentDestination {
            currentDestinationId = destination.id
            currentDestinationType = destination.type
            currentDestinationCoordinate =
                destination.coordinate

            activeOrderId = destination.orderId ?? destination.id
            hasActiveOrder = true

            if let order = dev2OrdersById[activeOrderId] {
                orderPayout = order.paymentMXN
                pickupName = order.restaurant?.name
                    ?? order.restaurant?.zone
                    ?? "Pickup"
                dropoffName = order.delivery?.name
                    ?? order.delivery?.zone
                    ?? "Entrega"
            }

            switch destination.type.lowercased() {
            case "pick", "pickup":
                pickupLocation = destination.coordinate
                dropoffLocation = nil
            case "drop", "dropoff", "delivery":
                pickupLocation = nil
                dropoffLocation = destination.coordinate
            default:
                pickupLocation = nil
                dropoffLocation = destination.coordinate
            }
        } else {
            currentDestinationId = nil
            currentDestinationType = nil
            currentDestinationCoordinate = nil
            hasActiveOrder = false
            pickupLocation = nil
            dropoffLocation = nil
        }

        try await animateDev2Position(
            to: state.position.coordinate,
            receivedRoute: receivedRoute
        )

        routeCoordinates = receivedRoute
        remainingRouteCoordinates = receivedRoute.isEmpty
            ? []
            : [state.position.coordinate] + Array(receivedRoute.dropFirst())
        routeProgressIndex = 0

        await notifyArrivalIfNeeded(
            at: state.position.coordinate
        )

        let timeSuffix = simulatedTime.flatMap { $0.isEmpty ? nil : " · \($0)" } ?? ""
        let isIdle = state.courierStatus == "wait"

        if isIdle, let error = lastAgentError {
            lastEventText = "Agente sin ruta: \(error)"
        } else if isIdle, agentPending {
            lastEventText = "Esperando decisión del agente\(timeSuffix)"
        } else {
            lastEventText = "Estado DEV2: \(state.courierStatus)\(timeSuffix)"
        }
        streamStatusText = "Conectado con DEV2"
    }

    private func apply(_ decision: Dev2AgentDecisionApplied) {
        let newOrderIds = decision.acceptedOrderIds.filter {
            !announcedOrderIds.contains($0)
        }
        guard !newOrderIds.isEmpty else { return }

        announcedOrderIds.formUnion(newOrderIds)
        let description = decision.description?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let usableDescription = description.flatMap { $0.isEmpty ? nil : $0 }
            ?? makeFallbackDescription(for: newOrderIds)
        let id = newOrderIds.sorted().joined(separator: ",")

        acceptedTripAnnouncement = AcceptedTripAnnouncement(
            id: id,
            orderIds: newOrderIds,
            description: usableDescription,
            orderedStops: decision.orderedStops,
            directions: decision.directions
        )
        lastEventText = "Viaje aceptado automáticamente: \(newOrderIds.joined(separator: ", "))"
    }

    private func makeFallbackDescription(for orderIds: [String]) -> String {
        let summaries = orderIds.map { orderId -> String in
            guard let order = dev2OrdersById[orderId] else { return orderId }
            let origin = order.restaurant?.name ?? order.restaurant?.zone ?? "el restaurante"
            let destination = order.delivery?.zone ?? order.delivery?.name ?? "la entrega"
            return "\(orderId), por $\(Int(order.paymentMXN)) MXN, de \(origin) hacia \(destination)"
        }

        return "El agente aceptó \(summaries.joined(separator: "; ")) y lo incorporó a la ruta optimizada. DEV2 todavía no envió una descripción explícita, así que este resumen se generó con los datos del pedido."
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

    private func animateDev2Position(
        to destination: CLLocationCoordinate2D,
        receivedRoute: [CLLocationCoordinate2D]
    ) async throws {
        guard let origin = courierCoordinate else {
            courierCoordinate = destination
            return
        }

        guard distance(from: origin, to: destination) > 0.25 else {
            courierCoordinate = destination
            return
        }

        let referenceRoute = routeCoordinates.count >= 2
            ? routeCoordinates
            : receivedRoute
        let path = movementPath(
            from: origin,
            to: destination,
            following: referenceRoute
        )
        let steps = 57
        var previous = origin

        for step in 1...steps {
            try await waitWhilePaused()
            try Task.checkCancellation()

            let linearProgress = Double(step) / Double(steps)
            let easedProgress = linearProgress * linearProgress
                * (3 - 2 * linearProgress)
            let position = coordinate(
                along: path,
                at: easedProgress
            )

            courierBearing = calculateBearing(from: previous, to: position.coordinate)
            courierCoordinate = position.coordinate
            remainingRouteCoordinates = [position.coordinate]
                + Array(path.dropFirst(position.nextIndex))
            previous = position.coordinate

            let milliseconds = max(1, Int(16 / playbackSpeed))
            try await Task.sleep(for: .milliseconds(milliseconds))
        }

        courierCoordinate = destination
    }

    private func movementPath(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        following route: [CLLocationCoordinate2D]
    ) -> [CLLocationCoordinate2D] {
        guard route.count >= 2,
              let originIndex = nearestIndex(to: origin, in: route),
              let destinationIndex = nearestIndex(to: destination, in: route),
              destinationIndex >= originIndex else {
            return [origin, destination]
        }

        var path = [origin]
        if destinationIndex > originIndex {
            path.append(contentsOf: route[(originIndex + 1)...destinationIndex])
        }
        path.append(destination)
        return removingAdjacentDuplicates(from: path)
    }

    private func coordinate(
        along path: [CLLocationCoordinate2D],
        at fraction: Double
    ) -> (coordinate: CLLocationCoordinate2D, nextIndex: Int) {
        guard path.count >= 2 else {
            return (path.first ?? CLLocationCoordinate2D(), 0)
        }

        let lengths = zip(path, path.dropFirst()).map {
            distance(from: $0.0, to: $0.1)
        }
        let totalLength = lengths.reduce(0, +)
        guard totalLength > 0 else { return (path.last!, path.count) }

        var remainingDistance = min(max(fraction, 0), 1) * totalLength
        for index in lengths.indices {
            let segmentLength = lengths[index]
            if remainingDistance <= segmentLength || index == lengths.count - 1 {
                let progress = segmentLength > 0
                    ? min(remainingDistance / segmentLength, 1)
                    : 1
                let start = path[index]
                let end = path[index + 1]
                return (
                    CLLocationCoordinate2D(
                        latitude: start.latitude + (end.latitude - start.latitude) * progress,
                        longitude: start.longitude + (end.longitude - start.longitude) * progress
                    ),
                    index + 1
                )
            }
            remainingDistance -= segmentLength
        }

        return (path.last!, path.count)
    }

    private func nearestIndex(
        to coordinate: CLLocationCoordinate2D,
        in coordinates: [CLLocationCoordinate2D]
    ) -> Int? {
        coordinates.indices.min {
            distance(from: coordinates[$0], to: coordinate)
                < distance(from: coordinates[$1], to: coordinate)
        }
    }

    private func removingAdjacentDuplicates(
        from coordinates: [CLLocationCoordinate2D]
    ) -> [CLLocationCoordinate2D] {
        coordinates.reduce(into: []) { result, coordinate in
            if let last = result.last,
               distance(from: last, to: coordinate) <= 0.25 {
                return
            }
            result.append(coordinate)
        }
    }

    private func distance(
        from first: CLLocationCoordinate2D,
        to second: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        CLLocation(latitude: first.latitude, longitude: first.longitude)
            .distance(from: CLLocation(latitude: second.latitude, longitude: second.longitude))
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
