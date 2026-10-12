import XCTest
@testable import CelynKit

private func fixture(_ name: String) throws -> Data {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/\(name).json")
    return try Data(contentsOf: url)
}

private func decodeLot(_ json: String) throws -> QuizLot {
    try JSONDecoder().decode(QuizLot.self, from: Data(json.utf8))
}

private func q(_ id: String, answer: Int? = 0, edition: String? = nil, choices: [String] = ["a", "b", "c"]) -> QuizQuestion {
    QuizQuestion(id: id, question: "Q \(id) ?", choices: choices, answerIndex: answer, edition: edition)
}

private func lot(_ qs: [QuizQuestion]) -> QuizLot { QuizLot(date: "2026-10-12", number: 3, quizzes: qs) }

// MARK: Decoding

final class QuizDecodingTests: XCTestCase {

    func testAllFiveFixturesDecodeWithTheSameModel() throws {
        let expected: [(String, Int)] = [
            ("partie-daily-keskonfe", 30), ("partie-daily-sirius", 10),
            ("quiz-v2-lot-keskonfe", 30), ("quiz-v2-lot-sirius", 10), ("quiz-v2-lot-leclub", 8),
        ]
        for (name, count) in expected {
            let lot = try JSONDecoder().decode(QuizLot.self, from: fixture(name))
            XCTAssertEqual(lot.quizzes.count, count, name)
            XCTAssertEqual(lot.playableQuizzes.count, count, name)
            XCTAssertNotNil(lot.citation, name)
            XCTAssertTrue(lot.quizzes.allSatisfy { $0.answerIndex != nil }, name)
        }
    }

    func testLegacyHasNoV2Fields() throws {
        let lot = try JSONDecoder().decode(QuizLot.self, from: fixture("partie-daily-keskonfe"))
        XCTAssertTrue(lot.quizzes.allSatisfy { $0.tone == nil && $0.horizon == nil && $0.promotedFrom == nil })
        XCTAssertNil(lot.editions)
        XCTAssertNil(lot.nextEditionAt)
    }

    func testV2FieldsPresentOnLeclub() throws {
        let lot = try JSONDecoder().decode(QuizLot.self, from: fixture("quiz-v2-lot-leclub"))
        XCTAssertEqual(lot.quizzes[0].tone, "actu")
        XCTAssertEqual(lot.quizzes[0].horizon, "jour")
        XCTAssertEqual(lot.citation?.author, "Honoré de Balzac")
        XCTAssertNotNil(lot.citation?.oeuvreId)
    }

    func testSiriusEditions() throws {
        for name in ["partie-daily-sirius", "quiz-v2-lot-sirius"] {
            let lot = try JSONDecoder().decode(QuizLot.self, from: fixture(name))
            XCTAssertEqual(lot.editions?.map(\.edition), ["matin", "midi"], name)
            XCTAssertEqual(lot.editions?.first?.quizCount, 5)
            XCTAssertEqual(lot.editions?.first?.number, 16)
            XCTAssertEqual(lot.nextEditionAt, "2026-10-12T18:00:00.000Z")
            XCTAssertEqual(Set(lot.quizzes.compactMap(\.edition)), ["matin", "midi"], name)
        }
    }

    func testThroughClientDecoderSnakeCaseStrategy() throws {
        // The client decodes with convertFromSnakeCase; camelCase keys must survive it.
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        let lot = try d.decode(QuizLot.self, from: fixture("quiz-v2-lot-sirius"))
        XCTAssertEqual(lot.quizzes.count, 10)
        XCTAssertNotNil(lot.nextEditionAt)
    }

    func testQuestionWithoutAnswerIndexIsAccepted() throws {
        let lot = try decodeLot("""
        {"date":"2026-10-12","number":1,"quizzes":[
          {"id":"a","question":"Q ?","choices":["x","y"]},
          {"id":"b","question":"Q ?","choices":["x","y"],"answerIndex":null}]}
        """)
        XCTAssertEqual(lot.quizzes.count, 2)
        XCTAssertNil(lot.quizzes[0].answerIndex)
        XCTAssertTrue(lot.quizzes.allSatisfy(\.isPlayable))
        XCTAssertNil(QuizSession(lot: lot).score)
    }

