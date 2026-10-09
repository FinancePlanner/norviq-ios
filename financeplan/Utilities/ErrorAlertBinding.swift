import SwiftUI

/// A Bool binding over an optional error message, for `.alert`.
@MainActor
func errorAlertBinding(_ message: Binding<String?>) -> Binding<Bool> {
  Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })
}
