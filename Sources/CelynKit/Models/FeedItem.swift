import Foundation

// Wire model for GET /curation/feed — the editorial feed that powers "Le Fil".
// Geo-aware, diversity-balanced object selection; each item carries the swarm
// of critic `voices` (added server-side for the social card) plus the existing
// `topOpinion` / `opinionCount`. No user/circle data — that's a separate layer.
// Decoded with `.convertFromSnakeCase`, so snake_case JSON maps to camelCase.

public struct CurationFeedResponse: Codable, Sendable {
    public let data: [CurationFeedItem]
}

public struct CurationFeedItem: Codable, Sendable, Identifiable {
    public let category: String?
    public let oeuvre: CurationFeedOeuvre
    public let opinionCount: Int?
    public let voices: [CurationFeedVoice]?
    public let explainer: String?
    /// Editorial score from the server's press-ranking (higher = more
    /// discussed). The on-device taste-rank uses it as the editorial spine `E`.
    public let score: Double?

    public var id: String { oeuvre.id }
}

public struct CurationFeedOeuvre: Codable, Sendable {
    public let id: String
    public let title: String
    public let oeuvreType: String?
    public let director: String?
    public let author: String?
    public let year: Int?
    public let imageUrl: String?
    public let description: String?
}

public struct CurationFeedVoice: Codable, Sendable {
    public let name: String
    public let show: String?
    public let mono: String
    /// French verb: "Défend" | "Apprécie" | "Nuance" | "Réserve" | "En parle"
    public let verb: String
    /// "positif" | "mitige" | "negatif"
    public let sentiment: String
    public let quote: String?
    /// signal_source id behind this voice — keys into the on-device curator
    /// taste vectors for user↔curator affinity. Null for legacy episode rows.
    public let sourceId: String?
}
