import Foundation
import Testing
@testable import StockPlanShared

struct AdvancedReportingDTOsTests {
    @Test(arguments: ReportBlockKind.allCases)
    func `every report block kind round trips`(_ kind: ReportBlockKind) throws {
        let block = ReportBlock(
            id: "block-\(kind.rawValue)",
            kind: kind,
            title: "Block",
            commentary: "Context",
            portfolioIds: ["portfolio-1"],
            dateRange: .init(preset: .yearToDate),
            settings: .init(
                visualization: .automatic,
                maximumRows: 25,
                benchmarkSymbol: "SPY",
                comparisonPortfolioId: "portfolio-2",
                customText: kind == .customText ? "Custom narrative" : nil
            )
        )

        let data = try JSONEncoder().encode(block)
        #expect(try JSONDecoder().decode(ReportBlock.self, from: data) == block)
    }

    @Test
    func `template preserves ordered composable blocks and page settings`() throws {
        let input = ReportTemplateInput(
            name: "Quarterly portfolio review",
            description: "Owner and joint editor review",
            theme: .advisor,
            pageSettings: .init(size: .letter, orientation: .landscape),
            blocks: [
                .init(id: "cover", kind: .cover, title: "Portfolio Review"),
                .init(
                    id: "holdings",
                    kind: .holdings,
                    title: "Holdings",
                    portfolioIds: ["portfolio-1"],
                    settings: .init(visualization: .table, maximumRows: 50)
                ),
            ]
        )
        let template = ReportTemplate(
            id: "template-1",
            ownerUserId: "user-1",
            input: input,
            revision: 3,
            createdAt: "2026-07-14T08:00:00Z"
        )

        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(ReportTemplate.self, from: data)

        #expect(decoded == template)
        #expect(decoded.input.blocks.map(\.id) == ["cover", "holdings"])
    }

    @Test(arguments: ReportRecurrenceFrequency.allCases)
    func `schedule recurrence supports every frequency`(_ frequency: ReportRecurrenceFrequency) throws {
        let recurrence = ReportRecurrence(
            frequency: frequency,
            timeZone: "Europe/Lisbon",
            localTime: "08:30",
            weekday: frequency == .weekly ? .monday : nil,
            dayOfMonth: frequency == .weekly ? nil : 31,
            anchorMonth: frequency == .quarterly || frequency == .yearly ? 1 : nil
        )
        let input = ReportScheduleInput(
            name: "Scheduled review",
            templateId: "template-1",
            outputFormats: [.pdf, .xlsx],
            recurrence: recurrence,
            recipientUserIds: ["user-1", "user-2"]
        )
        let schedule = ReportSchedule(
            id: "schedule-1",
            ownerUserId: "user-1",
            input: input,
            nextRunAt: "2026-07-31T07:30:00Z",
            createdAt: "2026-07-14T08:00:00Z"
        )

        let data = try JSONEncoder().encode(schedule)
        #expect(try JSONDecoder().decode(ReportSchedule.self, from: data) == schedule)
    }

    @Test
    func `schedule page preserves cursor and pause state`() throws {
        let schedule = ReportSchedule(
            id: "schedule-1",
            ownerUserId: "user-1",
            input: .init(
                name: "Quarterly review",
                templateId: "template-1",
                outputFormats: [.pdf, .xlsx],
                recurrence: .init(
                    frequency: .quarterly,
                    timeZone: "Europe/Lisbon",
                    localTime: "09:00",
                    dayOfMonth: 1,
                    anchorMonth: 1
                ),
                recipientUserIds: ["user-1"],
                isEnabled: false
            ),
            lastRunAt: "2026-07-01T08:00:00Z",
            pausedReason: "subscription_downgraded",
            createdAt: "2026-01-01T08:00:00Z",
            updatedAt: "2026-07-02T08:00:00Z"
        )
        let page = ReportSchedulePageResponse(items: [schedule], nextCursor: "next-page")

        let data = try JSONEncoder().encode(page)
        let decoded = try JSONDecoder().decode(ReportSchedulePageResponse.self, from: data)

        #expect(decoded == page)
        #expect(decoded.items.first?.pausedReason == "subscription_downgraded")
    }

    @Test
    func `report run carries artifacts and recipient delivery states`() throws {
        let artifact = ReportArtifact(
            id: "artifact-1",
            runId: "run-1",
            format: .xlsx,
            filename: "portfolio-review.xlsx",
            contentType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            sizeBytes: 42000,
            sha256: "abc123",
            downloadPath: "/v1/report-artifacts/artifact-1/download",
            expiresAt: "2026-10-12T08:00:00Z",
            createdAt: "2026-07-14T08:00:00Z"
        )
        let delivery = ReportDelivery(
            id: "delivery-1",
            runId: "run-1",
            recipientUserId: "user-2",
            recipientEmail: "a***@example.com",
            status: .delivered,
            attemptCount: 1,
            deliveredAt: "2026-07-14T08:01:00Z",
            linkExpiresAt: "2026-07-21T08:01:00Z"
        )
        let run = ReportRun(
            id: "run-1",
            templateId: "template-1",
            scheduleId: "schedule-1",
            requestedByUserId: "user-1",
            templateRevision: 3,
            outputFormats: [.pdf, .xlsx],
            status: .delivered,
            scheduledFor: "2026-07-14T08:00:00Z",
            startedAt: "2026-07-14T08:00:01Z",
            completedAt: "2026-07-14T08:01:00Z",
            artifacts: [artifact],
            deliveries: [delivery],
            createdAt: "2026-07-14T08:00:00Z"
        )

        let data = try JSONEncoder().encode(run)
        #expect(try JSONDecoder().decode(ReportRun.self, from: data) == run)
    }
}
