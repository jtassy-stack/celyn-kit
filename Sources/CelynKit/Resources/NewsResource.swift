import Foundation

/// The Actu (news) vertical — `GET /api/news/*`. Mirrors
/// culture-api/sdk/src/resources/news.ts exactly. Runs on the same box/key
/// as everything else in CelynKit (Caddy proxies `/api/news*` to the actu
/// box transparently) — no separate key or configuration needed.
public struct NewsResource: Sendable {
    let client: CultureAPIClient

    public struct StoryListParams: Sendable {
        /// Max 100, default 30.
        public var limit: Int?
        /// "recent" (lastUpdateAt desc, default) or "confidence" (confidenceScore desc).
        public var sort: String?
        public var kind: NewsEventKind?
        /// "active" (default) | "cooling" | "archived" | "all" (no status filter).
        public var status: String?
        /// Only stories whose lastUpdateAt ≥ since (incremental polling).
        public var since: Date?
        /// Entity tokens (OR); normalized server-side like ingest.
        public var entity: [String]?

        public init(
            limit: Int? = nil,
            sort: String? = nil,
            kind: NewsEventKind? = nil,
            status: String? = nil,
            since: Date? = nil,
            entity: [String]? = nil
        ) {
            self.limit = limit
            self.sort = sort
            self.kind = kind
            self.status = status
            self.since = since
            self.entity = entity
        }
    }

    public struct EventListParams: Sendable {
        /// Max 200, default 50.
        public var limit: Int?
        public var kind: NewsEventKind?
        /// Only events published (or ingested) at or after this instant.
        public var since: Date?
        public var entity: [String]?

        public init(
            limit: Int? = nil,
            kind: NewsEventKind? = nil,
            since: Date? = nil,
            entity: [String]? = nil
        ) {
            self.limit = limit
            self.kind = kind
            self.since = since
            self.entity = entity
        }
    }

    public func stories(_ params: StoryListParams = .init()) async throws -> NewsStoryListResponse {
        var query: [String: String] = [:]
        if let l = params.limit { query["limit"] = String(l) }
        if let s = params.sort { query["sort"] = s }
        if let k = params.kind { query["kind"] = k.rawValue }
        if let st = params.status { query["status"] = st }
        if let since = params.since { query["since"] = ISO8601DateFormatter().string(from: since) }
        // Server expects repeated `entity=` params, but the client's `get`
        // takes a flat [String: String] — join with commas is NOT what the
        // server parses (it reads c.req.queries("entity")), so multi-entity
        // filtering isn't supported through this convenience method yet.
        if let entities = params.entity, let first = entities.first { query["entity"] = first }
        return try await client.get("news/stories", query: query)
    }

    public func story(id: String) async throws -> NewsStoryDetail {
        let response: NewsStoryDetailResponse = try await client.get("news/stories/\(id)")
        return response.data
    }

    public func feed(_ params: EventListParams = .init()) async throws -> NewsEventListResponse {
        var query: [String: String] = [:]
        if let l = params.limit { query["limit"] = String(l) }
        if let k = params.kind { query["kind"] = k.rawValue }
        if let since = params.since { query["since"] = ISO8601DateFormatter().string(from: since) }
        if let entities = params.entity, let first = entities.first { query["entity"] = first }
        return try await client.get("news/feed", query: query)
    }

    public func feedItem(id: String) async throws -> NewsEvent {
        let response: NewsEventDetailResponse = try await client.get("news/feed/\(id)")
        return response.data
    }
}
