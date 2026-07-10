import SwiftUI
import Factory

struct FeedbackSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme
  private var feedbackService: FeedbackService { Container.shared.feedbackService() }

  @State private var topic: String
  @State private var message = ""
  @State private var isSubmitting = false
  @State private var errorMessage: String?
  @State private var showSuccessToast = false

  let topics = ["General Feedback", "Feature Request", "Bug Report", "UI/UX Feedback", "Other"]

  init(initialTopic: String = "Feature Request") {
    _topic = State(initialValue: initialTopic)
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        Form {
          Section {
            Picker("Topic", selection: $topic) {
              ForEach(topics, id: \.self) {
                Text($0)
              }
            }
          } header: {
            Text("What's on your mind?")
          }

          Section {
            TextEditor(text: $message)
              .frame(minHeight: 150)
              .typography(.small)
          } header: {
            Text("Details")
          } footer: {
            Text("We appreciate your feedback! It helps us make Norviq better for everyone.")
          }
        }
        .scrollContentBackground(.hidden)

        Button {
          submitFeedback()
        } label: {
          if isSubmitting {
            ProgressView()
              .tint(.white)
          } else {
            Text("Send Feedback")
              .font(.headline)
              .fontWeight(.bold)
          }
        }
        .buttonStyle(GlowingButtonStyle())
        .padding(20)
        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
        .opacity(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
      }
      .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
      .navigationTitle("Submit Feedback")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
      }
      .overlay(alignment: .top) {
        if let errorMessage {
          ToastBanner(message: errorMessage, style: .error)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        if showSuccessToast {
          ToastBanner(message: "Feedback sent! Thank you.", style: .success)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
    }
  }

  private func submitFeedback() {
    isSubmitting = true
    errorMessage = nil

    Task {
      do {
        _ = try await feedbackService.submitFeedback(topic: topic, message: message)
        withAnimation(AppMotion.structural) { showSuccessToast = true }
        try? await Task.sleep(for: AppMotion.toastLifetime)
        dismiss()
      } catch {
        withAnimation(AppMotion.structural) {
          errorMessage = error.localizedDescription
        }
        isSubmitting = false
      }
    }
  }
}
