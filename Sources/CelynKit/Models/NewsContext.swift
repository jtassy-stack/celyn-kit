import Foundation

// ─── News context & « Pour aller plus loin » ─────────────
// Additive, optional keys on `GET /api/news/stories/:id` (culture-api
// docs/news-context.md, contract src/lib/news-context/contract.ts):
// `concepts`, `context`, `relatedStories`, `furtherReading`,
// `furtherReadingPolicy`. Every key may be absent. Unknown enum values map to
// a generic fallback and an invalid array element is skipped — a bad element
// never blanks the story detail.

/// Decodes an array element by element, dropping the elements that fail.
struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]

    private struct AnyDecodable: Decodable {}

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        var out: [Element] = []
        while !c.isAtEnd {
            if let e = try? c.decode(Element.self) {
                out.append(e)
            } else {
                _ = try? c.decode(AnyDecodable.self) // advance past the bad element
            }
        }
        elements = out
    }
}

extension KeyedDecodingContainer {
    /// Absent / null / not an array → []. Invalid elements are skipped.
    func decodeLossyArray<T: Decodable>(_ type: T.Type, forKey key: Key) -> [T] {
        ((try? decodeIfPresent(LossyArray<T>.self, forKey: key)) ?? nil)?.elements ?? []
    }

    func decodeLenient<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }

    /// Absolute http(s) URL only, else nil.
    func decodeWebURL(forKey key: Key) -> URL? {
        guard let s = decodeLenient(String.self, forKey: key),
              let url = URL(string: s.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              url.host != nil else { return nil }
        return url
    }
}

// MARK: - Concepts

public enum NewsConceptKind: String, Codable, Sendable, CaseIterable {
    case person, organization, place, event, concept, law, other

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = NewsConceptKind(rawValue: raw) ?? .other
    }
}

/// A key concept of the story (person, organisation, place…). `entityToken`
/// matches `NewsStoryDetail.entityTokens` → `news.entity(name:)`.
public struct NewsConcept: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String { wikidataId ?? entityToken ?? label }
    public let label: String
    public let kind: NewsConceptKind
    public let entityToken: String?
    public let wikidataId: String?
    public let wikipediaUrl: URL?
    /// First sentence of the Wikipedia FR summary — display with `attribution` + link.
    public let definition: String?
    /// "CC BY-SA 4.0" whenever `definition` is set.
    public let definitionLicence: String?

    public init(label: String, kind: NewsConceptKind = .other, entityToken: String? = nil, wikidataId: String? = nil,
                wikipediaUrl: URL? = nil, definition: String? = nil, definitionLicence: String? = nil) {
        self.label = label
        self.kind = kind
        self.entityToken = entityToken
        self.wikidataId = wikidataId
        self.wikipediaUrl = wikipediaUrl
        self.definition = definition
        self.definitionLicence = definitionLicence
    }

    private enum CodingKeys: String, CodingKey {
        case label, kind, entityToken, wikidataId, wikipediaUrl, definition, definitionLicence
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        kind = c.decodeLenient(NewsConceptKind.self, forKey: .kind) ?? .other
        entityToken = c.decodeLenient(String.self, forKey: .entityToken).flatMap { $0.isEmpty ? nil : $0 }
        wikidataId = c.decodeLenient(String.self, forKey: .wikidataId)
        wikipediaUrl = c.decodeWebURL(forKey: .wikipediaUrl)
        definition = c.decodeLenient(String.self, forKey: .definition).flatMap { $0.isEmpty ? nil : $0 }
        definitionLicence = c.decodeLenient(String.self, forKey: .definitionLicence)
    }

    /// « Wikipédia, CC BY-SA 4.0 » when a licensed definition is shown, else nil.
    public var attribution: String? {
        guard definition != nil else { return nil }
        return "Wikipédia, \(definitionLicence ?? "CC BY-SA 4.0")"
    }
}

// MARK: - Context (flag-gated server-side: usually absent)

