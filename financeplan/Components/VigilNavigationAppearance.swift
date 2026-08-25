import SwiftUI
import UIKit

enum VigilNavigationAppearance {
  /// - Note: `colorScheme` is no longer read. The appearance is built from
  ///   dynamic `UIColor`s, so UIKit resolves light/dark itself. The parameter and
  ///   the re-apply on scheme change are kept because the *brand* still has to be
  ///   resolved in Swift, and that is not something UIKit can track.
  static func apply(colorScheme _: ColorScheme) {
    let nav = UINavigationBarAppearance()
    nav.configureWithOpaqueBackground()
    nav.backgroundColor = AppTheme.Colors.uiNavBarBackground
    nav.titleTextAttributes = [.foregroundColor: AppTheme.Colors.uiForeground]
    nav.largeTitleTextAttributes = [.foregroundColor: AppTheme.Colors.uiForeground]

    // The nav bar's bottom rule is a separator, not an accent. It used to be
    // tint at 12%, which put a cyan line under every navigation bar.
    nav.shadowColor = AppTheme.Colors.uiSeparator

    UINavigationBar.appearance().standardAppearance = nav
    UINavigationBar.appearance().scrollEdgeAppearance = nav
    UINavigationBar.appearance().compactAppearance = nav
  }
}
