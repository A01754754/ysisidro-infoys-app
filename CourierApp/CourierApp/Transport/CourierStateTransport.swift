import Foundation

protocol CourierStateTransport: Sendable {
    func eventStream() -> AsyncThrowingStream<Dev2StreamMessage, Error>
    func fetchSnapshot() async throws -> Dev2SimulationSnapshot
}

enum CourierStateTransportError: LocalizedError {
    case demoFileNotFound
    case invalidHTTPResponse
    case httpStatus(Int)
    case eventStreamEnded

    var errorDescription: String? {
        switch self {
        case .demoFileNotFound:
            return "No se encontró dev2-courier-state.json en la aplicación."
        case .invalidHTTPResponse:
            return "DEV2 devolvió una respuesta HTTP inválida."
        case let .httpStatus(statusCode):
            return "DEV2 devolvió el código HTTP \(statusCode)."
        case .eventStreamEnded:
            return "La conexión de eventos de DEV2 terminó."
        }
    }
}

struct BundledCourierStateTransport: CourierStateTransport {
    func fetchSnapshot() async throws -> Dev2SimulationSnapshot {
        guard let url = Bundle.main.url(
            forResource: "dev2-courier-state",
            withExtension: "json"
        ) else {
            throw CourierStateTransportError.demoFileNotFound
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Dev2SimulationSnapshot.self, from: data)
    }

