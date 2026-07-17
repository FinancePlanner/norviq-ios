import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var ctaLabel: String? = nil
    var onCTA: (() -> Void)? = nil
    /// When true, shows the Cerberus head brand mark instead of the SF symbol.
    /// Use for signature empty states (portfolio, ledger, assistant).
    var usesBrandIcon: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                if usesBrandIcon {
                    // Monoline template mark; tinted per brand theme.
                    Image("CerberusHeadIcon")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: icon)
                }
            }
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
