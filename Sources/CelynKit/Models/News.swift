import Foundation

// ─── News (Actu) ─────────────────────────────────────────
// Mirrors culture-api/sdk/src/types.ts's News* types exactly — see that
// file's own header comment for the legal posture this vertical operates
// under (never raw_text, only LLM-reformulated summary + attribution).

public enum NewsEventKind: String, Codable, Sendable, CaseIterable {
    case politique
    case international
    case societe
    case economie
    case justice
    case sante
    case environnement
    case sciencesTech = "sciences_tech"
    case sport
    case culture
    case faitDivers = "fait_divers"
    case autre

    /// Decodes unknown future values to `.autre` rather than failing.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = NewsEventKind(rawValue: raw) ?? .autre
    }
}

/// One contributing outlet/programme behind a story — the vertical's
/// "who's covering this" chip.
public struct NewsStorySource: Codable, Sendable, Equatable {
    public let sourceType: String
    public let label: String
    public let count: Int

    public init(sourceType: String, label: String, count: Int) {
        self.sourceType = sourceType
        self.label = label
        self.count = count
    }
}

public struct NewsStory: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let primaryKind: NewsEventKind?
    /// Capped to the top 8 (full array on the detail response). Already
    /// human-readable — no id lookup needed.
    public let entityTokens: [String]
    public let confidenceScore: Double
    public let eventCount: Int
    public let sourceCount: Int
    public let firstSeenAt: Date
    public let lastUpdateAt: Date
    public let status: String
    public let sources: [NewsStorySource]

    public init(
        id: String,
        title: String,
        primaryKind: NewsEventKind? = nil,
        entityTokens: [String] = [],
        confidenceScore: Double,
        eventCount: Int,
        sourceCount: Int,
        firstSeenAt: Date,
        lastUpdateAt: Date,
        status: String,
        sources: [NewsStorySource] = []
    ) {
        self.id = id
        self.title = title
        self.primaryKind = primaryKind
        self.entityTokens = entityTokens
        self.confidenceScore = confidenceScore
        self.eventCount = eventCount
        self.sourceCount = sourceCount
        self.firstSeenAt = firstSeenAt
        self.lastUpdateAt = lastUpdateAt
        self.status = status
        self.sources = sources
    }
}

public enum NewsFactCheckVerdict: String, Codable, Sendable, CaseIterable {
    case verified
    case plausible
    case contradicted
    case unverifiable

    /// Decodes unknown future values to `.unverifiable` rather than failing.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = NewsFactCheckVerdict(rawValue: raw) ?? .unverifiable
    }
}

/// One claim-level fact-check verdict attached to a `NewsEvent`, checked
/// against Wikipedia.
public struct NewsFactCheck: Codable, Sendable, Equatable {
    public let claim: String
    public let subject: String
    public let verdict: NewsFactCheckVerdict
    public let confidence: Double
    public let source: String?
    public let sourceUrl: String?
    public let note: String?

    public init(
        claim: String,
        subject: String,
        verdict: NewsFactCheckVerdict,
        confidence: Double,
        source: String? = nil,
        sourceUrl: String? = nil,
        note: String? = nil
    ) {
        self.claim = claim
        self.subject = subject
        self.verdict = verdict
        self.confidence = confidence
        self.source = source
        self.sourceUrl = sourceUrl
        self.note = note
    }
}

/// A single reformulated news signal. Deliberately does NOT carry raw
/// source text — this vertical's legal posture never exposes verbatim
/// source text, only the LLM-reformulated `summary` + attribution + a
/// source hyperlink.
public struct NewsEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let kind: NewsEventKind
    public let summary: String?
    public let sourceType: String
    public let sourceUrl: String?
    public let sourcePublishedAt: Date?
    public let authorDisplayName: String?
    public let programme: String?
    public let isLiveBlog: Bool
    public let createdAt: Date
    /// Claim-level fact-check verdicts for this event. Empty until the
    /// server's fact-check job has run.
    public let factChecks: [NewsFactCheck]

    public init(
        id: String,
        kind: NewsEventKind,
        summary: String? = nil,
        sourceType: String,
        sourceUrl: String? = nil,
        sourcePublishedAt: Date? = nil,
        authorDisplayName: String? = nil,
        programme: String? = nil,
        isLiveBlog: Bool = false,
        createdAt: Date,
        factChecks: [NewsFactCheck] = []
    ) {
        self.id = id
        self.kind = kind
        self.summary = summary
        self.sourceType = sourceType
        self.sourceUrl = sourceUrl
        self.sourcePublishedAt = sourcePublishedAt
        self.authorDisplayName = authorDisplayName
        self.programme = programme
        self.isLiveBlog = isLiveBlog
        self.createdAt = createdAt
        self.factChecks = factChecks
    }
}

public struct NewsStoryDetail: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let primaryKind: NewsEventKind?
    public let entityTokens: [String]
    public let confidenceScore: Double
    public let eventCount: Int
    public let sourceCount: Int
    public let firstSeenAt: Date
    public let lastUpdateAt: Date
    public let status: String
    public let sources: [NewsStorySource]
    /// ALL member events, oldest-first — no cap.
    public let events: [NewsEvent]

    public init(
        id: String,
        title: String,
        primaryKind: NewsEventKind? = nil,
        entityTokens: [String] = [],
        confidenceScore: Double,
        eventCount: Int,
        sourceCount: Int,
        firstSeenAt: Date,
        lastUpdateAt: Date,
        status: String,
        sources: [NewsStorySource] = [],
        events: [NewsEvent] = []
    ) {
        self.id = id
        self.title = title
        self.primaryKind = primaryKind
        self.entityTokens = entityTokens
        self.confidenceScore = confidenceScore
        self.eventCount = eventCount
        self.sourceCount = sourceCount
        self.firstSeenAt = firstSeenAt
        self.lastUpdateAt = lastUpdateAt
        self.status = status
        self.sources = sources
        self.events = events
    }
}

public struct NewsStoryListMeta: Codable, Sendable, Equatable {
    public let limit: Int
    public let count: Int
    public let sort: String
    public let status: String
}

public struct NewsStoryListResponse: Codable, Sendable {
    public let data: [NewsStory]
    public let meta: NewsStoryListMeta
}

public struct NewsStoryDetailResponse: Codable, Sendable {
    public let data: NewsStoryDetail
}

public struct NewsEventListMeta: Codable, Sendable, Equatable {
    public let limit: Int
    public let count: Int
}

public struct NewsEventListResponse: Codable, Sendable {
    public let data: [NewsEvent]
    public let meta: NewsEventListMeta
}

public struct NewsEventDetailResponse: Codable, Sendable {
    public let data: NewsEvent
}
