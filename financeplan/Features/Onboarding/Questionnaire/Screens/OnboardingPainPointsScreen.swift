import SwiftUI

struct OnboardingPainPointsScreen: View {
  @Binding var selectedPainPoints: Set<OnboardingPainPoint>
  let onContinue: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 16) {
          VStack(spacing: 10) {
            Text("What's been getting in the way?")
              .typography(.title, weight: .bold)
              .multilineTextAlignment(.center)

            Text("Pick all that apply.")
              .typography(.label)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
          .padding(.top, 24)
          .padding(.bottom, 8)

          VStack(spacing: 10) {
            ForEach(OnboardingPainPoint.allCases) { pain in
              OnboardingSelectableRow(
                emoji: pain.emoji,
                title: pain.title,
                isSelected: selectedPainPoints.contains(pain),
                isMultiSelect: true,
                action: {
                  if selectedPainPoints.contains(pain) {
                    selectedPainPoints.remove(pain)
                  } else {
                    selectedPainPoints.insert(pain)
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
        isEnabled: !selectedPainPoints.isEmpty,
        showsArrow: true,
        onPrimary: onContinue
      )
    }
  }
}
