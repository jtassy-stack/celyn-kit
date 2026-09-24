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
    /// Films / tvshow / series only — where to watch it, sourced from TMDB
    /// (France only) by culture-api's enrich-streaming-providers job. NULL
    /// until enriched, or when TMDB has no French offer for the title.
    public let streamingProviders: StreamingAvailability?
    /// Only on `oeuvres.list(sort: .mentioned)`: distinct sources with a
    /// direct opinion on this oeuvre over the server's recent window (180 days).
    public var sourceCount: Int? = nil
    /// Only on `oeuvres.list(sort: .mentioned)`: when the oeuvre was last
    /// discussed by a source. nil = no recent mention (or other sort).
    public var lastMentionedAt: Date? = nil
    /// Only on `oeuvres.list(sort: .mentioned / .upcoming)`: French theatrical release
    /// date (date-only, decoded at noon UTC). nil = unknown / not a film.
    public var releaseDateTheatricalFr: Date? = nil
    /// Only on `oeuvres.list(sort: .mentioned / .upcoming)`: French digital (VOD/EST)
    /// release date (date-only, decoded at noon UTC).
    public var releaseDateDigitalFr: Date? = nil
    /// Only on `oeuvres.list(sort: .mentioned / .upcoming)`: French TV premiere date
    /// (date-only, decoded at noon UTC).
    public var releaseDateTvFr: Date? = nil
    /// Only on `oeuvres.list(sort: .mentioned / .upcoming)`: most recent arrival on a
    /// French streaming provider. nil = none known.
    public var streamingLatestArrivalAt: Date? = nil
    /// Only on `oeuvres.list(sort: .mentioned / .upcoming)`: currently showing in French
    /// cinemas. nil = not reported (older server or other sort).
    public var nowShowing: Bool? = nil
    /// Literary prize selections / wins (books; culture-api migration 0132),
    /// one entry per (prize, year, category) at the best stage reached,
    /// newest year first. Always sent by `oeuvres.get(id:)` (`[]` when none);
    /// on `oeuvres.list(sort: .mentioned)` only for oeuvres that have one.
    /// nil = not reported (older server, other sort, or no award in a list).
    public var awards: [OeuvreAward]? = nil
    /// Most recent award announcement (any stage), date-only decoded at noon
    /// UTC. A recency event for ranking. nil = none / not reported.
    public var latestAwardAt: Date? = nil
    /// Films only — a public trailer page that is NOT a YouTube video (today
    /// an AlloCiné player page, culture-api migration 0133). Cannot be played
    /// in-app: open it externally, and only when `trailerUrl` is nil
    /// (`trailerUrl` stays a YouTube watch URL). nil = none / older server.
    public var trailerExternalUrl: String? = nil
    /// Japanese animation (culture-api migration 0134: TMDB original
    /// language `ja` + Animation genre). nil = unclassified / older server.
    public var isAnime: Bool? = nil
    /// List rows only (`oeuvres.list`): TMDB provider ids with an offer
    /// INCLUDED with the service in France (subscription, free or
    /// ad-supported — never rent/buy). Match against
    /// `StreamingPlatform.providerId` for "mes plateformes" filtering.
    /// nil = not reported (older server / detail endpoint); [] = none known.
    public var streamingProviderIds: [Int]? = nil
    /// tvshow / series only, on `oeuvres.list(sort: .mentioned / .upcoming)`:
    /// air date of the next episode dated today (Paris) or later (date-only,
    /// decoded at noon UTC). nil = nothing scheduled / not TV / older server.
    public var nextEpisodeAt: Date? = nil
    /// tvshow / series only, on `oeuvres.get(id:)`: next episode (an episode
    /// airing today counts as next). nil = none known / older server.
    public var nextEpisode: EpisodeSummary? = nil
    /// tvshow / series only, on `oeuvres.get(id:)`: most recent episode aired
    /// before today. nil = none known / older server.
    public var lastEpisode: EpisodeSummary? = nil
    /// tvshow / series only, on `oeuvres.get(id:)`: the current season's
    /// episodes in order. nil = older server / not TV; [] = not enriched yet.
    public var currentSeasonEpisodes: [EpisodeSummary]? = nil
    /// tvshow / series only, on `oeuvres.get(id:)`: direct streaming links
    /// (anime, AniList — e.g. Crunchyroll). nil = older server; [] = none.
    /// culture-api migration 0136.
    public var watchLinks: [WatchLink]? = nil
    /// Games only (culture-api games vertical, IGDB): platform slugs among
    /// ps5, ps4, xbox-series, xbox-one, switch, switch-2, pc, mac, linux, ios,
    /// android. nil = unknown / not a game / older server.
    public var platforms: [String]? = nil
    /// Games only, on `oeuvres.list(sort: .mentioned / .upcoming)` and
    /// `oeuvres.get(id:)`: earliest French (Europe, else worldwide) day-precise
    /// release date across platforms (date-only, decoded at noon UTC).
    public var releaseDateGameFr: Date? = nil
    /// Games only, on `oeuvres.list(type: .game, sort: .upcoming)`: the
    /// earliest release inside the requested window and its platforms.
    public var upcomingRelease: GameUpcomingRelease? = nil
    /// Games only, `oeuvres.get(id:)`: main developer studio.
    public var developer: String? = nil
    /// Games only, `oeuvres.get(id:)`: IGDB id.
    public var igdbId: Int? = nil
    /// Games only, `oeuvres.get(id:)`: every known release (all regions).
    public var releases: [GameRelease]? = nil
    /// Games only, `oeuvres.get(id:)`: one release per platform for France
    /// (Europe else worldwide), soonest first.
    public var releasesFr: [GameRelease]? = nil
    /// Games only, `oeuvres.get(id:)`: where to buy / play.
    public var storeLinks: [GameStoreLink]? = nil
    /// Games only, `oeuvres.get(id:)`: "Game data by IGDB.com".
    public var gameDataAttribution: String? = nil
    /// Films, on `oeuvres.list(sort: .mentioned / .upcoming)` and
    /// `oeuvres.get(id:)`: earliest active screening from now on (UTC).
    /// nil = none scheduled / not reported (older server, other type).
    /// culture-api migration 0140; `nowShowing` is derived from it server-side.
    public var nextScreeningAt: Date? = nil
    /// Films only, `oeuvres.get(id:)`: the earliest screening and its venue.
    /// nil = none / older server.
    public var nextScreening: OeuvreNextScreening? = nil
    /// Artworks only, `oeuvres.get(id:)`: where the work hangs (Wikidata
    /// location / collection, matched to a venue when possible).
    /// nil = unknown / older server / not an artwork.
    public var location: ArtworkLocation? = nil
}

