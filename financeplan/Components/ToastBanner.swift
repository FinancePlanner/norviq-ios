import SwiftUI

struct ToastBanner: View {
  enum Style {
    case success
    case error
    case info

    var iconName: String {
      switch self {
      case .success:
        return "checkmark.circle.fill"
      case .error:
        return "exclamationmark.triangle.fill"
      case .info:
        return "info.circle.fill"
      }
    }

    func foreground(for scheme: ColorScheme) -> Color {
      switch self {
      case .success:
        return AppTheme.Colors.success
      case .error:
        return AppTheme.Colors.danger
      case .info:
        return AppTheme.Colors.ember(for: scheme)
      }
    }

    func background(for scheme: ColorScheme) -> Color {
      foreground(for: scheme).opacity(0.14)
    }
  }

  let message: String
  let style: Style
  @Environment(\.colorScheme) private var colorScheme
  @AccessibilityFocusState private var isAccessibilityFocused: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      Image(systemName: style.iconName)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(style.foreground(for: colorScheme))

      Text(message)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(style.foreground(for: colorScheme))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .appGlassEffect(.capsule, tint: style.background(for: colorScheme))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text(accessibilityAnnouncement))
    .accessibilityHint(Text("Temporary message."))
    .accessibilityAddTraits(.isStaticText)
    .accessibilityFocused($isAccessibilityFocused)
    .accessibilitySortPriority(1)
    .onAppear {
      Task { @MainActor in
        await Task.yield()
        isAccessibilityFocused = true
      }
    }
  }

  private var accessibilityAnnouncement: String {
    switch style {
    case .success:
      "Success. \(message)"
    case .error:
      "Error. \(message)"
    case .info:
      "Info. \(message)"
    }
  }
}
