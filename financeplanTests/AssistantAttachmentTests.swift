import Foundation
import PDFKit
import UIKit
import XCTest
@testable import financeplan

/// Keeps the body of the one request sent.
private final class AttachmentURLProtocol: URLProtocol {
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var request: URLRequest?
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var responseBody = Data("event: started\ndata: {}\n\n".utf8)

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.request = request
        Self.body = Data()
        if let body = request.httpBody {
            Self.body = body
        } else if let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                guard read > 0 else { break }
                Self.body.append(buffer, count: read)
            }
            stream.close()
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
final class AssistantAttachmentTests: XCTestCase {
    private func pdfDocument(pages: Int) -> PDFDocument {
        let document = PDFDocument()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        for index in 0 ..< pages {
            document.insert(PDFPage(image: image)!, at: index)
        }
        return document
    }

    private func pdfData(pages: Int, password: String? = nil) throws -> Data {
        let document = pdfDocument(pages: pages)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        var options: [PDFDocumentWriteOption: Any] = [:]
        if let password {
            options[.userPasswordOption] = password
            options[.ownerPasswordOption] = password
        }
        XCTAssertTrue(document.write(to: url, withOptions: options))
        return try Data(contentsOf: url)
    }

    private func pdf(_ name: String = "a.pdf") -> AssistantAttachment {
        .pdf(id: UUID(), data: Data([0x25, 0x50]), filename: name, pageCount: 1)
    }

    private func csv(_ name: String = "a.csv") -> AssistantAttachment {
        .csv(id: UUID(), data: Data("a,b".utf8), filename: name)
    }

    private func image() -> AssistantAttachment {
        .image(ScreenshotUploadImage(data: Data([0xFF, 0xD8, 0xFF])))
    }

    // MARK: Checks

    func testPDFAccepted() throws {
        let attachment = try AssistantAttachmentChecker.pdf(data: pdfData(pages: 2), filename: "s.pdf")
        guard case let .pdf(_, _, filename, pageCount) = attachment else { return XCTFail("not a pdf") }
        XCTAssertEqual(filename, "s.pdf")
        XCTAssertEqual(pageCount, 2)
        XCTAssertEqual(attachment.contentType, "application/pdf")
        XCTAssertTrue(attachment.isDocument)
    }

    func testPDFEncryptedRejected() throws {
        let data = try pdfData(pages: 1, password: "secret")
        XCTAssertThrowsError(try AssistantAttachmentChecker.pdf(data: data, filename: "s.pdf")) {
            XCTAssertEqual($0 as? AttachmentCheckError, .encrypted)
        }
    }

    func testPDFTwentyOnePagesRejected() throws {
        let data = try pdfData(pages: 21)
        XCTAssertThrowsError(try AssistantAttachmentChecker.pdf(data: data, filename: "s.pdf")) {
            XCTAssertEqual($0 as? AttachmentCheckError, .tooManyPages)
        }
        XCTAssertNoThrow(try AssistantAttachmentChecker.pdf(data: pdfData(pages: 20), filename: "s.pdf"))
    }

    func testPDFGarbageUnreadable() {
        XCTAssertThrowsError(try AssistantAttachmentChecker.pdf(data: Data([1, 2, 3]), filename: "bad.pdf")) {
            XCTAssertEqual($0 as? AttachmentCheckError, .unreadable("bad.pdf"))
        }
    }

    func testPDFTooLargeRejected() {
        let data = Data(count: AssistantAttachmentLimits.maxPDFBytes + 1)
        XCTAssertThrowsError(try AssistantAttachmentChecker.pdf(data: data, filename: "big.pdf")) {
            XCTAssertEqual($0 as? AttachmentCheckError, .tooLarge("big.pdf"))
        }
    }

    func testCSVAccepted() throws {
        let attachment = try AssistantAttachmentChecker.csv(data: Data("a,b\n1,2\n".utf8), filename: "t.csv")
        XCTAssertEqual(attachment.contentType, "text/csv")
        XCTAssertEqual(attachment.filename, "t.csv")
    }

