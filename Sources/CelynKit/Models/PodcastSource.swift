import Foundation

/// A podcast / radio / YouTube / newsletter source tracked by culture-api.
///
/// Mirrors `GET /podcasts/sources` from culture-api. Only the fields actually
/// consumed by the iOS app are decoded — the route projects extra signals
/// (inboundMentionCount, coveredTypes, platform-specific metadata) that we
/// can wire up later without changing this model.
public struct PodcastSource: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let showName: String?
    public let station: String?
    public let rssUrl: String?
    /// The route returns this as `coverUrl` — see CodingKeys.
    public let imageUrl: String?
    public let sourceType: String
    public let category: String?
    public let language: String?

    enum CodingKeys: String, CodingKey {
        case id, name, showName, station, rssUrl
        case imageUrl = "coverUrl"
        case sourceType, category, language
    }

    public init(
        id: String,
        name: String,
        showName: String? = nil,
        station: String? = nil,
        rssUrl: String? = nil,
        imageUrl: String? = nil,
        sourceType: String,
        category: String? = nil,
        language: String? = nil
    ) {
        self.id = id
        self.name = name
        self.showName = showName
        self.station = station
        self.rssUrl = rssUrl
        self.imageUrl = imageUrl
        self.sourceType = sourceType
        self.category = category
        self.language = language
    }
}

public struct PodcastSourceListResponse: Codable, Sendable {
    public let data: [PodcastSource]
}

public extension PodcastSource {
    /// `sourceType` values that represent something a user can actually
    /// listen to / watch. The /podcasts/sources endpoint also returns
    /// signal-only sources (newsletters, institutional feeds like BnF,
    /// research scrapers) that the LLM mention-extractor crawls for
    /// reviews — those have no playable artifact and must not be surfaced
    /// as "podcasts to consume" in the agenda.
    private static let consumableSourceTypes: Set<String> = [
        "podcast", "radio", "youtube"
    ]

    /// Project a podcast / radio / YouTube source onto a synthetic Oeuvre
    /// of type `.podcast` so it can flow through any pipeline designed for
    /// Oeuvres (HomePickEngine, OeuvreDetailView, the home-pick cross-day
    /// dedup, etc.) without a parallel code path.
    ///
    /// Returns nil when the source isn't user-consumable (newsletter,
    /// institutional feed, research source). The id is namespaced with a
    /// `podcast-source-` prefix so the synth can't collide with a real
    /// oeuvre id.
    func asOeuvre() -> Oeuvre? {
        let type = sourceType.lowercased()
        guard Self.consumableSourceTypes.contains(type) else {
            return nil
        }
        let resolvedTitle = showName ?? name
        guard !resolvedTitle.isEmpty else { return nil }
        let isYouTube = type == "youtube"
        // YouTube channels are not podcasts: namespace the synthetic id so
        // the UI can relabel them and surface a "voir la chaîne" link. The
        // /podcasts/sources RSS for a channel is
        // youtube.com/feeds/videos.xml?channel_id=UC… — derive the watchable
        // channel URL from it; nil when the feed isn't a channel feed.
        return Oeuvre(
            id: isYouTube ? "youtube-source-\(id)" : "podcast-source-\(id)",
            title: resolvedTitle,
            originalTitle: nil,
            oeuvreType: .podcast,
            year: nil,
            director: nil,
            author: station,
            description: nil,
            genres: category.map { [$0] },
            imageUrl: imageUrl,
            trailerUrl: isYouTube ? Self.youTubeChannelURL(fromFeed: rssUrl) : nil,
            ageMin: nil,
            ageMax: nil,
            duration: nil,
            thematicTags: nil,
            topics: category.map { [$0] },
            publisher: station,
            isKidFriendly: nil,
            opinions: nil,
            opinionCount: nil
        )
    }

    /// Turn a YouTube channel RSS feed
    /// (`https://www.youtube.com/feeds/videos.xml?channel_id=UC…`) into the
    /// human channel URL (`https://www.youtube.com/channel/UC…`). Returns
    /// nil for non-channel feeds so callers can fall back gracefully.
    static func youTubeChannelURL(fromFeed feed: String?) -> String? {
        guard let feed,
              let comps = URLComponents(string: feed),
              let channelId = comps.queryItems?
                .first(where: { $0.name == "channel_id" })?.value,
              !channelId.isEmpty
        else { return nil }
        return "https://www.youtube.com/channel/\(channelId)"
    }
}

public extension Oeuvre {
    /// True when this Oeuvre is a synthetic projection of a YouTube channel
    /// source (see `PodcastSource.asOeuvre()`), not a real podcast. UI uses
    /// this to relabel "podcast" → "YouTube" and offer a channel link.
    var isYouTubeSource: Bool { id.hasPrefix("youtube-source-") }
}
