import Foundation
import PDFKit

/// One file on its way to Q: a screenshot, a PDF or a CSV.
nonisolated enum AssistantAttachment: Identifiable, Sendable, Equatable {
    case image(ScreenshotUploadImage)
    case pdf(id: UUID, data: Data, filename: String, pageCount: Int)
    case csv(id: UUID, data: Data, filename: String)

    var id: UUID {
        switch self {
        case let .image(image): image.id
        case let .pdf(id, _, _, _), let .csv(id, _, _): id
        }
    }

    var filename: String {
        switch self {
        case let .image(image): image.filename ?? "image.jpg"
        case let .pdf(_, _, filename, _), let .csv(_, _, filename): filename
        }
    }

    var contentType: String {
        switch self {
        case let .image(image): image.contentType
        case .pdf: "application/pdf"
        case .csv: "text/csv"
        }
    }

    var data: Data {
        switch self {
        case let .image(image): image.data
        case let .pdf(_, data, _, _), let .csv(_, data, _): data
        }
    }

    /// A PDF or a CSV: what the composer shows as a chip, not a thumbnail.
    var isDocument: Bool {
        if case .image = self { return false }
        return true
    }
}

nonisolated enum AttachmentCheckError: LocalizedError, Equatable {
    case unreadable(String)
    case tooLarge(String)
    case encrypted
    case tooManyPages
    case notUTF8
    case onePDF
    case oneCSV
    case tooMany

    var errorDescription: String? {
        switch self {
        case let .unreadable(name): String(localized: "Couldn't read \(name).")
        case let .tooLarge(name): String(localized: "\(name) is too large.")
        case .encrypted: String(localized: "This PDF is password-protected.")
        case .tooManyPages: String(localized: "PDFs can have up to 20 pages.")
        case .notUTF8: String(localized: "This CSV isn't plain UTF-8 text.")
        case .onePDF: String(localized: "Attach one PDF at a time.")
        case .oneCSV: String(localized: "Attach one CSV at a time.")
        case .tooMany: String(localized: "Attach up to 3 files.")
        }
    }
}

nonisolated enum AssistantAttachmentLimits {
    static let maxFiles = 3
    static let maxImageBytes = 5 << 20
    static let maxPDFBytes = 8 << 20
    static let maxPDFPages = 20
    static let maxCSVBytes = 1 << 20
}

/// Refuses on the device what the server would refuse, so the user hears it
/// before an upload and a turn are spent.
nonisolated enum AssistantAttachmentChecker {
    static func pdf(data: Data, filename: String) throws -> AssistantAttachment {
        guard data.count <= AssistantAttachmentLimits.maxPDFBytes else { throw AttachmentCheckError.tooLarge(filename) }
        guard let document = PDFDocument(data: data) else { throw AttachmentCheckError.unreadable(filename) }
        // An encrypted PDF stays locked until it is given a password, and a
        // locked one reports no pages.
        guard !document.isEncrypted, !document.isLocked else { throw AttachmentCheckError.encrypted }
        guard document.pageCount > 0 else { throw AttachmentCheckError.unreadable(filename) }
        guard document.pageCount <= AssistantAttachmentLimits.maxPDFPages else { throw AttachmentCheckError.tooManyPages }
        return .pdf(id: UUID(), data: data, filename: filename, pageCount: document.pageCount)
    }

    static func csv(data: Data, filename: String) throws -> AssistantAttachment {
        guard data.count <= AssistantAttachmentLimits.maxCSVBytes else { throw AttachmentCheckError.tooLarge(filename) }
        guard String(data: data, encoding: .utf8) != nil else { throw AttachmentCheckError.notUTF8 }
        return .csv(id: UUID(), data: data, filename: filename)
    }

    /// Whether `new` may join `existing`: three files at most, one PDF, one CSV.
    static func admit(_ new: AssistantAttachment, into existing: [AssistantAttachment]) throws {
        guard existing.count < AssistantAttachmentLimits.maxFiles else { throw AttachmentCheckError.tooMany }
        switch new {
        case .image: break
        case .pdf:
            if existing.contains(where: { if case .pdf = $0 { true } else { false } }) { throw AttachmentCheckError.onePDF }
        case .csv:
            if existing.contains(where: { if case .csv = $0 { true } else { false } }) { throw AttachmentCheckError.oneCSV }
        }
    }

    /// Reads a file the document picker handed over, inside its security scope.
    static func read(url: URL) throws -> (Data, String) {
        let name = url.lastPathComponent
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            return (try Data(contentsOf: url), name)
        } catch {
            throw AttachmentCheckError.unreadable(name)
        }
    }
}
