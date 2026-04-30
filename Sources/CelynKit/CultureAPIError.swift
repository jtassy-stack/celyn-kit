import Foundation

public enum CultureAPIError: LocalizedError, Sendable {
    case invalidResponse
    case missingAPIKey
    case httpError(statusCode: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .missingAPIKey:
            return "Missing culture-api key"
        case .httpError(let statusCode, _):
            return "HTTP \(statusCode)"
        }
    }
}
