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

    var foreground: Color {
      switch self {
      case .success:
        return Color.green
      case .error:
        return Color.red
      case .info:
        return Color.blue
      }
    }

    var background: Color {
      switch self {
      case .success:
        return Color.green.opacity(0.14)
      case .error:
        return Color.red.opacity(0.14)
      case .info:
        return Color.blue.opacity(0.14)
      }
    }
  }

  let message: String
  let style: Style
  @AccessibilityFocusState private var isAccessibilityFocused: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      Image(systemName: style.iconName)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(style.foreground)

      Text(message)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(style.foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(
      Capsule()
        .fill(style.background)
    )
    .overlay(
      Capsule()
        .stroke(style.foreground.opacity(0.35), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
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
