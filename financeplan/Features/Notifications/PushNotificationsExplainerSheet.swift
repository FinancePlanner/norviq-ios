import SwiftUI

struct PushNotificationsExplainerSheet: View {
  let onEnable: () async -> Void
  let onNotNow: () -> Void

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 20) {
        Image(systemName: "bell.badge.fill")
          .font(.largeTitle.bold())
          .foregroundStyle(.tint)

        Text("Stay on top of target hits")
          .font(.title2.weight(.semibold))

        Text("Enable notifications to get alerts when your bull/base/bear targets are reached.")
          .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 10) {
          Label("Target price alerts", systemImage: "chart.line.uptrend.xyaxis")
          Label("One tap to manage in Settings", systemImage: "gearshape")
          Label("You can opt out at any time", systemImage: "hand.raised")
        }
        .foregroundStyle(.secondary)

        Spacer()

        Button {
          Task {
            await onEnable()
          }
        } label: {
          Text("Enable Notifications")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)

        Button("Not now", role: .cancel, action: onNotNow)
          .frame(maxWidth: .infinity)
      }
      .padding(24)
      .navigationTitle("Notifications")
      .navigationBarTitleDisplayMode(.inline)
    }
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
  }
}
