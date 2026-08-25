import SwiftUI

extension View {
  /// Command Center canvas — mesh blooms on Vigil, flat page bg on Classic.
  func vigilScreenBackground(animated: Bool = false) -> some View {
    background {
      MeshGradientBackground(animatesOnAppear: animated)
    }
  }

  /// List screens: hide system chrome, use Vigil card rows when active.
  func vigilListChrome() -> some View {
    modifier(VigilListChromeModifier())
  }

  /// Inline nav title suppressed under Vigil when using in-content `VigilPageHeader`.
  func vigilNavigationTitle(_ title: LocalizedStringKey) -> some View {
    navigationTitle("")
  }

  func vigilNavigationTitle(_ title: String) -> some View {
    navigationTitle(VigilNavigationTitle.display(title))
  }

  func vigilInlineNavigationBar() -> some View {
    navigationBarTitleDisplayMode(.inline)
  }
}

private struct VigilListChromeModifier: ViewModifier {
  @Environment(\.colorScheme) private var scheme

  func body(content: Content) -> some View {
    content
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
  }
}

