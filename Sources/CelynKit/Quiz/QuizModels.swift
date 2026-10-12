import Foundation

// Quiz v2 models. One model serves both the v2 lot (`GET quiz/v2/lot`) and the
// frozen legacy daily (`GET partie/daily`): the v2 fields (`tone`, `horizon`,
// `validUntil`, `promotedFrom`) are optional and absent on legacy.
//
// Decoding is deliberately tolerant (contract §8): an unreadable question is
// dropped and never takes the lot down, an unreadable citation becomes nil,
// unknown keys are ignored. Dates stay `String` (`YYYY-MM-DD` or ISO instants)
// because callers key on them.

/// A day's quiz. `Identifiable` by its date.
public struct QuizLot: Codable, Sendable, Equatable, Identifiable {
    public var date: String
    public var number: Int
    public var citation: QuizCitation?
    /// Unreadable questions are already dropped. May still hold questions that
    /// are not `isPlayable`; use `playableQuizzes` to play.
    public var quizzes: [QuizQuestion]
    /// Sirius only (nil for Keskonfé / Club).
    public var editions: [QuizEdition]?
    /// ISO instant of the next edition (Sirius only).
    public var nextEditionAt: String?

    public var id: String { date }

    public var playableQuizzes: [QuizQuestion] { quizzes.filter(\.isPlayable) }

    public init(
        date: String,
        number: Int,
        citation: QuizCitation? = nil,
        quizzes: [QuizQuestion],
        editions: [QuizEdition]? = nil,
        nextEditionAt: String? = nil
    ) {
        self.date = date
        self.number = number
        self.citation = citation
        self.quizzes = quizzes
        self.editions = editions
        self.nextEditionAt = nextEditionAt
    }

    private enum CodingKeys: String, CodingKey {
        case date, number, citation, quizzes, editions, nextEditionAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        number = (try? c.decode(Int.self, forKey: .number)) ?? 0
        citation = try? c.decodeIfPresent(QuizCitation.self, forKey: .citation)
        quizzes = (try? c.decode([QuizLossy<QuizQuestion>].self, forKey: .quizzes))?
            .compactMap(\.value) ?? []
        editions = (try? c.decode([QuizLossy<QuizEdition>].self, forKey: .editions))?
            .compactMap(\.value)
        nextEditionAt = try? c.decodeIfPresent(String.self, forKey: .nextEditionAt)
    }
}

