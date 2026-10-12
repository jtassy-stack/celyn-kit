import Foundation

/// Typed failures of `QuizResource.report`. Anything else is passed through as
/// `.other` (the underlying `CultureAPIError` or transport error).
public enum QuizReportError: Error, Sendable {
    /// 404: unknown question.
    case notFound
    /// 429: this reporter hit the daily report cap.
    case tooManyReports
    case other(any Error)
}

/// Daily quiz — `GET /api/quiz/v2/lot`, legacy `GET /api/partie/daily`,
/// `POST /api/quiz/v2/quiz/:id/report`, `GET /api/quiz/v2/story/:id`.
/// Contract: culture-api docs/quiz-v2-contrat.md §1 and §6.
public struct QuizResource: Sendable {
    let client: CultureAPIClient

    /// The v2 lot. `app` is `keskonfe|sirius|leclub`; `date` is `YYYY-MM-DD` (default: today, server side).
    /// 404 (no lot) surfaces as `CultureAPIError.httpError(statusCode: 404, ...)`.
    public func lot(app: String, date: String? = nil) async throws -> QuizLot {
        var query = ["app": app]
        if let date { query["date"] = date }
        return try await client.get("quiz/v2/lot", query: query)
    }

    /// The frozen legacy daily, same model (v2 fields come back nil).
    /// `app` nil lets the server default to `keskonfe`.
    public func legacyDaily(app: String? = nil, date: String? = nil) async throws -> QuizLot {
        var query: [String: String] = [:]
        if let app { query["app"] = app }
        if let date { query["date"] = date }
        return try await client.get("partie/daily", query: query)
    }

    /// Reports an error in a question. 202 and 200 are success. `deviceId`, when
    /// given, is sent as `x-device-id` so the server can cap reports per
    /// reporter (it only stores a salted hash).
    public func report(id: String, reason: String? = nil, deviceId: UUID? = nil) async throws {
        struct Body: Encodable { let reason: String? }
        struct Ack: Decodable {}
        var headers: [String: String] = [:]
        if let deviceId { headers["x-device-id"] = deviceId.uuidString }
        do {
            let _: Ack = try await client.post(
                "quiz/v2/quiz/\(Self.pathSegment(id))/report",
                body: Body(reason: reason),
                headers: headers
            )
        } catch let CultureAPIError.httpError(status, body) {
            switch status {
            case 404: throw QuizReportError.notFound
            case 429: throw QuizReportError.tooManyReports
            default: throw QuizReportError.other(CultureAPIError.httpError(statusCode: status, body: body))
            }
        } catch {
            throw QuizReportError.other(error)
        }
    }

    /// The question attached to a news story (the Fil links a card to it). 404 when the story has none.
    public func story(id: String) async throws -> QuizQuestion {
        try await client.get("quiz/v2/story/\(Self.pathSegment(id))")
    }

    /// Un id dans le chemin ne doit jamais changer la route ("/" ou "?") : encodage percent, UUID et "celyn:<uuid>" inchangés.
    static func pathSegment(_ id: String) -> String {
        id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?"))) ?? id
    }
}