    func eventStream() -> AsyncThrowingStream<Dev2StreamMessage, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(16)) { continuation in
            let task = Task {
                do {
                    continuation.yield(.connected)
                    continuation.yield(.snapshot(try await fetchSnapshot()))
                    try await Task.sleep(for: .milliseconds(500))
                    continuation.yield(
                        .agentDecisionApplied(
                            Dev2AgentDecisionApplied(
                                reason: "new_order",
                                acceptedOrderIds: ["order-12"],
                                orderedStops: ["pick-order-12", "drop-order-12"],
                                directions: [
                                    "Continúa por la ruta marcada hasta el pickup.",
                                    "Después dirígete a la entrega de order-12."
                                ],
                                description: "Acepté el pedido order-12 porque agrega una buena ganancia y sus paradas encajan con la ruta actual."
                            )
                        )
                    )
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

struct Dev2SSECourierStateTransport: CourierStateTransport {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchSnapshot() async throws -> Dev2SimulationSnapshot {
        let endpoint = baseURL.appendingPathComponent("simulation/state")
        let (data, response) = try await session.data(from: endpoint)
        try validate(response)
        return try JSONDecoder().decode(Dev2SimulationSnapshot.self, from: data)
    }

    func eventStream() -> AsyncThrowingStream<Dev2StreamMessage, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(16)) { continuation in
            let task = Task {
                var retryDelay = 1.0

                while !Task.isCancelled {
                    do {
                        var request = URLRequest(url: baseURL.appendingPathComponent("events"))
                        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                        request.timeoutInterval = 60

                        let (bytes, response) = try await session.bytes(for: request)
                        try validate(response)
                        continuation.yield(.connected)
                        retryDelay = 1

                        var eventName = "message"
                        var dataLines: [String] = []

                        for try await line in bytes.lines {
                            try Task.checkCancellation()

                            if line.isEmpty {
                                if let message = try decodeEvent(
                                    name: eventName,
                                    data: dataLines.joined(separator: "\n")
                                ) {
                                    continuation.yield(message)
                                }
                                eventName = "message"
                                dataLines.removeAll(keepingCapacity: true)
                            } else if line.hasPrefix("event:") {
                                eventName = fieldValue(line, prefix: "event:")
                            } else if line.hasPrefix("data:") {
                                dataLines.append(fieldValue(line, prefix: "data:"))
                            }
                        }

                        if let message = try decodeEvent(
                            name: eventName,
                            data: dataLines.joined(separator: "\n")
                        ) {
                            continuation.yield(message)
                        }
                        throw CourierStateTransportError.eventStreamEnded
                    } catch is CancellationError {
                        break
                    } catch {
                        continuation.yield(.reconnecting(error.localizedDescription))
                        do {
                            try await Task.sleep(for: .seconds(retryDelay))
                        } catch {
                            break
                        }
                        retryDelay = min(retryDelay * 2, 10)
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CourierStateTransportError.invalidHTTPResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw CourierStateTransportError.httpStatus(httpResponse.statusCode)
        }
    }

    private func fieldValue(_ line: String, prefix: String) -> String {
        var value = String(line.dropFirst(prefix.count))
        if value.first == " " { value.removeFirst() }
        return value
    }

    func decodeEvent(name: String, data: String) throws -> Dev2StreamMessage? {
        guard !data.isEmpty else { return nil }
        let payload = Data(data.utf8)
        let decoder = JSONDecoder()

        switch name {
        case "simulation_snapshot":
            return .snapshot(try decoder.decode(Dev2SimulationSnapshot.self, from: payload))

        case "courier_positions":
            let event = try decoder.decode(CourierPositionsEvent.self, from: payload)
            return .courierPositions(event.data.couriers, simulatedTime: event.simulatedTime)

        case "agent_decision_applied":
            let event = try decoder.decode(AgentDecisionEvent.self, from: payload)
            return .agentDecisionApplied(
                Dev2AgentDecisionApplied(
                    reason: event.data.reason,
                    acceptedOrderIds: event.data.acceptedOrderIds,
                    orderedStops: event.data.orderedStops,
                    directions: event.data.directions,
                    description: event.data.description
                )
            )

        case "agent_decision_failed":
            let event = try decoder.decode(MessageEvent.self, from: payload)
            return .agentDecisionFailed(event.data.message ?? event.data.error ?? "La decisión del agente falló.")

        case "courier_waiting_agent":
            let event = try decoder.decode(MessageEvent.self, from: payload)
            return .agentWaiting(event.data.reason ?? "Esperando una decisión del agente.")

        case "agent_request_sent":
            let event = try decoder.decode(MessageEvent.self, from: payload)
            return .agentWaiting(event.data.reason ?? "DEV2 consultó al agente.")

        case "order_created", "order_picked", "order_delivered",
             "route_recalculated", "weather_changed", "street_closed",
             "route_unreachable", "simulation_started", "simulation_stopped",
             "simulation_reset":
            return .refreshSnapshot

        default:
            return nil
        }
    }
}

private struct CourierPositionsEvent: Decodable {
    let simulatedTime: String?
    let data: CourierPositionsData

    enum CodingKeys: String, CodingKey {
        case simulatedTime = "tiempo_simulado"
        case data
    }
}

private struct CourierPositionsData: Decodable {
    let couriers: [Dev2CourierState]
}

private struct AgentDecisionEvent: Decodable {
    let data: AgentDecisionData
}

private struct AgentDecisionData: Decodable {
    let reason: String
    let acceptedOrderIds: [String]
    let orderedStops: [String]
    let directions: [String]
    let description: String?

    enum CodingKeys: String, CodingKey {
        case reason = "evento"
        case acceptedOrderIds = "aceptar_pedidos"
        case orderedStops = "paradas_ordenadas"
        case directions = "direcciones"
        case englishDirections = "directions"
        case description = "descripcion"
        case englishDescription = "description"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
        acceptedOrderIds = try container.decodeIfPresent([String].self, forKey: .acceptedOrderIds) ?? []
        orderedStops = try container.decodeIfPresent([String].self, forKey: .orderedStops) ?? []
        directions = Self.decodeStringList(
            from: container,
            primaryKey: .directions,
            secondaryKey: .englishDirections
        )
        description = try container.decodeIfPresent(String.self, forKey: .description)
            ?? container.decodeIfPresent(String.self, forKey: .englishDescription)
    }

    private static func decodeStringList(
        from container: KeyedDecodingContainer<CodingKeys>,
        primaryKey: CodingKeys,
        secondaryKey: CodingKeys
    ) -> [String] {
        if let values = try? container.decode([String].self, forKey: primaryKey) {
            return values
        }
        if let value = try? container.decode(String.self, forKey: primaryKey) {
            return [value]
        }
        if let values = try? container.decode([String].self, forKey: secondaryKey) {
            return values
        }
        if let value = try? container.decode(String.self, forKey: secondaryKey) {
            return [value]
        }
        return []
    }
}

private struct MessageEvent: Decodable {
    let data: MessageEventData
}

private struct MessageEventData: Decodable {
    let reason: String?
    let message: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case reason = "evento"
        case waitingReason = "motivo"
        case message = "mensaje"
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
            ?? container.decodeIfPresent(String.self, forKey: .waitingReason)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}
