import Foundation

/// One screenshot on its way to the extractor.
nonisolated struct ScreenshotUploadImage: Sendable, Equatable, Identifiable {
  /// Tells two copies of one picture apart in a list. Not part of equality.
  let id = UUID()
  let data: Data
  let contentType: String
  let filename: String?

  init(data: Data, contentType: String = "image/jpeg", filename: String? = nil) {
    self.data = data
    self.contentType = contentType
    self.filename = filename
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.data == rhs.data && lhs.contentType == rhs.contentType && lhs.filename == rhs.filename
  }
}
