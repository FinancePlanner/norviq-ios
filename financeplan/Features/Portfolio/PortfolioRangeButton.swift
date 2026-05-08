import SwiftUI

struct PortfolioRangeButton: View {
  let title: String
  let isSelected: Bool
  let tint: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.caption.weight(.semibold))
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .foregroundStyle(isSelected ? .primary : .secondary)
        .glassEffect(
          isSelected ? .regular.tint(tint).interactive() : .regular.interactive(),
          in: .rect(cornerRadius: 8)
        )
    }
  }
}