    func testCorruptedQuestionsAreDroppedNotTheLot() throws {
        let lot = try decodeLot("""
        {"date":"2026-10-12","number":1,"quizzes":[
          {"id":"ok","question":"Q ?","choices":["x","y"],"answerIndex":1},
          {"id":"nochoices","question":"Q ?"},
          {"id":"badtype","question":"Q ?","choices":"nope"},
          {"id":"badanswer","question":"Q ?","choices":["x","y"],"answerIndex":"1"},
          42,
          {"question":"no id","choices":["x","y"]},
          {"id":"ok2","question":"Q ?","choices":["x","y"],"futureField":{"a":1}}]}
        """)
        XCTAssertEqual(lot.quizzes.map(\.id), ["ok", "ok2"])
    }

    func testBadCosmeticFieldsDegradeToNil() throws {
        let lot = try decodeLot("""
        {"date":"2026-10-12","number":1,"quizzes":[
          {"id":"a","question":"Q ?","choices":["x","y"],"difficulty":"hard","genres":"x","tone":3}]}
        """)
        XCTAssertEqual(lot.quizzes.count, 1)
        XCTAssertNil(lot.quizzes[0].difficulty)
        XCTAssertNil(lot.quizzes[0].genres)
        XCTAssertNil(lot.quizzes[0].tone)
    }

    func testUnreadableCitationBecomesNilAndEditionsDegrade() throws {
        let lot = try decodeLot("""
        {"date":"2026-10-12","number":1,"citation":{"id":"c"},"quizzes":[],
         "editions":[{"edition":"matin","number":"x"},{"nope":1}]}
        """)
        XCTAssertNil(lot.citation)
        XCTAssertEqual(lot.editions?.map(\.edition), ["matin"])
        XCTAssertNil(lot.editions?.first?.number)
    }

    func testIsPlayable() {
        XCTAssertTrue(q("a").isPlayable)
        XCTAssertFalse(QuizQuestion(id: "a", question: "  ", choices: ["x", "y"]).isPlayable)
        XCTAssertFalse(QuizQuestion(id: "a", question: "Q", choices: ["x"]).isPlayable)
        XCTAssertFalse(q("a", answer: 3).isPlayable)
        XCTAssertFalse(q("a", answer: -1).isPlayable)
        XCTAssertTrue(q("a", answer: nil).isPlayable)
    }

    func testIdentifiable() throws {
        let lot = try JSONDecoder().decode(QuizLot.self, from: fixture("quiz-v2-lot-sirius"))
        XCTAssertEqual(lot.id, lot.date)
        XCTAssertEqual(lot.editions?.first?.id, "matin")
        XCTAssertEqual(lot.quizzes[0].id.count, 36)
        XCTAssertEqual(lot.citation?.id.count, 36)
    }
}

// MARK: Session

final class QuizSessionTests: XCTestCase {

    func testAnswerGradesAndFirstAnswerWins() {
        var s = QuizSession(lot: lot([q("a", answer: 1), q("b", answer: 0)]))
        XCTAssertEqual(s.answer(questionId: "a", choice: 1), .correct)
        XCTAssertEqual(s.answer(questionId: "a", choice: 0), .rejected)
        XCTAssertEqual(s.answer(questionId: "b", choice: 2), .incorrect(correctIndex: 0))
        XCTAssertEqual(s.choice(for: "a"), 1)
        XCTAssertEqual(s.progress, .init(answered: 2, skipped: 0, total: 2))
        XCTAssertTrue(s.isFinished)
        XCTAssertEqual(s.score, .init(correct: 1, total: 2))
    }

    func testRejectsUnknownQuestionAndOutOfRangeChoice() {
        var s = QuizSession(lot: lot([q("a")]))
        XCTAssertEqual(s.answer(questionId: "zzz", choice: 0), .rejected)
        XCTAssertEqual(s.answer(questionId: "a", choice: 3), .rejected)
        XCTAssertEqual(s.answer(questionId: "a", choice: -1), .rejected)
        XCTAssertEqual(s.progress.answered, 0)
        XCTAssertFalse(s.skip(questionId: "zzz"))
    }

