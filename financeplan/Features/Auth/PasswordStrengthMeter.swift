import SwiftUI

struct PasswordStrengthMeter: View {
  let score: Int
  let strength: AuthValidation.PasswordStrength
  @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        ForEach(0..<5, id: \.self) { index in
          Capsule()
            .fill(index < score ? barColor : Color(white: 0.85))
            .frame(height: 6)
        }
      }

      HStack(spacing: 6) {
        if differentiateWithoutColor {
          Image(systemName: strengthIcon)
            .foregroundStyle(barColor)
        }

        Text("Password strength: \(strengthLabel)")
          .font(.caption.weight(.medium))
          .foregroundStyle(strengthTextColor)
      }
    }
  }

  private var barColor: Color {
    switch strength {
    case .weak: AppTheme.Colors.danger
    case .medium: AppTheme.Colors.warning
    case .strong: AppTheme.Colors.success
    }
  }

  private var strengthTextColor: Color {
    switch strength {
    case .weak: AppTheme.Colors.danger
    case .medium: AppTheme.Colors.warning
    case .strong: AppTheme.Colors.success
    }
  }

  private var strengthLabel: String {
    switch strength {
    case .weak: "Weak"
    case .medium: "Medium"
    case .strong: "Strong"
    }
  }

  private var strengthIcon: String {
    switch strength {
    case .weak: "exclamationmark.triangle.fill"
    case .medium: "checkmark.circle"
    case .strong: "checkmark.seal.fill"
    }
  }
}
