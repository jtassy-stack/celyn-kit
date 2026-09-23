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
    public let airDate: Date?

    public init(seasonNumber: Int, episodeNumber: Int, name: String? = nil, airDate: Date? = nil) {
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.name = name
        self.airDate = airDate
    }

    /// "S2E5".
    public var code: String { "S\(seasonNumber)E\(episodeNumber)" }
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

    public init(id: String, title: String, oeuvreType: OeuvreType? = .tvshow, imageUrl: String? = nil, isAnime: Bool? = nil, streamingProviderIds: [Int]? = nil, streamingProviders: [EpisodeStreamingProvider]? = nil) {
        self.id = id
        self.title = title
        self.oeuvreType = oeuvreType
        self.imageUrl = imageUrl
        self.isAnime = isAnime
        self.streamingProviderIds = streamingProviderIds
        self.streamingProviders = streamingProviders
    }
}

/// A TV episode airing soon, with its series (`GET /api/episodes/upcoming`).
public struct Episode: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let seasonNumber: Int
    public let episodeNumber: Int
    public let name: String?
    public let overview: String?
    /// First-air date (date-only, decoded at noon UTC).
    public let airDate: Date?
    /// Minutes.
    public let runtime: Int?
    public let stillUrl: String?
    public let oeuvre: EpisodeSeries

    public init(id: String, seasonNumber: Int, episodeNumber: Int, name: String? = nil, overview: String? = nil, airDate: Date? = nil, runtime: Int? = nil, stillUrl: String? = nil, oeuvre: EpisodeSeries) {
        self.id = id
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.name = name
        self.overview = overview
        self.airDate = airDate
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
