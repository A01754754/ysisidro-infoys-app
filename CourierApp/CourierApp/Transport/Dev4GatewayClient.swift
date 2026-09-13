import Foundation

struct CourierArrivalCommand: Encodable {
    let schemaVersion: String
    let type: String
    let actionId: String
    let orderId: String
    let routeId: String?
    let waypointType: String
    let basedOnSequence: Int
    let latitude: Double
    let longitude: Double

    init(
        actionId: String,
        orderId: String,
        routeId: String?,
        basedOnSequence: Int,
        latitude: Double,
        longitude: Double
    ) {
        self.schemaVersion = "1.0"
        self.type = "WAYPOINT_REACHED"
        self.actionId = actionId
        self.orderId = orderId
        self.routeId = routeId
        self.waypointType = "dropoff"
        self.basedOnSequence = basedOnSequence
        self.latitude = latitude
        self.longitude = longitude
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case type
        case actionId = "action_id"
        case orderId = "order_id"
        case routeId = "route_id"
        case waypointType = "waypoint_type"
        case basedOnSequence = "based_on_sequence"
        case latitude
        case longitude
    }
}

protocol Dev4GatewayClient {
    func sendArrival(
        _ command: CourierArrivalCommand
    ) async throws
}

struct MockDev4GatewayClient: Dev4GatewayClient {
    func sendArrival(
        _ command: CourierArrivalCommand
    ) async throws {
        try await Task.sleep(
            for: .milliseconds(300)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        let data = try encoder.encode(command)

        guard let json = String(
            data: data,
            encoding: .utf8
        ) else {
            return
        }

        print("📤 Mensaje simulado para DEV4:")
        print(json)
    }
}