public struct NewsContextSentence: Codable, Sendable, Equatable, Hashable {
    public let text: String
    /// Ids of `NewsStoryContext.sources` ("c0", "w1"…).
    public let cites: [String]

    public init(text: String, cites: [String] = []) {
        self.text = text
        self.cites = cites
    }

    private enum CodingKeys: String, CodingKey { case text, cites }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        cites = c.decodeLossyArray(String.self, forKey: .cites)
    }
}

public struct NewsContextSource: Codable, Sendable, Equatable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case claim, wikipedia, other

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .other
        }
    }

    public let id: String
    public let kind: Kind
    public let label: String
    public let url: URL?
    public let licence: String?

    public init(id: String, kind: Kind = .other, label: String, url: URL? = nil, licence: String? = nil) {
        self.id = id
        self.kind = kind
        self.label = label
        self.url = url
        self.licence = licence
    }

    private enum CodingKeys: String, CodingKey { case id, kind, label, url, licence }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = c.decodeLenient(Kind.self, forKey: .kind) ?? .other
        label = c.decodeLenient(String.self, forKey: .label) ?? ""
        url = c.decodeWebURL(forKey: .url)
        licence = c.decodeLenient(String.self, forKey: .licence)
    }
}

/// Short generated context paragraph, each sentence citing its sources.
/// Withheld by the server until `NEWS_CONTEXT_TEXT_ENABLED` — render only if present.
public struct NewsStoryContext: Codable, Sendable, Equatable, Hashable {
    public let sentences: [NewsContextSentence]
    public let whyItMatters: NewsContextSentence?
    public let sources: [NewsContextSource]
    public let generatedAt: Date?
    public let model: String?
    public let verifiedBy: String?

    public init(sentences: [NewsContextSentence], whyItMatters: NewsContextSentence? = nil,
                sources: [NewsContextSource] = [], generatedAt: Date? = nil, model: String? = nil, verifiedBy: String? = nil) {
        self.sentences = sentences
        self.whyItMatters = whyItMatters
        self.sources = sources
        self.generatedAt = generatedAt
        self.model = model
        self.verifiedBy = verifiedBy
    }

    private enum CodingKeys: String, CodingKey { case sentences, whyItMatters, sources, generatedAt, model, verifiedBy }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sentences = c.decodeLossyArray(NewsContextSentence.self, forKey: .sentences)
        whyItMatters = c.decodeLenient(NewsContextSentence.self, forKey: .whyItMatters)
        sources = c.decodeLossyArray(NewsContextSource.self, forKey: .sources)
        generatedAt = c.decodeLenient(Date.self, forKey: .generatedAt)
        model = c.decodeLenient(String.self, forKey: .model)
        verifiedBy = c.decodeLenient(String.self, forKey: .verifiedBy)
    }

    /// Something to show (at least one sentence).
    public var hasDisplayableContent: Bool { !sentences.isEmpty }

    /// « [1] », « [2] »… — 1-based position of `sourceId` in `sources`, nil if unknown.
    public func citationLabel(for sourceId: String) -> String? {
        sources.firstIndex { $0.id == sourceId }.map { "[\($0 + 1)]" }
    }

    /// Sources cited by a sentence, in citation order (unknown ids dropped).
    public func sources(citedBy sentence: NewsContextSentence) -> [NewsContextSource] {
        sentence.cites.compactMap { id in sources.first { $0.id == id } }
    }

    /// « Sources : Wikipédia (CC BY-SA 4.0), recoupement Sirius » — from the source kinds present.
    public var attributionLine: String {
        var parts: [String] = []
        if sources.contains(where: { $0.kind == .wikipedia }) { parts.append("Wikipédia (CC BY-SA 4.0)") }
        if sources.contains(where: { $0.kind == .claim }) { parts.append("recoupement Sirius") }
        return parts.isEmpty ? "" : "Sources : " + parts.joined(separator: ", ")
    }
}

// MARK: - Related stories

