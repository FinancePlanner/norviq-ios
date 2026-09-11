import Foundation

/// One screenshot on its way to the extractor.
struct ScreenshotUploadImage: Sendable, Equatable {
  let data: Data
  let contentType: String
  let filename: String?

  init(data: Data, contentType: String = "image/jpeg", filename: String? = nil) {
    self.data = data
    self.contentType = contentType
    self.filename = filename
  }
}
