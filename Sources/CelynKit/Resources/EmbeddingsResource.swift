import Foundation

/// A single oeuvre embedding row from the server.
///
/// The `embedding` is expected to be a 1024-d Mistral vector, **already
/// L2-normalized** by the backend. Clients can take cosine similarity by
/// plain dot-product without re-normalizing.
public struct EmbeddingsItem: Codable, Sendable, Equatable {
    public let id: String
    public let embedding: [Float]
    public let type: String?
    public let year: Int?
    public let thematicTags: [String]?
    public let topics: [String]?
    public let updatedAt: Date?

    public init(
        id: String,
        embedding: [Float],
        type: String? = nil,
        year: Int? = nil,
        thematicTags: [String]? = nil,
        topics: [String]? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.embedding = embedding
        self.type = type
        self.year = year
        self.thematicTags = thematicTags
        self.topics = topics
        self.updatedAt = updatedAt
    }
}

/// One page of an embeddings sync.
public struct EmbeddingsPage: Codable, Sendable, Equatable {
    public let data: [EmbeddingsItem]
    public let nextCursor: String?
    public let hasMore: Bool

    public init(data: [EmbeddingsItem], nextCursor: String?, hasMore: Bool) {
        self.data = data
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

/// Resource: server-side oeuvre embeddings used by the on-device ranker.
///
/// The host should invoke `oeuvres(...)` explicitly (e.g. on a manual
/// refresh) — we deliberately do NOT auto-fetch at app launch so the user's
/// privacy contract is preserved (no implicit background network call).
public struct EmbeddingsResource: Sendable {
    let client: CultureAPIClient

    public func oeuvres(
        since: Date? = nil,
        limit: Int? = nil,
        cursor: String? = nil
    ) async throws -> EmbeddingsPage {
        var query: [String: String] = [:]
        if let since {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            query["since"] = fmt.string(from: since)
        }
        if let limit { query["limit"] = String(limit) }
        if let cursor { query["cursor"] = cursor }
        // Mounted OUTSIDE /api (host root), un-authenticated + edge-cached. Using
        // `get` (which targets /api/…) 404'd — the remote-embeddings sync never
        // landed and the ranker silently fell back to on-device NLEmbedding.
        return try await client.getPublic("public/embeddings/oeuvres", query: query)
    }
}

/// A single curator (signal-source) taste vector from the server.
///
/// `embedding` is the L2-normalised centroid of the oeuvres this source
/// positively reviewed (1024-d) — cosine = dot product, no re-normalisation.
public struct CuratorVectorItem: Codable, Sendable, Equatable {
    public let id: String          // source_id
    public let name: String?
    public let embedding: [Float]
    public let positiveCount: Int?
    public let updatedAt: Date?

    public init(id: String, name: String? = nil, embedding: [Float], positiveCount: Int? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.embedding = embedding
        self.positiveCount = positiveCount
        self.updatedAt = updatedAt
    }
}

/// One page of a curator-vectors sync. Same envelope as `EmbeddingsPage`.
public struct CuratorVectorsPage: Codable, Sendable, Equatable {
    public let data: [CuratorVectorItem]
    public let nextCursor: String?
    public let hasMore: Bool

    public init(data: [CuratorVectorItem], nextCursor: String?, hasMore: Bool) {
        self.data = data
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

/// Resource: server-side per-source curator taste vectors for on-device
/// user↔curator matching in Le Fil. Host-root public feed; same opt-in,
/// no-auto-fetch contract as `EmbeddingsResource`.
public struct CuratorVectorsResource: Sendable {
    let client: CultureAPIClient

    public func curators(
        since: Date? = nil,
        limit: Int? = nil,
        cursor: String? = nil
    ) async throws -> CuratorVectorsPage {
        var query: [String: String] = [:]
        if let since {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            query["since"] = fmt.string(from: since)
        }
        if let limit { query["limit"] = String(limit) }
        if let cursor { query["cursor"] = cursor }
        return try await client.getPublic("public/embeddings/curators", query: query)
    }
}
