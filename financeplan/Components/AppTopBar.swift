import SwiftUI

struct AppTopBar: View {
  let title: String
  let searchText: Binding<String>?
  let searchPlaceholder: String
  let onSearchSubmit: (() -> Void)?
  let leadingAccessory: AnyView?
  let trailingAccessory: AnyView?

  @Environment(\.colorScheme) private var colorScheme

  init(
    title: String,
    searchText: Binding<String>? = nil,
    searchPlaceholder: String = "Search assets",
    onSearchSubmit: (() -> Void)? = nil,
    leadingAccessory: AnyView? = nil,
    trailingAccessory: AnyView? = nil
  ) {
    self.title = title
    self.searchText = searchText
    self.searchPlaceholder = searchPlaceholder
    self.onSearchSubmit = onSearchSubmit
    self.leadingAccessory = leadingAccessory
    self.trailingAccessory = trailingAccessory
  }

  var body: some View {
    HStack(spacing: 12) {
      if let leadingAccessory {
        accessorySlot(leadingAccessory)
      }

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

      if let trailingAccessory {
        accessorySlot(trailingAccessory)
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 12)
    .background {
      Rectangle()
        .fill(AppTheme.Colors.navBarBackground(for: colorScheme).opacity(0.88))
        .background(.ultraThinMaterial)
        .ignoresSafeArea(edges: .top)
    }
    .overlay(alignment: .bottom) {
      Divider()
        .opacity(0.12)
    }
  }

  @ViewBuilder
  private func accessorySlot(_ accessory: AnyView) -> some View {
    accessory
      .frame(width: 40, height: 40)
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
        .foregroundStyle(.secondary)

      TextField(placeholder, text: $text)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .submitLabel(.search)
        .onSubmit(onSubmit)

      if !text.isEmpty {
        Button {
          text = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(AppTheme.Colors.tertiaryFill(for: colorScheme))
    )
  }
}

struct AppTopBarProfileButton: View {
  let isUserMenuPresented: Bool
  let onTap: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: onTap) {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(
          isUserMenuPresented
          ? AppTheme.Colors.tint(for: colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.14)
          : AppTheme.Colors.tint(for: colorScheme).opacity(0.12)
        )
        .frame(width: 28, height: 28)
        .overlay(
          Image(systemName: "person.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
        )
        .overlay {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(
              AppTheme.Colors.navBarForeground(for: colorScheme).opacity(0.08),
              lineWidth: 1
            )
        }
    }
    .buttonStyle(.plain)
  }
}

struct AppTopBarChromeModifier: ViewModifier {
  let title: String
  let searchText: Binding<String>?
  let searchPlaceholder: String
  let onSearchSubmit: (() -> Void)?
  let leadingAccessory: AnyView?
  let trailingAccessory: AnyView?

  func body(content: Content) -> some View {
    content
      .toolbar(.hidden, for: .navigationBar)
      .safeAreaInset(edge: .top, spacing: 0) {
        AppTopBar(
          title: title,
          searchText: searchText,
          searchPlaceholder: searchPlaceholder,
          onSearchSubmit: onSearchSubmit,
          leadingAccessory: leadingAccessory,
          trailingAccessory: trailingAccessory
        )
      }
  }
}

extension View {
  func appTopBarChrome(
    title: String,
    searchText: Binding<String>? = nil,
    searchPlaceholder: String = "Search assets",
    onSearchSubmit: (() -> Void)? = nil,
    leadingAccessory: AnyView? = nil,
    trailingAccessory: AnyView? = nil
  ) -> some View {
    modifier(
      AppTopBarChromeModifier(
        title: title,
        searchText: searchText,
        searchPlaceholder: searchPlaceholder,
        onSearchSubmit: onSearchSubmit,
        leadingAccessory: leadingAccessory,
        trailingAccessory: trailingAccessory
      )
    )
  }
}
