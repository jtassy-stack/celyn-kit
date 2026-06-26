import Foundation

/// Envelope returned by GET /api/me/sync. `payload` is the app-defined blob
/// (generic so CelynKit stays decoupled from the app's profile shape); null on
/// first login.
public struct SyncEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public let version: Int
    public let payload: Payload?
    public let updatedAt: Date?
}

public struct SyncPutResponse: Codable, Sendable {
    public let version: Int
    public let updatedAt: Date?
}

public struct CircleListResponse<Member: Codable & Sendable>: Codable, Sendable {
    public let data: [Member]
    public let count: Int
}

/// Authenticated end-user account endpoints. All require the user bearer token
/// (set via the client's bearerProvider) in addition to the app key.
public struct MeResource: Sendable {
    let client: CultureAPIClient

    // MARK: Profile sync (portability)

    public func getSync<Payload: Codable & Sendable>(
        _ : Payload.Type
    ) async throws -> SyncEnvelope<Payload> {
        try await client.get("me/sync")
    }

    public func putSync<Payload: Codable & Sendable>(
        _ payload: Payload
    ) async throws -> SyncPutResponse {
        try await client.put("me/sync", body: SyncBody(payload: payload))
    }

    // MARK: Circle (contacts matching + follows)

    public func matchContacts(hashes: [String]) async throws -> ContactMatchResponse {
        struct Body: Encodable { let hashes: [String] }
        return try await client.post("me/contacts/match", body: Body(hashes: hashes))
    }

    public func follow(_ followeeId: String) async throws -> FollowResponse {
        struct Body: Encodable { let followeeId: String }
        return try await client.post("me/follows", body: Body(followeeId: followeeId))
    }

    public func unfollow(_ followeeId: String) async throws -> FollowResponse {
        try await client.delete("me/follows/\(followeeId)")
    }

    public func getCircle() async throws -> CircleListResponse<CircleMember> {
        try await client.get("me/circle")
    }

    // MARK: RGPD

    public struct DeleteResponse: Codable, Sendable { public let deleted: Bool }

    public func deleteAccount() async throws -> DeleteResponse {
        try await client.delete("me")
    }
}

public struct ContactMatchResponse: Codable, Sendable {
    public let matches: [MatchedContact]
}

public struct MatchedContact: Codable, Sendable, Identifiable {
    public let id: String
    public let displayName: String?
    public let phone: String?
    public let following: Bool
}

public struct CircleMember: Codable, Sendable, Identifiable {
    public let id: String
    public let displayName: String?
    public let phone: String?
    public let since: Date?
}

public struct FollowResponse: Codable, Sendable {
    public let following: Bool
}

private struct SyncBody<P: Encodable>: Encodable { let payload: P }

public extension CultureAPIClient {
    var me: MeResource { MeResource(client: self) }
}
