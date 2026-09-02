import SwiftUI

struct CGRectValuePreferenceKey: PreferenceKey {
  static var defaultValue: CGRect { .zero }

  static func reduce(value: inout Value, nextValue: () -> Value) {
    value = nextValue()
  }
}
