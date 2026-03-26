import Combine
import Factory
import Foundation

@MainActor
final class AssetSearchViewModel: ObservableObject {
  @Published var query = ""
  @Published private(set) var results: [AssetSearchResult] = []
  @Published private(set) var isLoading = false
  @Published var errorMessage: String?

  private let service: AssetSearchServicing
  private var searchTask: Task<Void, Never>?

  init(service: AssetSearchServicing) {
    self.service = service
  }

  convenience init() {
    self.init(service: Container.shared.assetSearchService())
  }

  deinit {
    searchTask?.cancel()
  }

  func queryChanged() {
    searchTask?.cancel()

    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 2 else {
      results = []
      errorMessage = nil
      return
    }

    searchTask = Task {
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled else { return }
      await search(trimmed)
    }
  }

  func searchNow() async {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    await search(trimmed)
  }

  private func search(_ query: String) async {
    guard query.count >= 2 else {
      results = []
      errorMessage = nil
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      results = try await service.searchAssets(query: query)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
