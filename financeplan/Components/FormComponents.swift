import SwiftUI

// MARK: - Form Sheet Header

/// A centered sheet header with title and dismiss button.
/// Replaces the NavigationStack toolbar pattern for sheets.
struct FormSheetHeader: View {
  let title: String
  var subtitle: String?
  let onDismiss: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack {
      // Title
      VStack(spacing: 2) {
        Text(title)
          .typography(.label, weight: .semibold)

        if let subtitle {
          Text(subtitle)
            .typography(.caption)
            .foregroundStyle(.secondary)
        }
      }

      // Dismiss
      HStack {
        Button(action: onDismiss) {
          Image(systemName: "xmark")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 30, height: 30)
            .appGlassEffect(.circle, interactive: true)
        }
        .accessibilityLabel("Dismiss")

        Spacer()
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 14)
    .padding(.bottom, 10)
  }
}

// MARK: - Form Card

/// A rounded card container for grouping form fields.
struct FormCard<Content: View>: View {
  var title: String?
  @ViewBuilder let content: () -> Content

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let title {
        Text(title.uppercased())
          .typography(.caption, weight: .semibold)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 20)
          .padding(.bottom, 8)
      }

      VStack(spacing: 0) {
        content()
      }
      .appGlassEffect(.rect(cornerRadius: 18))
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
  }
}

// MARK: - Form Row

/// A single form row with an optional leading icon, label, and trailing content.
struct FormRow<Trailing: View>: View {
  let icon: String?
  let iconColor: Color?
  let label: String
  @ViewBuilder let trailing: () -> Trailing

  @Environment(\.colorScheme) private var colorScheme

  init(
    icon: String? = nil,
    iconColor: Color? = nil,
    label: String,
    @ViewBuilder trailing: @escaping () -> Trailing
  ) {
    self.icon = icon
    self.iconColor = iconColor
    self.label = label
    self.trailing = trailing
  }

  var body: some View {
    HStack(spacing: 12) {
      if let icon {
        Image(systemName: icon)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(iconColor ?? .secondary)
          .frame(width: 24, alignment: .center)
      }

      Text(label)
        .typography(.label)
        .foregroundStyle(.primary)

      Spacer(minLength: 4)

      trailing()
        .multilineTextAlignment(.trailing)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      AppTheme.Colors.elevatedCardBackground(for: colorScheme)
        .opacity(0.6)
    )
  }
}

/// A form row with a text field as the trailing content.
struct FormTextField: View {
  let icon: String?
  let iconColor: Color?
  let placeholder: String
  @Binding var text: String
  var keyboardType: UIKeyboardType = .default
  var autocapitalization: TextInputAutocapitalization = .sentences
  var disableAutocorrection: Bool = false
  var accessibilityIdentifier: String? = nil

  @Environment(\.colorScheme) private var colorScheme

  init(
    icon: String? = nil,
    iconColor: Color? = nil,
    placeholder: String,
    text: Binding<String>,
    keyboardType: UIKeyboardType = .default,
    autocapitalization: TextInputAutocapitalization = .sentences,
    disableAutocorrection: Bool = false,
    accessibilityIdentifier: String? = nil
  ) {
    self.icon = icon
    self.iconColor = iconColor
    self.placeholder = placeholder
    self._text = text
    self.keyboardType = keyboardType
    self.autocapitalization = autocapitalization
    self.disableAutocorrection = disableAutocorrection
    self.accessibilityIdentifier = accessibilityIdentifier
  }

  var body: some View {
    HStack(spacing: 12) {
      if let icon {
        Image(systemName: icon)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(iconColor ?? .secondary)
          .frame(width: 24, alignment: .center)
      }

      TextField(placeholder, text: $text)
        .typography(.label)
        .keyboardType(keyboardType)
        .textInputAutocapitalization(autocapitalization)
        .autocorrectionDisabled(disableAutocorrection)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      AppTheme.Colors.elevatedCardBackground(for: colorScheme)
        .opacity(0.6)
    )
  }
}

// MARK: - Form Toggle

/// A form row with a toggle as the trailing content.
struct FormToggle: View {
  let icon: String?
  let iconColor: Color?
  let label: String
  @Binding var isOn: Bool

  @Environment(\.colorScheme) private var colorScheme

  init(
    icon: String? = nil,
    iconColor: Color? = nil,
    label: String,
    isOn: Binding<Bool>
  ) {
    self.icon = icon
    self.iconColor = iconColor
    self.label = label
    self._isOn = isOn
  }

  var body: some View {
    HStack(spacing: 12) {
      if let icon {
        Image(systemName: icon)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(iconColor ?? .secondary)
          .frame(width: 24, alignment: .center)
      }

      Text(label)
        .typography(.label)
        .foregroundStyle(.primary)

      Spacer(minLength: 4)

      Toggle("", isOn: $isOn)
        .labelsHidden()
        .tint(AppTheme.Colors.tint(for: colorScheme))
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      AppTheme.Colors.elevatedCardBackground(for: colorScheme)
        .opacity(0.6)
    )
  }
}

// MARK: - Form Divider

/// A thin divider used between form rows inside a FormCard.
struct FormDivider: View {
  var leadingInset: CGFloat = 16

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Rectangle()
      .fill(AppTheme.Colors.separator(for: colorScheme).opacity(0.3))
      .frame(height: 0.5)
      .padding(.leading, leadingInset)
  }
}

// MARK: - Form Action Bar

/// A floating bottom bar with a primary capsule button.
struct FormActionBar: View {
  let primaryLabel: String
  var secondaryText: String?
  var isLoading: Bool = false
  var isDisabled: Bool = false
  var accessibilityIdentifier: String? = nil
  let onPrimary: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 0) {
      Divider().opacity(0.3)

      HStack(spacing: 12) {
        if let secondaryText {
          Text(secondaryText)
            .typography(.small)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button(action: onPrimary) {
          HStack(spacing: 6) {
            if isLoading {
              ProgressView()
                .tint(.white)
                .scaleEffect(0.8)
            }
            Text(primaryLabel)
              .font(.headline)
              .fontWeight(.bold)
            if !isLoading {
              Image(systemName: "arrow.right")
                .font(.subheadline.weight(.bold))
            }
          }
          .foregroundStyle(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
        }
        .buttonStyle(.glassProminent)
        .tint(isDisabled ? AppTheme.Colors.disabled : AppTheme.Colors.tint(for: colorScheme))
        .disabled(isDisabled || isLoading)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)
      .appGlassEffect(.rect(cornerRadius: 0))
      .ignoresSafeArea(edges: .bottom)
    }
  }
}

// MARK: - Form Info Tag

/// A non-editable display tag (pill) used for locked values like symbol or month.
struct FormInfoTag: View {
  let text: String
  var icon: String?

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 6) {
      if let icon {
        Image(systemName: icon)
          .font(.caption.weight(.semibold))
      }
      Text(text)
        .typography(.small, weight: .semibold)
    }
    .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .appGlassEffect(.capsule, tint: AppTheme.Colors.tintSoft(for: colorScheme))
  }
}

// MARK: - Form Error Banner

/// Inline error banner that appears in form sheets.
struct FormErrorBanner: View {
  let message: String

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(AppTheme.Colors.danger)
      Text(message)
        .typography(.small)
        .foregroundStyle(AppTheme.Colors.danger)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .appGlassEffect(.rect(cornerRadius: 12), tint: AppTheme.Colors.danger.opacity(0.08))
  }
}
