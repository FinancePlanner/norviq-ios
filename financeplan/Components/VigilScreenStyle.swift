import SwiftUI

extension View {
  /// Command Center canvas — mesh blooms on Vigil, flat page bg on Classic.
  func vigilScreenBackground(animated: Bool = false) -> some View {
    background {
      if BrandTheme.current == .vigil {
        MeshGradientBackground(animatesOnAppear: animated)
      } else {
        Color.clear
      }
    }
  }

  /// List screens: hide system chrome, use Vigil card rows when active.
  func vigilListChrome() -> some View {
    modifier(VigilListChromeModifier())
  }

  /// Inline nav title suppressed under Vigil when using in-content `VigilPageHeader`.
  func vigilNavigationTitle(_ title: LocalizedStringKey) -> some View {
    navigationTitle(BrandTheme.current == .vigil ? "" : title)
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

/// Terminal line styling for MCP / status readouts.
struct VigilTerminalLine: View {
  @Environment(\.colorScheme) private var scheme
  let text: String

  var body: some View {
    Text(text)
      .font(.caption.monospaced())
      .foregroundStyle(AppTheme.Colors.tint(for: scheme))
  }
}

/// Scope chip matching web MCP engine room.
struct VigilScopeChip: View {
  @Environment(\.colorScheme) private var scheme
  let label: String
  var isActive: Bool = true

  var body: some View {
    Text(label)
      .font(.caption2.weight(.semibold).monospaced())
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .foregroundStyle(
        isActive
          ? AppTheme.Colors.secondaryTint(for: scheme)
          : AppTheme.Colors.secondaryText(for: scheme)
      )
      .background(
        Capsule()
          .fill(AppTheme.Colors.secondaryTint(for: scheme).opacity(isActive ? 0.14 : 0.06))
          .overlay(
            Capsule()
              .stroke(
                AppTheme.Colors.secondaryTint(for: scheme).opacity(isActive ? 0.45 : 0.18),
                lineWidth: 1
              )
          )
      )
  }
}
