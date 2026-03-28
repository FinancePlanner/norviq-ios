import SwiftUI

extension View {
  func appSensoryFeedback(success: Int = 0, destructive: Int = 0) -> some View {
    self
      .sensoryFeedback(.success, trigger: success) { oldValue, newValue in
        newValue > oldValue
      }
      .sensoryFeedback(.warning, trigger: destructive) { oldValue, newValue in
        newValue > oldValue
      }
  }
}
