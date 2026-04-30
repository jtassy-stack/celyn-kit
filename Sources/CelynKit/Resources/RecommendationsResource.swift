import Foundation

public struct RecommendationsResource: Sendable {
    let client: CultureAPIClient

    public func get(oeuvreId: String, limit: Int? = nil) async throws -> RecommendationResponse {
        var query: [String: String] = [:]
        if let l = limit { query["limit"] = String(l) }
        return try await client.get("recommendations/\(oeuvreId)", query: query)
    }
}
