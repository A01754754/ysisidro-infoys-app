import Foundation

enum AppConfiguration {
    static var elevenLabsAgentId: String? {
        guard let value = Bundle.main.object(
            forInfoDictionaryKey: "ELEVENLABS_AGENT_ID"
        ) as? String else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedValue.isEmpty,
              !trimmedValue.contains("$("),
              !trimmedValue.contains("YOUR_") else {
            return nil
        }

        return trimmedValue
    }
}
