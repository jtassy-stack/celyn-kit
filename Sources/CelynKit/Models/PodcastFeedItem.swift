import Foundation

/// One ranked item of `GET /podcasts/feed`: an audio episode (`sourceType`
/// "rss") or a YouTube video ("youtube"), with the oeuvres it discusses.
public struct PodcastFeedItem: Identifiable, Codable, Sendable, Equatable, Hashable {
    public struct OeuvreMention: Codable, Sendable, Equatable, Hashable {
        public let id: String
        public let title: String
        public let type: String
        /// Seconds into the episode where this oeuvre is first discussed
        /// (LLM-estimated, minute grain). nil when unknown / older servers.
        public var segmentStart: Int? = nil
        /// Seconds where the discussion ends. Not populated server-side yet.
        public var segmentEnd: Int? = nil

        public init(id: String, title: String, type: String, segmentStart: Int? = nil, segmentEnd: Int? = nil) {
            self.id = id
            self.title = title
            self.type = type
            self.segmentStart = segmentStart
            self.segmentEnd = segmentEnd
        }
    }

    public let episodeId: String
    public let title: String
    /// Streamable audio URL for podcasts. YouTube items carry a non-playable
    /// `youtube:audio:<id>` marker instead — use `youtubeVideoId`.
    public let audioUrl: String?
    public let publishedAt: Date?
    public let showName: String?
    public let station: String?
    public let coverUrl: String?
    public let sourceType: String?
    /// Bare YouTube video id (YouTube items only). Older servers omit it.
    public var youtubeVideoId: String? = nil
    public var oeuvres: [OeuvreMention]? = nil
    public var score: Double? = nil
    /// Earliest `segmentStart` across `oeuvres` (seconds), or nil.
    public var startAt: Int? = nil

    public var id: String { episodeId }

    public init(
        episodeId: String,
        title: String,
        audioUrl: String? = nil,
        publishedAt: Date? = nil,
        showName: String? = nil,
        station: String? = nil,
        coverUrl: String? = nil,
        sourceType: String? = nil,
        youtubeVideoId: String? = nil,
        oeuvres: [OeuvreMention]? = nil,
        score: Double? = nil,
        startAt: Int? = nil
    ) {
        self.episodeId = episodeId
        self.title = title
        self.audioUrl = audioUrl
        self.publishedAt = publishedAt
        self.showName = showName
        self.station = station
        self.coverUrl = coverUrl
        self.sourceType = sourceType
        self.youtubeVideoId = youtubeVideoId
        self.oeuvres = oeuvres
        self.score = score
        self.startAt = startAt
    }
}

public extension PodcastFeedItem {
    /// YouTube video id: the server field, else parsed from the
    /// `youtube:audio:<id>` marker (servers predating `youtubeVideoId`).
    var resolvedYouTubeVideoId: String? {
        if let id = youtubeVideoId, !id.isEmpty { return id }
        let prefix = "youtube:audio:"
        guard let audioUrl, audioUrl.hasPrefix(prefix) else { return nil }
        let id = String(audioUrl.dropFirst(prefix.count))
        return id.isEmpty ? nil : id
    }

    /// Segment start (seconds) for a given oeuvre in this item, else nil.
    func segmentStart(forOeuvre oeuvreId: String) -> Int? {
        oeuvres?.first { $0.id == oeuvreId }?.segmentStart
    }

    /// `https://www.youtube.com/watch?v=<id>` for YouTube items.
    var youtubeWatchURL: URL? {
        resolvedYouTubeVideoId.flatMap { URL(string: "https://www.youtube.com/watch?v=\($0)") }
    }

    /// High-quality YouTube thumbnail for YouTube items.
    var youtubeThumbnailURL: URL? {
        resolvedYouTubeVideoId.flatMap { URL(string: "https://i.ytimg.com/vi/\($0)/hqdefault.jpg") }
    }

    /// Directly streamable audio (http/https), nil for YouTube markers.
    var playableAudioURL: URL? {
        guard let audioUrl, let url = URL(string: audioUrl),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        return url
    }
}

public struct PodcastFeedResponse: Codable, Sendable {
    public let data: [PodcastFeedItem]
}
