import Combine
import Factory
import Foundation
import StockPlanShared

@MainActor
final class InsightsViewModel: ObservableObject {
    enum CardState: Equatable {
        case idle
        case loading
        case loaded(AIInsightCardResponse)
        case failed(String)
    }

    @Published private(set) var states: [AIInsightKind: CardState] = [:]

    private let service: any AIInsightsServicing

    init(service: any AIInsightsServicing = Container.shared.aiInsightsService()) {
        self.service = service
    }

    func state(for kind: AIInsightKind) -> CardState {
        states[kind] ?? .idle
    }

    /// Generate a card on demand. Insight cards are not auto-loaded on appear so
    /// each LLM call is an explicit user action — bounding cost.
    func generate(_ kind: AIInsightKind) async {
        states[kind] = .loading
        do {
            let card = try await service.generate(kind: kind)
            states[kind] = .loaded(card)
        } catch {
            states[kind] = .failed(error.localizedDescription)
        }
    }
}
