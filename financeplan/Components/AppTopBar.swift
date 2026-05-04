import SwiftUI

struct AppTopBar<LeadingAccessory: View, TrailingAccessory: View>: View {
  let title: String
  let searchText: Binding<String>?
  let searchPlaceholder: String
  let onSearchSubmit: (() -> Void)?
  let leadingAccessory: LeadingAccessory
  let trailingAccessory: TrailingAccessory

  @Environment(\.colorScheme) private var colorScheme

  init(
    title: String,
    searchText: Binding<String>? = nil,
    searchPlaceholder: String = "Search assets",
    onSearchSubmit: (() -> Void)? = nil,
    @ViewBuilder leadingAccessory: () -> LeadingAccessory,
    @ViewBuilder trailingAccessory: () -> TrailingAccessory
  ) {
    self.title = title
    self.searchText = searchText
    self.searchPlaceholder = searchPlaceholder
    self.onSearchSubmit = onSearchSubmit
    self.leadingAccessory = leadingAccessory()
    self.trailingAccessory = trailingAccessory()
  }

  var body: some View {
    HStack(spacing: 12) {
      accessorySlot(leadingAccessory)

      Text(title)
        .font(.headline.bold())
        .foregroundStyle(AppTheme.Colors.navBarForeground(for: colorScheme))
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .fixedSize(horizontal: true, vertical: false)

      if let searchText {
        AppTopBarSearchField(
          text: searchText,
          placeholder: searchPlaceholder,
          onSubmit: { onSearchSubmit?() }
        )
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
      } else {
        Spacer(minLength: 0)
      }

      accessorySlot(trailingAccessory)
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 12)
    .appGlassEffect(.rect(cornerRadius: 0))
    .ignoresSafeArea(edges: .top)
    .overlay(alignment: .bottom) {
      Divider()
        .opacity(0.12)
    }
  }

  @ViewBuilder
  private func accessorySlot<Accessory: View>(_ accessory: Accessory) -> some View {
    if accessory is EmptyView {
      EmptyView()
    } else {
      accessory
        .frame(width: 40, height: 40)
    }
  }
}

extension AppTopBar where LeadingAccessory == EmptyView, TrailingAccessory == EmptyView {
  init(
    title: String,
    searchText: Binding<String>? = nil,
    searchPlaceholder: String = "Search assets",
    onSearchSubmit: (() -> Void)? = nil
  ) {
    self.init(
      title: title,
      searchText: searchText,
      searchPlaceholder: searchPlaceholder,
      onSearchSubmit: onSearchSubmit,
      leadingAccessory: { EmptyView() },
      trailingAccessory: { EmptyView() }
    )
  }
}

private struct AppTopBarSearchField: View {
  @Binding var text: String
  let placeholder: String
  let onSubmit: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .accessibilityHidden(true)
        .foregroundStyle(.secondary)

      TextField(placeholder, text: $text)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .submitLabel(.search)
        .onSubmit(onSubmit)

      if !text.isEmpty {
        Button("Clear", systemImage: "xmark.circle.fill") {
          text = ""
        }
        .labelStyle(.iconOnly)
        .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .appGlassEffect(
      .rect(cornerRadius: 14),
      tint: AppTheme.Colors.tertiaryFill(for: colorScheme),
      interactive: true
    )
  }
}

struct AppTopBarChromeModifier<LeadingAccessory: View, TrailingAccessory: View>: ViewModifier {
  let title: String
  let searchText: Binding<String>?
  let searchPlaceholder: String
  let onSearchSubmit: (() -> Void)?
  let leadingAccessory: LeadingAccessory
  let trailingAccessory: TrailingAccessory

  func body(content: Content) -> some View {
    content
      .toolbar(.hidden, for: .navigationBar)
      .safeAreaInset(edge: .top, spacing: 0) {
        AppTopBar(
          title: title,
          searchText: searchText,
          searchPlaceholder: searchPlaceholder,
          onSearchSubmit: onSearchSubmit,
          leadingAccessory: { leadingAccessory },
          trailingAccessory: { trailingAccessory }
        )
      }
  }
}

extension View {
  func appTopBarChrome(
    title: String,
    searchText: Binding<String>? = nil,
    searchPlaceholder: String = "Search assets",
    onSearchSubmit: (() -> Void)? = nil
  ) -> some View {
    modifier(
      AppTopBarChromeModifier(
        title: title,
        searchText: searchText,
        searchPlaceholder: searchPlaceholder,
        onSearchSubmit: onSearchSubmit,
        leadingAccessory: EmptyView(),
        trailingAccessory: EmptyView()
      )
    )
  }

  func appTopBarChrome<LeadingAccessory: View, TrailingAccessory: View>(
    title: String,
    searchText: Binding<String>? = nil,
    searchPlaceholder: String = "Search assets",
    onSearchSubmit: (() -> Void)? = nil,
    @ViewBuilder leadingAccessory: () -> LeadingAccessory,
    @ViewBuilder trailingAccessory: () -> TrailingAccessory
  ) -> some View {
    modifier(
      AppTopBarChromeModifier(
        title: title,
        searchText: searchText,
        searchPlaceholder: searchPlaceholder,
        onSearchSubmit: onSearchSubmit,
        leadingAccessory: leadingAccessory(),
        trailingAccessory: trailingAccessory()
      )
    )
  }
}
