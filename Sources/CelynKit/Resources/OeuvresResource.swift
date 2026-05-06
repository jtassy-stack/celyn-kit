import Foundation

public struct OeuvresResource: Sendable {
    let client: CultureAPIClient

    public func list(type: OeuvreType? = nil, limit: Int? = nil) async throws -> OeuvreListResponse {
        var query: [String: String] = [:]
        if let t = type { query["type"] = t.rawValue }
        if let l = limit { query["limit"] = String(l) }
        return try await client.get("oeuvres", query: query)
    }

    public func get(id: String) async throws -> Oeuvre {
        try await client.get("oeuvres/\(id)")
    }

    public func opinions(id: String) async throws -> [OeuvreOpinion] {
        struct Wrap: Decodable { let data: [OeuvreOpinion] }
        let w: Wrap = try await client.get("oeuvres/\(id)/opinions")
        return w.data
    }
}
