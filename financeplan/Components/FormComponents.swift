import SwiftUI
import StockPlanShared

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
            .background(
              Circle()
                .fill(AppTheme.Colors.elevatedCardBackground(for: colorScheme))
            )
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
      .appGlassEffect(.rect(cornerRadius: 16))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    .padding(.vertical, 13)
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
  var isCurrencyField: Bool = false

  @Environment(\.colorScheme) private var colorScheme
  @FocusState private var isFocused: Bool

  init(
    icon: String? = nil,
    iconColor: Color? = nil,
    placeholder: String,
    text: Binding<String>,
    keyboardType: UIKeyboardType = .default,
    autocapitalization: TextInputAutocapitalization = .sentences,
    disableAutocorrection: Bool = false,
    isCurrencyField: Bool = false
  ) {
    self.icon = icon
    self.iconColor = iconColor
    self.placeholder = placeholder
    self._text = text
    self.keyboardType = keyboardType
    self.autocapitalization = autocapitalization
    self.disableAutocorrection = disableAutocorrection
    self.isCurrencyField = isCurrencyField
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
        .focused($isFocused)
        .onChange(of: text) { _, newValue in
          if isCurrencyField {
            text = formatCurrencyInput(newValue)
          }
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 13)
    .background(
      isFocused
        ? AppTheme.Colors.tintSoft(for: colorScheme)
        : Color.clear
    )
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .animation(.easeInOut(duration: 0.15), value: isFocused)
  }

  private func formatCurrencyInput(_ input: String) -> String {
    let digits = input.filter { $0.isNumber || $0 == "." }
    
    guard !digits.isEmpty else { return "" }
    
    if let lastDotIndex = digits.lastIndex(of: ".") {
      let beforeDot = digits[..<lastDotIndex]
      let afterDot = digits[digits.index(after: lastDotIndex)...]
      
      let decimalPart = String(afterDot).prefix(2)
      let wholePart = String(beforeDot)
      
      if decimalPart.isEmpty {
        return wholePart + "."
      } else {
        return wholePart + "." + decimalPart
      }
    }
    
    return digits
  }
}

// MARK: - Form Divider

/// A thin divider used between form rows inside a FormCard.
struct FormDivider: View {
  var leadingInset: CGFloat = 52

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Rectangle()
      .fill(AppTheme.Colors.separator(for: colorScheme).opacity(0.35))
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
          .background(
            Capsule()
              .fill(
                isDisabled
                  ? AppTheme.Colors.disabled
                  : AppTheme.Colors.tint(for: colorScheme)
              )
          )
          .shadow(
            color: isDisabled
              ? .clear
              : AppTheme.Colors.tint(for: colorScheme).opacity(0.25),
            radius: 8, x: 0, y: 4
          )
        }
        .disabled(isDisabled || isLoading)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
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

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(AppTheme.Colors.dangerText(for: colorScheme))
      Text(message)
        .typography(.small)
        .foregroundStyle(AppTheme.Colors.dangerText(for: colorScheme))
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .appGlassEffect(.rect(cornerRadius: 12), tint: AppTheme.Colors.danger.opacity(colorScheme == .dark ? 0.15 : 0.08))
  }
}

// MARK: - Currency Input Field

/// Enhanced text field for currency input with real-time formatting validation.
struct CurrencyInputField: View {
  let icon: String?
  let iconColor: Color?
  let placeholder: String
  @Binding var value: String
  var isValid: Bool = true
  var errorMessage: String?

  @Environment(\.colorScheme) private var colorScheme
  @FocusState private var isFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
        if let icon {
          Image(systemName: icon)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(iconColor ?? .secondary)
            .frame(width: 24, alignment: .center)
        }

