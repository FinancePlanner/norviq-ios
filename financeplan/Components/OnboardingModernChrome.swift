import SwiftUI

/// Shared onboarding-modern header: WATCH kicker + title + subtitle under Vigil.
struct OnboardingQuestionHeader: View {
  @Environment(\.colorScheme) private var scheme

  let watch: VigilWatch
  let title: LocalizedStringKey
  let subtitle: LocalizedStringKey?

  init(
    watch: VigilWatch,
    title: LocalizedStringKey,
    subtitle: LocalizedStringKey? = nil
  ) {
    self.watch = watch
    self.title = title
    self.subtitle = subtitle
  }

  var body: some View {
    VStack(spacing: 10) {
      if BrandTheme.current == .vigil {
        Text(watch.eyebrow)
          .vigilOverline()
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      Text(title)
        .typography(.title, weight: .bold)
        .multilineTextAlignment(.center)

      if let subtitle {
        Text(subtitle)
          .typography(.label)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.top, 24)
    .padding(.bottom, 8)
  }
}

extension View {
  /// Glass step card on Vigil; unchanged on Classic.
  func onboardingStepCard(cornerRadius: CGFloat = 24) -> some View {
    Group {
      if BrandTheme.current == .vigil {
        GlassCard(cornerRadius: cornerRadius, padding: 0) {
          self
            .padding(20)
        }
      } else {
        self
      }
    }
  }
}
