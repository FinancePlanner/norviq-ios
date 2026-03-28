import SwiftUI

/// Presents a short prompt to open a URL in the user’s default browser (SwiftUI-only; no in-app web view).
struct ExternalBrowserLinkSheet: View {
  let url: URL
  var openActionTitle: String = "Open in browser"
  var message: String = "This link opens outside the app in Safari or your default browser."

  @Environment(\.openURL) private var openURL
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        Text(message)
          .typography(.small)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.top, 8)

        Button {
          openURL(url)
          dismiss()
        } label: {
          Label(openActionTitle, systemImage: "safari")
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(24)
      .frame(maxWidth: .infinity)
      .navigationTitle("External link")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}
