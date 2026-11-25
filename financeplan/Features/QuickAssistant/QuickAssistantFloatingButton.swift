import SwiftUI

/// Q below iOS 26: Vig's star, resting at the bottom trailing corner of the
/// tab's content. The tab bar is outside that content, so the safe area keeps
/// the button above it.
struct QuickAssistantFloatingButton: View {
    let actions: QEntryActions

    var body: some View {
        QEntryButton(actions: actions) {
            QuickAssistantMascotStar()
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .padding(.trailing, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        // The keyboard covers it, rather than lifting it over a form's fields.
        .ignoresSafeArea(.keyboard)
    }
}

/// Vig's face inside a four-point star, with the assistant's small sparkles beside
/// it. The star stays light in dark mode, because Vig is navy and would disappear.
private struct QuickAssistantMascotStar: View {
    var body: some View {
        ZStack {
            FourPointStar(waist: 0.3)
                .fill(Color(red: 0.99, green: 0.98, blue: 0.95))
            Image("VigIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .offset(y: 5)
                .clipShape(FourPointStar(waist: 0.3))
            FourPointStar(waist: 0.3)
                .stroke(AppTheme.Colors.tint, lineWidth: 1.5)
            FourPointStar(waist: 0.2)
                .fill(AppTheme.Colors.tint)
                .frame(width: 13, height: 13)
                .offset(x: -24, y: -24)
            FourPointStar(waist: 0.2)
                .fill(AppTheme.Colors.tint)
                .frame(width: 8, height: 8)
                .offset(x: -14, y: -30)
        }
    }
}
