import XCTest
@testable import CelynKit

final class CelynKitTests: XCTestCase {

    func testClientIsConfiguredWithKey() {
        let client = CultureAPIClient(apiKey: "test-key")
        XCTAssertTrue(client.isConfigured)
    }

    func testClientIsNotConfiguredWithEmptyKey() {
        let client = CultureAPIClient(apiKey: "")
        XCTAssertFalse(client.isConfigured)
    }

    func testDateParsingISO8601() {
        let date = CultureAPIDateParsing.parse("2026-04-25T18:30:00Z")
        XCTAssertNotNil(date)
    }

    func testDateParsingISO8601Fractional() {
        let date = CultureAPIDateParsing.parse("2026-04-25T18:30:00.123Z")
        XCTAssertNotNil(date)
    }

    func testDateParsingPostgres() {
        let date = CultureAPIDateParsing.parse("2026-04-25 18:30:00+00")
        XCTAssertNotNil(date)
    }

    func testDateParsingPostgresWithoutTimezoneIsUTC() {
        let date = CultureAPIDateParsing.parse("2026-09-20 15:55:00")
        XCTAssertEqual(date, CultureAPIDateParsing.parse("2026-09-20T15:55:00Z"))
    }

    func testDateParsingInvalid() {
        let date = CultureAPIDateParsing.parse("not a date")
        XCTAssertNil(date)
    }

    func testVenueTypeUnknownDecodesToOther() throws {
        let json = #""some_future_type""#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(VenueType.self, from: json)
        XCTAssertEqual(decoded, .other)
    }

    func testVenueDecodingFromAPIShape() throws {
        let json = """
        {
            "id": "v1",
            "name": "Le Grand Action",
            "address": "5 rue des Écoles",
            "city": "Paris",
            "latitude": 48.8492,
            "longitude": 2.3494,
            "venue_type": "cinema",
            "website": null,
            "geofence_radius": null,
            "mention_count": 12
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let venue = try decoder.decode(Venue.self, from: json)

        XCTAssertEqual(venue.id, "v1")
        XCTAssertEqual(venue.name, "Le Grand Action")
        XCTAssertEqual(venue.venueType, .cinema)
        XCTAssertEqual(venue.mentionCount, 12)
        XCTAssertEqual(venue.latitude, 48.8492)
    }

    func testEventListResponseDecoding() throws {
        let json = """
        {
            "data": [
                {
                    "id": "e1",
                    "title": "Anatomie d'une chute",
                    "category": "cinema",
                    "image_url": null,
                    "start_time": "2026-04-25T20:00:00Z",
                    "end_time": null,
                    "price": null,
                    "is_free": 0,
                    "is_sold_out": 0,
                    "is_active": 1,
                    "venue": null,
                    "oeuvre": null
                }
            ],
            "count": 1
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            guard let d = CultureAPIDateParsing.parse(str) else {
                throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "")
            }
            return d
        }

