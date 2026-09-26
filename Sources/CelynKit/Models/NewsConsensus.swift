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
    public let url: String

    public init(name: String, url: String) {
        self.name = name
        self.url = url
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

    public init(claim: String, sources: [NewsConsensusSource] = []) {
        self.claim = claim
        self.sources = sources
    }
}

/// A subject on which sources disagree, with each competing version.
public struct NewsContestedPoint: Codable, Sendable, Equatable {
    public let subject: String
    public let versions: [NewsContestedVersion]

    public init(subject: String, versions: [NewsContestedVersion]) {
        self.subject = subject
        self.versions = versions
    }
}

public struct NewsConsensus: Codable, Sendable, Equatable {
    public let generatedAt: Date
    public let eventCount: Int
    public let independentSourceCount: Int
    /// Server order: confirmed first, then informativeness, then source count.
    public let facts: [NewsConsensusFact]
    public let contested: [NewsContestedPoint]

    public init(
        generatedAt: Date,
        eventCount: Int,
        independentSourceCount: Int,
        facts: [NewsConsensusFact] = [],
        contested: [NewsContestedPoint] = []
    ) {
        self.generatedAt = generatedAt
        self.eventCount = eventCount
        self.independentSourceCount = independentSourceCount
        self.facts = facts
        self.contested = contested
    }

    private enum CodingKeys: String, CodingKey {
        case generatedAt, eventCount, independentSourceCount, facts, contested
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try c.decode(Date.self, forKey: .generatedAt)
        eventCount = try c.decodeIfPresent(Int.self, forKey: .eventCount) ?? 0
        independentSourceCount = try c.decodeIfPresent(Int.self, forKey: .independentSourceCount) ?? 0
        facts = try c.decodeIfPresent([NewsConsensusFact].self, forKey: .facts) ?? []
        contested = try c.decodeIfPresent([NewsContestedPoint].self, forKey: .contested) ?? []
    }

    /// Confirmed facts, in server order.
    public var confirmedFacts: [NewsConsensusFact] { facts.filter { $0.status == .confirmed } }
    /// Single-source facts, in server order.
    public var singleSourceFacts: [NewsConsensusFact] { facts.filter { $0.status == .singleSource } }
}
