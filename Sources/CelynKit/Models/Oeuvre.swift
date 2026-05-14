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
    /// Films / series only — official trailer URL (typically YouTube watch
    /// URL) sourced from TMDB by culture-api's enrich-trailers job. NULL when
    /// no trailer is available; consumers should fall back to a search.
    public let trailerUrl: String?
    public let ageMin: Int?
    public let ageMax: Int?
    public let duration: Int?
    public let thematicTags: [String]?
    public let topics: [String]?
    public let publisher: String?
    /// Server-side hint, sent by culture-api once it has audited an oeuvre's
    /// suitability. Authoritative when present:
    ///   - `true`  → trust it; the heuristic is bypassed (the row was
    ///               positively vetted for kids).
    ///   - `false` → trust it; the row was *explicitly* marked unsuitable
    ///               for kids (e.g. adult HBO comedy mis-tagged with
    ///               "Programme scolaire" topic) and the badge must not
    ///               show, even when other heuristic signals would say yes.
    ///   - `nil`   → no audit yet; fall back to the on-device heuristic.
    public let isKidFriendly: Bool?
    public let opinions: [OeuvreOpinion]?
    public let opinionCount: Int?
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
    /// Same authoritative server hint as `Oeuvre.isKidFriendly`. Carried on
    /// the ref so list-level surfaces (FilmGroup, EventCard) can apply the
    /// veto without needing a second fetch.
    public let isKidFriendly: Bool?

    public init(
        id: String? = nil,
        title: String? = nil,
        type: OeuvreType? = nil,
        director: String? = nil,
        year: Int? = nil,
        imageUrl: String? = nil,
        genres: [String]? = nil,
        isKidFriendly: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.director = director
        self.year = year
        self.imageUrl = imageUrl
        self.genres = genres
        self.isKidFriendly = isKidFriendly
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
            trailerUrl: nil,
            ageMin: nil,
            ageMax: nil,
            duration: nil,
            thematicTags: nil,
            topics: nil,
            publisher: nil,
            isKidFriendly: nil,
            opinions: nil,
            opinionCount: nil
        )
    }
}

public extension Oeuvre {
    /// True when we're confident the work suits a young audience.
    ///
    /// Two-step gate:
    /// 1. Honour the explicit server hint (`isKidFriendly`) when present —
    ///    `false` is an authoritative veto, `true` an authoritative accept.
    /// 2. Otherwise fall back to the on-device heuristic: scoped to types
    ///    whose celyn-api kid metadata is reliable (livres, films, podcasts,
    ///    théâtre, opéra). Music (album / song) is excluded because the API
    ///    tags rap albums with "Programme scolaire" topics.
    ///
    /// Always read this — never read the stored `isKidFriendly` directly
    /// in UI or services. Doing so bypasses the heuristic fallback for
    /// rows the backend hasn't audited yet (nil).
    var effectiveIsKidFriendly: Bool {
        if let server = isKidFriendly { return server }
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

/// A critic's opinion sourced from a podcast/radio/YouTube segment.
public struct OeuvreOpinion: Codable, Sendable, Equatable, Hashable {
    public let criticName: String?
    public let opinionSummary: String
    public let sentiment: Sentiment
    public let keyQuotes: [String]?
    public let episodeTitle: String?
    public let showName: String?
    public let station: String?
    public let publishedAt: Date?
    public let segmentStart: Int?
    public let segmentEnd: Int?
    public let audioUrl: String?
    public let episodeId: String?
}

public struct OeuvreListResponse: Codable, Sendable {
    public let data: [Oeuvre]
    public let count: Int
}