        let response = try decoder.decode(EventListResponse.self, from: json)
        XCTAssertEqual(response.count, 1)
        XCTAssertEqual(response.data.first?.title, "Anatomie d'une chute")
        XCTAssertFalse(response.data.first?.isFreeBool ?? true)
        XCTAssertTrue(response.data.first?.isActiveBool ?? false)
    }

    // MARK: - PodcastEpisode.asOeuvre()

    private func episode(
        audioUrl: String? = "https://cdn.example.com/ep.mp3",
        sourceType: String? = "podcast",
        title: String = "Épisode 42"
    ) -> PodcastEpisode {
        PodcastEpisode(
            id: "ep42", title: title, description: "desc",
            audioUrl: audioUrl, durationSeconds: 3600,
            author: "France Inter", showName: "Le Masque",
            station: "France Inter", category: "culture",
            coverUrl: "https://cdn.example.com/c.jpg", sourceType: sourceType
        )
    }

    func testEpisodeProjectsToPlayablePodcastOeuvre() {
        let o = episode().asOeuvre()
        XCTAssertEqual(o?.id, "podcast-episode-ep42")
        XCTAssertEqual(o?.oeuvreType, .podcast)
        XCTAssertEqual(o?.trailerUrl, "https://cdn.example.com/ep.mp3")
        XCTAssertEqual(o?.author, "Le Masque")          // showName preferred
        XCTAssertEqual(o?.duration, 60)                  // 3600s → 60 min
        XCTAssertEqual(o?.isPodcastEpisode, true)
    }

    func testEpisodeWithoutAudioIsDropped() {
        XCTAssertNil(episode(audioUrl: nil).asOeuvre())
        XCTAssertNil(episode(audioUrl: "").asOeuvre())
    }

    func testNonAudioSourceIsDropped() {
        XCTAssertNil(episode(sourceType: "youtube").asOeuvre())
        XCTAssertNil(episode(sourceType: nil).asOeuvre())
    }

    func testRadioCountsAsAudio() {
        XCTAssertNotNil(episode(sourceType: "radio").asOeuvre())
    }

    // MARK: - VenueRef.asVenue()

    func testVenueRefPromotesToFullVenueCarryingItsFields() {
        let ref = VenueRef(
            id: "v1", supabaseId: "sb1", name: "Le Patio",
            address: "1 rue du Panier", city: "Marseille",
            latitude: 43.30, longitude: 5.37
        )
        let venue = ref.asVenue(venueType: .cinema)
        XCTAssertEqual(venue.id, "v1")
        XCTAssertEqual(venue.supabaseId, "sb1")
        XCTAssertEqual(venue.name, "Le Patio")
        XCTAssertEqual(venue.address, "1 rue du Panier")
        XCTAssertEqual(venue.city, "Marseille")
        XCTAssertEqual(venue.latitude, 43.30)
        XCTAssertEqual(venue.longitude, 5.37)
        XCTAssertEqual(venue.venueType, .cinema)
    }

    /// `VenueRef` carries no `venueType` at all — the caller's choice must
    /// pass through unchanged, not get silently overridden.
    func testVenueRefAsVenueHonoursTheSuppliedType() {
        let ref = VenueRef(id: "v2", name: "Le Sémillant")
        XCTAssertEqual(ref.asVenue(venueType: .bar).venueType, .bar)
        XCTAssertEqual(ref.asVenue(venueType: .museum).venueType, .museum)
    }

    func testVenueRefAsVenuePreservesNilOptionals() {
        let ref = VenueRef(id: "v3", name: "Sans coordonnées")
        let venue = ref.asVenue(venueType: .other)
        XCTAssertNil(venue.address)
        XCTAssertNil(venue.city)
        XCTAssertNil(venue.latitude)
        XCTAssertNil(venue.longitude)
    }

    private func newsDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            guard let d = CultureAPIDateParsing.parse(str) else {
                throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "")
            }
            return d
        }
        return decoder
    }

    func testOeuvreDecodesMentionSignals() throws {
        let json = """
        {"id":"o1","title":"Anora","oeuvreType":"film","sourceCount":3,"lastMentionedAt":"2026-09-20T08:00:00.000Z"}
        """.data(using: .utf8)!
        let o = try newsDecoder().decode(Oeuvre.self, from: json)
        XCTAssertEqual(o.sourceCount, 3)
        XCTAssertNotNil(o.lastMentionedAt)

        let bare = """
        {"id":"o2","title":"X","oeuvreType":"book","lastMentionedAt":null}
        """.data(using: .utf8)!
        let b = try newsDecoder().decode(Oeuvre.self, from: bare)
        XCTAssertNil(b.sourceCount)
        XCTAssertNil(b.lastMentionedAt)
    }

    func testOeuvreDecodesReleaseAndAvailabilitySignals() throws {
        let json = """
        {"id":"o1","title":"Anora","oeuvreType":"film","sourceCount":2,
         "releaseDateTheatricalFr":"2026-09-17","releaseDateDigitalFr":"2027-01-05",
         "releaseDateTvFr":"2027-06-01","streamingLatestArrivalAt":"2026-09-21T10:00:00.000Z",
         "nowShowing":true}
        """.data(using: .utf8)!
        let o = try newsDecoder().decode(Oeuvre.self, from: json)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        func ymd(_ d: Date?) -> [Int]? {
            guard let d else { return nil }
            let c = cal.dateComponents([.year, .month, .day], from: d)
            return [c.year!, c.month!, c.day!]
        }
        XCTAssertEqual(ymd(o.releaseDateTheatricalFr), [2026, 9, 17])
        XCTAssertEqual(ymd(o.releaseDateDigitalFr), [2027, 1, 5])
        XCTAssertEqual(ymd(o.releaseDateTvFr), [2027, 6, 1])
        XCTAssertEqual(o.streamingLatestArrivalAt, CultureAPIDateParsing.parse("2026-09-21T10:00:00.000Z"))
        XCTAssertEqual(o.nowShowing, true)

        let nulls = """
        {"id":"o2","title":"X","oeuvreType":"film","releaseDateTheatricalFr":null,
         "releaseDateDigitalFr":null,"releaseDateTvFr":null,
         "streamingLatestArrivalAt":null,"nowShowing":false}
        """.data(using: .utf8)!
        let n = try newsDecoder().decode(Oeuvre.self, from: nulls)
        XCTAssertNil(n.releaseDateTheatricalFr)
        XCTAssertNil(n.releaseDateDigitalFr)
        XCTAssertNil(n.releaseDateTvFr)
        XCTAssertNil(n.streamingLatestArrivalAt)
        XCTAssertEqual(n.nowShowing, false)

        let absent = """
        {"id":"o3","title":"Y","oeuvreType":"book"}
        """.data(using: .utf8)!
        let a = try newsDecoder().decode(Oeuvre.self, from: absent)
        XCTAssertNil(a.releaseDateTheatricalFr)
        XCTAssertNil(a.releaseDateDigitalFr)
        XCTAssertNil(a.releaseDateTvFr)
        XCTAssertNil(a.streamingLatestArrivalAt)
        XCTAssertNil(a.nowShowing)
    }

    func testNewsStoryListResponseDecoding() throws {
        let json = """
        {
            "data": [
                {
                    "id": "s1",
                    "title": "Grève des transports",
                    "primary_kind": "societe",
                    "entity_tokens": ["ratp", "greve"],
                    "confidence_score": 0.87,
                    "event_count": 5,
                    "source_count": 3,
                    "first_seen_at": "2026-09-20T08:00:00Z",
                    "last_update_at": "2026-09-22T10:00:00Z",
                    "status": "active",
                    "sources": [
                        {"source_type": "editorial_rss", "label": "Le Monde", "count": 2}
                    ]
                }
            ],
            "meta": {"limit": 30, "count": 1, "sort": "recent", "status": "active"}
        }
        """.data(using: .utf8)!

        let response = try newsDecoder().decode(NewsStoryListResponse.self, from: json)
        XCTAssertEqual(response.data.first?.title, "Grève des transports")
        XCTAssertEqual(response.data.first?.primaryKind, .societe)
        XCTAssertEqual(response.data.first?.sources.first?.label, "Le Monde")
        XCTAssertEqual(response.meta.count, 1)
    }

    func testNewsEventKindDecodesUnknownValueToAutre() throws {
        let json = "\"some_future_kind\"".data(using: .utf8)!
        let kind = try JSONDecoder().decode(NewsEventKind.self, from: json)
        XCTAssertEqual(kind, .autre)
    }

    func testNewsEventDecodingWithFactCheck() throws {
        let json = """
        {
            "id": "e1",
            "kind": "politique",
            "summary": "Un résumé reformulé.",
            "source_type": "editorial_rss",
            "source_url": "https://example.com/a",
            "source_published_at": null,
            "author_display_name": "Le Monde",
            "programme": null,
            "is_live_blog": false,
            "created_at": "2026-09-22T09:00:00Z",
            "fact_checks": [
                {
                    "claim": "3000 manifestants",
                    "subject": "manifestation",
                    "verdict": "plausible",
                    "confidence": 0.3,
                    "source": null,
                    "source_url": null,
                    "note": null
                }
            ]
        }
        """.data(using: .utf8)!

        let event = try newsDecoder().decode(NewsEvent.self, from: json)
        XCTAssertEqual(event.kind, .politique)
        XCTAssertEqual(event.factChecks.first?.verdict, .plausible)
        XCTAssertNil(event.sourcePublishedAt)
    }

    func testCuratedSourceListResponseDecoding() throws {
        let json = """
        {
            "data": [
                {
                    "id": "src1",
                    "name": "France Inter",
                    "show_name": "Le Masque et la Plume",
                    "station": "France Inter",
                    "source_type": "rss",
                    "category": "culture",
                    "city": null,
                    "image_url": null,
                    "featured": true,
                    "venue_id": null,
                    "tier": "reference",
                    "credibility_score": 0.9
                }
            ],
            "count": 1
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(CuratedSourceListResponse.self, from: json)
        XCTAssertEqual(response.data.first?.showName, "Le Masque et la Plume")
        XCTAssertEqual(response.data.first?.featured, true)
        XCTAssertEqual(response.count, 1)
    }

    // MARK: - Seances

    func testSeanceListQueryIncludesOeuvreId() {
        let q = SeancesResource.listQuery(oeuvreId: "o1", lat: 48.85, lng: 2.35, radiusKm: 10, limit: 20)
        XCTAssertEqual(q["oeuvre_id"], "o1")
        XCTAssertEqual(q["lat"], "48.85")
        XCTAssertEqual(q["radius_km"], "10.0")
        XCTAssertEqual(q["limit"], "20")
        XCTAssertNil(q["venue_id"])
        XCTAssertNil(SeancesResource.listQuery()["oeuvre_id"])
    }

    func testSeanceListResponseDecodingFromAPIShape() throws {
        let json = """
        {
            "data": [{
                "id": "s1", "startsAt": "2026-09-24T18:30:00.000Z", "endsAt": null,
                "room": "Salle 1", "price": null, "source": "allocine",
                "oeuvre": {"id": "o1", "title": "Anatomie d'une chute", "type": "film"},
                "venue": {"id": "v1", "name": "Le Grand Action", "city": "Paris",
                          "latitude": 48.8492, "longitude": 2.3524, "venueType": "cinema"},
                "_links": {"recommendations": "/api/recommendations/o1"}
            }],
            "count": 1, "syncAt": "2026-09-23T10:00:00.000Z", "isDelta": false,
            "nextCursor": null, "hasMore": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            guard let d = CultureAPIDateParsing.parse(str) else {
                throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "")
            }
            return d
        }

        let response = try decoder.decode(SeanceListResponse.self, from: json)
        XCTAssertEqual(response.count, 1)
        XCTAssertEqual(response.data.first?.oeuvre?.id, "o1")
        XCTAssertEqual(response.data.first?.venue?.name, "Le Grand Action")
        XCTAssertEqual(response.data.first?.venue?.latitude, 48.8492)
    }

    // MARK: - Actu magazine (upcoming releases + feed)

    func testOeuvreListQueryUpcoming() {
        let q = OeuvresResource.listQuery(limit: 20, sort: .upcoming, withinDays: 60)
        XCTAssertEqual(q["sort"], "upcoming")
        XCTAssertEqual(q["within_days"], "60")
        XCTAssertEqual(q["limit"], "20")
        XCTAssertNil(q["type"])
        XCTAssertNil(OeuvresResource.listQuery(sort: .mentioned)["within_days"])
    }

    func testPodcastFeedQuery() {
        let q = PodcastsResource.feedQuery(sourceType: .youtube, limit: 15)
        XCTAssertEqual(q["source_type"], "youtube")
        XCTAssertEqual(q["limit"], "15")
        XCTAssertTrue(PodcastsResource.feedQuery().isEmpty)
        XCTAssertEqual(PodcastsResource.feedQuery(sourceType: .rss)["source_type"], "rss")
    }

    func testPodcastFeedDecodingFromAPIShape() throws {
        let json = """
        {"data":[
          {"episodeId":"e1","title":"Video","audioUrl":"youtube:audio:oGVtbkHof8w",
           "publishedAt":"2026-09-22 16:00:11","showName":"Regelegorila","station":"YouTube",
           "coverUrl":null,"sourceType":"youtube","youtubeVideoId":"oGVtbkHof8w",
           "oeuvres":[{"id":"o1","title":"Slayground","type":"film"}],
           "nearestEventKm":null,"soonestEventAt":null,"score":0.61,
           "signals":{"freshness":0.9,"geo":0,"eventSoon":0,"pulse":0.2}},
          {"episodeId":"e2","title":"Legacy video","audioUrl":"youtube:audio:zzzYYY98765",
           "publishedAt":"2026-09-21T10:00:00.000Z","showName":"X","station":"YouTube",
           "coverUrl":null,"sourceType":"youtube","oeuvres":[]},
          {"episodeId":"e3","title":"Pod","audioUrl":"https://cdn.example.com/a.mp3",
           "publishedAt":"2026-09-21T10:00:00.000Z","showName":"Le Masque","station":"France Inter",
           "coverUrl":"https://img/x.jpg","sourceType":"rss","youtubeVideoId":null,"oeuvres":[]}
        ],"meta":{"pool":3,"geo":null,"trendingTopics":[]}}
        """.data(using: .utf8)!
        let r = try newsDecoder().decode(PodcastFeedResponse.self, from: json)
        XCTAssertEqual(r.data.count, 3)
        let v = r.data[0]
        XCTAssertEqual(v.id, "e1")
        XCTAssertNotNil(v.publishedAt)
        XCTAssertEqual(v.oeuvres?.first?.title, "Slayground")
        XCTAssertEqual(v.youtubeWatchURL?.absoluteString, "https://www.youtube.com/watch?v=oGVtbkHof8w")
        XCTAssertEqual(v.youtubeThumbnailURL?.absoluteString, "https://i.ytimg.com/vi/oGVtbkHof8w/hqdefault.jpg")
        XCTAssertNil(v.playableAudioURL)
        XCTAssertEqual(r.data[1].resolvedYouTubeVideoId, "zzzYYY98765")
        XCTAssertNil(r.data[2].resolvedYouTubeVideoId)
        XCTAssertEqual(r.data[2].playableAudioURL?.absoluteString, "https://cdn.example.com/a.mp3")
    }
}
