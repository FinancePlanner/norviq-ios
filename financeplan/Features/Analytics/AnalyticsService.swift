import AmplitudeUnified
import Factory
import Foundation
import PostHog

@MainActor
final class AnalyticsService {
    let amplitude: Amplitude
    
    init() {
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "AmplitudeAPIKey") as? String ?? ""
        self.amplitude = Amplitude(apiKey: apiKey, serverZone: .EU)
    }
    
    func track(_ event: String, properties: [String: Any] = [:]) {
        amplitude.track(eventType: event)
        PostHogSDK.shared.capture(event, properties: properties.isEmpty ? nil : properties)
    }
}
