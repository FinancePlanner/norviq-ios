import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var ctaLabel: String? = nil
    var onCTA: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        } actions: {
            if let ctaLabel, let onCTA {
                Button(ctaLabel, action: onCTA)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.tint(for: colorScheme))
            }
        }
    }
}
