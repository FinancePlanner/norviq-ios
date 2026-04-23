//
//  UserMenuDrawer.swift
//  financeplan
//
//  Created by Fernando Correia on 04.03.26.
//

import SwiftUI

struct UserMenuDrawer: View {
  @Binding var isPresented: Bool
  let username: String

  let onProfile: (() -> Void)?
  let onNotifications: (() -> Void)?
  let onHelp: (() -> Void)?
  let onAbout: (() -> Void)?
  let onSettings: (() -> Void)?
  let onSignOut: (() -> Void)?

  init(
    isPresented: Binding<Bool>,
    username: String,
    onProfile: (() -> Void)? = nil,
    onNotifications: (() -> Void)? = nil,
    onHelp: (() -> Void)? = nil,
    onAbout: (() -> Void)? = nil,
    onSettings: (() -> Void)? = nil,
    onSignOut: (() -> Void)? = nil
  ) {
    self._isPresented = isPresented
    self.username = username
    self.onProfile = onProfile
    self.onNotifications = onNotifications
    self.onHelp = onHelp
    self.onAbout = onAbout
    self.onSettings = onSettings
    self.onSignOut = onSignOut
  }

  @Environment(\.colorScheme) private var colorScheme
  @GestureState private var dragY: CGFloat = 0

  private let height: CGFloat = 420

  var body: some View {
    VStack(spacing: 12) {
      Capsule()
        .fill(.secondary.opacity(0.35))
        .frame(width: 42, height: 5)
        .padding(.top, 10)

      HStack(spacing: 12) {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(AppTheme.Colors.tint(for: colorScheme).opacity(0.18))
          .frame(width: 44, height: 44)
          .overlay(
            Image(systemName: "person.fill")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          )

        VStack(alignment: .leading, spacing: 2) {
          Text(username)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
          Text("View profile")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 12, weight: .semibold))
            .padding(10)
            .appGlassEffect(.circle, tint: .secondary.opacity(0.12), interactive: true)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 16)

      Divider().opacity(0.6)

      VStack(spacing: 8) {
          drawerRow(icon: "person", title: "Profile") {
            dismiss()
            onProfile?()
          }
          drawerRow(icon: "bell", title: "Notifications") {
            dismiss()
            onNotifications?()
          }
          drawerRow(icon: "questionmark.circle", title: "Help & Support") {
            dismiss()
            onHelp?()
          }
          drawerRow(icon: "info.circle", title: "About Norviqa") {
            dismiss()
            onAbout?()
          }
          drawerRow(icon: "gearshape", title: "Settings") {
            dismiss()
            onSettings?()
          }
          drawerRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign out") {
            dismiss()
            onSignOut?()
          }
      }
      .padding(.horizontal, 10)

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity)
    .frame(height: height, alignment: .top)
    .appGlassEffect(.rect(cornerRadius: 24))
    .padding(.horizontal, 10)
    .padding(.bottom, 10)
    .frame(maxHeight: .infinity, alignment: .bottom)
    .offset(y: max(0, dragY))
    .gesture(
      DragGesture()
        .updating($dragY) { value, state, _ in
          state = value.translation.height
        }
        .onEnded { value in
          if value.translation.height > 120 {
            dismiss()
          }
        }
    )
    .animation(.spring(response: 0.28, dampingFraction: 0.9), value: dragY)
  }

  private func dismiss() {
    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
      isPresented = false
    }
  }

  private func drawerRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .frame(width: 22)
          .foregroundStyle(.primary.opacity(0.85))

        Text(title)
          .font(.system(size: 14, weight: .semibold, design: .rounded))
          .foregroundStyle(.primary)

        Spacer()

        Image(systemName: "chevron.right")
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
