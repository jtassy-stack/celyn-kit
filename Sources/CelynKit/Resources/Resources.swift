import Foundation

public extension CultureAPIClient {
    var events: EventsResource { EventsResource(client: self) }
    var venues: VenuesResource { VenuesResource(client: self) }
    var oeuvres: OeuvresResource { OeuvresResource(client: self) }
    var seances: SeancesResource { SeancesResource(client: self) }
    var recommendations: RecommendationsResource { RecommendationsResource(client: self) }
    var podcasts: PodcastsResource { PodcastsResource(client: self) }
}
