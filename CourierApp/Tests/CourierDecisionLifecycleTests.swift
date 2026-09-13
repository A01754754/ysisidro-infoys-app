import Foundation

private struct LifecycleTransport: CourierStateTransport {
    let stream: AsyncThrowingStream<Dev2StreamMessage, Error>
    func eventStream() -> AsyncThrowingStream<Dev2StreamMessage, Error> { stream }
    func fetchSnapshot() async throws -> Dev2SimulationSnapshot { throw URLError(.notConnectedToInternet) }
    func startSimulation() async throws {}
}

@main
struct CourierDecisionLifecycleTests {
    @MainActor
    static func main() async throws {
        let (stream, continuation) = AsyncThrowingStream<Dev2StreamMessage, Error>.makeStream()
        let model = CourierViewModel(courierStateTransport: LifecycleTransport(stream: stream))
        let receiver = Task { await model.startReceivingCourierState() }
        defer { receiver.cancel(); continuation.finish() }

        // A local presentation pause must never block the decision lifecycle.
        model.pause()
        continuation.yield(.snapshot(try snapshot(pending: true, time: "14:00:00", latitude: 25.68)))
        try await waitUntil { model.isAgentThinking && model.simulatedTime == "14:00:00" }
        precondition(model.isPaused)

        // Repeated server time remains fixed without stopping stream consumption.
        continuation.yield(.snapshot(try snapshot(pending: true, time: "14:00:00", latitude: 25.68)))
        continuation.yield(.agentDecisionFailed("timeout"))
        try await waitUntil { !model.isAgentThinking && model.lastEventText.contains("timeout") }
        precondition(model.simulatedTime == "14:00:00")

        // Snapshots recover even when an SSE completion event was missed.
        continuation.yield(.agentWaiting("new_order"))
        try await waitUntil { model.isAgentThinking }
        continuation.yield(.snapshot(try snapshot(pending: false, time: "14:00:30", latitude: 25.69)))
        try await waitUntil { !model.isAgentThinking && model.simulatedTime == "14:00:30" }
        model.resume()
        try await waitUntil { abs((model.courierCoordinate?.latitude ?? 0) - 25.69) < 0.000001 }

        // Pending does not invent a local freeze when the server keeps moving.
        continuation.yield(.snapshot(try snapshot(pending: true, time: "14:01:00", latitude: 25.70)))
        try await waitUntil { model.isAgentThinking && model.simulatedTime == "14:01:00" }
        try await waitUntil { abs((model.courierCoordinate?.latitude ?? 0) - 25.70) < 0.000001 }
        precondition(!model.isPaused)
        precondition(model.makeVoiceState().isAgentThinking)
        continuation.yield(.agentDecisionApplied(Dev2AgentDecisionApplied(
            reason: "new_order", acceptedOrderIds: ["order-1"],
            orderedStops: ["pick-order-1"], directions: [], description: "Pedido aceptado"
        )))
        try await waitUntil { !model.isAgentThinking && model.acceptedTripAnnouncement != nil }
        precondition(model.acceptedTripAnnouncement?.orderIds == ["order-1"])
        print("PASS: paused display consumes decisions, frozen server time, error recovery, snapshot recovery, and resumed movement")
    }

    private static func snapshot(pending: Bool, time: String, latitude: Double) throws -> Dev2SimulationSnapshot {
        let json = """
        {"corriendo":true,"tiempo_simulado":"\(time)","agente":{"decision_pendiente":\(pending)},
         "couriers":[{"courier_id":"agent","controlado_por_agente":true,"estado_courier":"pick",
         "posicion":{"latitud":\(latitude),"longitud":-100.3}}]}
        """
        return try JSONDecoder().decode(Dev2SimulationSnapshot.self, from: Data(json.utf8))
    }

    @MainActor
    private static func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while !condition() {
            precondition(ContinuousClock.now < deadline, "Timed out waiting for live state")
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
