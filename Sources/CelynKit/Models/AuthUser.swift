import Foundation

// Wire models for end-user phone auth (/auth/users/*). snake_case JSON maps to
// camelCase via the client's .convertFromSnakeCase strategy.

public struct OTPRequestResponse: Codable, Sendable {
    public let status: String   // "pending"
    public let phone: String    // normalized E.164 echoed back
}

public struct OTPVerifyResponse: Codable, Sendable {
    public let token: String    // 30-day user JWT
    public let user: AuthUser
}

public struct AuthUser: Codable, Sendable, Identifiable {
    public let id: String
    public let phone: String
    public let displayName: String?
    public let createdAt: Date?
}

public struct AuthMeResponse: Codable, Sendable {
    public let user: AuthUser
}
