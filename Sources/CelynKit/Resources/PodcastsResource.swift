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
}
