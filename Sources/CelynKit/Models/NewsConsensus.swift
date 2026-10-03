import Foundation

// ─── News consensus digest ───────────────────────────────
// Optional `consensus` block on `GET /api/news/stories/:id`: the story's
// claims cross-checked across independent outlets. Absent when the server
// has no digest for the story. Every `claim` is a server-reformulated
// sentence — never publisher text.

public enum NewsConsensusFacet: String, Codable, Sendable, CaseIterable {
    case programme
    case securite
    case affluence
    case politique
    case religieux
    case logistique
    case economie
    case justice
    case sante
    case autre

    /// Decodes unknown future values to `.autre` rather than failing.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = NewsConsensusFacet(rawValue: raw) ?? .autre
    }
}

public enum NewsConsensusStatus: String, Codable, Sendable, CaseIterable {
    /// Reported by at least two independent sources.
    case confirmed
    /// Reported by a single source so far.
    case singleSource = "single_source"
    /// Sources disagree (see `NewsConsensus.contested`).
    case contested
    /// A status this client version does not know yet — clients should not display it.
    case unknown

    /// Decodes unknown future values to `.unknown` rather than failing.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = NewsConsensusStatus(rawValue: raw) ?? .unknown
    }
}

/// One outlet backing a claim, with a link to its article.
public struct NewsConsensusSource: Codable, Sendable, Equatable, Hashable {
    public let name: String
    /// Article URL as sent by the server. `""` when the source has no URL
    /// (the server may send `""` or `null`) — use `link` to open it.
    public let url: String

    public init(name: String, url: String) {
        self.name = name
        self.url = url
    }

    private enum CodingKeys: String, CodingKey { case name, url }

    /// Tolerates a missing, `null` or `""` url (decoded as `""`) so one
    /// URL-less source never drops the whole digest.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
    }

    /// The article link, only when it is an absolute http(s) URL — nil for
    /// `""`, relative paths or any other scheme (javascript:, file:, …), in
    /// which case clients should render the source name as plain text.
    public var link: URL? {
        guard !url.isEmpty, let u = URL(string: url), u.host != nil,
              let scheme = u.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else { return nil }
        return u
    }
}

public struct NewsConsensusFact: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    /// Reformulated French sentence.
    public let claim: String
    public let facet: NewsConsensusFacet
    public let status: NewsConsensusStatus
    public let independentSources: Int
    public let sources: [NewsConsensusSource]
    /// 0...1 — how specific/informative the claim is.
    public let informativeness: Double

    /// French label for `independentSources`: « 1 source », « 3 sources ».
    public var independentSourcesLabelFR: String { NewsConsensus.sourcesLabelFR(independentSources) }

    public init(
        id: String,
        claim: String,
        facet: NewsConsensusFacet = .autre,
        status: NewsConsensusStatus,
        independentSources: Int,
        sources: [NewsConsensusSource] = [],
        informativeness: Double = 0
    ) {
        self.id = id
        self.claim = claim
        self.facet = facet
        self.status = status
        self.independentSources = independentSources
        self.sources = sources
        self.informativeness = informativeness
    }

    private enum CodingKeys: String, CodingKey {
        case id, claim, facet, status, independentSources, sources, informativeness
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        claim = try c.decode(String.self, forKey: .claim)
        facet = try c.decodeIfPresent(NewsConsensusFacet.self, forKey: .facet) ?? .autre
        status = try c.decode(NewsConsensusStatus.self, forKey: .status)
        independentSources = try c.decodeIfPresent(Int.self, forKey: .independentSources) ?? 0
        sources = try c.decodeIfPresent([NewsConsensusSource].self, forKey: .sources) ?? []
        informativeness = try c.decodeIfPresent(Double.self, forKey: .informativeness) ?? 0
    }
}

public struct NewsContestedVersion: Codable, Sendable, Equatable {
    public let claim: String
    public let sources: [NewsConsensusSource]
    /// The version's figure, for number points. Nil on older digests and date points.
    public let value: Double?
    /// Earliest publication among the version's sources. Nil on older digests.
    public let firstPublishedAt: Date?

