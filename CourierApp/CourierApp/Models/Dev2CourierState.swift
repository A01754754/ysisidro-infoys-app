import CoreLocation
import Foundation

struct Dev2CourierState: Decodable, Sendable {
    let courierId: String
    let controlledByAgent: Bool
    let courierStatus: String
    let activeOrderCount: Int
    let accumulatedEarningsMXN: Double
    let position: Dev2Coordinate
    let currentDestination: Dev2Destination?
    let currentRoute: [Dev2Coordinate]
    let currentTrajectory: [Dev2Coordinate]

    enum CodingKeys: String, CodingKey {
        case courierId = "courier_id"
        case controlledByAgent = "controlado_por_agente"
        case courierStatus = "estado_courier"
        case activeOrderCount = "pedidos_activos"
        case accumulatedEarningsMXN = "ganancia_acumulada_mxn"
        case position = "posicion"
        case currentDestination = "destino_actual"
        case currentRoute = "ruta_actual"
        case currentTrajectory = "trayectoria_actual"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        courierId = try container.decode(String.self, forKey: .courierId)
        controlledByAgent = try container.decode(Bool.self, forKey: .controlledByAgent)
        courierStatus = try container.decode(String.self, forKey: .courierStatus)
        activeOrderCount = try container.decodeIfPresent(Int.self, forKey: .activeOrderCount) ?? 0
        accumulatedEarningsMXN = try container.decodeIfPresent(Double.self, forKey: .accumulatedEarningsMXN) ?? 0
        position = try container.decode(Dev2Coordinate.self, forKey: .position)
        currentDestination = try container.decodeIfPresent(Dev2Destination.self, forKey: .currentDestination)
        currentRoute = try container.decodeIfPresent([Dev2Coordinate].self, forKey: .currentRoute) ?? []
        currentTrajectory = try container.decodeIfPresent([Dev2Coordinate].self, forKey: .currentTrajectory) ?? []
    }
}

struct Dev2Coordinate: Decodable, Sendable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case latitude = "latitud"
        case longitude = "longitud"
    }
}

struct Dev2Destination: Decodable, Sendable {
    let id: String
    let orderId: String?
    let type: String
    let latitude: Double
    let longitude: Double
    let mandatory: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "pedido_id"
        case type
        case latitude = "latitud"
        case longitude = "longitud"
        case mandatory = "obligatoria"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        orderId = try container.decodeIfPresent(String.self, forKey: .orderId)
        type = try container.decode(String.self, forKey: .type)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        mandatory = try container.decodeIfPresent(Bool.self, forKey: .mandatory) ?? false
    }
}

struct Dev2SimulationSnapshot: Decodable, Sendable {
    let isRunning: Bool
    let simulatedTime: String
    let speed: Dev2SimulationSpeed?
    let weather: Dev2Weather?
    let traffic: Dev2Traffic?
    let couriers: [Dev2CourierState]
    let orders: [Dev2Order]

    var controlledCourier: Dev2CourierState? {
        couriers.first(where: \.controlledByAgent)
    }

    enum CodingKeys: String, CodingKey {
        case isRunning = "corriendo"
        case simulatedTime = "tiempo_simulado"
        case speed = "velocidad"
        case weather = "clima"
        case traffic = "trafico"
        case couriers
        case orders = "pedidos"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isRunning = try container.decodeIfPresent(Bool.self, forKey: .isRunning) ?? false
        simulatedTime = try container.decodeIfPresent(String.self, forKey: .simulatedTime) ?? ""
        speed = try container.decodeIfPresent(Dev2SimulationSpeed.self, forKey: .speed)
        weather = try container.decodeIfPresent(Dev2Weather.self, forKey: .weather)
        traffic = try container.decodeIfPresent(Dev2Traffic.self, forKey: .traffic)
        couriers = try container.decodeIfPresent([Dev2CourierState].self, forKey: .couriers) ?? []
        orders = try container.decodeIfPresent([Dev2Order].self, forKey: .orders) ?? []
    }
}

struct Dev2SimulationSpeed: Decodable, Sendable {
    let realSeconds: Double
    let simulatedSeconds: Double

    enum CodingKeys: String, CodingKey {
        case realSeconds = "segundos_reales"
        case simulatedSeconds = "segundos_simulados"
    }
}

struct Dev2Weather: Decodable, Sendable {
    let type: String
    let edgeMultiplier: Double?
    let newOrderPaymentMultiplier: Double?

    enum CodingKeys: String, CodingKey {
        case type = "tipo"
        case edgeMultiplier = "multiplicador_aristas"
        case newOrderPaymentMultiplier = "multiplicador_pago_nuevos_pedidos"
    }
}

struct Dev2Traffic: Decodable, Sendable {
    let edgeMultiplier: Double?

    enum CodingKeys: String, CodingKey {
        case edgeMultiplier = "multiplicador_aristas"
    }
}

struct Dev2Order: Decodable, Sendable {
    let orderId: String
    let status: String
    let paymentMXN: Double
    let restaurant: Dev2OrderLocation?
    let delivery: Dev2OrderLocation?

    enum CodingKeys: String, CodingKey {
        case orderId = "pedido_id"
        case status = "estado"
        case paymentMXN = "pago_mxn"
        case restaurant = "restaurante"
        case delivery = "entrega"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = try container.decode(String.self, forKey: .orderId)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        paymentMXN = try container.decodeIfPresent(Double.self, forKey: .paymentMXN) ?? 0
        restaurant = try container.decodeIfPresent(Dev2OrderLocation.self, forKey: .restaurant)
        delivery = try container.decodeIfPresent(Dev2OrderLocation.self, forKey: .delivery)
    }
}

struct Dev2OrderLocation: Decodable, Sendable {
    let id: String?
    let name: String?
    let zone: String?
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name = "nombre"
        case zone = "zona"
        case latitude = "latitud"
        case longitude = "longitud"
    }
}

struct Dev2AgentDecisionApplied: Sendable {
    let reason: String
    let acceptedOrderIds: [String]
    let orderedStops: [String]
    let directions: [String]
    let description: String?
}

struct AcceptedTripAnnouncement: Identifiable, Sendable {
    let id: String
    let orderIds: [String]
    let description: String
    let orderedStops: [String]
    let directions: [String]
}

enum Dev2StreamMessage: Sendable {
    case connected
    case reconnecting(String)
    case snapshot(Dev2SimulationSnapshot)
    case courierPositions([Dev2CourierState], simulatedTime: String?)
    case agentDecisionApplied(Dev2AgentDecisionApplied)
    case agentDecisionFailed(String)
    case agentWaiting(String)
    case refreshSnapshot
}