/// An earlier story on the same subject (« Déjà dans l'actu »).
public struct NewsRelatedStory: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String { storyId }
    public let storyId: String
    public let title: String
    public let firstSeenAt: Date?
    public let similarity: Double?

    public init(storyId: String, title: String, firstSeenAt: Date? = nil, similarity: Double? = nil) {
        self.storyId = storyId
        self.title = title
        self.firstSeenAt = firstSeenAt
        self.similarity = similarity
    }

    private enum CodingKeys: String, CodingKey { case storyId, title, firstSeenAt, similarity }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        storyId = try c.decode(String.self, forKey: .storyId)
        title = try c.decode(String.self, forKey: .title)
        firstSeenAt = c.decodeLenient(Date.self, forKey: .firstSeenAt)
        similarity = c.decodeLenient(Double.self, forKey: .similarity)
    }
}

// MARK: - Further reading

/// Wire values are French and stable; unknown → `.oeuvre` (generic).
public enum FurtherReadingType: String, Codable, Sendable, CaseIterable {
    case film, serie, anime, livre
    case jeuVideo = "jeu_video"
    case album, podcast, episode, oeuvre

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = FurtherReadingType(rawValue: raw) ?? .oeuvre
    }

    /// « Film », « Série », « Anime », « Livre », « Jeu vidéo », « Album », « Podcast », « Épisode », « Œuvre ».
    public var label: String {
        switch self {
        case .film: return "Film"
        case .serie: return "Série"
        case .anime: return "Anime"
        case .livre: return "Livre"
        case .jeuVideo: return "Jeu vidéo"
        case .album: return "Album"
        case .podcast: return "Podcast"
        case .episode: return "Épisode"
        case .oeuvre: return "Œuvre"
        }
    }

    /// SF Symbol for a type badge / cover placeholder.
    public var symbolName: String {
        switch self {
        case .film: return "film"
        case .serie: return "tv"
        case .anime: return "sparkles.tv"
        case .livre: return "book"
        case .jeuVideo: return "gamecontroller"
        case .album: return "music.note"
        case .podcast: return "mic"
        case .episode: return "waveform"
        case .oeuvre: return "square.stack"
        }
    }
}

/// standard = any type · seriousOnly = books, podcasts, documentaries only (grave story) · none = hide.
public enum FurtherReadingPolicy: String, Codable, Sendable, CaseIterable {
    case standard
    case seriousOnly = "serious_only"
    case none

    /// Unknown → `.standard`.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = FurtherReadingPolicy(rawValue: raw) ?? .standard
    }

    /// The carousel is never shown for `.none`.
    public var allowsCarousel: Bool { self != .none }

    /// Sober sub-header for grave stories; nil otherwise.
    public var emptyStateText: String? {
        switch self {
        case .seriousOnly: return "Sujet grave : seulement des documentaires, livres et podcasts."
        case .standard, .none: return nil
        }
    }

    /// Section title (« Pour aller plus loin » in both visible cases).
    public var sectionTitle: String { "Pour aller plus loin" }
}

