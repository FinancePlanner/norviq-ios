import SwiftUI

struct ExpensesCircularOverviewCard: View {
  let leftAmount: Double
  let totalAmount: Double
  @State private var progress: Double = 0

  var body: some View {
    VStack {
      ZStack {
        Circle()
          .stroke(Color.white.opacity(0.1), lineWidth: 20)

        Circle()
          .trim(from: 0, to: progress)
          .stroke(
            AngularGradient(
              gradient: Gradient(colors: [
                Color(red: 0.7, green: 0.3, blue: 1.0),
                Color(red: 0.9, green: 0.4, blue: 0.8),
                Color(red: 0.5, green: 0.3, blue: 1.0),
                Color(red: 0.2, green: 0.6, blue: 1.0),
                Color(red: 0.7, green: 0.3, blue: 1.0)
              ]),
              center: .center,
              startAngle: .degrees(-90),
              endAngle: .degrees(270)
            ),
            style: StrokeStyle(lineWidth: 20, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))

        VStack(spacing: 8) {
          Text("Monthly Budget")
            .typography(.small)
            .foregroundStyle(.secondary)

          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(leftAmount.currency)
              .font(.largeTitle.bold())
              .fontDesign(.rounded)
            Text("Left")
              .typography(.headline)
          }

          Text("of \(totalAmount.currency)")
            .typography(.small)
            .foregroundStyle(.secondary)
        }
      }
      .aspectRatio(1, contentMode: .fit)
      .frame(maxHeight: 280)
      .padding(.horizontal, 40)
      .padding(.vertical, 20)
    }
    .onAppear {
      withAnimation(.spring(response: 1.5, dampingFraction: 0.8).delay(0.2)) {
        progress = totalAmount > 0 ? max(0, min(1, leftAmount / totalAmount)) : 0
      }
    }
  }
}
