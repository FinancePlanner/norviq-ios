import SwiftUI

struct OnboardingGoalScreen: View {
  @Binding var selectedGoal: OnboardingGoal?
  let onContinue: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 16) {
          OnboardingQuestionHeader(
            watch: .wealthPlan,
            title: "What brings you to Norviq?",
            subtitle: "We'll tailor what you see next."
          )

          VStack(spacing: 10) {
            ForEach(OnboardingGoal.allCases) { goal in
              OnboardingSelectableRow(
                emoji: goal.emoji,
                title: goal.title,
                isSelected: selectedGoal == goal,
                isMultiSelect: false,
                action: { selectedGoal = goal }
              )
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
      }

      if selectedGoal != nil {
        OnboardingActionBar(
          primaryTitle: "Continue",
          showsArrow: true,
          onPrimary: onContinue
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .appAnimation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedGoal)
  }
}
