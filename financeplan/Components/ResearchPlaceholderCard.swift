import SwiftUI

struct ResearchPlaceholderCard: View {
    let title: String
    let bodyText: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .typography(.small, weight: .semibold)

                Text(bodyText)
                    .typography(.small)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
