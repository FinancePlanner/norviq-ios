import SwiftUI

/// TODO: replace placeholder testimonials with real beta-user reviews before App Store / TestFlight submission.
struct OnboardingSocialProofScreen: View {
  let onContinue: () -> Void

  private static let testimonials: [Testimonial] = [
    Testimonial(
      initials: "LK",
      name: "Lena K.",
      persona: "DIY index investor",
      quote: "I deleted three apps and a spreadsheet. Just this now."
    ),
    Testimonial(
      initials: "MR",
      name: "Marcus R.",
      persona: "Saver-investor",
      quote: "Found $180/month I didn't know was leaking. That's a real ETF contribution."
    ),
    Testimonial(
      initials: "PS",
      name: "Priya S.",
      persona: "Spreadsheet refugee",
      quote: "Finally see my full picture without doing maths in my head."
    )
  ]

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 16) {
          VStack(spacing: 10) {
            Text("You're in good company.")
              .typography(.title, weight: .bold)
              .multilineTextAlignment(.center)

            Text("Money-conscious investors track everything here.")
              .typography(.label)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 24)
          }
          .padding(.top, 24)
          .padding(.bottom, 8)

          ForEach(Self.testimonials) { testimonial in
            TestimonialCard(testimonial: testimonial)
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
      }

      OnboardingActionBar(primaryTitle: "Continue", onPrimary: onContinue)
    }
  }
}

private struct Testimonial: Identifiable {
  let id = UUID()
  let initials: String
  let name: String
  let persona: String
  let quote: String
}

private struct TestimonialCard: View {
  let testimonial: Testimonial
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GlassCard(cornerRadius: 22) {
      VStack(alignment: .leading, spacing: 12) {
        starsRow
        Text("“\(testimonial.quote)”")
          .typography(.label, weight: .medium)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 12) {
          ZStack {
            Circle()
              .fill(LinearGradient(colors: AppTheme.avatarGradient(for: colorScheme), startPoint: .topLeading, endPoint: .bottomTrailing))
              .frame(width: 36, height: 36)
            Text(testimonial.initials)
              .typography(.caption, weight: .bold)
              .foregroundStyle(.white)
          }
          VStack(alignment: .leading, spacing: 2) {
            Text(testimonial.name)
              .typography(.small, weight: .semibold)
            Text(testimonial.persona)
              .typography(.nano)
              .foregroundStyle(.secondary)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 4)
    }
  }

  private var starsRow: some View {
    HStack(spacing: 4) {
      ForEach(0..<5, id: \.self) { _ in
        Image(systemName: "star.fill")
          .font(.caption)
          .foregroundStyle(AppTheme.Colors.warning)
      }
    }
  }
}
