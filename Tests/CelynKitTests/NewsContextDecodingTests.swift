import XCTest
@testable import CelynKit

final class NewsContextDecodingTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = CultureAPIDateParsing.parse(s) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: s)
        }
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private let head = #""id":"s1","title":"T","confidenceScore":0.8,"eventCount":2,"sourceCount":2,"firstSeenAt":"2026-09-29T06:10:00.000Z","lastUpdateAt":"2026-09-29T07:10:00Z","status":"active""#

    private func story(_ extra: String = "") throws -> NewsStoryDetail {
        try decoder().decode(NewsStoryDetail.self, from: Data(("{" + head + extra + "}").utf8))
    }

    /// Shape of the prod payload of story cb5d55c9 (Manchester City), trimmed.
    func testRealPayloadShapeDecodes() throws {
        let s = try story(#"""
        ,"concepts":[{"label":"Manchester City","kind":"organization","entityToken":"manchester city","wikidataId":"Q50602","wikipediaUrl":"https://fr.wikipedia.org/wiki/Manchester_City_Football_Club","definition":"Le Manchester City Football Club est un club.","definitionLicence":"CC BY-SA 4.0"},
                     {"label":"Estonie","kind":"other","entityToken":"estonie","wikidataId":null,"wikipediaUrl":null,"definition":null,"definitionLicence":null}],
         "relatedStories":[{"storyId":"514313ec","title":"Leicester relégué","firstSeenAt":"2026-08-14T10:20:30.580Z","similarity":0.851}],
         "furtherReading":[{"type":"serie","oeuvreId":"e70d","episodeId":null,"wikidataId":null,"title":"Super Ligue : la guerre du football","year":2023,"creator":null,"reason":"Ce documentaire explore la régulation.","imageUrl":"https://image.tmdb.org/t/p/w500/x.jpg","availabilityFr":["Apple TV","Apple TV Amazon Channel"],"source":"concept_match"},
                           {"type":"livre","oeuvreId":"0404","episodeId":null,"wikidataId":null,"title":"Foot-business","year":null,"creator":"Simon Bolle","reason":"Un livre.","imageUrl":null,"availabilityFr":[],"source":"embedding"}],
         "furtherReadingPolicy":"standard"
        """#)
        XCTAssertEqual(s.concepts.count, 2)
        XCTAssertEqual(s.concepts[0].kind, .organization)
        XCTAssertEqual(s.concepts[0].attribution, "Wikipédia, CC BY-SA 4.0")
        XCTAssertNil(s.concepts[1].attribution)
        XCTAssertEqual(s.relatedStories.first?.similarity, 0.851)
        XCTAssertNotNil(s.relatedStories.first?.firstSeenAt)
        XCTAssertEqual(s.furtherReading.map(\.type), [.serie, .livre])
        XCTAssertEqual(s.furtherReading[0].imageUrl?.host, "image.tmdb.org")
        XCTAssertEqual(s.furtherReading[0].availabilityLabel(), "Disponible sur Apple TV, Apple TV Amazon Channel")
        XCTAssertNil(s.furtherReading[1].availabilityLabel())
        XCTAssertEqual(s.furtherReading[0].subtitle, "Série · 2023")
        XCTAssertEqual(s.furtherReading[1].subtitle, "Livre")
        XCTAssertEqual(s.furtherReadingPolicy, .standard)
        XCTAssertTrue(s.showsFurtherReading)
        XCTAssertNil(s.context)
    }

    func testAbsentKeysDefault() throws {
        let s = try story()
        XCTAssertEqual(s.concepts, [])
        XCTAssertEqual(s.relatedStories, [])
        XCTAssertEqual(s.furtherReading, [])
        XCTAssertNil(s.furtherReadingPolicy)
        XCTAssertNil(s.context)
        XCTAssertFalse(s.showsFurtherReading)
    }

    func testUnknownEnumsAndInvalidElementsAreTolerated() throws {
        let s = try story(#"""
        ,"concepts":[{"label":"X","kind":"planet"},{"kind":"person"},42],
         "relatedStories":[{"storyId":"a","title":"A","firstSeenAt":"not a date"},{"title":"no id"}],
         "furtherReading":[{"type":"manga","title":"M","reason":"r","imageUrl":"javascript:x","availabilityFr":["Netflix",3,""]},{"type":"film"}],
         "furtherReadingPolicy":"very_grave",
         "context":"oops"
        """#)
        XCTAssertEqual(s.concepts.map(\.label), ["X"])
        XCTAssertEqual(s.concepts.first?.kind, .other)
        XCTAssertEqual(s.relatedStories.map(\.storyId), ["a"])
        XCTAssertNil(s.relatedStories.first?.firstSeenAt)
        XCTAssertEqual(s.furtherReading.count, 1)
        XCTAssertEqual(s.furtherReading.first?.type, .oeuvre)
        XCTAssertEqual(s.furtherReading.first?.type.label, "Œuvre")
        XCTAssertNil(s.furtherReading.first?.imageUrl)
        XCTAssertEqual(s.furtherReading.first?.availabilityFr, ["Netflix"])
        XCTAssertEqual(s.furtherReadingPolicy, .standard)
        XCTAssertNil(s.context)
    }

    func testNonArrayFieldsDoNotFailTheStory() throws {
        let s = try story(#","concepts":null,"relatedStories":{},"furtherReading":"x","furtherReadingPolicy":7"#)
        XCTAssertTrue(s.concepts.isEmpty && s.relatedStories.isEmpty && s.furtherReading.isEmpty)
        XCTAssertNil(s.furtherReadingPolicy)
    }

    func testPolicyNoneHidesCarouselAndSeriousOnlyHasSoberText() throws {
        let item = #"{"type":"livre","title":"L","reason":"r"}"#
        let none = try story(#","furtherReading":["# + item + #"],"furtherReadingPolicy":"none""#)
        XCTAssertEqual(none.furtherReading.count, 1)
        XCTAssertTrue(none.visibleFurtherReading.isEmpty)
        XCTAssertFalse(none.showsFurtherReading)
        XCTAssertNil(FurtherReadingPolicy.none.emptyStateText)

        let grave = try story(#","furtherReading":["# + item + #"],"furtherReadingPolicy":"serious_only""#)
        XCTAssertEqual(grave.furtherReadingPolicy, .seriousOnly)
        XCTAssertTrue(grave.showsFurtherReading)
        XCTAssertEqual(FurtherReadingPolicy.seriousOnly.emptyStateText, "Sujet grave : seulement des documentaires, livres et podcasts.")
    }

    func testContextDecodesWithCitations() throws {
        let s = try story(#"""
        ,"context":{"sentences":[{"text":"A.","cites":["c0","w1"]},{"text":"B.","cites":["w1","zz"]}],
          "whyItMatters":{"text":"Parce que.","cites":["c1"]},
          "sources":[{"id":"c0","kind":"claim","label":"Titre","url":null,"licence":null},
                     {"id":"w1","kind":"wikipedia","label":"Estonie","url":"https://fr.wikipedia.org/wiki/Estonie","licence":"CC BY-SA 4.0"},
                     {"id":"c1","kind":"future","label":"?"}],
          "generatedAt":"2026-09-29T06:10:00.000Z","model":"m","verifiedBy":"jev-latest"}
        """#)
        let c = try XCTUnwrap(s.context)
        XCTAssertTrue(c.hasDisplayableContent)
        XCTAssertEqual(c.citationLabel(for: "w1"), "[2]")
        XCTAssertNil(c.citationLabel(for: "zz"))
        XCTAssertEqual(c.sources(citedBy: c.sentences[1]).map(\.id), ["w1"])
        XCTAssertEqual(c.sources.last?.kind, .other)
        XCTAssertEqual(c.attributionLine, "Sources : Wikipédia (CC BY-SA 4.0), recoupement Sirius")
        XCTAssertEqual(c.whyItMatters?.text, "Parce que.")
    }

    func testTypeLabelsAndSymbols() {
        XCTAssertEqual(FurtherReadingType.allCases.map(\.label),
                       ["Film", "Série", "Anime", "Livre", "Jeu vidéo", "Album", "Podcast", "Épisode", "Œuvre"])
        XCTAssertEqual(FurtherReadingType.jeuVideo.symbolName, "gamecontroller")
        XCTAssertEqual(FurtherReadingType.anime.symbolName, "sparkles.tv")
        XCTAssertEqual(OeuvreType.game.placeholderSymbolName, "gamecontroller")
    }

    func testAccessibilityLabel() {
        let i = FurtherReadingItem(type: .livre, title: "Les Pays baltes", year: 2024, reason: "Il éclaire le contexte.")
        XCTAssertEqual(i.accessibilityLabel, "Livre, Les Pays baltes, 2024. Pourquoi : Il éclaire le contexte.")
    }

    func testOeuvreNewCatalogueFieldsDecodeAndAreOptional() throws {
        let game = try decoder().decode(Oeuvre.self, from: Data(#"{"id":"g","title":"G","oeuvreType":"game","wikidataId":"Q1","dataSources":["wikidata"],"imageUrl":null}"#.utf8))
        XCTAssertEqual(game.wikidataId, "Q1")
        XCTAssertEqual(game.dataSources, ["wikidata"])
        XCTAssertNil(game.coverURL)
        XCTAssertNil(game.platforms)
        let film = try decoder().decode(Oeuvre.self, from: Data(#"{"id":"f","title":"F","oeuvreType":"film","isAnime":true}"#.utf8))
        XCTAssertEqual(film.isAnime, true)
        XCTAssertNil(film.wikidataId)
        XCTAssertNil(film.dataSources)
    }
}
