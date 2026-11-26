import Factory
import Foundation
import Observation

/// State behind the "Import from broker" sheet: which broker, which portfolio.
@Observable @MainActor
final class BrokerImportViewModel {
  var selectedBrokerId: String = BrokerImportCatalog.brokers[0].id
  private(set) var portfolios: [PortfolioListDTOResponse] = []
  /// The portfolio imports go into. Nil only until the list has loaded and
  /// when the user arrived with no portfolio, which the backend reads as
  /// "the default list".
  var selectedPortfolioListId: String?

  private let allowsAskQ: Bool
  private let loadPortfolios: () async throws -> [PortfolioListDTOResponse]

  /// - Parameters:
  ///   - initialPortfolioListId: the portfolio the user came from, if any.
  ///   - allowsAskQ: false where Q is not on screen (onboarding).
  init(
    initialPortfolioListId: String?,
    allowsAskQ: Bool,
    loadPortfolios: @escaping () async throws -> [PortfolioListDTOResponse]
  ) {
    let trimmed = initialPortfolioListId?.trimmingCharacters(in: .whitespaces) ?? ""
    selectedPortfolioListId = trimmed.isEmpty ? nil : trimmed
    self.allowsAskQ = allowsAskQ
    self.loadPortfolios = loadPortfolios
  }

  convenience init(initialPortfolioListId: String?, allowsAskQ: Bool) {
    self.init(
      initialPortfolioListId: initialPortfolioListId,
      allowsAskQ: allowsAskQ,
      loadPortfolios: { try await Container.shared.stockService().fetchPortfolioLists() }
    )
  }

  var selectedBroker: BrokerGuide {
    BrokerImportCatalog.brokers.first { $0.id == selectedBrokerId } ?? BrokerImportCatalog.brokers[0]
  }

  var methods: [ImportMethod] {
    selectedBroker.methods.filter { allowsAskQ || $0 != .askQ }
  }

  var screenshotGuide: String {
    BrokerImportCatalog.screenshotGuide(for: selectedBroker)
  }

  /// Loads the portfolios and settles the selection: the one the user came
  /// from, else the default, else the first. On failure the initial id stays,
  /// so an import from a known portfolio still works.
  func load() async {
    guard let lists = try? await loadPortfolios() else { return }
    portfolios = lists
    if let current = selectedPortfolioListId, lists.contains(where: { $0.id == current }) { return }
    selectedPortfolioListId = (lists.first { $0.isDefault } ?? lists.first)?.id
  }
}
