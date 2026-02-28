import Combine
import SwiftUI

@MainActor
final class OnboardingImportViewModel: ObservableObject {
  enum Step: Hashable {
    case chooseMethod
    case csv
    case manual
    case api
    case done
  }

  @Published var step: Step = .chooseMethod

  func select(_ method: StockImportMethod) {
    switch method {
    case .csv:
      step = .csv
    case .manual:
      step = .manual
    case .api:
      step = .api
    }
  }

  func backToChoose() { step = .chooseMethod }
  func finish() { step = .done }
}
