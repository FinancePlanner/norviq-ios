import SwiftUI

struct OnboardingHoldingsPrefScreen: View {
  @Binding var selectedHoldings: Set<OnboardingHoldingType>
  let onContinue: () -> Void

  private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 16) {
          VStack(spacing: 10) {
            Text("What do you currently invest in?")
              .typography(.title, weight: .bold)
              .multilineTextAlignment(.center)

            Text("Pick all that apply. We'll tailor your sample.")
              .typography(.label)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
          .padding(.top, 24)
          .padding(.bottom, 8)

          LazyVGrid(columns: columns, spacing: 12) {
            ForEach(OnboardingHoldingType.allCases) { holding in
              OnboardingSelectableTile(
                emoji: holding.emoji,
                title: holding.title,
                isSelected: selectedHoldings.contains(holding),
                action: {
                  if selectedHoldings.contains(holding) {
                    selectedHoldings.remove(holding)
                  } else {
                    selectedHoldings.insert(holding)
                  }
                }
              )
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
      }

      OnboardingActionBar(
        primaryTitle: "Continue",
        isEnabled: !selectedHoldings.isEmpty,
        showsArrow: true,
        onPrimary: onContinue
      )
    }
  }
}
