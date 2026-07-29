import SwiftUI
import UIKit

enum VigilNavigationAppearance {
  static func apply(colorScheme: ColorScheme) {
    let nav = UINavigationBarAppearance()
    nav.configureWithOpaqueBackground()
    nav.backgroundColor = UIColor(AppTheme.Colors.navBarBackground(for: colorScheme))
    nav.titleTextAttributes = [
      .foregroundColor: UIColor(AppTheme.Colors.foreground(for: colorScheme))
    ]
    nav.largeTitleTextAttributes = [
      .foregroundColor: UIColor(AppTheme.Colors.foreground(for: colorScheme))
    ]

    if BrandTheme.current == .vigil {
      nav.shadowColor = UIColor(AppTheme.Colors.tint(for: colorScheme).opacity(0.12))
    }

    UINavigationBar.appearance().standardAppearance = nav
    UINavigationBar.appearance().scrollEdgeAppearance = nav
    UINavigationBar.appearance().compactAppearance = nav
  }
}
