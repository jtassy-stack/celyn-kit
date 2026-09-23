import Foundation

/// A TV episode of a series / anime (culture-api migration 0135). Not a
/// podcast episode — see `PodcastEpisode` for those.
///
/// Compact form, as embedded in `Oeuvre.nextEpisode` / `lastEpisode` /
/// `currentSeasonEpisodes`.
public struct EpisodeSummary: Codable, Sendable, Equatable, Hashable {
    public let seasonNumber: Int
    public let episodeNumber: Int
    /// TMDB fr-FR title. TMDB uses "Épisode N" for untitled episodes.
    public let name: String?
    /// First-air date (date-only, decoded at noon UTC). nil = not dated yet.
    /// Since culture-api 0136 this is the Europe/Paris day of `airAt` when known.
    public let airDate: Date?
    /// Exact first-air instant (TVmaze airtime / AniList simulcast), when the
    /// server knows it (culture-api migration 0136). nil = only the day is known
    /// / older server. Display it in the user's time zone.
    public var airAt: Date? = nil

    public init(seasonNumber: Int, episodeNumber: Int, name: String? = nil, airDate: Date? = nil, airAt: Date? = nil) {
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.name = name
        self.airDate = airDate
        self.airAt = airAt
    }

    /// "S2E5".
    public var code: String { "S\(seasonNumber)E\(episodeNumber)" }
}

/// A direct streaming link for a series (anime, from AniList — e.g. "Crunchyroll").
/// culture-api migration 0136.
public struct WatchLink: Codable, Sendable, Equatable, Hashable {
    /// "Crunchyroll" | "Netflix" | "Amazon Prime Video" | "Disney Plus" | "Apple TV+" | "Max".
    public let site: String
    public let url: String

    public init(site: String, url: String) {
        self.site = site
        self.url = url
    }

    /// Parsed URL (nil when malformed).
    public var link: URL? { URL(string: url) }
}

/// An included-offer platform on an upcoming episode's series.
public struct EpisodeStreamingProvider: Codable, Sendable, Equatable, Hashable {
    public let providerId: Int
    public let providerName: String
    public let logoUrl: String?
    /// "flatrate" | "free" | "ads".
    public let monetization: String?

    public init(providerId: Int, providerName: String, logoUrl: String? = nil, monetization: String? = nil) {
        self.providerId = providerId
        self.providerName = providerName
        self.logoUrl = logoUrl
        self.monetization = monetization
    }
}

/// Parent series summary on an `Episode` from `episodes.upcoming()`.
public struct EpisodeSeries: Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let oeuvreType: OeuvreType?
    public let imageUrl: String?
    public let isAnime: Bool?
    public var streamingProviderIds: [Int]? = nil
    public var streamingProviders: [EpisodeStreamingProvider]? = nil
    /// Direct streaming links (anime, AniList). nil = older server; [] = none. Migration 0136.
    public var watchLinks: [WatchLink]? = nil

    public init(id: String, title: String, oeuvreType: OeuvreType? = .tvshow, imageUrl: String? = nil, isAnime: Bool? = nil, streamingProviderIds: [Int]? = nil, streamingProviders: [EpisodeStreamingProvider]? = nil, watchLinks: [WatchLink]? = nil) {
        self.id = id
        self.title = title
        self.oeuvreType = oeuvreType
        self.imageUrl = imageUrl
        self.isAnime = isAnime
        self.streamingProviderIds = streamingProviderIds
        self.streamingProviders = streamingProviders
        self.watchLinks = watchLinks
    }
}

/// A TV episode airing soon, with its series (`GET /api/episodes/upcoming`).
public struct Episode: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let seasonNumber: Int
    public let episodeNumber: Int
    public let name: String?
    public let overview: String?
    /// First-air date (date-only, decoded at noon UTC) — the Europe/Paris day
    /// the episode airs (Paris day of `airAt` when known, culture-api 0136).
    public let airDate: Date?
    /// Exact first-air instant when known (TVmaze / AniList, migration 0136).
    /// nil = only the day is known / older server.
    public var airAt: Date? = nil
    /// Minutes.
    public let runtime: Int?
    public let stillUrl: String?
    public let oeuvre: EpisodeSeries

    public init(id: String, seasonNumber: Int, episodeNumber: Int, name: String? = nil, overview: String? = nil, airDate: Date? = nil, airAt: Date? = nil, runtime: Int? = nil, stillUrl: String? = nil, oeuvre: EpisodeSeries) {
        self.id = id
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.name = name
        self.overview = overview
        self.airDate = airDate
        self.airAt = airAt
        self.runtime = runtime
        self.stillUrl = stillUrl
        self.oeuvre = oeuvre
    }

    /// "S2E5".
    public var code: String { "S\(seasonNumber)E\(episodeNumber)" }
}

public struct EpisodeListResponse: Codable, Sendable {
    public let data: [Episode]
    public let count: Int
    /// Window actually served (date-only).
    public var from: Date? = nil
    public var to: Date? = nil
    public var attribution: String? = nil
}
