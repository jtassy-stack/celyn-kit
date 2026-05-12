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

    /// `GET /podcasts/episodes?source_id=...&limit=N` — list recent episodes
    /// for a source, newest first. Use `limit: 1` to get just the latest.
    public func episodes(sourceId: String, limit: Int = 20) async throws -> PodcastEpisodeListResponse {
        let query: [String: String] = [
            "source_id": sourceId,
            "limit": String(limit),
        ]
        return try await client.get("podcasts/episodes", query: query)
    }
}