    public init(claim: String, sources: [NewsConsensusSource] = [], value: Double? = nil, firstPublishedAt: Date? = nil) {
        self.claim = claim
        self.sources = sources
        self.value = value
        self.firstPublishedAt = firstPublishedAt
    }
}

/// How to read a contested point.
public enum NewsContestedKind: String, Codable, Sendable, CaseIterable {
    /// Sources give rival versions of one fact.
    case dispute
    /// A running count (arrests, blockades…) read at different times; versions are in time order.
    case evolution

    /// Decodes unknown future values to `.dispute` (the cautious reading).
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = NewsContestedKind(rawValue: raw) ?? .dispute
    }
}

/// A subject on which sources disagree, with each competing version.
public struct NewsContestedPoint: Codable, Sendable, Equatable {
    public let subject: String
    /// Absent on older digests — read as `.dispute`.
    public let kind: NewsContestedKind?
    public let versions: [NewsContestedVersion]

    public init(subject: String, kind: NewsContestedKind? = nil, versions: [NewsContestedVersion]) {
        self.subject = subject
        self.kind = kind
        self.versions = versions
    }

    /// True only when the server says so and every version can be placed on a time axis.
    public var isEvolution: Bool {
        kind == .evolution && versions.allSatisfy { $0.value != nil && $0.firstPublishedAt != nil }
    }
}

public struct NewsConsensus: Codable, Sendable, Equatable {
    public let generatedAt: Date
    public let eventCount: Int
    public let independentSourceCount: Int
    /// Server order: confirmed first, then informativeness, then source count.
    public let facts: [NewsConsensusFact]
    public let contested: [NewsContestedPoint]
    /// Number of distinct outlets behind the digest. nil when the server
    /// does not send it (older culture-api builds).
    public let outletCount: Int?

    public init(
        generatedAt: Date,
        eventCount: Int,
        independentSourceCount: Int,
        facts: [NewsConsensusFact] = [],
        contested: [NewsContestedPoint] = [],
        outletCount: Int? = nil
    ) {
        self.generatedAt = generatedAt
        self.eventCount = eventCount
        self.independentSourceCount = independentSourceCount
        self.facts = facts
        self.contested = contested
        self.outletCount = outletCount
    }

    private enum CodingKeys: String, CodingKey {
        case generatedAt, eventCount, independentSourceCount, facts, contested, outletCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try c.decode(Date.self, forKey: .generatedAt)
        eventCount = try c.decodeIfPresent(Int.self, forKey: .eventCount) ?? 0
        independentSourceCount = try c.decodeIfPresent(Int.self, forKey: .independentSourceCount) ?? 0
        facts = try c.decodeIfPresent([NewsConsensusFact].self, forKey: .facts) ?? []
        contested = try c.decodeIfPresent([NewsContestedPoint].self, forKey: .contested) ?? []
        outletCount = try c.decodeIfPresent(Int.self, forKey: .outletCount)
    }

    /// Confirmed facts, in server order.
    public var confirmedFacts: [NewsConsensusFact] { facts.filter { $0.status == .confirmed } }
    /// Single-source facts, in server order.
    public var singleSourceFacts: [NewsConsensusFact] { facts.filter { $0.status == .singleSource } }
    /// Contested points with at least two versions to compare — a point with
    /// fewer versions has nothing to contrast and should not be displayed.
    public var contestedPoints: [NewsContestedPoint] { contested.filter { $0.versions.count >= 2 } }
    /// Whether the digest has anything worth displaying (confirmed facts,
    /// single-source facts or displayable contested points).
    public var hasDisplayableContent: Bool {
        !confirmedFacts.isEmpty || !singleSourceFacts.isEmpty || !contestedPoints.isEmpty
    }

    /// French count label: « 0 source », « 1 source », « 3 sources »
    /// (French keeps the singular for 0 and 1).
    public static func sourcesLabelFR(_ count: Int) -> String {
        "\(count) source\(count > 1 ? "s" : "")"
    }
}
