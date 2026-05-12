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
