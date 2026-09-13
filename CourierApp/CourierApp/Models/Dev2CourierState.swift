import CoreLocation
import Foundation

struct Dev2CourierState: Decodable, Sendable {
    let courierId: String
    let controlledByAgent: Bool
    let courierStatus: String
    let position: Dev2Coordinate
    let currentDestination: Dev2Destination?
    let currentRoute: [Dev2Coordinate]

    enum CodingKeys: String, CodingKey {
        case courierId = "courier_id"
        case controlledByAgent = "controlado_por_agente"
        case courierStatus = "estado_courier"
        case position = "posicion"
        case currentDestination = "destino_actual"
        case currentRoute = "ruta_actual"
    }
}

struct Dev2Coordinate: Decodable, Sendable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )
    }

    enum CodingKeys: String, CodingKey {
        case latitude = "latitud"
        case longitude = "longitud"
    }
}

struct Dev2Destination: Decodable, Sendable {
    let id: String
    let type: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case latitude = "latitud"
        case longitude = "longitud"
    }
}