/// Films: the next screening on `oeuvres.get(id:)`.
public struct OeuvreNextScreening: Codable, Sendable, Equatable, Hashable {
    public let startsAt: Date
    public var venueId: String? = nil
    public var venueName: String? = nil

    public init(startsAt: Date, venueId: String? = nil, venueName: String? = nil) {
        self.startsAt = startsAt
        self.venueId = venueId
        self.venueName = venueName
    }
}

/// Artworks: where the work can be seen (museum / collection).
public struct ArtworkLocation: Codable, Sendable, Equatable, Hashable {
    /// Museum / collection name as given by Wikidata.
    public let label: String
    public var wikidataId: String? = nil
    /// Matched culture-api venue id; nil when no venue matched.
    public var venueId: String? = nil
    /// Matched venue (the only source of a city). nil when unmatched.
    public var venue: ArtworkLocationVenue? = nil

    public init(label: String, wikidataId: String? = nil, venueId: String? = nil, venue: ArtworkLocationVenue? = nil) {
        self.label = label
        self.wikidataId = wikidataId
        self.venueId = venueId
        self.venue = venue
    }
}

public struct ArtworkLocationVenue: Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public var city: String? = nil
    public var latitude: Double? = nil
    public var longitude: Double? = nil

    public init(id: String, name: String, city: String? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id
        self.name = name
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// A game release on one platform in one region (IGDB).
public struct GameRelease: Codable, Sendable, Equatable, Hashable {
    /// Platform slug (ps5, switch-2, pc, …).
    public let platform: String
    public var platformName: String? = nil
    /// "europe", "worldwide", "north_america", "japan", …
    public var region: String? = nil
    /// Date-only (noon UTC). nil when not day/month precise or unknown.
    public var date: Date? = nil
    /// "day" | "month" | "quarter" | "year" | "tbd".
    public var precision: String? = nil
    /// Human-readable IGDB date ("Q4 2026", "Nov 12, 2026", "TBD").
    public var human: String? = nil
    public var status: String? = nil

    public init(platform: String, platformName: String? = nil, region: String? = nil, date: Date? = nil, precision: String? = nil, human: String? = nil, status: String? = nil) {
        self.platform = platform
        self.platformName = platformName
        self.region = region
        self.date = date
        self.precision = precision
        self.human = human
        self.status = status
    }

    /// True when `date` is an actual day.
    public var isDayPrecise: Bool { date != nil && (precision == nil || precision == "day") }
}

/// Earliest upcoming release in a `sort=upcoming&type=game` window.
public struct GameUpcomingRelease: Codable, Sendable, Equatable, Hashable {
    public let date: Date
    public let platforms: [String]

    public init(date: Date, platforms: [String]) {
        self.date = date
        self.platforms = platforms
    }
}

/// Store page for a game ("steam" | "playstation" | "xbox" | "nintendo" | "epic" | "gog").
public struct GameStoreLink: Codable, Sendable, Equatable, Hashable {
    public let store: String
    public let url: String

    public init(store: String, url: String) {
        self.store = store
        self.url = url
    }

    public var link: URL? { URL(string: url) }
}

/// A game platform from `oeuvres.gamePlatforms()` (`GET /oeuvres/game-platforms`).
public struct GamePlatform: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let slug: String
    public let name: String
    public let gameCount: Int
    public let upcomingCount: Int

    public var id: String { slug }

    public init(slug: String, name: String, gameCount: Int, upcomingCount: Int) {
        self.slug = slug
        self.name = name
        self.gameCount = gameCount
        self.upcomingCount = upcomingCount
    }
}

