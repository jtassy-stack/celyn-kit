import Foundation

public extension CultureAPIClient {
    var events: EventsResource { EventsResource(client: self) }
    var venues: VenuesResource { VenuesResource(client: self) }
    var oeuvres: OeuvresResource { OeuvresResource(client: self) }
    var seances: SeancesResource { SeancesResource(client: self) }
    var recommendations: RecommendationsResource { RecommendationsResource(client: self) }
    var podcasts: PodcastsResource { PodcastsResource(client: self) }
    var embeddings: EmbeddingsResource { EmbeddingsResource(client: self) }
    var creators: CreatorsResource { CreatorsResource(client: self) }
    var venueSubmissions: VenueSubmissionsResource { VenueSubmissionsResource(client: self) }
    var eventSubmissions: EventSubmissionsResource { EventSubmissionsResource(client: self) }
    var festivals: FestivalsResource { FestivalsResource(client: self) }
    var feed: FeedResource { FeedResource(client: self) }
}
