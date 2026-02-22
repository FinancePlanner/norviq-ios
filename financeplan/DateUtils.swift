import Foundation

enum DateUtils {
  static let shortFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
  }()

  static func formatTime(_ date: Date) -> String {
    shortFormatter.string(from: date)
  }
}
