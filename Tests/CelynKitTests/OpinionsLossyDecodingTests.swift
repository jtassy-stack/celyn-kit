import XCTest
@testable import CelynKit

/// Regression: `GET /oeuvres/986f89a8-…` (Game of Thrones) shipped
/// `$.opinions[5].opinionSummary = null` (a HugoDécrypte mention with no
/// summary, culture-api prod 2026-09-26). `OeuvreOpinion.opinionSummary` is a
/// non-optional `String`, so the strict `[OeuvreOpinion]` decode threw and the
/// WHOLE `Oeuvre` was lost. `Oeuvre.opinions` now decodes lossily.
final class OpinionsLossyDecodingTests: XCTestCase {
    /// Same configuration as `CultureAPIClient.jsonDecoder()`.
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            let s = try c.decode(String.self)
            guard let date = CultureAPIDateParsing.parse(s) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: s)
            }
            return date
        }
        return decoder
    }

    private func decode(_ json: String) throws -> Oeuvre {
        try decoder().decode(Oeuvre.self, from: Data(json.utf8))
    }

    private func opinion(
        _ critic: String,
        summary: String? = "Un vrai avis.",
        sentiment: String? = "positive",
        keyQuotes: String = #"["Une citation assez longue."]"#
    ) -> String {
        let s = summary.map { "\"\($0)\"" } ?? "null"
        let sent = sentiment.map { "\"\($0)\"" } ?? "null"
        return """
        {"criticName":"\(critic)","opinionSummary":\(s),"sentiment":\(sent),
         "keyQuotes":\(keyQuotes),"episodeTitle":"Épisode","showName":"\(critic)",
         "station":"YouTube","publishedAt":"2025-11-22T10:00:00.000Z",
         "segmentStart":null,"segmentEnd":null,"audioUrl":"youtube:audio:abc","episodeId":"ep-\(critic)"}
        """
    }

    private func detail(opinions: String) -> String {
        """
        {"id":"986f89a8-ae14-44a9-aa8d-af1921d94d59","title":"Game of Thrones","oeuvreType":"tvshow",
         "year":2011,"opinions":\(opinions),"opinionCount":14,"sourceCount":9,
         "_links":{"opinions":"/api/podcasts/about/986f89a8-ae14-44a9-aa8d-af1921d94d59"}}
        """
    }

    func testNullSummaryDropsThatOpinionNotTheOeuvre() throws {
        let rows = [
            opinion("Regelegorila"),
            opinion("Pauline", sentiment: "negative"),
            opinion("Redge"),
            opinion("Simon", sentiment: "negative"),
            opinion("Jérémy", sentiment: "negative"),
            opinion("HugoDécrypte - Actus et interviews", summary: nil, sentiment: "mixed"), // $.opinions[5]
            opinion("Julie"),
        ]
        let o = try decode(detail(opinions: "[\(rows.joined(separator: ","))]"))

        XCTAssertEqual(o.title, "Game of Thrones")
        XCTAssertEqual(o.oeuvreType, .tvshow)
        XCTAssertEqual(o.opinionCount, 14)
        XCTAssertEqual(o.sourceCount, 9)
        XCTAssertEqual(
            o.opinions?.map(\.criticName),
            ["Regelegorila", "Pauline", "Redge", "Simon", "Jérémy", "Julie"]
        )
        XCTAssertEqual(o.opinions?[1].sentiment, .negative)
        XCTAssertEqual(o.opinions?.first?.publishedAt, ISO8601DateFormatter().date(from: "2025-11-22T10:00:00Z"))
    }

    func testNullSentimentAndBlankSummaryAreDropped() throws {
        let rows = [
            opinion("A", sentiment: "very_positive"),
            opinion("B", sentiment: nil),
            opinion("C", summary: "   "),
            opinion("D", summary: ""),
            opinion("E", sentiment: "ecstatic"), // unknown value: kept, decodes as .mixed
        ]
        let o = try decode(detail(opinions: "[\(rows.joined(separator: ","))]"))

        XCTAssertEqual(o.opinions?.map(\.criticName), ["A", "E"])
        XCTAssertEqual(o.opinions?.map(\.sentiment), [.veryPositive, .mixed])
    }

    func testMalformedOpinionsAreDropped() throws {
        let rows = [
            opinion("A"),
            opinion("B", keyQuotes: "42"),
            #""not an opinion""#,
            "null",
            opinion("C"),
        ]
        let o = try decode(detail(opinions: "[\(rows.joined(separator: ","))]"))

        XCTAssertEqual(o.opinions?.map(\.criticName), ["A", "C"])
    }

    func testAbsentNullOrNonArrayOpinionsDecodeAsNil() throws {
        let base = #""id":"o1","title":"T","oeuvreType":"film""#
        XCTAssertNil(try decode("{\(base)}").opinions) // include=none
        XCTAssertNil(try decode(#"{\#(base),"opinions":null}"#).opinions)
        XCTAssertNil(try decode(#"{\#(base),"opinions":{"oops":1}}"#).opinions)
        XCTAssertEqual(try decode(#"{\#(base),"opinions":[]}"#).opinions, [])
    }

    func testASingleOpinionStillDecodesStrictly() {
        // The tolerance lives on `Oeuvre.opinions`; the type itself keeps its
        // non-optional contract (no silent "" summary).
        XCTAssertThrowsError(
            try decoder().decode(OeuvreOpinion.self, from: Data(opinion("X", summary: nil).utf8))
        )
    }
}
