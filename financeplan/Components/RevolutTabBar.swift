import SwiftUI

/// Floating glass capsule tab bar inspired by Revolut / expo-glass-tabs.
/// - Inactive: icon only
/// - Active: wider pill with icon + label
/// - Optional raised Capture (not a TabView selection)
/// - Shrinks while scrolling via ``TabBarChromeController``
struct RevolutTabBar: View {
  struct Item: Identifiable, Hashable {
    enum Kind: Hashable {
      case tab(HomeTab)
      case more
    }

    let kind: Kind
    let title: String
    let systemImage: String

    var id: String {
      switch kind {
      case let .tab(tab):
        return "tab.\(String(describing: tab))"
      case .more:
        return "more"
      }
    }
  }

  @Binding var selection: HomeTab
  var items: [Item]
  /// Extra tabs that light up the More affordance when selected.
  var moreTabs: Set<HomeTab> = []
  var showsCapture: Bool = true
  var isMinimized: Bool = false
  var onSelect: (HomeTab) -> Void = { _ in }
  var onMore: () -> Void = {}
  var onCapture: () -> Void = {}

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme
  @Namespace private var pillNamespace

  private var moreIsActive: Bool {
    moreTabs.contains(selection)
  }

  var body: some View {
    ZStack(alignment: .top) {
      capsule
        .padding(.top, showsCapture && !isMinimized ? 18 : 0)

      if showsCapture {
        captureButton
          .offset(y: isMinimized ? 4 : -10)
          .scaleEffect(isMinimized ? 0.82 : 1)
          .opacity(isMinimized ? 0.92 : 1)
          .accessibilityIdentifier("tabBar.capture")
      }
    }
    .animation(reduceMotion ? AppMotion.reduced : AppMotion.tabBar, value: selection)
    .animation(reduceMotion ? AppMotion.reduced : AppMotion.tabBar, value: isMinimized)
    .animation(reduceMotion ? AppMotion.reduced : AppMotion.tabBar, value: moreIsActive)
  }

  private var capsule: some View {
    HStack(spacing: isMinimized ? 4 : 6) {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        if showsCapture, index == items.count / 2 {
          Color.clear
            .frame(width: isMinimized ? 36 : 48)
        }
        tabButton(item)
      }
    }
    .padding(.horizontal, isMinimized ? 10 : 12)
    .padding(.vertical, isMinimized ? 8 : 10)
    .background {
      Capsule(style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay {
          Capsule(style: .continuous)
            .strokeBorder(
              Color.white.opacity(colorScheme == .dark ? 0.12 : 0.22),
              lineWidth: 0.8
            )
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.12), radius: 18, y: 8)
    }
    .appGlassEffect(.capsule)
    .scaleEffect(isMinimized ? 0.94 : 1, anchor: .bottom)
  }

  @ViewBuilder
  private func tabButton(_ item: Item) -> some View {
    let isActive: Bool = {
      switch item.kind {
      case let .tab(tab):
        return selection == tab && !moreIsActive
      case .more:
        return moreIsActive
      }
    }()

    Button {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      switch item.kind {
      case let .tab(tab):
        onSelect(tab)
      case .more:
        onMore()
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: item.systemImage)
          .font(.system(size: isMinimized ? 16 : 17, weight: .semibold))
          .symbolRenderingMode(.hierarchical)

        if isActive, !isMinimized {
          Text(item.title)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
      }
      .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(0.72))
      .padding(.horizontal, isActive && !isMinimized ? 20 : (isMinimized ? 10 : 12))
      .padding(.vertical, isMinimized ? 8 : 10)
      .frame(minWidth: isActive && !isMinimized ? 96 : 44)
      .background {
        if isActive {
          Capsule(style: .continuous)
            .fill(Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.12))
            .matchedGeometryEffect(id: "revolutTabPill", in: pillNamespace)
        }
      }
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(item.title)
    .accessibilityAddTraits(isActive ? .isSelected : [])
    .accessibilityIdentifier("tabBar.\(item.id)")
  }

  private var captureButton: some View {
    Button {
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      onCapture()
    } label: {
      Image(systemName: "plus")
        .font(.system(size: isMinimized ? 16 : 20, weight: .bold))
        .foregroundStyle(Color.white)
        .frame(width: isMinimized ? 40 : 52, height: isMinimized ? 40 : 52)
        .background {
          Circle()
            .fill(AppTheme.Colors.tint(for: colorScheme).gradient)
            .shadow(color: AppTheme.Colors.tint(for: colorScheme).opacity(0.45), radius: 12, y: 4)
        }
        .overlay {
          Circle()
            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(String(localized: "Capture"))
  }
}
