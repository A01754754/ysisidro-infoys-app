import Foundation

protocol CourierStateTransport: Sendable {
    var shouldSimulateDelay: Bool { get }

    func stateStream()
        -> AsyncThrowingStream<Dev2CourierState, Error>
}

enum CourierStateTransportError: LocalizedError {
    case demoFileNotFound
    case invalidHTTPResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .demoFileNotFound:
            return "No se encontró dev2-courier-state.json en la aplicación."
        case .invalidHTTPResponse:
            return "DEV2 devolvió una respuesta HTTP inválida."
        case let .httpStatus(statusCode):
            return "DEV2 devolvió el código HTTP \(statusCode)."
        }
    }
}

struct BundledCourierStateTransport: CourierStateTransport {
    let shouldSimulateDelay = false

    func stateStream()
        -> AsyncThrowingStream<Dev2CourierState, Error> {

        AsyncThrowingStream { continuation in
            do {
                guard let url = Bundle.main.url(
                    forResource: "dev2-courier-state",
                    withExtension: "json"
                ) else {
                    throw CourierStateTransportError
                        .demoFileNotFound
                }

                let data = try Data(contentsOf: url)
                let state = try JSONDecoder().decode(
                    Dev2CourierState.self,
                    from: data
                )

                continuation.yield(state)
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}

struct Dev2HTTPCourierStateTransport: CourierStateTransport {
    let shouldSimulateDelay = false
    let endpoint: URL
    let pollingIntervalSeconds: Double

    init(
        endpoint: URL,
        pollingIntervalSeconds: Double = 1
    ) {
        self.endpoint = endpoint
        self.pollingIntervalSeconds = pollingIntervalSeconds
    }

    func stateStream()
        -> AsyncThrowingStream<Dev2CourierState, Error> {

        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    while !Task.isCancelled {
                        let (data, response) = try await URLSession
                            .shared
                            .data(from: endpoint)

                        guard let httpResponse =
                                response as? HTTPURLResponse else {
                            throw CourierStateTransportError
                                .invalidHTTPResponse
                        }

                        guard (200...299).contains(
                            httpResponse.statusCode
                        ) else {
                            throw CourierStateTransportError
                                .httpStatus(httpResponse.statusCode)
                        }

                        let state = try JSONDecoder().decode(
                            Dev2CourierState.self,
                            from: data
                        )

                        continuation.yield(state)

                        try await Task.sleep(
                            for: .seconds(
                                pollingIntervalSeconds
                            )
                        )
                    }

                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
