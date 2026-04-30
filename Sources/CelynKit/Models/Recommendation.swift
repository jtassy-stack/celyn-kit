import Foundation

public struct RecommendedOeuvre: Codable, Sendable, Equatable {
    public let oeuvre: Oeuvre
    public let score: Double
    public let reasons: [String]?
}

public struct RecommendationResponse: Codable, Sendable {
    public let data: [RecommendedOeuvre]
    public let count: Int
}
