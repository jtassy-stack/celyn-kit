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

    func testContestedEvolutionKindValuesAndDates() throws {
        let json = """
        {"generatedAt": "2026-10-03T08:00:00.000Z", "eventCount": 39, "independentSourceCount": 12,
         "facts": [], "contested": [
          {"subject": "Affluence : interpellations", "kind": "evolution", "versions": [
            {"claim": "164 interpellations.", "sources": [], "value": 164, "firstPublishedAt": "2026-09-28T19:00:00.000Z"},
            {"claim": "1 949 interpellations.", "sources": [], "value": 1949, "firstPublishedAt": "2026-10-01T18:00:00.000Z"}]},
          {"subject": "Bilan", "kind": "someday", "versions": [{"claim": "a", "sources": []}, {"claim": "b", "sources": []}]},
          {"subject": "Ancien", "versions": [{"claim": "a", "sources": []}, {"claim": "b", "sources": []}]}
        ]}
        """
        let r = try decoder().decode(NewsStoryDetailResponse.self, from: storyJSON(consensus: json))
        let points = try XCTUnwrap(r.data.consensus).contested
        XCTAssertEqual(points[0].kind, .evolution)
        XCTAssertTrue(points[0].isEvolution)
        XCTAssertEqual(points[0].versions.map(\.value), [164, 1949])
        XCTAssertNotNil(points[0].versions[0].firstPublishedAt)
        XCTAssertEqual(points[1].kind, .dispute)      // unknown kind → dispute
        XCTAssertNil(points[2].kind)                   // older digest
        XCTAssertFalse(points[2].isEvolution)
    }

    func testEvolutionSeries() throws {
        let json = """
        {"generatedAt": "2026-10-03T08:00:00.000Z", "eventCount": 2, "independentSourceCount": 2, "facts": [], "contested": [
          {"subject": "s", "kind": "evolution", "versions": [
            {"claim": "1 700 jeudi.", "sources": [], "value": 1700, "firstPublishedAt": "2026-10-02T08:00:00Z", "series": "daily"},
            {"claim": "5 000 depuis lundi.", "sources": [], "value": 5000, "firstPublishedAt": "2026-10-02T09:00:00Z", "series": "cumulative"},
            {"claim": "x", "sources": [], "value": 3, "firstPublishedAt": "2026-10-02T10:00:00Z", "series": "weekly"},
            {"claim": "y", "sources": [], "value": 4, "firstPublishedAt": "2026-10-02T11:00:00Z"}]}]}
        """
        let r = try decoder().decode(NewsStoryDetailResponse.self, from: storyJSON(consensus: json))
        let p = try XCTUnwrap(r.data.consensus?.contested.first)
        XCTAssertEqual(p.versions(in: .cumulative).map(\.value), [5000])
        XCTAssertEqual(p.versions(in: .daily).map(\.value), [1700, 3, 4])   // unknown + absent → daily
    }
}
