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

public extension OeuvreRef {
    /// Promote a lightweight reference to a full Oeuvre using only the fields
    /// available on the ref. Synopsis, topics, etc. will be missing — fine for
    /// a detail screen that just shows what we already have.
    func asOeuvre() -> Oeuvre? {
        guard let id, let title else { return nil }
        return Oeuvre(
            id: id,
            title: title,
            originalTitle: nil,
            oeuvreType: type ?? .film,
            year: year,
            director: director,
            author: nil,
            description: nil,
            genres: genres,
            imageUrl: imageUrl,
            ageMin: nil,
            ageMax: nil,
            duration: nil,
            thematicTags: nil,
            topics: nil
        )
    }
}

public extension Oeuvre {
    /// True when we're confident the work suits a young audience.
    ///
    /// Scoped to types whose celyn-api kid metadata is reliable (livres,
    /// films, podcasts, théâtre, opéra). Music (album / song) is excluded
    /// because the API tags rap albums with "Programme scolaire" topics —
    /// an explicit-content cover next to a "Enfants" badge is worse than no
    /// badge at all.
    var isKidFriendly: Bool {
        switch oeuvreType {
        case .album, .song:
            return false
        default:
            let kidTopics: Set<String> = ["scolaire", "programme scolaire", "enfants", "famille", "jeunesse", "kids", "family"]
            if let topics, topics.contains(where: { kidTopics.contains($0.lowercased()) }) { return true }
            if let max = ageMax, max <= 12 { return true }
            return false
        }
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
