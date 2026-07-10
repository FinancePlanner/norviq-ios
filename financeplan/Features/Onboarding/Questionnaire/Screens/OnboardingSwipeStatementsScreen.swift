import SwiftUI

struct OnboardingSwipeStatementsScreen: View {
  let onSwipe: (_ index: Int, _ agreed: Bool) -> Void
  let onComplete: () -> Void

  static let statements: [String] = [
    "I have no idea what I spent on takeaway last month.",
    "I open my brokerage app, then close it, no wiser.",
    "I keep meaning to start a real budget.",
    "I'm probably overweight in one stock — but who knows.",
    "I have savings in three places and can't tell you the total."
  ]

  @State private var topIndex = 0
  @State private var dragTranslation: CGSize = .zero
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 8) {
        Text("Sound like you?")
          .typography(.title, weight: .bold)

        Text("Swipe right if it does, left if it doesn't.")
          .typography(.label)
          .foregroundStyle(.secondary)

        Text("\(min(topIndex + 1, Self.statements.count)) of \(Self.statements.count)")
          .typography(.caption, weight: .semibold)
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          .padding(.top, 4)
      }
      .padding(.top, 24)
      .padding(.horizontal, 24)

      Spacer(minLength: 24)

      cardStack
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)

      Spacer(minLength: 24)

      actionButtons
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
    }
  }

  // MARK: - Card stack

  private var cardStack: some View {
    ZStack {
      ForEach(visibleCardIndexes, id: \.self) { index in
        let isTop = index == topIndex
        SwipeCard(
          text: Self.statements[index],
          dragTranslation: isTop ? dragTranslation : .zero,
          stackOffset: index - topIndex,
          isTop: isTop
        )
        .gesture(isTop ? dragGesture : nil)
        .zIndex(Double(Self.statements.count - index))
      }
    }
    .frame(height: 360)
  }

  private var visibleCardIndexes: [Int] {
    let upper = min(topIndex + 3, Self.statements.count)
    guard topIndex < Self.statements.count else { return [] }
    return Array(topIndex..<upper).reversed()
  }

  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        dragTranslation = value.translation
      }
      .onEnded { value in
        let horizontal = value.translation.width
        let threshold: CGFloat = 110
        if horizontal > threshold {
          finishSwipe(agreed: true)
        } else if horizontal < -threshold {
          finishSwipe(agreed: false)
        } else {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            dragTranslation = .zero
          }
        }
      }
  }

  // MARK: - Action buttons

  private var actionButtons: some View {
    HStack(spacing: 24) {
      circleButton(systemName: "xmark", tint: AppTheme.Colors.danger) {
        finishSwipe(agreed: false)
      }

      circleButton(systemName: "checkmark", tint: AppTheme.Colors.success) {
        finishSwipe(agreed: true)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func circleButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.title2.weight(.bold))
        .foregroundStyle(.white)
        .frame(width: 64, height: 64)
        .background(Circle().fill(tint))
        .shadow(color: tint.opacity(0.35), radius: 10, y: 4)
    }
    .buttonStyle(PressableStyle())
    .disabled(topIndex >= Self.statements.count)
  }

  // MARK: - Actions

  private func finishSwipe(agreed: Bool) {
    guard topIndex < Self.statements.count else { return }
    let index = topIndex
    onSwipe(index, agreed)

    withAnimation(.easeOut(duration: 0.3)) {
      dragTranslation = CGSize(width: agreed ? 600 : -600, height: 0)
    }

    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(280))
      topIndex += 1
      dragTranslation = .zero
      if topIndex >= Self.statements.count {
        try? await Task.sleep(for: .milliseconds(220))
        onComplete()
      }
    }
  }
}

// MARK: - Card

private struct SwipeCard: View {
  let text: String
  let dragTranslation: CGSize
  let stackOffset: Int
  let isTop: Bool

  @Environment(\.colorScheme) private var colorScheme

  private var rotationDegrees: Double {
    Double(dragTranslation.width) / 18.0
  }

  var body: some View {
    GlassCard(cornerRadius: 28) {
      VStack(spacing: 20) {
        Spacer()
        if isTop {
          Text("\u{201C}\(text)\u{201D}")
            .typography(.title, weight: .semibold)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.vertical, 24)
    }
    .frame(height: 320)
    .overlay(alignment: .topLeading) {
      stamp(text: "NO", color: AppTheme.Colors.danger, visible: dragTranslation.width < 0)
        .padding(20)
    }
    .overlay(alignment: .topTrailing) {
      stamp(text: "YES", color: AppTheme.Colors.success, visible: dragTranslation.width > 0)
        .padding(20)
    }
    .scaleEffect(stackOffset == 0 ? 1.0 : (1.0 - CGFloat(stackOffset) * 0.04))
    .offset(y: CGFloat(stackOffset) * 18)
    .offset(dragTranslation)
    .rotationEffect(.degrees(rotationDegrees))
  }

  @ViewBuilder
  private func stamp(text: String, color: Color, visible: Bool) -> some View {
    Text(text)
      .typography(.label, weight: .bold)
      .foregroundStyle(color)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .stroke(color, lineWidth: 2.5)
      }
      .opacity(visible ? agreementOpacity : 0)
  }

  private var agreementOpacity: Double {
    min(Double(abs(dragTranslation.width)) / 120.0, 1.0)
  }
}
