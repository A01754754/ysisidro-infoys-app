import Foundation

@main
struct CourierStateTransportTests {
    static func main() throws {
        // A persistent stream must dispatch each frame before the connection closes.
        for newline in ["\n", "\r\n", "\r"] {
            var parser = SSEFrameParser()
            var frames: [(name: String, data: String)] = []
            let stream = ": heartbeat\(newline)\(newline)"
                + "event: courier_positions\(newline)data: uno\(newline)\(newline)"
                + "event: agent_decision_applied\(newline)data: café\(newline)data: dos\(newline)\(newline)"
                + "data: default event\(newline)\(newline)"
                + "event: incomplete\(newline)data: pending"
            for byte in stream.utf8 {
                if let frame = parser.consume(byte) { frames.append(frame) }
            }
            precondition(frames.count == 3, "Must emit complete frames only")
            precondition(frames[0].name == "courier_positions" && frames[0].data == "uno")
            precondition(frames[1].name == "agent_decision_applied" && frames[1].data == "café\ndos")
            precondition(frames[2].name == "message", "Event name must reset between frames")
        }

        let transport = Dev2SSECourierStateTransport(baseURL: URL(string: "http://localhost:3000")!)
        var parser = SSEFrameParser()
        var positions: [Double] = []
        for latitude in [25.68, 25.69, 25.70] {
            let json = """
            {"tiempo_simulado":"12:00","data":{"couriers":[{"courier_id":"agent","controlado_por_agente":true,"estado_courier":"moving","posicion":{"latitud":\(latitude),"longitud":-100.3}}]}}
            """
            for byte in "event: courier_positions\ndata: \(json)\n\n".utf8 {
                if let frame = parser.consume(byte),
                   case let .courierPositions(couriers, _) = try transport.decodeEvent(name: frame.name, data: frame.data) {
                    positions.append(couriers[0].position.latitude)
                }
            }
            precondition(positions.last == latitude, "Position must update while stream remains open")
        }
        precondition(positions.count == 3)
        for name in ["agent_decision_skipped", "agent_decision_superseded",
                     "agent_plan_invalidated", "order_expired", "order_route_unavailable",
                     "order_route_available"] {
            guard case .refreshSnapshot = try transport.decodeEvent(name: name, data: "{\"data\":{}}") else {
                preconditionFailure("Must resynchronize after \(name)")
            }
        }
        print("PASS: SSE framing, newline variants, heartbeat, UTF-8, multiline data, and consecutive live positions")
    }
}
