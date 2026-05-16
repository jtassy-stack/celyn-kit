import Foundation

/// One episode of a tracked podcast source. Returned by `/podcasts/episodes`.
/// The audio URL is what an audio player can stream directly.
public struct PodcastEpisode: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let description: String?
    public let audioUrl: String?
    public let publishedAt: Date?
    public let durationSeconds: Int?
    public let status: String?
    public let author: String?
    public let showName: String?
    public let station: String?
    public let category: String?
    public let coverUrl: String?
    public let sourceType: String?

    public init(
        id: String,
        title: String,
        description: String? = nil,
        audioUrl: String? = nil,
        publishedAt: Date? = nil,
        durationSeconds: Int? = nil,
        status: String? = nil,
        author: String? = nil,
        showName: String? = nil,
        station: String? = nil,
        category: String? = nil,
        coverUrl: String? = nil,
        sourceType: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.audioUrl = audioUrl
        self.publishedAt = publishedAt
        self.durationSeconds = durationSeconds
        self.status = status
        self.author = author
        self.showName = showName
        self.station = station
        self.category = category
        self.coverUrl = coverUrl
        self.sourceType = sourceType
    }
}

public struct PodcastEpisodeListResponse: Codable, Sendable {
    public let data: [PodcastEpisode]
}

public extension PodcastEpisode {
    /// Source types that are actual streamable audio. The episodes feed
    /// also surfaces YouTube/newsletter signal items — those have no audio
    /// stream, so projecting them as playable podcasts would be a silent
    /// dead end (cf. the #4 YouTube relabel).
    private static let audioSourceTypes: Set<String> = ["podcast", "radio"]

    /// Project a recent episode onto a synthetic `.podcast` Oeuvre so it
    /// flows through the same HomePickEngine → Agenda pipeline as books /
    /// albums / films. The id is namespaced `podcast-episode-` so it can't
    /// collide with a real oeuvre (or a `podcast-source-` synth).
    ///
    /// Returns nil unless the episode is genuinely playable — a valid
    /// audio URL on an audio source — so an un-listenable card never
    /// reaches the feed.
    func asOeuvre() -> Oeuvre? {
        guard let type = sourceType?.lowercased(),
              Self.audioSourceTypes.contains(type),
              let audio = audioUrl, URL(string: audio) != nil,
              !title.isEmpty else { return nil }
        let credit = showName ?? station ?? author
        return Oeuvre(
            id: "podcast-episode-\(id)",
            title: title,
            originalTitle: nil,
            oeuvreType: .podcast,
            year: nil,
            director: nil,
            author: credit,
            description: description,
            genres: category.map { [$0] },
            imageUrl: coverUrl,
            // trailerUrl is the codebase's generic media-URL carrier (see
            // the YouTube-channel projection); the episode player reads it.
            trailerUrl: audio,
            ageMin: nil,
            ageMax: nil,
            duration: durationSeconds.map { max(1, $0 / 60) },
            thematicTags: nil,
            topics: category.map { [$0] },
            publisher: station,
            isKidFriendly: nil,
            opinions: nil,
            opinionCount: nil
        )
    }
}

public extension Oeuvre {
    /// True when this Oeuvre is a synthetic projection of a fresh podcast
    /// episode (see `PodcastEpisode.asOeuvre()`). Drives the "Écouter
    /// l'épisode" affordance and keeps it distinct from a YouTube source.
    var isPodcastEpisode: Bool { id.hasPrefix("podcast-episode-") }
}
