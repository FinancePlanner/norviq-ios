import Foundation

public enum ReportBlockKind: String, Codable, Sendable, CaseIterable {
    case cover
    case keyMetrics = "key_metrics"
    case holdings
    case allocation
    case performance
    case cashFlow = "cash_flow"
    case spending
    case budget
    case insights
    case retirementForecast = "retirement_forecast"
    case goalProgress = "goal_progress"
    case hypotheticalComparison = "hypothetical_comparison"
    case assumptions
    case customText = "custom_text"
    case pageBreak = "page_break"
}

public enum ReportVisualization: String, Codable, Sendable, CaseIterable {
    case automatic
    case table
    case lineChart = "line_chart"
    case areaChart = "area_chart"
    case barChart = "bar_chart"
    case donutChart = "donut_chart"
}

public enum ReportDateRangePreset: String, Codable, Sendable, CaseIterable {
    case monthToDate = "month_to_date"
    case quarterToDate = "quarter_to_date"
    case yearToDate = "year_to_date"
    case trailingTwelveMonths = "trailing_twelve_months"
    case allTime = "all_time"
    case custom
}

public struct ReportDateRange: Codable, Sendable, Equatable {
    public let preset: ReportDateRangePreset
    public let from: String?
    public let to: String?

    public init(preset: ReportDateRangePreset, from: String? = nil, to: String? = nil) {
        self.preset = preset
        self.from = from
        self.to = to
    }
}

public struct ReportBlockSettings: Codable, Sendable, Equatable {
    public let visualization: ReportVisualization
    public let showLegend: Bool
    public let showDetails: Bool
    public let showSourceURLs: Bool
    public let maximumRows: Int?
    public let benchmarkSymbol: String?
    public let comparisonPortfolioId: String?
    public let customText: String?

    public init(
        visualization: ReportVisualization = .automatic,
        showLegend: Bool = true,
        showDetails: Bool = true,
        showSourceURLs: Bool = true,
        maximumRows: Int? = nil,
        benchmarkSymbol: String? = nil,
        comparisonPortfolioId: String? = nil,
        customText: String? = nil
    ) {
        self.visualization = visualization
        self.showLegend = showLegend
        self.showDetails = showDetails
        self.showSourceURLs = showSourceURLs
        self.maximumRows = maximumRows
        self.benchmarkSymbol = benchmarkSymbol
        self.comparisonPortfolioId = comparisonPortfolioId
        self.customText = customText
    }
}

public struct ReportBlock: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: ReportBlockKind
    public let title: String
    public let commentary: String?
    public let portfolioIds: [String]
    public let dateRange: ReportDateRange?
    public let settings: ReportBlockSettings
    public let isVisible: Bool
    public let pageBreakBefore: Bool

    public init(
        id: String,
        kind: ReportBlockKind,
        title: String,
        commentary: String? = nil,
        portfolioIds: [String] = [],
        dateRange: ReportDateRange? = nil,
        settings: ReportBlockSettings = .init(),
        isVisible: Bool = true,
        pageBreakBefore: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.commentary = commentary
        self.portfolioIds = portfolioIds
        self.dateRange = dateRange
        self.settings = settings
        self.isVisible = isVisible
        self.pageBreakBefore = pageBreakBefore
    }
}

public enum ReportTheme: String, Codable, Sendable, CaseIterable {
    case norviqLight = "norviq_light"
    case midnight
    case advisor
}

public enum ReportPageSize: String, Codable, Sendable, CaseIterable {
    case a4
    case letter
}

public enum ReportPageOrientation: String, Codable, Sendable, CaseIterable {
    case portrait
    case landscape
}

public struct ReportPageSettings: Codable, Sendable, Equatable {
    public let size: ReportPageSize
    public let orientation: ReportPageOrientation
    public let showPageNumbers: Bool
    public let showGeneratedAt: Bool

    public init(
        size: ReportPageSize = .a4,
        orientation: ReportPageOrientation = .portrait,
        showPageNumbers: Bool = true,
        showGeneratedAt: Bool = true
    ) {
        self.size = size
        self.orientation = orientation
        self.showPageNumbers = showPageNumbers
        self.showGeneratedAt = showGeneratedAt
    }
}

