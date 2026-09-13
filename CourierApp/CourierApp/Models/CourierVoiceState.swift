import Foundation

struct CourierVoiceState: Encodable, Sendable {
    let lastEvent: String
    let streamStatus: String
    let isPaused: Bool
    let playbackSpeed: Double
    let isAgentThinking: Bool
    let simulatedTime: String

    let courierLatitude: Double?
    let courierLongitude: Double?
    let courierId: String?
    let controlledByAgent: Bool
    let courierStatus: String?
    let activeRouteId: String?

    let currentDestinationId: String?
    let currentDestinationType: String?
    let currentDestinationLatitude: Double?
    let currentDestinationLongitude: Double?

    let activeOrderId: String?
    let pickupName: String?
    let dropoffName: String?
    let orderPayoutMxn: Double?

    let offeredOrderId: String?
    let agentDecision: String?
    let agentExplanation: String?
    let agentConfidence: Double?

    let netEarningsMxn: Double
    let remainingMinutes: Int
    let completedDeliveries: Int

    let isRaining: Bool
    let surgeMultiplier: Double?
    let closedRoadId: String?
    let arrivalMessage: String?

    enum CodingKeys: String, CodingKey {
        case lastEvent = "last_event"
        case streamStatus = "stream_status"
        case isPaused = "is_paused"
        case playbackSpeed = "playback_speed"
        case isAgentThinking = "agent_thinking"
        case simulatedTime = "tiempo_simulado"
        case courierLatitude = "courier_latitude"
        case courierLongitude = "courier_longitude"
        case courierId = "courier_id"
        case controlledByAgent = "controlado_por_agente"
        case courierStatus = "estado_courier"
        case activeRouteId = "active_route_id"
        case currentDestinationId = "destino_actual_id"
        case currentDestinationType = "destino_actual_type"
        case currentDestinationLatitude = "destino_actual_latitud"
        case currentDestinationLongitude = "destino_actual_longitud"
        case activeOrderId = "active_order_id"
        case pickupName = "pickup_name"
        case dropoffName = "dropoff_name"
        case orderPayoutMxn = "order_payout_mxn"
        case offeredOrderId = "offered_order_id"
        case agentDecision = "agent_decision"
        case agentExplanation = "agent_explanation"
        case agentConfidence = "agent_confidence"
        case netEarningsMxn = "net_earnings_mxn"
        case remainingMinutes = "remaining_minutes"
        case completedDeliveries = "completed_deliveries"
        case isRaining = "is_raining"
        case surgeMultiplier = "surge_multiplier"
        case closedRoadId = "closed_road_id"
        case arrivalMessage = "arrival_message"
    }
}
