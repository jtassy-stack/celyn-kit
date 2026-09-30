import XCTest
@testable import CelynKit

final class NewsAudioDecodingTests: XCTestCase {
    private func decodeEvent(_ audio: String?) throws -> NewsEvent {
        let audioPart = audio.map { #","audio":"# + $0 } ?? ""
        let json = #"{"id":"e1","kind":"politique","sourceType":"rss","createdAt":"2026-09-29T06:10:00Z""# + audioPart + "}"
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return try d.decode(NewsEvent.self, from: Data(json.utf8))
    }

    private let base = #""episodeId":"ep1","audioUrl":"https://media.example/x.mp3","title":"Le journal de 8 h","showName":"Le journal de 8 h","station":"France Inter","publishedAt":"2026-09-29T06:00:00.000Z","durationSeconds":1080"#

    func testOffsetDecodes() throws {
        let e = try decodeEvent("{" + base + #","offsetSeconds":312.5}"#)
        XCTAssertEqual(e.audio?.offsetSeconds, 312.5)
        XCTAssertEqual(e.audio?.durationSeconds, 1080)
        XCTAssertEqual(e.audio?.station, "France Inter")
    }

    func testOffsetNullAbsentOrInvalidIsNil() throws {
        for tail in [#","offsetSeconds":null}"#, "}", #","offsetSeconds":"12"}"#, #","offsetSeconds":-4}"#] {
            let e = try decodeEvent("{" + base + tail)
            XCTAssertNotNil(e.audio, tail)
            XCTAssertNil(e.audio?.offsetSeconds, tail)
        }
    }

    func testAudioNullAbsentOrMalformedNeverFailsTheEvent() throws {
        XCTAssertNil(try decodeEvent(nil).audio)
        XCTAssertNil(try decodeEvent("null").audio)
        XCTAssertNil(try decodeEvent(#"{"title":"no url"}"#).audio)
        XCTAssertNil(try decodeEvent("42").audio)
    }
}