public struct QuizQuestion: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var domain: String?
    public var difficulty: Int?
    /// `actu|catalogue|bridge|filmo|fait` (open string: new kinds must not break decoding).
    public var kind: String?
    public var question: String
    public var choices: [String]
    /// nil when the server withholds the answer (the Club BFF does): the
    /// question is still playable, the score is just unknown.
    public var answerIndex: Int?
    public var explanation: String?
    public var storyId: String?
    public var oeuvreId: String?
    public var oeuvreTitle: String?
    public var genres: [String]?
    public var imageUrl: String?
    public var answerOeuvreId: String?
    /// Sirius: `matin|midi|soir|daily`.
    public var edition: String?
    // v2 only
    /// `actu|histoire|fun`.
    public var tone: String?
    public var horizon: String?
    public var validUntil: String?
    public var promotedFrom: String?

    /// Non-empty question, at least 2 choices, `answerIndex` inside the bounds when present.
    public var isPlayable: Bool {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              choices.count >= 2 else { return false }
        if let a = answerIndex { return choices.indices.contains(a) }
        return true
    }

    public init(
        id: String,
        domain: String? = nil,
        difficulty: Int? = nil,
        kind: String? = nil,
        question: String,
        choices: [String],
        answerIndex: Int? = nil,
        explanation: String? = nil,
        storyId: String? = nil,
        oeuvreId: String? = nil,
        oeuvreTitle: String? = nil,
        genres: [String]? = nil,
        imageUrl: String? = nil,
        answerOeuvreId: String? = nil,
        edition: String? = nil,
        tone: String? = nil,
        horizon: String? = nil,
        validUntil: String? = nil,
        promotedFrom: String? = nil
    ) {
        self.id = id
        self.domain = domain
        self.difficulty = difficulty
        self.kind = kind
        self.question = question
        self.choices = choices
        self.answerIndex = answerIndex
        self.explanation = explanation
        self.storyId = storyId
        self.oeuvreId = oeuvreId
        self.oeuvreTitle = oeuvreTitle
        self.genres = genres
        self.imageUrl = imageUrl
        self.answerOeuvreId = answerOeuvreId
        self.edition = edition
        self.tone = tone
        self.horizon = horizon
        self.validUntil = validUntil
        self.promotedFrom = promotedFrom
    }

    private enum CodingKeys: String, CodingKey {
        case id, domain, difficulty, kind, question, choices, answerIndex, explanation
        case storyId, oeuvreId, oeuvreTitle, genres, imageUrl, answerOeuvreId
        case edition, tone, horizon, validUntil, promotedFrom
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Required: without these the question cannot be shown or reported.
        id = try c.decode(String.self, forKey: .id)
        question = try c.decode(String.self, forKey: .question)
        choices = try c.decode([String].self, forKey: .choices)
        // A present-but-malformed answer is corruption (dropping the question
        // beats scoring against a wrong key); null / absent is a legit "hidden".
        if c.contains(.answerIndex), try !c.decodeNil(forKey: .answerIndex) {
            answerIndex = try c.decode(Int.self, forKey: .answerIndex)
        } else {
            answerIndex = nil
        }
        // Everything else is cosmetic: a bad value reads as nil.
        domain = try? c.decodeIfPresent(String.self, forKey: .domain)
        difficulty = try? c.decodeIfPresent(Int.self, forKey: .difficulty)
        kind = try? c.decodeIfPresent(String.self, forKey: .kind)
        explanation = try? c.decodeIfPresent(String.self, forKey: .explanation)
        storyId = try? c.decodeIfPresent(String.self, forKey: .storyId)
        oeuvreId = try? c.decodeIfPresent(String.self, forKey: .oeuvreId)
        oeuvreTitle = try? c.decodeIfPresent(String.self, forKey: .oeuvreTitle)
        genres = try? c.decodeIfPresent([String].self, forKey: .genres)
        imageUrl = try? c.decodeIfPresent(String.self, forKey: .imageUrl)
        answerOeuvreId = try? c.decodeIfPresent(String.self, forKey: .answerOeuvreId)
        edition = try? c.decodeIfPresent(String.self, forKey: .edition)
        tone = try? c.decodeIfPresent(String.self, forKey: .tone)
        horizon = try? c.decodeIfPresent(String.self, forKey: .horizon)
        validUntil = try? c.decodeIfPresent(String.self, forKey: .validUntil)
        promotedFrom = try? c.decodeIfPresent(String.self, forKey: .promotedFrom)
    }
}

public struct QuizCitation: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var text: String
    public var author: String
    public var work: String?
    public var oeuvreId: String?
    public var translator: String?
    public var decoys: [String]?

    public init(
        id: String,
        text: String,
        author: String,
        work: String? = nil,
        oeuvreId: String? = nil,
        translator: String? = nil,
        decoys: [String]? = nil
    ) {
        self.id = id
        self.text = text
        self.author = author
        self.work = work
        self.oeuvreId = oeuvreId
        self.translator = translator
        self.decoys = decoys
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, author, work, oeuvreId, translator, decoys
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        author = try c.decode(String.self, forKey: .author)
        work = try? c.decodeIfPresent(String.self, forKey: .work)
        oeuvreId = try? c.decodeIfPresent(String.self, forKey: .oeuvreId)
        translator = try? c.decodeIfPresent(String.self, forKey: .translator)
        decoys = try? c.decodeIfPresent([String].self, forKey: .decoys)
    }
}

/// One published edition of a Sirius day.
public struct QuizEdition: Codable, Sendable, Equatable, Identifiable {
    public var edition: String
    public var publishedAt: String?
    public var number: Int?
    public var quizCount: Int?

    public var id: String { edition }

    public init(edition: String, publishedAt: String? = nil, number: Int? = nil, quizCount: Int? = nil) {
        self.edition = edition
        self.publishedAt = publishedAt
        self.number = number
        self.quizCount = quizCount
    }

    private enum CodingKeys: String, CodingKey {
        case edition, publishedAt, number, quizCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        edition = try c.decode(String.self, forKey: .edition)
        publishedAt = try? c.decodeIfPresent(String.self, forKey: .publishedAt)
        number = try? c.decodeIfPresent(Int.self, forKey: .number)
        quizCount = try? c.decodeIfPresent(Int.self, forKey: .quizCount)
    }
}

/// Decodes `T` or yields nil, always consuming the element so an array keeps going.
struct QuizLossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}
