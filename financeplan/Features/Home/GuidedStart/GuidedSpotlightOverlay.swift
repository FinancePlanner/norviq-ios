import SwiftUI

nonisolated enum GuidedSpotlightGeometry {
  /// No anchor, no dim: a scrim with nothing to tap is a dead end.
  static func showsScrim(hole: CGRect?) -> Bool { hole != nil }
}

/// Blocks nothing, the same as the web: the scrim ignores hits, so the page
/// keeps scrolling and every control stays usable; only the bubble takes
/// touches. Contract: norviq-shared/docs/guided-start.md, "Spotlight rules".
struct GuidedSpotlightOverlay: View {
  let step: GuidedStartStep?
  let activeTab: GuidedTab?
  let anchors: [GuidedAnchorID: Anchor<CGRect>]
  let onSkip: () -> Void

  @AccessibilityFocusState private var bubbleFocused: Bool

  private static let holeInset: CGFloat = 8
  private static let holeRadius: CGFloat = 14
  private static let dimOpacity: Double = 0.55
  private static let bubbleMaxWidth: CGFloat = 340

  var body: some View {
    if let step {
      GeometryReader { proxy in
        let hole = resolvedHole(step: step, proxy: proxy)
        ZStack(alignment: .bottom) {
          if GuidedSpotlightGeometry.showsScrim(hole: hole), let hole {
            scrim(container: proxy.size, hole: hole)
          }
          bubble(step: step)
            .padding(.horizontal, 20)
            .padding(.bottom, 96)
        }
      }
      .ignoresSafeArea()
      .appAnimation(AppMotion.state, value: step)
      .onAppear { bubbleFocused = true }
    }
  }

  private func resolvedHole(step: GuidedStartStep, proxy: GeometryProxy) -> CGRect? {
    guard let anchor = anchors.anchor(for: step.targets, on: activeTab) else { return nil }
    let rect = proxy[anchor].insetBy(dx: -Self.holeInset, dy: -Self.holeInset)
    guard rect.width > 0, rect.height > 0, rect.intersects(CGRect(origin: .zero, size: proxy.size)) else { return nil }
    return rect
  }

  private func scrim(container: CGSize, hole: CGRect) -> some View {
    Path { path in
      path.addRect(CGRect(origin: .zero, size: container))
      path.addRoundedRect(in: hole, cornerSize: CGSize(width: Self.holeRadius, height: Self.holeRadius), style: .continuous)
    }
    .fill(Color.black.opacity(Self.dimOpacity), style: FillStyle(eoFill: true))
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private func bubble(step: GuidedStartStep) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(step.line)
        .typography(.small, weight: .semibold)
        .accessibilityFocused($bubbleFocused)
      HStack {
        Spacer()
        Button(GuidedStartCopy.skip, action: onSkip)
          .buttonStyle(.bordered)
          .controlSize(.small)
      }
    }
    .padding(16)
    .frame(maxWidth: Self.bubbleMaxWidth, alignment: .leading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .accessibilityElement(children: .contain)
    .accessibilityAction(.escape, onSkip)
  }
}

extension View {
  /// Attach once per presentation: the tab shell, and each cover a step passes through.
  func guidedSpotlight(step: GuidedStartStep?, activeTab: GuidedTab?, onSkip: @escaping () -> Void) -> some View {
    overlayPreferenceValue(GuidedAnchorKey.self) { anchors in
      GuidedSpotlightOverlay(step: step, activeTab: activeTab, anchors: anchors, onSkip: onSkip)
    }
  }
}
