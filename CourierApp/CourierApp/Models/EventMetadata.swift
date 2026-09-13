import Foundation

struct CoordinatePayload: Decodable, Sendable {
    let latitude: Double
    let longitude: Double
}

struct EventPayload: Decodable, Sendable {
    let latitude: Double?
    let longitude: Double?

    let routeId: String?
    let roadId: String?
    let coordinates: [CoordinatePayload]?
    let pickupCoordinate: CoordinatePayload?
    let dropoffCoordinate: CoordinatePayload?

    let orderId: String?
    let payoutMxn: Double?
    let pickupName: String?
    let dropoffName: String?

    let decision: String?
    let explanation: String?
    let confidence: Double?

    let surgeMultiplier: Double?

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case coordinates

        case routeId = "route_id"
        case roadId = "road_id"
        case pickupCoordinate = "pickup_coordinate"
        case dropoffCoordinate = "dropoff_coordinate"
        case orderId = "order_id"
        case payoutMxn = "payout_mxn"
        case pickupName = "pickup_name"
        case dropoffName = "dropoff_name"
        case surgeMultiplier = "surge_multiplier"

        case decision
        case explanation
        case confidence
    }
}

struct EventMetadata: Decodable, Identifiable, Sendable {
    let schemaVersion: String
    let eventId: String
    let runId: String
    let comparisonId: String
    let sequence: Int
    let simTimeS: Double
    let type: String
    let payload: EventPayload

    var id: String {
        eventId
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case eventId = "event_id"
        case runId = "run_id"
        case comparisonId = "comparison_id"
        case sequence
        case simTimeS = "sim_time_s"
        case type
        case payload
    }
}
