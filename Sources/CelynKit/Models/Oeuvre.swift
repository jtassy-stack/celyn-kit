import Foundation

public struct Oeuvre: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let originalTitle: String?
    public let oeuvreType: OeuvreType
    public let year: Int?
    public let director: String?
    public let author: String?
    public let description: String?
    public let genres: [String]?
    public let imageUrl: String?
    public let ageMin: Int?
    public let ageMax: Int?
    public let duration: Int?
    public let thematicTags: [String]?
    public let topics: [String]?
}

/// Lightweight oeuvre reference embedded in events / seances.
public struct OeuvreRef: Codable, Sendable, Equatable {
    public let id: String?
    public let title: String?
    public let type: OeuvreType?
    public let director: String?
    public let year: Int?
    public let imageUrl: String?
    public let genres: [String]?

    public init(
        id: String? = nil,
        title: String? = nil,
        type: OeuvreType? = nil,
        director: String? = nil,
        year: Int? = nil,
        imageUrl: String? = nil,
        genres: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.director = director
        self.year = year
        self.imageUrl = imageUrl
        self.genres = genres
    }
}

public extension Oeuvre {
    var isKidFriendly: Bool {
        let kidTopics: Set<String> = ["scolaire", "programme scolaire", "enfants", "famille", "jeunesse", "kids", "family"]
        if let topics, topics.contains(where: { kidTopics.contains($0.lowercased()) }) { return true }
        if let max = ageMax, max <= 12 { return true }
        return false
    }
}

public struct OeuvreOpinion: Codable, Sendable, Equatable {
    public let id: String
    public let oeuvreId: String
    public let source: String
    public let sourceTitle: String?
    public let quote: String
    public let author: String?
    public let sentiment: Sentiment
    public let publishedAt: Date?
    public let url: String?
}

public struct OeuvreListResponse: Codable, Sendable {
    public let data: [Oeuvre]
    public let count: Int
}
