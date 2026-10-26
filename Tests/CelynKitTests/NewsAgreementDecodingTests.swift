import XCTest
@testable import CelynKit

final class NewsAgreementDecodingTests: XCTestCase {
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

    private func storyJSON(agreement: String?) -> Data {
        let tail = agreement.map { ",\n\"agreement\": \($0)" } ?? ""
        return """
        {"id": "s1", "title": "Lula réélu", "primaryKind": "international",
         "entityTokens": ["lula"], "confidenceScore": 0.97, "eventCount": 100, "sourceCount": 64,
         "firstSeenAt": "2026-10-25T08:00:00Z", "lastUpdateAt": "2026-10-26T09:00:00Z",
         "status": "active", "sources": []\(tail)}
        """.data(using: .utf8)!
    }

    func testDecodesAgreement() throws {
        let story = try decoder().decode(NewsStory.self, from: storyJSON(agreement: #"{"score": 1, "confirmedFacts": 6, "disputedPoints": 0, "singleSourceFacts": 3}"#))
        XCTAssertEqual(story.agreement, NewsStoryAgreement(score: 1, confirmedFacts: 6, disputedPoints: 0, singleSourceFacts: 3))
    }

    func testAbsentAgreementIsNil() throws {
        XCTAssertNil(try decoder().decode(NewsStory.self, from: storyJSON(agreement: nil)).agreement)
    }

    func testMalformedAgreementNeverFailsTheStory() throws {
        let story = try decoder().decode(NewsStory.self, from: storyJSON(agreement: #"{"score": "high"}"#))
        XCTAssertNil(story.agreement)
        XCTAssertEqual(story.title, "Lula réélu")
    }
}
