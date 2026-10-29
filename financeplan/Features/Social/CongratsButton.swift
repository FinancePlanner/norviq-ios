import SwiftUI

/// 🎉 with the cheer count. Once you've cheered it stays lit and inert, so a
/// second tap sends nothing.
struct CongratsButton: View {
  let cheers: Int
  let isCongratulated: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Text(verbatim: "🎉")
        if cheers > 0 {
          Text("\(cheers)").monospacedDigit()
        }
      }
      .font(.subheadline.weight(.medium))
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
    .tint(isCongratulated ? AppTheme.Colors.tint : .secondary)
    .disabled(isCongratulated)
    .sensoryFeedback(.success, trigger: isCongratulated) { _, new in new }
    .accessibilityLabel(isCongratulated ? Text("Congratulated") : Text("Congratulate"))
    .accessibilityValue(Text("\(cheers) cheers"))
  }
}
