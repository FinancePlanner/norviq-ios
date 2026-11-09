import Foundation
import PDFKit
import UniformTypeIdentifiers

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
    /// Raw cap on an image picked from Files; `UploadImagePreparer` shrinks it afterwards.
    static let maxImageFileBytes = 20 << 20
}

/// Refuses on the device what the server would refuse, so the user hears it
/// before an upload and a turn are spent.
nonisolated enum AssistantAttachmentChecker {
    /// Reads and checks one file from the document picker, whatever its kind.
    /// Blocking: call it off the main actor.
    static func load(url: URL, maxImageBytes: Int) -> Result<AssistantAttachment, AttachmentCheckError> {
        do {
            guard let kind = Kind(url: url) else { throw AttachmentCheckError.unreadable(url.lastPathComponent) }
            let (data, name) = try read(url: url, limit: kind.readLimit)
            switch kind {
            case .pdf:
                return .success(try pdf(data: data, filename: name))
            case .image:
                guard let image = UploadImagePreparer.prepare(data, maxBytes: maxImageBytes) else { throw AttachmentCheckError.unreadable(name) }
                return .success(.image(image))
            case .csv:
                return .success(try csv(data: data, filename: name))
            }
        } catch let error as AttachmentCheckError {
            return .failure(error)
        } catch {
            return .failure(.unreadable(url.lastPathComponent))
        }
    }

    /// The text the server stores for an attachment turn, so the bubble reads
    /// the same before and after a reload. The prompts and markers are
    /// `defaultImagePrompt`, `defaultFilePrompt`, `imageMarker` and `fileMarker`
    /// in the backend's `attachments.go`: any PDF or CSV makes it a file turn.
    static func turnText(_ content: String, attachments: [AssistantAttachment]) -> String {
        if attachments.contains(where: \.isDocument) {
            return (content.isEmpty ? "What's in this file?" : content) + " [file attached]"
        }
        return (content.isEmpty ? "What's in this image?" : content) + " [image attached]"
    }

    static func isUpgradeRefusal(_ error: any Error) -> Bool {
        if let failure = error as? AssistantTurnFailure { return failure.code == "upgrade_required" }
        if case .upgradeRequired? = error as? AssistantStreamClient.Failure { return true }
        return false
    }

    static func upgradeNotice(for attachments: [AssistantAttachment]) -> String {
        attachments.contains(where: \.isDocument)
            ? String(localized: "Attaching files is part of Pro. Upgrade to use it.")
            : String(localized: "Attaching images is part of Pro. Upgrade to use it.")
    }

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

    /// What a picked file is, decided from its type before a byte is read.
    enum Kind: Equatable {
        case pdf, csv, image

        /// The most bytes worth reading for this kind.
        var readLimit: Int {
            switch self {
            case .pdf: AssistantAttachmentLimits.maxPDFBytes
            case .csv: AssistantAttachmentLimits.maxCSVBytes
            case .image: AssistantAttachmentLimits.maxImageFileBytes
            }
        }

        init?(url: URL) {
            let ext = url.pathExtension.lowercased()
            guard let type = UTType(filenameExtension: ext) else { return nil }
            if type.conforms(to: .pdf) {
                self = .pdf
            } else if type.conforms(to: .image) {
                self = .image
            } else if type.conforms(to: .commaSeparatedText) || (type.identifier == "public.plain-text" && ext == "csv") {
                self = .csv
            } else {
                return nil
            }
        }
    }

    /// Reads a file the document picker handed over, inside its security scope,
    /// never more than `limit` bytes: one byte past it is enough to refuse.
    static func read(url: URL, limit: Int = AssistantAttachmentLimits.maxPDFBytes) throws -> (Data, String) {
        let name = url.lastPathComponent
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        // The size is a hint that can be missing or wrong; the bounded read below decides.
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > limit {
            throw AttachmentCheckError.tooLarge(name)
        }
        let data: Data
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            data = try handle.read(upToCount: limit + 1) ?? Data()
        } catch {
            throw AttachmentCheckError.unreadable(name)
        }
        guard data.count <= limit else { throw AttachmentCheckError.tooLarge(name) }
        return (data, name)
    }
}
