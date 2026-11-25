import Foundation

/// Where exported files live before they go to the share sheet:
/// `{root}/{editionId}-r{revision}/{fileName}` for rendered files, and
/// `{root}/native/{fileName}` for the card drawn on the device.
///
/// A revision's files never change, so one already on disk is reused.
nonisolated struct MarketBriefExportFileStore: Sendable {
  enum Error: Swift.Error, Equatable {
    /// The edition id or file name is not a plain path component.
    case unsafeName(String)
  }

  let root: URL

  init(root: URL = FileManager.default.temporaryDirectory.appending(path: "market-brief-exports")) {
    self.root = root
  }

  /// Writes `file` atomically unless that revision already has it, and returns its URL.
  func url(for file: MarketBriefExportFile, editionId: String, revision: Int) throws -> URL {
    let destination = try location(of: file, in: "\(editionId)-r\(revision)")
    if FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) {
      return destination
    }
    return try write(file, to: destination)
  }

  /// The card drawn on the device. Its name carries no revision, so it is always
  /// rewritten: an older card for the same brief may show older items.
  func nativeURL(for file: MarketBriefExportFile) throws -> URL {
    try write(file, to: location(of: file, in: "native"))
  }

  private func location(of file: MarketBriefExportFile, in directory: String) throws -> URL {
    for name in [directory, file.fileName] where !Self.isPlainComponent(name) {
      throw Error.unsafeName(name)
    }
    return root
      .appending(path: directory, directoryHint: .isDirectory)
      .appending(path: file.fileName, directoryHint: .notDirectory)
  }

  private func write(_ file: MarketBriefExportFile, to destination: URL) throws -> URL {
    try FileManager.default.createDirectory(
      at: destination.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try file.data.write(to: destination, options: .atomic)
    return destination
  }

  private static func isPlainComponent(_ name: String) -> Bool {
    !name.isEmpty && name != "." && name != ".."
      && !name.contains("/") && !name.contains("\\") && !name.contains("\0")
  }
}
