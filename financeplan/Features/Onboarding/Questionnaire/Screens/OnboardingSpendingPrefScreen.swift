import SwiftUI

struct OnboardingSpendingPrefScreen: View {
  @Binding var selectedLeaks: Set<OnboardingSpendingLeak>
  let onContinue: () -> Void

  private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 16) {
          OnboardingQuestionHeader(
            watch: .spending,
            title: "Where does your money tend to leak?",
            subtitle: "Be honest — we won't tell."
          )

          LazyVGrid(columns: columns, spacing: 12) {
            ForEach(OnboardingSpendingLeak.allCases) { leak in
              OnboardingSelectableTile(
                emoji: leak.emoji,
                title: leak.title,
                isSelected: selectedLeaks.contains(leak),
                action: {
                  if selectedLeaks.contains(leak) {
                    selectedLeaks.remove(leak)
                  } else {
                    selectedLeaks.insert(leak)
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
        isEnabled: !selectedLeaks.isEmpty,
        showsArrow: true,
        onPrimary: onContinue
      )
    }
  }
}
