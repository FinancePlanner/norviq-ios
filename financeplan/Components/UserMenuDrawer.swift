import SwiftUI

struct UserMenuDrawer: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var isPresented: Bool
  @Binding var showLogoutConfirmation: Bool
  let username: String
  let email: String?

  var body: some View {
    ZStack {
      if isPresented {
        Color.black.opacity(0.3)
          .ignoresSafeArea()
          .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
              isPresented = false
            }
          }
          .transition(.opacity)
      }

      HStack {
        Spacer()

        if isPresented {
          drawerContent
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
      }
    }
    .ignoresSafeArea()
  }

  private var drawerContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      headerSection
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 24)

      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          drawerRow(icon: "gearshape.fill", title: String(localized: "Settings")) {
            // Settings action
          }

          drawerRow(icon: "person.badge.shield.check.fill", title: String(localized: "Privacy & Security")) {
            // Privacy action
          }

          drawerRow(icon: "questionmark.circle.fill", title: String(localized: "Help & Support")) {
            // Help action
          }

          Divider()
            .padding(.vertical, 8)

          drawerRow(icon: "arrow.right.square.fill", title: String(localized: "Logout")) {
            showLogoutConfirmation = true
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
      }

      Spacer()
    }
    .frame(width: 280)
    .background {
      AppTheme.Colors.pageBackground(for: colorScheme)
        .overlay {
          MeshGradientBackground()
            .opacity(colorScheme == .dark ? 0.3 : 0.2)
        }
    }
    .clipShape(.rect(topLeadingRadius: 32, bottomLeadingRadius: 32))
    .shadow(color: .black.opacity(0.2), radius: 20, x: -10)
  }

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 12) {
        AppTheme.Colors.tint(for: colorScheme).opacity(0.18)
          .frame(width: 44, height: 44)
          .clipShape(.rect(cornerRadius: 14))
          .overlay {
            Image(systemName: "person.fill")
              .accessibilityHidden(true)
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          }

        VStack(alignment: .leading, spacing: 2) {
          Text(username)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)

          if let email {
            Text(email)
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      }

      AppTheme.Colors.tint(for: colorScheme).opacity(0.1)
        .frame(height: 1)
        .padding(.top, 4)
    }
  }

  private func drawerRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .accessibilityHidden(true)
          .frame(width: 22)
          .foregroundStyle(.primary.opacity(0.85))

        Text(title)
          .font(.system(size: 14, weight: .semibold, design: .rounded))
          .foregroundStyle(.primary)

        Spacer()

        Image(systemName: "chevron.right")
          .accessibilityHidden(true)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 12)
      .appGlassEffect(
        .rect(cornerRadius: 16),
        tint: .secondary.opacity(colorScheme == .dark ? 0.16 : 0.10),
        interactive: true
      )
    }
    .buttonStyle(.plain)
  }
}
