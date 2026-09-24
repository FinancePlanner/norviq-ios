import SwiftUI

// Anchors, not named coordinate spaces: across a tab or sheet boundary a named
// space silently resolves to window coordinates. A tab the user has left keeps
// publishing stale anchors, so every key carries the tab its view lives on, and
// the overlay only reads the active tab's keys. Anchors raised inside a
// presented sheet or cover never reach an overlay outside it.

nonisolated struct GuidedAnchorID: Hashable, Sendable {
  let tab: GuidedTab
  let target: GuidedTarget
}

nonisolated enum GuidedAnchorKey: PreferenceKey {
  static let defaultValue: [GuidedAnchorID: Anchor<CGRect>] = [:]

  static func reduce(value: inout [GuidedAnchorID: Anchor<CGRect>], nextValue: () -> [GuidedAnchorID: Anchor<CGRect>]) {
    value.merge(nextValue()) { _, new in new }
  }
}

extension View {
  /// Publishes this view's bounds as `target` on `tab` — the tab it lives on,
  /// a constant at every call site. Mark the smallest view that is the control.
  func guidedTarget(_ target: GuidedTarget, in tab: GuidedTab) -> some View {
    anchorPreference(key: GuidedAnchorKey.self, value: .bounds) { anchor in
      [GuidedAnchorID(tab: tab, target: target): anchor]
    }
  }
}

extension Dictionary where Key == GuidedAnchorID, Value == Anchor<CGRect> {
  /// The first of `targets` present on `tab`, or nil.
  func anchor(for targets: [GuidedTarget], on tab: GuidedTab?) -> Anchor<CGRect>? {
    guard let tab else { return nil }
    return targets.lazy.compactMap { self[GuidedAnchorID(tab: tab, target: $0)] }.first
  }
}
