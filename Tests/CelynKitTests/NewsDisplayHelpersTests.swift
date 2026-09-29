import XCTest
@testable import CelynKit

final class NewsDisplayHelpersTests: XCTestCase {
    private func decodeSource(_ json: String) throws -> NewsConsensusSource {
        try JSONDecoder().decode(NewsConsensusSource.self, from: Data(json.utf8))
    }

    func testSourceURLToleratesNullEmptyAndMissing() throws {
        for json in [#"{"name":"A","url":null}"#, #"{"name":"A","url":""}"#, #"{"name":"A"}"#] {
            let s = try decodeSource(json)
            XCTAssertEqual(s.url, "")
            XCTAssertNil(s.link, json)
        }
    }

    func testLinkOnlyForAbsoluteHTTP() {
        XCTAssertEqual(NewsConsensusSource(name: "A", url: "https://ex.com/a").link?.absoluteString, "https://ex.com/a")
        XCTAssertNotNil(NewsConsensusSource(name: "A", url: "HTTP://ex.com").link)
        XCTAssertNil(NewsConsensusSource(name: "A", url: "javascript:alert(1)").link)
        XCTAssertNil(NewsConsensusSource(name: "A", url: "file:///etc/passwd").link)
        XCTAssertNil(NewsConsensusSource(name: "A", url: "/relative").link)
        XCTAssertNil(NewsConsensusSource(name: "A", url: "").link)
    }

    func testDigestWithURLLessSourceDecodes() throws {
        let json = #"""
        {"generatedAt":"2026-09-25T12:00:00Z","eventCount":3,"independentSourceCount":2,"outletCount":5,
         "facts":[{"id":"f1","claim":"c","status":"confirmed","independentSources":2,
                   "sources":[{"name":"Radio","url":""},{"name":"TV","url":null}]}]}
        """#
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        let c = try d.decode(NewsConsensus.self, from: Data(json.utf8))
        XCTAssertEqual(c.outletCount, 5)
        XCTAssertEqual(c.facts.first?.sources.compactMap(\.link).count, 0)
    }

    func testOutletCountAbsentIsNil() throws {
        let json = #"{"generatedAt":"2026-09-25T12:00:00Z"}"#
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        XCTAssertNil(try d.decode(NewsConsensus.self, from: Data(json.utf8)).outletCount)
    }

    func testContestedPointsAndDisplayableContent() {
        let now = Date()
        let one = NewsContestedPoint(subject: "Solo", versions: [.init(claim: "x")])
        let two = NewsContestedPoint(subject: "Affluence", versions: [.init(claim: "a"), .init(claim: "b")])
        let c = NewsConsensus(generatedAt: now, eventCount: 1, independentSourceCount: 1, contested: [one, two])
        XCTAssertEqual(c.contestedPoints.map(\.subject), ["Affluence"])
        XCTAssertTrue(c.hasDisplayableContent)

        let onlySolo = NewsConsensus(generatedAt: now, eventCount: 1, independentSourceCount: 1, contested: [one])
        XCTAssertFalse(onlySolo.hasDisplayableContent)
        let unknownOnly = NewsConsensus(generatedAt: now, eventCount: 1, independentSourceCount: 1,
                                        facts: [.init(id: "u", claim: "?", status: .unknown, independentSources: 1)])
        XCTAssertFalse(unknownOnly.hasDisplayableContent)
        let single = NewsConsensus(generatedAt: now, eventCount: 1, independentSourceCount: 1,
                                   facts: [.init(id: "s", claim: "s", status: .singleSource, independentSources: 1)])
        XCTAssertTrue(single.hasDisplayableContent)
    }

    func testSourcesLabelFR() {
        XCTAssertEqual(NewsConsensus.sourcesLabelFR(0), "0 source")
        XCTAssertEqual(NewsConsensus.sourcesLabelFR(1), "1 source")
        XCTAssertEqual(NewsConsensus.sourcesLabelFR(3), "3 sources")
        XCTAssertEqual(NewsConsensusFact(id: "f", claim: "c", status: .confirmed, independentSources: 4).independentSourcesLabelFR, "4 sources")
    }

    func testNewsIdentityConformances() {
        let s = NewsStorySource(sourceType: "editorial_rss", label: "Le Monde", count: 2)
        XCTAssertEqual(s.id, "editorial_rss-Le Monde")
        XCTAssertEqual(NewsFactCheck(claim: "c", subject: "s", verdict: .verified, confidence: 1).id, "c")
        let story = NewsStory(id: "1", title: "t", confidenceScore: 1, eventCount: 1, sourceCount: 1,
                              firstSeenAt: Date(timeIntervalSince1970: 0), lastUpdateAt: Date(timeIntervalSince1970: 0),
                              status: "active", sources: [s])
        XCTAssertEqual(Set([story, story]).count, 1)
    }
}
