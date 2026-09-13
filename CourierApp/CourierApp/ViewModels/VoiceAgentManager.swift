import Combine
import ElevenLabs
import Foundation

@MainActor
final class VoiceAgentManager: ObservableObject {
    @Published private(set) var isConnecting = false
    @Published private(set) var isConnected = false
    @Published private(set) var isMuted = true
    @Published private(set) var isAgentSpeaking = false
    @Published private(set) var statusText =
        "Asistente desconectado"
    @Published private(set) var lastTranscript = ""
    @Published private(set) var errorMessage: String?

    private var conversation: Conversation?
    private var connectTask: Task<Conversation, Error>?
    private var inactivityTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private weak var courierViewModel: CourierViewModel?
    private var queuedAnnouncements: [AcceptedTripAnnouncement] = []
    private var processingAnnouncementId: String?
    private var isProcessingAnnouncementQueue = false
    private var announcedTripIds: Set<String> = []

    private static let acceptedTripMessage =
        "Has aceptado un viaje automáticamente. Si tienes dudas de por qué aceptaste este viaje, házmelo saber."

    private static let inactivityTimeout: Duration = .seconds(5)

    private static let courierAgentPrompt = """
    Actúa como un agente inteligente que acompaña a un courier. Habla y responde siempre en español claro y breve, trata de ser lo más conciso posible. Tu objetivo es ayudarle a tomar buenas decisiones para maximizar su ganancia sin inventar datos. Usa el contexto del simulador para explicar por qué se aceptó un pedido, qué paradas siguen y qué cambió en la ruta. Si el contexto indica que una descripción fue generada localmente porque DEV2 aún no la envía, dilo con honestidad cuando sea relevante.
    """

    func toggleConversation(
        courierViewModel: CourierViewModel
    ) async {
        if isConnected || isConnecting {
            await endConversation()
        } else {
            await startConversation(
                courierViewModel: courierViewModel
            )
        }
    }

    func announceAcceptedTrip(
        _ announcement: AcceptedTripAnnouncement,
        courierViewModel: CourierViewModel
    ) async {
        guard !announcedTripIds.contains(announcement.id),
              processingAnnouncementId != announcement.id,
              !queuedAnnouncements.contains(where: {
                  $0.id == announcement.id
              }) else {
            return
        }

        self.courierViewModel = courierViewModel
        queuedAnnouncements.append(announcement)
        await processAnnouncementQueue(
            courierViewModel: courierViewModel
        )
    }

    private func processAnnouncementQueue(
        courierViewModel: CourierViewModel
    ) async {
        guard !isProcessingAnnouncementQueue else { return }

        isProcessingAnnouncementQueue = true

        while !queuedAnnouncements.isEmpty {
            let announcement = queuedAnnouncements.removeFirst()
            processingAnnouncementId = announcement.id

            if isConnected || isConnecting {
                await endConversation()
            }

            await startConversation(
                courierViewModel: courierViewModel,
                announcement: announcement
            )
        }

        processingAnnouncementId = nil
        isProcessingAnnouncementQueue = false
    }

    func startConversation(
        courierViewModel: CourierViewModel,
        announcement: AcceptedTripAnnouncement? = nil
    ) async {
        guard let agentId =
                AppConfiguration.elevenLabsAgentId else {
            errorMessage =
                "Falta ELEVENLABS_AGENT_ID en Secrets.xcconfig"
            statusText = "Falta configurar el agente"
            return
        }

        guard !isConnected, !isConnecting else {
            return
        }

        self.courierViewModel = courierViewModel
        errorMessage = nil
        isConnecting = true
        statusText = "Conectando con ElevenLabs…"

        let config = ConversationConfig(
            onError: { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.show(error: error)
                }
            },
            onAgentResponse: { [weak self] text, _ in
                Task { @MainActor [weak self] in
                    self?.lastTranscript =
                        "Agente: \(text)"
                    self?.registerVoiceActivity()
                }
            },
            onUserTranscript: { [weak self] text, _ in
                Task { @MainActor [weak self] in
                    self?.lastTranscript =
                        "Tú: \(text)"
                    self?.registerVoiceActivity()
                }
            },
            onVadScore: { [weak self] score in
                guard score >= 0.5 else { return }

                Task { @MainActor [weak self] in
                    self?.registerVoiceActivity()
                }
            },
            onUnhandledClientToolCall: {
                [weak self] toolCall in

                Task { @MainActor [weak self] in
                    await self?.handle(toolCall)
                }
            }
        )

