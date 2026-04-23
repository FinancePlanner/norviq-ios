import SwiftUI

struct VaultTextField<RightAccessory: View>: View {
  let label: String
  let placeholder: String
  @Binding var text: String
  var icon: String?
  var isSecure: Bool = false
  let rightAccessory: RightAccessory
  var showsRightAccessory: Bool = true

  var keyboardType: UIKeyboardType = .default
  var textContentType: UITextContentType?
  var submitLabel: SubmitLabel = .return
  var onSubmit: (() -> Void)?

  @FocusState private var isFocused: Bool
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(label.uppercased())
        .font(.caption.weight(.bold))
        .tracking(1.2)
        .foregroundStyle(.secondary)

      HStack(spacing: 12) {
        if let icon {
          Image(systemName: icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 20)
        }

        Group {
          if isSecure {
            SecureField(placeholder, text: $text)
          } else {
            TextField(placeholder, text: $text)
          }
        }
        .keyboardType(keyboardType)
        .textContentType(textContentType)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($isFocused)
        .foregroundStyle(.primary)
        .tint(AppTheme.Colors.tint(for: colorScheme))
        .submitLabel(submitLabel)
        .onSubmit {
          onSubmit?()
        }

        if showsRightAccessory {
          rightAccessory
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 16)
      .background(AppTheme.Colors.cardBackground(for: colorScheme))
      .clipShape(.rect(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(isFocused ? AppTheme.Colors.tint(for: colorScheme) : AppTheme.Colors.separator(for: colorScheme), lineWidth: 1)
      )
    }
  }
}

extension VaultTextField where RightAccessory == EmptyView {
  init(
    label: String,
    placeholder: String,
    text: Binding<String>,
    icon: String? = nil,
    isSecure: Bool = false,
    keyboardType: UIKeyboardType = .default,
    textContentType: UITextContentType? = nil,
    submitLabel: SubmitLabel = .return,
    onSubmit: (() -> Void)? = nil
  ) {
    self.label = label
    self.placeholder = placeholder
    self._text = text
    self.icon = icon
    self.isSecure = isSecure
    self.rightAccessory = EmptyView()
    self.showsRightAccessory = false
    self.keyboardType = keyboardType
    self.textContentType = textContentType
    self.submitLabel = submitLabel
    self.onSubmit = onSubmit
  }
}
