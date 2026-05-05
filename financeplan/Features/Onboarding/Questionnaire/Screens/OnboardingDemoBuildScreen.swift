import SwiftUI

struct OnboardingDemoBuildScreen: View {
  let holdingsHint: Set<OnboardingHoldingType>
  let onPick: (String) -> Void
  /// Called when the user has picked 3 tickers OR exhausted the deck without picking 3.
  /// `picks` is the list of selected ticker symbols, in pick order.
  /// `usedFallback` is true when the deck was exhausted with fewer than 3 picks.
  let onComplete: (_ picks: [String], _ usedFallback: Bool) -> Void

  static let targetPickCount = 3

  @State private var deck: [OnboardingDemoTicker] = []
  @State private var topIndex = 0
  @State private var picks: [String] = []
  @State private var dragTranslation: CGSize = .zero
  @State private var fallbackBanner: String?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.top, 16)
        .padding(.horizontal, 24)

      if let fallbackBanner {
        Text(fallbackBanner)
          .typography(.caption, weight: .medium)
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(AppTheme.Colors.tintSoft(for: colorScheme))
          .transition(.opacity)
      }

      Spacer(minLength: 12)

      cardStack
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)

      Spacer(minLength: 16)

      actionButtons
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }
    .onAppear {
      if deck.isEmpty {
        deck = OnboardingDemoTickers.ordered(forHoldings: holdingsHint)
      }
    }
  }

  // MARK: - Header

  @ViewBuilder
  private var header: some View {
    VStack(spacing: 6) {
      Text("Pick 3 to start your sample portfolio.")
        .typography(.title, weight: .bold)
        .multilineTextAlignment(.center)

      Text("Swipe right to add. Left to skip.")
        .typography(.label)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      counter
        .padding(.top, 4)
    }
  }

  private var counter: some View {
    let remaining = max(Self.targetPickCount - picks.count, 0)
    let label: String = {
      switch remaining {
      case 0: return "Done"
      case 1: return "Pick 1 more"
      case 2: return "Pick 2 more"
      default: return "Pick 3 more"
      }
    }()
    return Text(label)
      .typography(.caption, weight: .bold)
      .foregroundStyle(.white)
      .padding(.horizontal, 14)
      .padding(.vertical, 6)
      .background(Capsule().fill(AppTheme.Colors.tint(for: colorScheme)))
  }

  // MARK: - Card stack

  private var cardStack: some View {
    ZStack {
      ForEach(visibleCardIndexes, id: \.self) { index in
        let isTop = index == topIndex
        TickerSwipeCard(
          ticker: deck[index],
          dragTranslation: isTop ? dragTranslation : .zero,
          stackOffset: index - topIndex
        )
        .gesture(isTop ? dragGesture : nil)
        .zIndex(Double(deck.count - index))
      }
    }
    .frame(height: 380)
  }

  private var visibleCardIndexes: [Int] {
    guard topIndex < deck.count else { return [] }
    let upper = min(topIndex + 3, deck.count)
    return Array(topIndex..<upper).reversed()
  }

  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged { value in dragTranslation = value.translation }
      .onEnded { value in
        let threshold: CGFloat = 110
        if value.translation.width > threshold {
          finishSwipe(adding: true)
        } else if value.translation.width < -threshold {
          finishSwipe(adding: false)
        } else {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            dragTranslation = .zero
          }
        }
      }
  }

  // MARK: - Buttons

  private var actionButtons: some View {
    HStack(spacing: 24) {
      circleButton(systemName: "xmark", tint: AppTheme.Colors.danger.opacity(0.85)) {
        finishSwipe(adding: false)
      }

      circleButton(systemName: "plus", tint: AppTheme.Colors.success) {
        finishSwipe(adding: true)
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
    .buttonStyle(PressEffectStyle())
    .disabled(topIndex >= deck.count)
  }

  // MARK: - Actions

  private func finishSwipe(adding: Bool) {
    guard topIndex < deck.count else { return }
    let ticker = deck[topIndex]

    if adding {
      picks.append(ticker.symbol)
      onPick(ticker.symbol)
    }

    withAnimation(.easeOut(duration: 0.3)) {
      dragTranslation = CGSize(width: adding ? 600 : -600, height: 0)
    }

    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(280))
      topIndex += 1
      dragTranslation = .zero

      if picks.count >= Self.targetPickCount {
        try? await Task.sleep(for: .milliseconds(200))
        onComplete(picks, false)
        return
      }

      if topIndex >= deck.count {
        // Deck exhausted with fewer than 3 picks → fallback seed.
        fallbackBanner = "We'll start you with three popular ones."
        try? await Task.sleep(for: .milliseconds(900))
        onComplete(OnboardingDemoTickers.fallbackPicks, true)
      }
    }
  }
}

// MARK: - Card

private struct TickerSwipeCard: View {
  let ticker: OnboardingDemoTicker
  let dragTranslation: CGSize
  let stackOffset: Int
  @Environment(\.colorScheme) private var colorScheme

  private var rotationDegrees: Double { Double(dragTranslation.width) / 18.0 }
  private var stampOpacity: Double { min(Double(abs(dragTranslation.width)) / 120.0, 1.0) }

  var body: some View {
    GlassCard(cornerRadius: 28) {
      VStack(alignment: .leading, spacing: 18) {
        HStack(spacing: 12) {
          ZStack {
            Circle()
              .fill(AppTheme.Colors.tintSoft(for: colorScheme))
              .frame(width: 44, height: 44)
            Image(systemName: ticker.glyphSystemName)
              .font(.title3.weight(.bold))
              .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          }

          VStack(alignment: .leading, spacing: 2) {
            Text(ticker.symbol)
              .typography(.label, weight: .bold)
            Text(ticker.name)
              .typography(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          Spacer()
        }

        Text(ticker.blurb)
          .typography(.label, weight: .medium)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)

        SparklinePath(values: ticker.sparkline)
          .stroke(
            AppTheme.Colors.tint(for: colorScheme),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
          )
          .frame(height: 56)

        HStack(spacing: 8) {
          ForEach(ticker.tags, id: \.self) { tag in
            Text(tag)
              .typography(.nano, weight: .semibold)
              .padding(.horizontal, 10)
              .padding(.vertical, 5)
              .background(Capsule().fill(AppTheme.Colors.tintSoft(for: colorScheme)))
              .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          }
          Spacer()
        }
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 4)
    }
    .frame(height: 360)
    .overlay(alignment: .topLeading) {
      stamp("SKIP", color: AppTheme.Colors.danger, visible: dragTranslation.width < 0)
        .padding(20)
    }
    .overlay(alignment: .topTrailing) {
      stamp("ADD", color: AppTheme.Colors.success, visible: dragTranslation.width > 0)
        .padding(20)
    }
    .scaleEffect(stackOffset == 0 ? 1.0 : (1.0 - CGFloat(stackOffset) * 0.04))
    .offset(y: CGFloat(stackOffset) * 10)
    .offset(dragTranslation)
    .rotationEffect(.degrees(rotationDegrees))
  }

  @ViewBuilder
  private func stamp(_ text: String, color: Color, visible: Bool) -> some View {
    Text(text)
      .typography(.label, weight: .bold)
      .foregroundStyle(color)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .stroke(color, lineWidth: 2.5)
      }
      .opacity(visible ? stampOpacity : 0)
  }
}
