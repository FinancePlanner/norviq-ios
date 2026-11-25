import SwiftUI

struct PortfolioFilterButton: View {
  let title: String
  let isSelected: Bool
  let tint: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.subheadline.weight(.medium))
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .foregroundStyle(isSelected ? .primary : .secondary)
        .appGlassEffect(
          .rect(cornerRadius: AppTheme.Radius.control),
          tint: isSelected ? tint : nil,
          interactive: true
        )
    }
  }
}
