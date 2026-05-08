import SwiftUI

struct OverviewSectionLabel: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 16)
            Text(title)
                .font(.headline)
        }
        .padding(.horizontal)
    }
}
