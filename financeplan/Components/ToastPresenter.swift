import SwiftUI

/// A transient toast presented via `.toastOverlay(_:)`.
struct ToastData: Equatable {
  let id = UUID()
  var message: String
  var style: ToastBanner.Style

  static func success(_ message: String) -> ToastData {
    ToastData(message: message, style: .success)
  }

  static func error(_ message: String) -> ToastData {
    ToastData(message: message, style: .error)
  }

  static func info(_ message: String) -> ToastData {
    ToastData(message: message, style: .info)
  }
}

extension View {
  /// Presents a `ToastBanner` at the top edge with the app-standard
  /// transition, lifetime, and swipe-up dismissal. Set the binding to a
  /// `ToastData` to show it; it clears itself after `AppMotion.toastLifetime`
  /// unless `autoDismiss` is false.
  func toastOverlay(_ toast: Binding<ToastData?>, autoDismiss: Bool = true) -> some View {
    modifier(ToastPresenter(toast: toast, autoDismiss: autoDismiss))
  }
}

private struct ToastPresenter: ViewModifier {
  @Binding var toast: ToastData?
  var autoDismiss = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .top) {
        if let toast {
          ToastBanner(message: toast.message, style: toast.style)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(AppTransition.move(edge: .top, reduceMotion: reduceMotion))
            .gesture(
              DragGesture(minimumDistance: 10)
                .onEnded { value in
                  // Flick or drag upward dismisses along the entry edge.
                  if value.translation.height < -20 || value.predictedEndTranslation.height < -60 {
                    dismiss()
                  }
                }
            )
            .task(id: toast.id) {
              guard autoDismiss else { return }
              try? await Task.sleep(for: AppMotion.toastLifetime)
              guard !Task.isCancelled else { return }
              dismiss()
            }
        }
      }
      .appAnimation(AppMotion.structural, value: toast)
  }

  private func dismiss() {
    withAnimation(reduceMotion ? AppMotion.reduced : AppMotion.structural) {
      toast = nil
    }
  }
}