    func testSkipThenAnswerLater() {
        var s = QuizSession(lot: lot([q("a"), q("b")]))
        XCTAssertTrue(s.skip(questionId: "a"))
        XCTAssertTrue(s.isSkipped("a"))
        XCTAssertEqual(s.progress, .init(answered: 0, skipped: 1, total: 2))
        XCTAssertFalse(s.isFinished)
        s.answer(questionId: "b", choice: 0)
        XCTAssertTrue(s.isFinished)
        XCTAssertEqual(s.score, .init(correct: 1, total: 2))   // skipped counts as missed
        XCTAssertEqual(s.answer(questionId: "a", choice: 0), .correct)
        XCTAssertFalse(s.isSkipped("a"))
        XCTAssertEqual(s.score, .init(correct: 2, total: 2))
    }

    func testCannotSkipAnAnsweredQuestion() {
        var s = QuizSession(lot: lot([q("a")]))
        s.answer(questionId: "a", choice: 0)
        XCTAssertFalse(s.skip(questionId: "a"))
        XCTAssertEqual(s.choice(for: "a"), 0)
    }

    func testScoreNilWithoutAnswerIndexAndPartialOtherwise() {
        var none = QuizSession(lot: lot([q("a", answer: nil), q("b", answer: nil)]))
        XCTAssertEqual(none.answer(questionId: "a", choice: 0), .unscored)
        none.answer(questionId: "b", choice: 1)
        XCTAssertTrue(none.isFinished)
        XCTAssertNil(none.score)

        var mixed = QuizSession(lot: lot([q("a", answer: 0), q("b", answer: nil)]))
        mixed.answer(questionId: "a", choice: 0)
        mixed.answer(questionId: "b", choice: 0)
        XCTAssertEqual(mixed.score, .init(correct: 1, total: 1))
    }

    func testUnplayableAndDuplicateQuestionsAreLeftOut() {
        let s = QuizSession(lot: lot([q("a"), q("bad", answer: 9), q("a"), q("c", choices: ["x"])]))
        XCTAssertEqual(s.questions.map(\.id), ["a"])
    }

    func testEmptySession() {
        let s = QuizSession(lot: lot([]))
        XCTAssertTrue(s.questions.isEmpty)
        XCTAssertNil(s.score)
        XCTAssertNil(s.nextQuestion())
    }

    func testResumeByQuestionId() {
        var s = QuizSession(lot: lot([q("a"), q("b"), q("c"), q("d")]))
        XCTAssertEqual(s.nextQuestion()?.id, "a")
        s.answer(questionId: "a", choice: 0)
        s.skip(questionId: "b")
        XCTAssertEqual(s.nextQuestion()?.id, "c")
        XCTAssertEqual(s.nextQuestion(after: "c")?.id, "d")
        XCTAssertEqual(s.nextQuestion(after: "d")?.id, "c")        // wraps
        XCTAssertEqual(s.nextQuestion(after: "unknown")?.id, "c")
        XCTAssertEqual(s.pending.map(\.id), ["c", "d"])
        s.answer(questionId: "c", choice: 0)
        s.answer(questionId: "d", choice: 0)
        XCTAssertEqual(s.nextQuestion()?.id, "b")                  // second chance for skipped
        XCTAssertEqual(s.skippedQuestions.map(\.id), ["b"])
        s.answer(questionId: "b", choice: 0)
        XCTAssertNil(s.nextQuestion())
    }

    func testCodableRoundTripResumesExactly() throws {
        var s = QuizSession(lot: lot([q("a", answer: 1), q("b"), q("c", answer: nil)]))
        s.answer(questionId: "a", choice: 1)
        s.skip(questionId: "b")
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(QuizSession.self, from: data)
        XCTAssertEqual(back, s)
        XCTAssertEqual(back.progress, s.progress)
        XCTAssertEqual(back.nextQuestion()?.id, "c")
        XCTAssertEqual(back.lotDate, "2026-10-12")
        XCTAssertEqual(back.lotNumber, 3)
    }