/// A work or podcast episode recommended to go further on the story.
public struct FurtherReadingItem: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String { oeuvreId ?? episodeId ?? "\(type.rawValue):\(title)" }
    public let type: FurtherReadingType
    /// → `oeuvres.get(id:)`. nil for podcast episodes.
    public let oeuvreId: String?
    /// Podcast episode id when `type == .episode`.
    public let episodeId: String?
    public let wikidataId: String?
    public let title: String
    public let year: Int?
    public let creator: String?
    /// « Pourquoi » — one French sentence.
    public let reason: String
    /// Only licensed hosts (TMDB / IGDB / Wikimedia Commons), else nil → type placeholder.
    public let imageUrl: URL?
    /// French availability labels (streaming platforms…). [] = unknown.
    public let availabilityFr: [String]
    /// Server-side provenance ("embedding", "concept_match"…). Informational.
    public let source: String?

    public init(type: FurtherReadingType, oeuvreId: String? = nil, episodeId: String? = nil, wikidataId: String? = nil,
                title: String, year: Int? = nil, creator: String? = nil, reason: String = "",
                imageUrl: URL? = nil, availabilityFr: [String] = [], source: String? = nil) {
        self.type = type
        self.oeuvreId = oeuvreId
        self.episodeId = episodeId
        self.wikidataId = wikidataId
        self.title = title
        self.year = year
        self.creator = creator
        self.reason = reason
        self.imageUrl = imageUrl
        self.availabilityFr = availabilityFr
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case type, oeuvreId, episodeId, wikidataId, title, year, creator, reason, imageUrl, availabilityFr, source
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = c.decodeLenient(FurtherReadingType.self, forKey: .type) ?? .oeuvre
        oeuvreId = c.decodeLenient(String.self, forKey: .oeuvreId)
        episodeId = c.decodeLenient(String.self, forKey: .episodeId)
        wikidataId = c.decodeLenient(String.self, forKey: .wikidataId)
        title = try c.decode(String.self, forKey: .title)
        year = c.decodeLenient(Int.self, forKey: .year)
        creator = c.decodeLenient(String.self, forKey: .creator).flatMap { $0.isEmpty ? nil : $0 }
        reason = c.decodeLenient(String.self, forKey: .reason) ?? ""
        imageUrl = c.decodeWebURL(forKey: .imageUrl)
        availabilityFr = c.decodeLossyArray(String.self, forKey: .availabilityFr).filter { !$0.isEmpty }
        source = c.decodeLenient(String.self, forKey: .source)
    }

    /// « Disponible sur Apple TV, Netflix » (at most `limit` names, « … » beyond), nil when unknown.
    public func availabilityLabel(limit: Int = 2) -> String? {
        guard !availabilityFr.isEmpty else { return nil }
        let shown = availabilityFr.prefix(max(1, limit)).joined(separator: ", ")
        return "Disponible sur " + shown + (availabilityFr.count > limit ? "…" : "")
    }

    /// « Livre · 2023 » — type label and year when known.
    public var subtitle: String {
        [type.label, year.map(String.init)].compactMap { $0 }.joined(separator: " · ")
    }

    /// VoiceOver label: « Livre, titre, 2023. Pourquoi : … ».
    public var accessibilityLabel: String {
        var s = [type.label, title, year.map(String.init)].compactMap { $0 }.joined(separator: ", ")
        if !reason.isEmpty { s += ". Pourquoi : " + reason }
        if let a = availabilityLabel(limit: 3) { s += ". " + a }
        return s
    }

    /// The item links to a catalogue fiche (`oeuvres.get(id:)`).
    public var hasOeuvreDetail: Bool { oeuvreId != nil }
}

extension NewsStoryDetail {
    /// Items to show in the « Pour aller plus loin » carousel: [] when the policy is `.none`.
    public var visibleFurtherReading: [FurtherReadingItem] {
        (furtherReadingPolicy ?? .standard).allowsCarousel ? furtherReading : []
    }

    /// Whether to render the carousel section at all.
    public var showsFurtherReading: Bool { !visibleFurtherReading.isEmpty }
}

// MARK: - Oeuvre placeholders

extension OeuvreType {
    /// SF Symbol for a cover placeholder (games from Wikidata often have no image).
    public var placeholderSymbolName: String {
        switch self {
        case .film: return "film"
        case .tvshow, .series: return "tv"
        case .book: return "book"
        case .game: return "gamecontroller"
        case .album, .song, .concert, .opera: return "music.note"
        case .podcast: return "mic"
        case .play, .dance: return "theatermasks"
        case .exhibition, .artwork: return "photo.artframe"
        case .monument: return "building.columns"
        case .festival: return "sparkles"
        case .other: return "square.stack"
        }
    }
}

extension Oeuvre {
    /// A displayable http(s) cover URL, nil → show `oeuvreType.placeholderSymbolName`.
    public var coverURL: URL? {
        guard let s = imageUrl, !s.isEmpty, let u = URL(string: s),
              let scheme = u.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        return u
    }
}
