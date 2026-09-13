import Foundation

enum MockTransportError: LocalizedError {
    case demoFileNotFound

    var errorDescription: String? {
        switch self {
        case .demoFileNotFound:
            return """
            No se encontró demo-stream.jsonl \
            en la aplicación.
            """
        }
    }
}

struct MockTransport: EventTransport {
    let shouldSimulateDelay = true

    func eventStream()
        -> AsyncThrowingStream<EventMetadata, Error> {

        AsyncThrowingStream { continuation in
            do {
                let events = try loadEvents()

                for event in events {
                    continuation.yield(event)
                }

                continuation.finish()
            } catch {
                continuation.finish(
                    throwing: error
                )
            }
        }
    }

    private func loadEvents()
        throws -> [EventMetadata] {

        guard let url = Bundle.main.url(
            forResource: "demo-stream",
            withExtension: "jsonl"
        ) else {
            throw MockTransportError.demoFileNotFound
        }

        let contents = try String(
            contentsOf: url,
            encoding: .utf8
        )

        let decoder = JSONDecoder()

        return try contents
            .split(whereSeparator: \.isNewline)
            .map { line in
                try decoder.decode(
                    EventMetadata.self,
                    from: Data(line.utf8)
                )
            }
    }
}