    func testRestoreDropsImpossibleResponses() throws {
        let json = """
        {"lotDate":"d","lotNumber":1,
         "questions":[{"id":"a","question":"Q","choices":["x","y"],"answerIndex":0}],
         "responses":{"a":{"answered":{"choice":7}},"ghost":{"skipped":{}}}}
        """
        let s = try JSONDecoder().decode(QuizSession.self, from: Data(json.utf8))
        XCTAssertTrue(s.responses.isEmpty)
    }

    func testEditionBlocks() throws {
        let l = try JSONDecoder().decode(QuizLot.self, from: fixture("quiz-v2-lot-sirius"))
        var s = QuizSession(lot: l)
        XCTAssertEqual(s.blocks.map(\.edition), ["matin", "midi"])
        XCTAssertEqual(s.blocks.map(\.total), [5, 5])
        for question in s.blocks[0].questions { s.answer(questionId: question.id, choice: 0) }
        s.skip(questionId: s.blocks[1].questions[0].id)
        XCTAssertTrue(s.blocks[0].isFinished)
        XCTAssertEqual(s.blocks[0].answered, 5)
        XCTAssertFalse(s.blocks[1].isFinished)
        XCTAssertEqual(s.blocks[1].answered, 0)
    }

    func testBlocksWithoutEditionAreOneGroup() {
        let s = QuizSession(lot: lot([q("a"), q("b")]))
        XCTAssertEqual(s.blocks.count, 1)
        XCTAssertNil(s.blocks[0].edition)
    }

    func testFullFixtureSessionEndToEnd() throws {
        let l = try JSONDecoder().decode(QuizLot.self, from: fixture("quiz-v2-lot-leclub"))
        var s = QuizSession(lot: l)
        for question in s.questions { s.answer(questionId: question.id, choice: question.answerIndex!) }
        XCTAssertTrue(s.isFinished)
        XCTAssertEqual(s.score, .init(correct: 8, total: 8))
    }
}

// MARK: Resource (URL / params through a stubbed URLProtocol)

