import SwiftUI

struct CGRectValuePreferenceKey: PreferenceKey {
  nonisolated(unsafe) static var defaultValue: CGRect = .zero

  static func reduce(value: inout Value, nextValue: () -> Value) {
    value = nextValue()
  }
}