    func testCSVNotUTF8Rejected() {
        let latin1 = "caf\u{E9},1".data(using: .isoLatin1)!
        XCTAssertThrowsError(try AssistantAttachmentChecker.csv(data: latin1, filename: "t.csv")) {
            XCTAssertEqual($0 as? AttachmentCheckError, .notUTF8)
        }
    }

    func testCSVTooLargeRejected() {
        let data = Data(count: AssistantAttachmentLimits.maxCSVBytes + 1)
        XCTAssertThrowsError(try AssistantAttachmentChecker.csv(data: data, filename: "t.csv")) {
            XCTAssertEqual($0 as? AttachmentCheckError, .tooLarge("t.csv"))
        }
    }

    // MARK: Admission

    func testAdmitRefusesSecondPDF() {
        XCTAssertThrowsError(try AssistantAttachmentChecker.admit(pdf("b.pdf"), into: [pdf()])) {
            XCTAssertEqual($0 as? AttachmentCheckError, .onePDF)
        }
    }

    func testAdmitRefusesSecondCSV() {
        XCTAssertThrowsError(try AssistantAttachmentChecker.admit(csv("b.csv"), into: [csv()])) {
            XCTAssertEqual($0 as? AttachmentCheckError, .oneCSV)
        }
    }

    func testAdmitRefusesFourth() {
        XCTAssertThrowsError(try AssistantAttachmentChecker.admit(image(), into: [image(), image(), image()])) {
            XCTAssertEqual($0 as? AttachmentCheckError, .tooMany)
        }
    }

    func testAdmitAllowsOnePDFOneCSVAndImage() throws {
        try AssistantAttachmentChecker.admit(csv(), into: [pdf(), image()])
        try AssistantAttachmentChecker.admit(image(), into: [pdf(), csv()])
    }

    // MARK: Reading

