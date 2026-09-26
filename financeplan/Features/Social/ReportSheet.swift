import Factory
import SwiftUI

struct ReportSheet: View {
  let user: SocialUserSummary
  @InjectedObservable(\Container.socialStore) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var reason: ReportReason?
  @State private var note = ""
  @State private var isSubmitting = false
  @State private var didSubmit = false
  @State private var alsoBlock = false

  var body: some View {
    NavigationStack {
      Form {
        if didSubmit {
          Section {
            Label("Thanks. We review every report within 24 hours.", systemImage: "checkmark.shield")
          }
        } else {
          Section("Why are you reporting @\(user.username)?") {
            ForEach(ReportReason.allCases) { option in
              Button {
                reason = option
              } label: {
                HStack {
                  Text(option.title).foregroundStyle(.primary)
                  Spacer()
                  if reason == option {
                    Image(systemName: "checkmark").foregroundStyle(AppTheme.Colors.tint)
                  }
                }
              }
            }
          }
          Section("Details (optional)") {
            TextField("What happened?", text: $note, axis: .vertical)
              .lineLimit(3...6)
          }
          Section {
            Toggle("Also block @\(user.username)", isOn: $alsoBlock)
          }
        }
      }
      .navigationTitle("Report")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(didSubmit ? "Done" : "Cancel") { dismiss() }
        }
        if !didSubmit {
          ToolbarItem(placement: .confirmationAction) {
            Button("Send") { submit() }
              .disabled(reason == nil || isSubmitting)
          }
        }
      }
    }
  }

  private func submit() {
    guard let reason else { return }
    Task {
      isSubmitting = true
      defer { isSubmitting = false }
      guard await store.report(userID: user.id, reason: reason, note: note) else { return }
      if alsoBlock { await store.block(user) }
      didSubmit = true
    }
  }
}
