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

    /// How many people the caller MUTUALLY follows have saved each id.
    ///
    /// Mutual is not an implementation detail, it is the contract: follows in
    /// this app are one-way and are seeded from the reader's address book, so
    /// counting them one-way would expose what someone saves to anyone holding
    /// their phone number. The server enforces this (see
    /// `circleFavoriteCounts`); the client must not paper over a future change
    /// by treating the number as "people I follow".
    ///
    /// `kind` mirrors the library's own kinds: `event`, `venue`, `oeuvre`.
    /// Ids absent from the response simply have no one behind them — the
    /// server omits zeroes rather than sending a map full of them.
    public func circleSignal(kind: String, ids: [String]) async throws -> CircleSignalResponse {
        struct Body: Encodable { let kind: String; let ids: [String] }
        return try await client.post("me/circle/signal", body: Body(kind: kind, ids: ids))
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
    /// The digest the caller submitted for this person, echoed back so the
    /// client can rejoin the match to its own address-book entry. It reveals
    /// nothing new — the caller sent it a moment ago.
    public let phoneSha256: String?
    /// No longer sent: returning the full number turned a guessed digest into
    /// a full identity, which is what made `/me/contacts/match` worth walking.
    /// Kept optional so older payloads still decode, and so a rollback of the
    /// server change needs no client release.
    public let phone: String?
    public let following: Bool
}

public struct CircleMember: Codable, Sendable, Identifiable {
    public let id: String
    public let displayName: String?
    /// No longer sent — see `MatchedContact.phone`. Nothing replaces it here:
    /// the circle is people the caller chose to follow, and `displayName` is
    /// the name they published to be known by.
    public let phone: String?
    public let since: Date?
}

public struct CircleSignalResponse: Codable, Sendable {
    /// rawId → number of mutually-followed people who saved it. Absent means 0.
    public let counts: [String: Int]
}

public struct FollowResponse: Codable, Sendable {
    public let following: Bool
}

private struct SyncBody<P: Encodable>: Encodable { let payload: P }

public extension CultureAPIClient {
    var me: MeResource { MeResource(client: self) }
}