        let task = Task { @MainActor in
            try await ElevenLabs.startConversation(
                agentId: agentId,
                config: config
            )
        }

        connectTask = task

        do {
            let conversation = try await task.value

            guard !Task.isCancelled else {
                await conversation.endConversation()
                return
            }

            self.conversation = conversation
            observe(conversation)

            isConnecting = false
            isConnected = true
            statusText = "Asistente conectado"

            await sendCourierContext(through: conversation)

            if let announcement {
                await deliver(announcement, through: conversation)
            }

            scheduleInactivityTimeout()
        } catch is CancellationError {
            resetConnectionState()
        } catch {
            show(error: error)
        }

        connectTask = nil
    }

    private func sendCourierContext(
        through conversation: Conversation
    ) async {
        do {
            try await conversation.updateContext(Self.courierAgentPrompt)
        } catch {
            errorMessage =
                "El asistente se conectó, pero no recibió el contexto: \(error.localizedDescription)"
        }
    }

    private func deliver(
        _ announcement: AcceptedTripAnnouncement,
        through conversation: Conversation
    ) async {
        do {
            try await conversation.updateContext(announcementContext(announcement))
            try await conversation.sendMessage(
                "Evento del sistema: se aceptó un viaje automáticamente. Responde diciendo: \(Self.acceptedTripMessage)"
            )
            announcedTripIds.insert(announcement.id)
        } catch {
            errorMessage = "No se pudo anunciar el viaje: \(error.localizedDescription)"
            statusText = "Error al actualizar el contexto"
        }
    }

    private func announcementContext(
        _ announcement: AcceptedTripAnnouncement
    ) -> String {
        """
        Pedidos aceptados: \(announcement.orderIds.joined(separator: ", ")).
        Descripción: \(announcement.description)
        Paradas ordenadas: \(announcement.orderedStops.isEmpty ? "no disponibles" : announcement.orderedStops.joined(separator: " → ")).
        Indicaciones: \(announcement.directions.isEmpty ? "no disponibles" : announcement.directions.joined(separator: " ")).
        """
    }

    func endConversation() async {
        cancelInactivityTimeout()
        connectTask?.cancel()
        connectTask = nil

        if let conversation {
            await conversation.endConversation()
        }

        conversation = nil
        cancellables.removeAll()
        resetConnectionState()
    }

    func toggleMute() async {
        guard let conversation, isConnected else {
            return
        }

        do {
            try await conversation.toggleMute()
        } catch {
            show(error: error)
        }
    }

    private func observe(
        _ conversation: Conversation
    ) {
        cancellables.removeAll()

        conversation.$state
            .sink { [weak self] state in
                self?.updateConversationState(state)
            }
            .store(in: &cancellables)

        conversation.$agentState
            .sink { [weak self] agentState in
                guard let self else {
                    return
                }

                isAgentSpeaking =
                    agentState == .speaking

                if isConnected {
                    switch agentState {
                    case .listening:
                        statusText = "Escuchando…"
                        scheduleInactivityTimeout()
                    case .speaking:
                        statusText =
                            "El agente está hablando"
                        cancelInactivityTimeout()
                    case .thinking:
                        statusText = "Pensando…"
                        cancelInactivityTimeout()
                    }
                }
            }
            .store(in: &cancellables)

        conversation.$isMuted
            .sink { [weak self] muted in
                self?.isMuted = muted
            }
            .store(in: &cancellables)
    }

    private func updateConversationState(
        _ state: ConversationState
    ) {
        switch state {
        case .idle:
            isConnected = false
        case .connecting:
            isConnecting = true
            statusText = "Conectando…"
        case .active:
            isConnecting = false
            isConnected = true
            statusText = "Escuchando…"
        case .ended:
            resetConnectionState()
        case let .error(error):
            show(error: error)
        }
    }

    private func handle(
        _ toolCall: ClientToolCallEvent
    ) async {
        guard let courierViewModel else {
            await sendError(
                "El estado del courier no está disponible.",
                for: toolCall
            )
            return
        }

        switch toolCall.toolName {
        case "get_courier_state":
            let response = CourierStateResponse(
                success: true,
                state: courierViewModel.makeVoiceState()
            )

            await send(
                response,
                for: toolCall
            )

        case "pause_simulation":
            courierViewModel.pause()

            await send(
                VoiceToolResponse(
                    success: true,
                    message: "La simulación está pausada."
                ),
                for: toolCall
            )

        case "resume_simulation":
            courierViewModel.resume()

            await send(
                VoiceToolResponse(
                    success: true,
                    message: "La simulación continúa."
                ),
                for: toolCall
            )

        case "set_playback_speed":
            await changePlaybackSpeed(
                from: toolCall,
                courierViewModel: courierViewModel
            )

        default:
            await sendError(
                "Herramienta desconocida: \(toolCall.toolName)",
                for: toolCall
            )
        }
    }

    private func changePlaybackSpeed(
        from toolCall: ClientToolCallEvent,
        courierViewModel: CourierViewModel
    ) async {
        do {
            let parameters = try toolCall.getParameters()
            let speed = parseSpeed(
                parameters["speed"]
            )

            guard let speed,
                  [1.0, 5.0, 20.0].contains(speed) else {
                await sendError(
                    "La velocidad debe ser 1, 5 o 20.",
                    for: toolCall
                )
                return
            }

            courierViewModel.setPlaybackSpeed(speed)

            await send(
                VoiceToolResponse(
                    success: true,
                    message:
                        "Velocidad cambiada a \(Int(speed))x."
                ),
                for: toolCall
            )
        } catch {
            await sendError(
                "No se pudieron leer los parámetros.",
                for: toolCall
            )
        }
    }

    private func parseSpeed(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if let text = value as? String {
            return Double(text)
        }

        return nil
    }

    private func send<Result: Encodable>(
        _ result: Result,
        for toolCall: ClientToolCallEvent
    ) async {
        guard let conversation else {
            return
        }

        if toolCall.expectsResponse {
            do {
                try await conversation.sendToolResult(
                    for: toolCall.toolCallId,
                    result: result
                )
            } catch {
                show(error: error)
            }
        } else {
            conversation.markToolCallCompleted(
                toolCall.toolCallId
            )
        }
    }

    private func sendError(
        _ message: String,
        for toolCall: ClientToolCallEvent
    ) async {
        guard let conversation else {
            return
        }

        let response = VoiceToolResponse(
            success: false,
            message: message
        )

        if toolCall.expectsResponse {
            do {
                try await conversation.sendToolResult(
                    for: toolCall.toolCallId,
                    result: response,
                    isError: true
                )
            } catch {
                show(error: error)
            }
        } else {
            conversation.markToolCallCompleted(
                toolCall.toolCallId
            )
        }
    }

    private func show(error: Error) {
        cancelInactivityTimeout()
        errorMessage = error.localizedDescription
        isConnecting = false
        isConnected = false
        statusText = "Error de voz"
    }

    private func resetConnectionState() {
        cancelInactivityTimeout()
        isConnecting = false
        isConnected = false
        isMuted = true
        isAgentSpeaking = false
        statusText = "Asistente desconectado"
    }

    private func registerVoiceActivity() {
        guard isConnected else { return }
        scheduleInactivityTimeout()
    }

    private func scheduleInactivityTimeout() {
        cancelInactivityTimeout()

        guard isConnected, !isAgentSpeaking else { return }

        inactivityTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.inactivityTimeout)
            } catch {
                return
            }

            guard let self, isConnected else { return }

            inactivityTask = nil
            await endConversation()
            statusText = "Sesión cerrada por inactividad"
        }
    }

    private func cancelInactivityTimeout() {
        inactivityTask?.cancel()
        inactivityTask = nil
    }
}

private struct CourierStateResponse: Encodable {
    let success: Bool
    let state: CourierVoiceState
}

private struct VoiceToolResponse: Encodable {
    let success: Bool
    let message: String
}