public struct ReportTemplateInput: Codable, Sendable, Equatable {
    public let name: String
    public let description: String?
    public let theme: ReportTheme
    public let pageSettings: ReportPageSettings
    public let blocks: [ReportBlock]

    public init(
        name: String,
        description: String? = nil,
        theme: ReportTheme = .norviqLight,
        pageSettings: ReportPageSettings = .init(),
        blocks: [ReportBlock]
    ) {
        self.name = name
        self.description = description
        self.theme = theme
        self.pageSettings = pageSettings
        self.blocks = blocks
    }
}

public struct ReportTemplate: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let ownerUserId: String
    public let input: ReportTemplateInput
    public let revision: Int
    public let isStarterTemplate: Bool
    public let archivedAt: String?
    public let createdAt: String
    public let updatedAt: String?

    public init(
        id: String,
        ownerUserId: String,
        input: ReportTemplateInput,
        revision: Int,
        isStarterTemplate: Bool = false,
        archivedAt: String? = nil,
        createdAt: String,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.input = input
        self.revision = revision
        self.isStarterTemplate = isStarterTemplate
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ReportTemplatePageResponse: Codable, Sendable, Equatable {
    public let items: [ReportTemplate]
    public let nextCursor: String?

    public init(items: [ReportTemplate], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public enum ReportOutputFormat: String, Codable, Sendable, CaseIterable {
    case pdf
    case xlsx
}

public enum ReportRecurrenceFrequency: String, Codable, Sendable, CaseIterable {
    case weekly
    case monthly
    case quarterly
    case yearly
}

public enum ReportWeekday: Int, Codable, Sendable, CaseIterable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
}

public struct ReportRecurrence: Codable, Sendable, Equatable {
    public let frequency: ReportRecurrenceFrequency
    public let timeZone: String
    public let localTime: String
    public let weekday: ReportWeekday?
    public let dayOfMonth: Int?
    public let anchorMonth: Int?

    public init(
        frequency: ReportRecurrenceFrequency,
        timeZone: String,
        localTime: String,
        weekday: ReportWeekday? = nil,
        dayOfMonth: Int? = nil,
        anchorMonth: Int? = nil
    ) {
        self.frequency = frequency
        self.timeZone = timeZone
        self.localTime = localTime
        self.weekday = weekday
        self.dayOfMonth = dayOfMonth
        self.anchorMonth = anchorMonth
    }
}

public struct ReportScheduleInput: Codable, Sendable, Equatable {
    public let name: String
    public let templateId: String
    public let outputFormats: [ReportOutputFormat]
    public let recurrence: ReportRecurrence
    public let recipientUserIds: [String]
    public let isEnabled: Bool

    public init(
        name: String,
        templateId: String,
        outputFormats: [ReportOutputFormat],
        recurrence: ReportRecurrence,
        recipientUserIds: [String],
        isEnabled: Bool = true
    ) {
        self.name = name
        self.templateId = templateId
        self.outputFormats = outputFormats
        self.recurrence = recurrence
        self.recipientUserIds = recipientUserIds
        self.isEnabled = isEnabled
    }
}

public struct ReportSchedule: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let ownerUserId: String
    public let input: ReportScheduleInput
    public let nextRunAt: String?
    public let lastRunAt: String?
    public let pausedReason: String?
    public let createdAt: String
    public let updatedAt: String?

    public init(
        id: String,
        ownerUserId: String,
        input: ReportScheduleInput,
        nextRunAt: String? = nil,
        lastRunAt: String? = nil,
        pausedReason: String? = nil,
        createdAt: String,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.input = input
        self.nextRunAt = nextRunAt
        self.lastRunAt = lastRunAt
        self.pausedReason = pausedReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ReportSchedulePageResponse: Codable, Sendable, Equatable {
    public let items: [ReportSchedule]
    public let nextCursor: String?

    public init(items: [ReportSchedule], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public enum ReportRunStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case claimed
    case generating
    case delivering
    case ready
    case partiallyDelivered = "partially_delivered"
    case delivered
    case retry
    case failed
    case expired
}

public enum ReportDeliveryStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case sending
    case delivered
    case retry
    case failed
    case revoked
    case expired
}

public struct ReportArtifact: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let runId: String
    public let format: ReportOutputFormat
    public let filename: String
    public let contentType: String
    public let sizeBytes: Int64
    public let sha256: String
    public let downloadPath: String
    public let expiresAt: String
    public let createdAt: String

    public init(
        id: String,
        runId: String,
        format: ReportOutputFormat,
        filename: String,
        contentType: String,
        sizeBytes: Int64,
        sha256: String,
        downloadPath: String,
        expiresAt: String,
        createdAt: String
    ) {
        self.id = id
        self.runId = runId
        self.format = format
        self.filename = filename
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.downloadPath = downloadPath
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}

public struct ReportDelivery: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let runId: String
    public let recipientUserId: String
    public let recipientEmail: String
    public let status: ReportDeliveryStatus
    public let attemptCount: Int
    public let lastAttemptAt: String?
    public let deliveredAt: String?
    public let failureReason: String?
    public let linkExpiresAt: String?

    public init(
        id: String,
        runId: String,
        recipientUserId: String,
        recipientEmail: String,
        status: ReportDeliveryStatus,
        attemptCount: Int,
        lastAttemptAt: String? = nil,
        deliveredAt: String? = nil,
        failureReason: String? = nil,
        linkExpiresAt: String? = nil
    ) {
        self.id = id
        self.runId = runId
        self.recipientUserId = recipientUserId
        self.recipientEmail = recipientEmail
        self.status = status
        self.attemptCount = attemptCount
        self.lastAttemptAt = lastAttemptAt
        self.deliveredAt = deliveredAt
        self.failureReason = failureReason
        self.linkExpiresAt = linkExpiresAt
    }
}

public struct ReportRunCreateRequest: Codable, Sendable, Equatable {
    public let templateId: String
    public let outputFormats: [ReportOutputFormat]
    public let recipientUserIds: [String]

    public init(
        templateId: String,
        outputFormats: [ReportOutputFormat],
        recipientUserIds: [String] = []
    ) {
        self.templateId = templateId
        self.outputFormats = outputFormats
        self.recipientUserIds = recipientUserIds
    }
}

public struct ReportRun: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let templateId: String
    public let scheduleId: String?
    public let requestedByUserId: String
    public let templateRevision: Int
    public let outputFormats: [ReportOutputFormat]
    public let status: ReportRunStatus
    public let scheduledFor: String?
    public let startedAt: String?
    public let completedAt: String?
    public let failureReason: String?
    public let artifacts: [ReportArtifact]
    public let deliveries: [ReportDelivery]
    public let createdAt: String

    public init(
        id: String,
        templateId: String,
        scheduleId: String? = nil,
        requestedByUserId: String,
        templateRevision: Int,
        outputFormats: [ReportOutputFormat],
        status: ReportRunStatus,
        scheduledFor: String? = nil,
        startedAt: String? = nil,
        completedAt: String? = nil,
        failureReason: String? = nil,
        artifacts: [ReportArtifact] = [],
        deliveries: [ReportDelivery] = [],
        createdAt: String
    ) {
        self.id = id
        self.templateId = templateId
        self.scheduleId = scheduleId
        self.requestedByUserId = requestedByUserId
        self.templateRevision = templateRevision
        self.outputFormats = outputFormats
        self.status = status
        self.scheduledFor = scheduledFor
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.failureReason = failureReason
        self.artifacts = artifacts
        self.deliveries = deliveries
        self.createdAt = createdAt
    }
}

public struct ReportRunPageResponse: Codable, Sendable, Equatable {
    public let items: [ReportRun]
    public let nextCursor: String?

    public init(items: [ReportRun], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct ReportArtifactDownloadResponse: Codable, Sendable, Equatable {
    public let url: String
    public let expiresAt: String

    public init(url: String, expiresAt: String) {
        self.url = url
        self.expiresAt = expiresAt
    }
}
