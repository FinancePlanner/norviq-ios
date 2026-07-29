import SwiftUI

struct OnboardingPainPointsScreen: View {
  @Binding var selectedPainPoints: Set<OnboardingPainPoint>
  let onContinue: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 16) {
          OnboardingQuestionHeader(
            watch: .wealthPlan,
            title: "What's been getting in the way?",
            subtitle: "Pick all that apply."
          )

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
