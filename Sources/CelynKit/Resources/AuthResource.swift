import Foundation

public struct AuthResource: Sendable {
    let client: CultureAPIClient

    private struct RequestOTPBody: Encodable { let phone: String }
    private struct VerifyOTPBody: Encodable { let phone: String; let code: String }

    /// Send an SMS code to the phone number. The server normalizes it to E.164
    /// and returns the canonical form.
    public func requestOTP(phone: String) async throws -> OTPRequestResponse {
        try await client.post("auth/users/request-otp", body: RequestOTPBody(phone: phone))
    }

    /// Verify the code; on success returns a session token + the user.
    public func verifyOTP(phone: String, code: String) async throws -> OTPVerifyResponse {
        try await client.post("auth/users/verify-otp", body: VerifyOTPBody(phone: phone, code: code))
    }

    /// Current user (requires the session bearer token to be set on the client).
    public func me() async throws -> AuthMeResponse {
        try await client.get("auth/users/me")
    }
}

public extension CultureAPIClient {
    var auth: AuthResource { AuthResource(client: self) }
}