public struct GamePlatformListResponse: Codable, Sendable {
    public let data: [GamePlatform]
    public let count: Int
}

/// A literary prize selection or win ("Prix Goncourt 2026 · 1re sélection").
public struct OeuvreAward: Codable, Sendable, Equatable, Hashable {
    public enum Stage: String, Codable, Sendable, Equatable, Hashable, Comparable {
        case selection1 = "selection_1"
        case selection2 = "selection_2"
        case selection3 = "selection_3"
        case finalist
        case winner
        /// A stage this CelynKit version doesn't know yet.
        case unknown

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Stage(rawValue: raw) ?? .unknown
        }

        /// selection1 < selection2 < selection3 < finalist < winner (unknown lowest).
        public var rank: Int {
            switch self {
            case .unknown: return 0
            case .selection1: return 1
            case .selection2: return 2
            case .selection3: return 3
            case .finalist: return 4
            case .winner: return 5
            }
        }

        public static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rank < rhs.rank }
    }

    /// Display name, e.g. "Prix Goncourt".
    public let prize: String
    /// goncourt | renaudot | femina | medicis | grand-prix-roman-academie-francaise |
    /// interallie | goncourt-lyceens | prix-du-livre-inter | decembre | wepler | flore
    public let prizeSlug: String
    public let year: Int
    public let stage: Stage
    /// "roman" (French novel / default), "roman-etranger", "essai".
    public let category: String
    /// Announcement date of that stage (date-only, decoded at noon UTC).
    public let announcedAt: Date?

    public init(prize: String, prizeSlug: String, year: Int, stage: Stage, category: String = "roman", announcedAt: Date? = nil) {
        self.prize = prize
        self.prizeSlug = prizeSlug
        self.year = year
        self.stage = stage
        self.category = category
        self.announcedAt = announcedAt
    }
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
            opinionCount: nil,
            streamingProviders: nil
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
    ///    whose celyn-api kid metadata is reliable (podcasts, théâtre, opéra…).
    ///    Music (album / song) is excluded because the API tags rap albums
    ///    with "Programme scolaire" topics; books and films too, because
    ///    adult novels / films carry "famille" or "scolaire" topics — they
    ///    are never badged without an explicit server verdict.
    ///
    /// Always read this — never read the stored `isKidFriendly` directly
    /// in UI or services. Doing so bypasses the heuristic fallback for
    /// rows the backend hasn't audited yet (nil).
    var effectiveIsKidFriendly: Bool {
        if let server = isKidFriendly { return server }
        switch oeuvreType {
        case .album, .song, .book, .film:
            return false
        default:
            let kidTopics: Set<String> = ["scolaire", "programme scolaire", "enfants", "famille", "jeunesse", "kids", "family"]
            if let topics, topics.contains(where: { kidTopics.contains($0.lowercased()) }) { return true }
            if let max = ageMax, max <= 12 { return true }
            return false
        }
    }
}