    func testReadUnreadableURLThrowsWithName() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)/x.pdf")
        XCTAssertThrowsError(try AssistantAttachmentChecker.read(url: url)) {
            XCTAssertEqual($0 as? AttachmentCheckError, .unreadable("x.pdf"))
        }
    }

    func testReadReturnsBytesAndName() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).csv")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("a,b".utf8).write(to: url)
        let (data, name) = try AssistantAttachmentChecker.read(url: url)
        XCTAssertEqual(data, Data("a,b".utf8))
        XCTAssertEqual(name, url.lastPathComponent)
    }

    // MARK: Copy

    func testErrorCopy() {
        XCTAssertEqual(AttachmentCheckError.unreadable("a.pdf").errorDescription, "Couldn't read a.pdf.")
        XCTAssertEqual(AttachmentCheckError.tooLarge("a.pdf").errorDescription, "a.pdf is too large.")
        XCTAssertEqual(AttachmentCheckError.encrypted.errorDescription, "This PDF is password-protected.")
        XCTAssertEqual(AttachmentCheckError.tooManyPages.errorDescription, "PDFs can have up to 20 pages.")
        XCTAssertEqual(AttachmentCheckError.notUTF8.errorDescription, "This CSV isn't plain UTF-8 text.")
        XCTAssertEqual(AttachmentCheckError.onePDF.errorDescription, "Attach one PDF at a time.")
        XCTAssertEqual(AttachmentCheckError.oneCSV.errorDescription, "Attach one CSV at a time.")
        XCTAssertEqual(AttachmentCheckError.tooMany.errorDescription, "Attach up to 3 files.")
    }

    // MARK: Form

    private func makeClient() -> AssistantStreamClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AttachmentURLProtocol.self]
        return AssistantStreamClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: URLSession(configuration: configuration),
            authTokenProvider: { "token" }
        )
    }

    override func setUp() {
        AttachmentURLProtocol.status = 200
        AttachmentURLProtocol.responseBody = Data("event: started\ndata: {}\n\n".utf8)
    }

    func testFormCarriesEachAttachmentAsFilePart() async throws {
        let attachments: [AssistantAttachment] = [
            .image(ScreenshotUploadImage(data: Data([0xFF, 0xD8, 0xFF]), filename: "shot.jpg")),
            pdf("report.pdf"),
            csv("fills.csv"),
        ]
        for try await _ in makeClient().streamTurn(conversationID: "c1", content: "Hi", attachments: attachments, context: nil) {}

        let contentType = try XCTUnwrap(AttachmentURLProtocol.request?.value(forHTTPHeaderField: "Content-Type"))
        let boundary = String(contentType.dropFirst("multipart/form-data; boundary=".count))
        let text = try XCTUnwrap(String(data: AttachmentURLProtocol.body, encoding: .isoLatin1))
        let sections = text.components(separatedBy: "--\(boundary)").dropFirst().dropLast()
        let filePartHeaders = sections.compactMap { section -> (String, String)? in
            guard section.contains("name=\"file\"") else { return nil }
            let filename = section.components(separatedBy: "filename=\"").dropFirst().first?.prefix { $0 != "\"" }
            let type = section.components(separatedBy: "Content-Type: ").dropFirst().first?.prefix { !$0.isNewline }
            return (String(filename ?? ""), String(type ?? ""))
        }
        XCTAssertEqual(filePartHeaders.count, 3)
        XCTAssertEqual(filePartHeaders.map(\.0), ["shot.jpg", "report.pdf", "fills.csv"])
        XCTAssertEqual(filePartHeaders.map(\.1), ["image/jpeg", "application/pdf", "text/csv"])
        XCTAssertFalse(text.contains("name=\"image\""))
    }

    private func failure(status: Int, body: String) async -> AssistantStreamClient.Failure? {
        AttachmentURLProtocol.status = status
        AttachmentURLProtocol.responseBody = Data(body.utf8)
        do {
            for try await _ in makeClient().streamTurn(conversationID: "c1", content: "Hi", attachments: [pdf()], context: nil) {}
            return nil
        } catch {
            return error as? AssistantStreamClient.Failure
        }
    }

    func testRejectedJSONShowsServerReason() async {
        let failure = await failure(status: 422, body: #"{"error":true,"code":"attachment_rejected","reason":"That PDF has no readable text."}"#)
        XCTAssertEqual(failure?.errorDescription, "That PDF has no readable text.")
    }

    func testImageRejectedJSONShowsServerReason() async {
        let failure = await failure(status: 400, body: #"{"error":true,"code":"image_rejected","reason":"That image could not be read."}"#)
        XCTAssertEqual(failure?.errorDescription, "That image could not be read.")
    }

    func testRejectedJSONFallsBackToMessage() async {
        let failure = await failure(status: 422, body: #"{"code":"attachment_rejected","message":"Nope."}"#)
        XCTAssertEqual(failure?.errorDescription, "Nope.")
    }

    func testOtherJSON4xxStaysServerFailure() async {
        let failure = await failure(status: 400, body: #"{"error":true,"code":"bad_request","reason":"Bad."}"#)
        guard case .server(400)? = failure else { return XCTFail("expected .server(400), got \(String(describing: failure))") }
    }

    func testSSEErrorFrameCarriesAttachmentRejectedMessage() async throws {
        AttachmentURLProtocol.responseBody = Data(#"event: error\#ndata: {"code":"attachment_rejected","message":"That CSV has no rows."}\#n\#n"#.utf8)
        var events: [PersistentAssistantStreamEvent] = []
        for try await event in makeClient().streamTurn(conversationID: "c1", content: "Hi", attachments: [csv()], context: nil) {
            events.append(event)
        }
        guard case let .error(message, code)? = events.first else { return XCTFail("no error frame: \(events)") }
        XCTAssertEqual(message, "That CSV has no rows.")
        XCTAssertEqual(code, "attachment_rejected")
    }
}
