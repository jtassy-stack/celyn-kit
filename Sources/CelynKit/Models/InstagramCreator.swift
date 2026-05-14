import Foundation

/// A curated Instagram account tracked by culture-api as a cultural source
/// (cinema, books, food, music, art). Mirrors `GET /api/creators/instagram`.
///
/// Curated manually by the editorial team — Instagram's TOS forbid scraping,
/// so each row is a deliberate editorial choice rather than an automated
/// crawl result. Surfaced in the iOS agenda alongside oeuvres and podcast
/// sources as one of the "à consommer" picks.
public struct InstagramCreator: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let handle: String
    public let displayName: String
    public let bioShort: String?
    public let avatarUrl: String?
    public let profileUrl: String?
    public let vertical: String
    public let language: String?
    public let followerCount: Int?
    public let isFeatured: Bool

    public init(
        id: String,
        handle: String,
        displayName: String,
        bioShort: String? = nil,
        avatarUrl: String? = nil,
        profileUrl: String? = nil,
        vertical: String,
        language: String? = nil,
        followerCount: Int? = nil,
        isFeatured: Bool = false
    ) {
        self.id = id
        self.handle = handle
        self.displayName = displayName
        self.bioShort = bioShort
        self.avatarUrl = avatarUrl
        self.profileUrl = profileUrl
        self.vertical = vertical
        self.language = language
        self.followerCount = followerCount
        self.isFeatured = isFeatured
    }
}

public struct InstagramCreatorListResponse: Codable, Sendable {
    public let data: [InstagramCreator]
    public let count: Int
}

public extension InstagramCreator {
    /// Project an Instagram curator onto a synthetic Oeuvre so it flows
    /// through the same home-pick pipeline as books, films, podcasts, etc.
    ///
    /// The synth is typed `.other` because the curator isn't a work in the
    /// traditional sense — they're a feed. `description` carries the bio,
    /// `topics` carries the vertical, `genres` is mirrored so the row
    /// surfaces a "books" / "cinema" chip the same way a podcast source
    /// does. Id is namespaced with `ig-creator-` to keep cross-day dedup
    /// collision-free.
    func asOeuvre() -> Oeuvre {
        Oeuvre(
            id: "ig-creator-\(id)",
            title: displayName,
            originalTitle: nil,
            oeuvreType: .other,
            year: nil,
            director: nil,
            author: "@\(handle)",
            description: bioShort,
            genres: [vertical],
            imageUrl: avatarUrl,
            trailerUrl: nil,
            ageMin: nil,
            ageMax: nil,
            duration: nil,
            thematicTags: nil,
            topics: [vertical],
            publisher: "Instagram",
            isKidFriendly: nil,
            opinions: nil,
            opinionCount: nil
        )
    }
}
