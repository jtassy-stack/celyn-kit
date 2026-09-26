import XCTest
@testable import CelynKit

final class NewsConsensusDecodingTests: XCTestCase {
    private func decoder() -> JSONDecoder {
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

    private func storyJSON(consensus: String?) -> Data {
        let tail = consensus.map { ",\n\"consensus\": \($0)" } ?? ""
        return """
        {"data": {
          "id": "4b82244a", "title": "Visite du pape", "primaryKind": "international",
          "entityTokens": ["pape"], "confidenceScore": 0.9, "eventCount": 12, "sourceCount": 6,
          "firstSeenAt": "2026-09-20T08:00:00Z", "lastUpdateAt": "2026-09-22T10:00:00Z",
          "status": "active",
          "sources": [{"sourceType": "editorial_rss", "label": "Le Monde", "count": 2}],
          "events": []\(tail)
        }}
        """.data(using: .utf8)!
    }

    private let fullConsensus = """
    {
      "generatedAt": "2026-09-25T12:00:00.000Z",
      "eventCount": 145,
      "independentSourceCount": 9,
      "facts": [
        {"id": "f1", "claim": "Le pape célèbre une messe au stade.", "facet": "programme",
         "status": "confirmed", "independentSources": 4, "informativeness": 0.8,
         "sources": [{"name": "Le Monde", "url": "https://example.com/a"}]},
        {"id": "f2", "claim": "Un fait isolé.", "facet": "securite",
         "status": "single_source", "independentSources": 1, "informativeness": 0.4,
         "sources": [{"name": "Ouest-France", "url": "https://example.com/b"}]}
      ],
      "contested": [
        {"subject": "Affluence", "versions": [
          {"claim": "700 000 personnes attendues.", "sources": [{"name": "A", "url": "https://a"}]},
          {"claim": "500 000 personnes attendues.", "sources": [{"name": "B", "url": "https://b"}]}
        ]}
      ]
    }
    """

    func testDecodesWithoutConsensus() throws {
        let r = try decoder().decode(NewsStoryDetailResponse.self, from: storyJSON(consensus: nil))
        XCTAssertNil(r.data.consensus)
        XCTAssertEqual(r.data.title, "Visite du pape")
    }

    func testDecodesNullConsensus() throws {
        let r = try decoder().decode(NewsStoryDetailResponse.self, from: storyJSON(consensus: "null"))
        XCTAssertNil(r.data.consensus)
    }

    func testDecodesFullConsensus() throws {
        let r = try decoder().decode(NewsStoryDetailResponse.self, from: storyJSON(consensus: fullConsensus))
        let c = try XCTUnwrap(r.data.consensus)
        XCTAssertEqual(c.eventCount, 145)
        XCTAssertEqual(c.independentSourceCount, 9)
        XCTAssertEqual(c.facts.count, 2)
        XCTAssertEqual(c.facts[0].status, .confirmed)
        XCTAssertEqual(c.facts[0].facet, .programme)
        XCTAssertEqual(c.facts[0].sources.first?.name, "Le Monde")
        XCTAssertEqual(c.facts[1].status, .singleSource)
        XCTAssertEqual(c.confirmedFacts.map(\.id), ["f1"])
        XCTAssertEqual(c.singleSourceFacts.map(\.id), ["f2"])
        XCTAssertEqual(c.contested.first?.versions.count, 2)
        XCTAssertEqual(c.contested.first?.versions.last?.sources.first?.name, "B")
    }

    func testUnknownEnumValuesFallBack() throws {
        let json = """
        {"id": "f9", "claim": "x", "facet": "meteo", "status": "retracted",
         "independentSources": 2, "sources": [], "informativeness": 0.5}
        """.data(using: .utf8)!
        let f = try decoder().decode(NewsConsensusFact.self, from: json)
        XCTAssertEqual(f.facet, .autre)
        XCTAssertEqual(f.status, .unknown)
    }

    func testMalformedConsensusDoesNotBlankStory() throws {
        let r = try decoder().decode(
            NewsStoryDetailResponse.self,
            from: storyJSON(consensus: #"{"facts": "oops"}"#)
        )
        XCTAssertNil(r.data.consensus)
        XCTAssertEqual(r.data.id, "4b82244a")
    }
}
