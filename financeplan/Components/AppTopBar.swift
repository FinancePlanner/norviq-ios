import SwiftUI

struct AppTopBar: View {
    let username: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                // Logo circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.40, blue: 0.95),
                                Color(red: 0.30, green: 0.58, blue: 1.00),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("FP")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    )

                // App name
                Text("FinPlanner")
                    .typography(.label, weight: .bold)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.navBarForeground(for: colorScheme))
            }

            Spacer()

            // Username badge
            HStack(spacing: 5) {
                Circle()
                    .fill(AppTheme.Colors.tint(for: colorScheme).opacity(0.2))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                    )

                Text(username)
                    .typography(.nano, weight: .medium)
                    .foregroundStyle(
                        AppTheme.Colors.navBarForeground(for: colorScheme).opacity(0.7)
                    )
                    .lineLimit(1)
            }
        }
        .padding(.leading, 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            AppTheme.Colors.navBarBackground(for: colorScheme)
                .opacity(0.95)
                .blur(radius: 0)
        )
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    AppTheme.Colors.navBarForeground(for: colorScheme).opacity(0.10),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 1)
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.Colors.navBarBackground(for: colorScheme), for: .navigationBar)
    }
}