/// Where-to-watch info for a film/tvshow/series, France only. The `link`
/// points to TMDB's generic "where to watch" page (not a deep-link into a
/// specific provider's app) — same limitation as the Spotify search fallback
/// used for music.
public struct StreamingAvailability: Codable, Sendable, Equatable, Hashable {
    public let link: String
    public let providers: [StreamingProvider]
}

public struct StreamingProvider: Codable, Sendable, Equatable, Hashable {
    public let providerId: Int
    public let providerName: String
    public let logoPath: String
    /// culture-api reports free / ad-supported offers as `.flatrate` (kept
    /// for clients ≤ 1.7 whose enum had only flatrate/rent/buy); the real
    /// value is in `monetization`.
    public let type: StreamingProviderType
    /// Real TMDB monetization ("flatrate", "free", "ads", "rent", "buy").
    /// nil = older server.
    public var monetization: StreamingProviderType? = nil

    /// Included with the service (subscription, free or ads) — not rent/buy.
    public var isIncluded: Bool {
        switch monetization ?? type {
        case .flatrate, .free, .ads: return true
        case .rent, .buy, .unknown: return false
        }
    }
}

/// Decodes any unknown future value as `.unknown` instead of failing the
/// whole oeuvre.
public enum StreamingProviderType: String, Codable, Sendable {
    case flatrate
    case free
    case ads
    case rent
    case buy
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = StreamingProviderType(rawValue: raw) ?? .unknown
    }
}

/// A French streaming platform from `oeuvres.providers()` (culture-api
/// `GET /oeuvres/providers`, migration 0134).
public struct StreamingPlatform: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let providerId: Int
    /// "netflix", "prime-video", "crunchyroll", "france-tv", … — accepted by
    /// `oeuvres.list(provider:)`.
    public let slug: String
    public let name: String
    public let logoPath: String?
    /// TMDB w92 logo URL.
    public let logoUrl: String?
    public let oeuvreCount: Int
    public let tvCount: Int
    public let filmCount: Int
    public let animeCount: Int

    public var id: Int { providerId }

    public init(providerId: Int, slug: String, name: String, logoPath: String?, logoUrl: String?, oeuvreCount: Int, tvCount: Int, filmCount: Int, animeCount: Int) {
        self.providerId = providerId
        self.slug = slug
        self.name = name
        self.logoPath = logoPath
        self.logoUrl = logoUrl
        self.oeuvreCount = oeuvreCount
        self.tvCount = tvCount
        self.filmCount = filmCount
        self.animeCount = animeCount
    }
}

public struct StreamingPlatformListResponse: Codable, Sendable {
    public let data: [StreamingPlatform]
    public let count: Int
    /// JustWatch attribution to show next to provider logos.
    public var attribution: String? = nil
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
