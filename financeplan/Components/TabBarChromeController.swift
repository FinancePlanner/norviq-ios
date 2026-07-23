import Observation
import SwiftUI

/// Shared chrome for the floating Revolut-style tab bar.
/// Child scroll views call ``noteScrolling()`` so the bar can shrink;
/// idle / focus expands it again.
@Observable
@MainActor
final class TabBarChromeController {
  private(set) var isMinimized = false
  private var expandTask: Task<Void, Never>?

  func noteScrolling() {
    expandTask?.cancel()
    guard !isMinimized else { return }
    withAnimation(AppMotion.tabBar) {
      isMinimized = true
    }
  }

  /// Expand after scroll settles (or sooner via ``expand()`` on focus).
  func scheduleExpand(after delay: Duration = .milliseconds(280)) {
    expandTask?.cancel()
    expandTask = Task { @MainActor in
      try? await Task.sleep(for: delay)
      guard !Task.isCancelled else { return }
      expand()
    }
  }

  func expand() {
    expandTask?.cancel()
    guard isMinimized else { return }
    withAnimation(AppMotion.tabBar) {
      isMinimized = false
    }
  }
}

private struct TabBarChromeControllerKey: EnvironmentKey {
  static let defaultValue: TabBarChromeController? = nil
}

extension EnvironmentValues {
  var tabBarChrome: TabBarChromeController? {
    get { self[TabBarChromeControllerKey.self] }
    set { self[TabBarChromeControllerKey.self] = newValue }
  }
}

extension View {
  /// Shrink floating tab bar while this scroll view is interacting.
  func tracksTabBarMinimize() -> some View {
    modifier(TabBarScrollMinimizeModifier())
  }
}

private struct TabBarScrollMinimizeModifier: ViewModifier {
  @Environment(\.tabBarChrome) private var chrome

  func body(content: Content) -> some View {
    content
      .onScrollPhaseChange { _, phase in
        guard let chrome else { return }
        switch phase {
        case .interacting, .decelerating:
          chrome.noteScrolling()
        case .idle:
          chrome.scheduleExpand()
        @unknown default:
          break
        }
      }
  }
}
