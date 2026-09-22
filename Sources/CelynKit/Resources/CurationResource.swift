import Foundation

/// The subscribable curator catalogue — `GET /curation/sources`. Distinct
/// from `FeedResource` (`/curation/feed`, the scored editorial feed): this
/// is the flat browsable list of sources themselves.
public struct CurationResource: Sendable {
    let client: CultureAPIClient

    public struct SourceListParams: Sendable {
        public var city: String?
        public var category: String?
        public var sourceType: String?
        public var featuredOnly: Bool?
        public var limit: Int?
        public var offset: Int?

        public init(
            city: String? = nil,
            category: String? = nil,
            sourceType: String? = nil,
            featuredOnly: Bool? = nil,
            limit: Int? = nil,
            offset: Int? = nil
        ) {
            self.city = city
            self.category = category
            self.sourceType = sourceType
            self.featuredOnly = featuredOnly
            self.limit = limit
            self.offset = offset
        }
    }

    public func sources(_ params: SourceListParams = .init()) async throws -> CuratedSourceListResponse {
        var query: [String: String] = [:]
        if let c = params.city { query["city"] = c }
        if let c = params.category { query["category"] = c }
        if let t = params.sourceType { query["source_type"] = t }
        if params.featuredOnly == true { query["featured"] = "true" }
        if let l = params.limit { query["limit"] = String(l) }
        if let o = params.offset { query["offset"] = String(o) }
        return try await client.get("curation/sources", query: query)
    }
}