final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var seen: [URLRequest] = []
    nonisolated(unsafe) static var seenBodies: [Data] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = request.httpBody
        if body == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var data = Data(); var buf = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let n = stream.read(&buf, maxLength: buf.count)
                if n <= 0 { break }
                data.append(buf, count: n)
            }
            body = data
        }
        Self.seen.append(request)
        Self.seenBodies.append(body ?? Data())
        let (status, data) = Self.handler?(request) ?? (500, Data())
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class QuizResourceTests: XCTestCase {

    private func makeClient() -> CultureAPIClient {
        StubProtocol.seen = []; StubProtocol.seenBodies = []
        return CultureAPIClient(apiKey: "key-1", configuration: .init(clientIdentifier: "sirius"), protocolClasses: [StubProtocol.self])
    }

    private func queryItems(_ r: URLRequest) -> [String: String] {
        let items = URLComponents(url: r.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    func testLotURLAndHeaders() async throws {
        let body = try fixture("quiz-v2-lot-sirius")
        StubProtocol.handler = { _ in (200, body) }
        let lot = try await makeClient().quiz.lot(app: "sirius", date: "2026-10-12")
        XCTAssertEqual(lot.quizzes.count, 10)
        let r = try XCTUnwrap(StubProtocol.seen.last)
        XCTAssertEqual(r.httpMethod, "GET")
        XCTAssertEqual(r.url?.path, "/api/quiz/v2/lot")
        XCTAssertEqual(queryItems(r), ["app": "sirius", "date": "2026-10-12"])
        XCTAssertEqual(r.value(forHTTPHeaderField: "x-api-key"), "key-1")
        XCTAssertEqual(r.value(forHTTPHeaderField: "x-client"), "sirius")
    }

    func testLotWithoutDateOmitsParam() async throws {
        let body = try fixture("quiz-v2-lot-leclub")
        StubProtocol.handler = { _ in (200, body) }
        _ = try await makeClient().quiz.lot(app: "leclub")
        XCTAssertEqual(queryItems(try XCTUnwrap(StubProtocol.seen.last)), ["app": "leclub"])
    }

    func testLegacyDaily() async throws {
        let body = try fixture("partie-daily-keskonfe")
        StubProtocol.handler = { _ in (200, body) }
        let c = makeClient()
        let lot = try await c.quiz.legacyDaily(app: nil, date: nil)
        XCTAssertEqual(lot.quizzes.count, 30)
        var r = try XCTUnwrap(StubProtocol.seen.last)
        XCTAssertEqual(r.url?.path, "/api/partie/daily")
        XCTAssertTrue(queryItems(r).isEmpty)
        _ = try await c.quiz.legacyDaily(app: "sirius", date: "2026-10-12")
        r = try XCTUnwrap(StubProtocol.seen.last)
        XCTAssertEqual(queryItems(r), ["app": "sirius", "date": "2026-10-12"])
    }

    func testReportSendsPostBodyAndDeviceHeader() async throws {
        StubProtocol.handler = { _ in (202, Data(#"{"ok":true}"#.utf8)) }
        let device = UUID()
        try await makeClient().quiz.report(id: "abc", reason: "mauvaise réponse", deviceId: device)
        let r = try XCTUnwrap(StubProtocol.seen.last)
        XCTAssertEqual(r.httpMethod, "POST")
        XCTAssertEqual(r.url?.path, "/api/quiz/v2/quiz/abc/report")
        XCTAssertEqual(r.value(forHTTPHeaderField: "x-device-id"), device.uuidString)
        XCTAssertEqual(r.value(forHTTPHeaderField: "x-api-key"), "key-1")
        XCTAssertEqual(r.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let json = try JSONSerialization.jsonObject(with: try XCTUnwrap(StubProtocol.seenBodies.last)) as? [String: String]
        XCTAssertEqual(json, ["reason": "mauvaise réponse"])
    }

    func testReportMinimalAndOk200() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"ok":true}"#.utf8)) }
        try await makeClient().quiz.report(id: "abc")
        let r = try XCTUnwrap(StubProtocol.seen.last)
        XCTAssertNil(r.value(forHTTPHeaderField: "x-device-id"))
    }

    func testReportTypedErrors() async throws {
        let c = makeClient()
        StubProtocol.handler = { _ in (404, Data(#"{"error":"quiz not found"}"#.utf8)) }
        do { try await c.quiz.report(id: "x"); XCTFail() } catch QuizReportError.notFound {} catch { XCTFail("\(error)") }
        StubProtocol.handler = { _ in (429, Data(#"{"error":"too many reports"}"#.utf8)) }
        do { try await c.quiz.report(id: "x"); XCTFail() } catch QuizReportError.tooManyReports {} catch { XCTFail("\(error)") }
        StubProtocol.handler = { _ in (500, Data()) }
        do { try await c.quiz.report(id: "x"); XCTFail() } catch QuizReportError.other(let e) {
            guard case CultureAPIError.httpError(let s, _) = e else { return XCTFail("\(e)") }
            XCTAssertEqual(s, 500)
        } catch { XCTFail("\(error)") }
    }

    func testStory() async throws {
        let lotData = try fixture("quiz-v2-lot-leclub")
        let first = try XCTUnwrap(try JSONSerialization.jsonObject(with: lotData) as? [String: Any])
        let one = try JSONSerialization.data(withJSONObject: (first["quizzes"] as! [Any])[0])
        StubProtocol.handler = { _ in (200, one) }
        let question = try await makeClient().quiz.story(id: "story-1")
        XCTAssertEqual(question.tone, "actu")
        let r = try XCTUnwrap(StubProtocol.seen.last)
        XCTAssertEqual(r.url?.path, "/api/quiz/v2/story/story-1")
        XCTAssertEqual(r.httpMethod, "GET")
    }

    func testLotNotFoundIsHTTPError() async throws {
        StubProtocol.handler = { _ in (404, Data()) }
        do { _ = try await makeClient().quiz.lot(app: "leclub"); XCTFail() }
        catch CultureAPIError.httpError(let s, _) { XCTAssertEqual(s, 404) }
    }
}
