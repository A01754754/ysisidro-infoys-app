import Foundation

protocol EventTransport: Sendable {
    var shouldSimulateDelay: Bool { get }

    func eventStream()
        -> AsyncThrowingStream<EventMetadata, Error>
}