         HStack(spacing: 4) {
          Text("$")
            .typography(.label)
            .foregroundStyle(.secondary)

          TextField(placeholder, text: $value)
            .typography(.label)
            .keyboardType(.decimalPad)
            .focused($isFocused)
            .onChange(of: value) { _, newValue in
              value = formatCurrencyInput(newValue)
            }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 13)
      .background(
        isFocused && isValid
          ? AppTheme.Colors.tintSoft(for: colorScheme)
          : Color.clear
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(
            isValid ? (isFocused ? AppTheme.Colors.tint(for: colorScheme).opacity(0.3) : Color.clear) : AppTheme.Colors.dangerText(for: colorScheme),
            lineWidth: isValid ? (isFocused ? 1 : 0) : 1.5
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .animation(.easeInOut(duration: 0.15), value: isFocused)

      if let errorMessage, !isValid {
        HStack(spacing: 6) {
          Image(systemName: "exclamationmark.circle.fill")
            .font(.caption)
          Text(errorMessage)
            .typography(.small)
        }
        .foregroundStyle(AppTheme.Colors.dangerText(for: colorScheme))
      }
    }
  }

  private func formatCurrencyInput(_ input: String) -> String {
    let digits = input.filter { $0.isNumber || $0 == "." }
    
    guard !digits.isEmpty else { return "" }
    
    if let lastDotIndex = digits.lastIndex(of: ".") {
      let beforeDot = digits[..<lastDotIndex]
      let afterDot = digits[digits.index(after: lastDotIndex)...]
      
      let decimalPart = String(afterDot).prefix(2)
      let wholePart = String(beforeDot)
      
      if decimalPart.isEmpty {
        return wholePart + "."
      } else {
        return wholePart + "." + decimalPart
      }
    }
    
    return digits
  }
}

// MARK: - Pillar Picker with Color Preview

/// A pillar selector with color indicator for better visual feedback.
struct PillarPicker: View {
  let label: String
  let icon: String?
  let iconColor: Color?
  @Binding var selectedPillar: BudgetPillar

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    FormRow(icon: icon, iconColor: iconColor, label: label) {
      HStack(spacing: 10) {
        HStack(spacing: 6) {
          Circle()
            .fill(selectedPillar.color(for: colorScheme))
            .frame(width: 10, height: 10)
          
          Text(selectedPillar.title)
            .typography(.label)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill(selectedPillar.color(for: colorScheme).opacity(0.1))
        )
        
        Picker("Pillar", selection: $selectedPillar) {
          ForEach(BudgetPillar.allCases, id: \.self) { pillar in
            HStack(spacing: 6) {
              Circle()
                .fill(pillar.color(for: colorScheme))
                .frame(width: 6, height: 6)
              Text(pillar.title)
            }
            .tag(pillar)
          }
        }
        .labelsHidden()
        .frame(width: 0)
        .opacity(0)
      }
    }
  }
}

// MARK: - Split Mode Indicator

/// Visual indicator for expense split mode (personal/shared).
struct SplitModeIndicator: View {
  @Binding var splitMode: ExpenseSplitMode
  @Binding var userSharePercent: Double

  var body: some View {
    VStack(spacing: 12) {
      FormRow(icon: "person.2", iconColor: .green, label: "Mode") {
        HStack(spacing: 6) {
          Image(systemName: splitMode == .personal ? "person.fill" : "person.2.fill")
            .font(.caption.weight(.semibold))
          Picker("Mode", selection: $splitMode) {
            Text("Personal").tag(ExpenseSplitMode.personal)
            Text("Shared").tag(ExpenseSplitMode.shared)
          }
          .labelsHidden()
        }
      }

      if splitMode == .shared {
        FormDivider()
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Label("Your Share", systemImage: "person.crop.circle.badge.checkmark")
              .font(.subheadline.weight(.medium))
            Spacer()
            Text("\(Int(userSharePercent.rounded()))%")
              .typography(.label, weight: .semibold)
              .foregroundStyle(.secondary)
          }
          Slider(value: $userSharePercent, in: 0...100, step: 1)
            .tint(.green)
          HStack(spacing: 8) {
            Text("You pay")
            Spacer()
            Text("Partner pays")
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
    }
  }
}
