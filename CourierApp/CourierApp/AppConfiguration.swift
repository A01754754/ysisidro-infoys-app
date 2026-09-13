import Foundation

enum AppConfiguration {
    static var dev2StateURL: URL? {
        configuredURL(forInfoDictionaryKey: "DEV2_STATE_URL")
    }

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

    private static func configuredURL(
        forInfoDictionaryKey key: String
    ) -> URL? {
        guard let value = Bundle.main.object(
            forInfoDictionaryKey: key
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

        return URL(string: trimmedValue)
    }
}
