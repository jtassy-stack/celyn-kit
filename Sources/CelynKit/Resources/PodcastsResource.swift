import Foundation

public struct PodcastsResource: Sendable {
    let client: CultureAPIClient

    /// `GET /podcasts/sources` — lists all active podcast/radio/YouTube/newsletter
    /// sources tracked by culture-api.
    public func sources(limit: Int? = nil) async throws -> PodcastSourceListResponse {
        var query: [String: String] = [:]
        if let l = limit { query["limit"] = String(l) }
        return try await client.get("podcasts/sources", query: query)
    }

    /// `GET /podcasts/episodes?source_id=...&limit=N` — recent episodes,
    /// newest first. Omit `sourceId` for the global latest-episodes feed
    /// across every source; pass it (with `limit: 1`) for just one source's
    /// latest.
    public func episodes(sourceId: String? = nil, limit: Int = 20) async throws -> PodcastEpisodeListResponse {
        var query: [String: String] = ["limit": String(limit)]
        if let sourceId { query["source_id"] = sourceId }
        return try await client.get("podcasts/episodes", query: query)
    }

    /// `GET /podcasts/feed` — ranked recent items with the oeuvres they
    /// discuss. `sourceType` restricts to one source type before ranking:
    /// `.rss` for audio podcasts, `.youtube` for videos.
    public func feed(sourceType: PodcastFeedSourceType? = nil, limit: Int? = nil) async throws -> PodcastFeedResponse {
        try await client.get("podcasts/feed", query: Self.feedQuery(sourceType: sourceType, limit: limit))
    }

    /// Query builder for `feed`, exposed for tests.
    public static func feedQuery(sourceType: PodcastFeedSourceType? = nil, limit: Int? = nil) -> [String: String] {
        var query: [String: String] = [:]
        if let sourceType { query["source_type"] = sourceType.rawValue }
        if let limit { query["limit"] = String(limit) }
        return query
    }
}

public enum PodcastFeedSourceType: String, Sendable {
    case rss
    case youtube
}
