import Foundation

/// Pure state machine for playing one `QuizLot`: no UI, no network, no clock.
/// `Codable` so the host app can persist it between launches and resume.
///
/// Only playable questions (`QuizQuestion.isPlayable`) are kept, in lot order.
/// The session carries the questions themselves, so a restored session needs no
/// refetch. Scoring is local and only possible for questions that carry an
/// `answerIndex`; when the server withholds answers, `score` is nil.
public struct QuizSession: Codable, Sendable, Equatable {

    public enum Response: Codable, Sendable, Equatable {
        case answered(choice: Int)
        case skipped
    }

    public enum AnswerOutcome: Sendable, Equatable {
        case correct
        case incorrect(correctIndex: Int)
        /// Recorded, but the question has no `answerIndex`: nothing to grade against.
        case unscored
        /// Unknown question, choice out of range, or already answered (first answer wins).
        case rejected
    }

    public struct Progress: Sendable, Equatable {
        public let answered: Int
        public let skipped: Int
        public let total: Int
    }

    public struct Score: Sendable, Equatable {
        public let correct: Int
        /// Questions that can be graded (carry an `answerIndex`). Skipped ones count as missed.
        public let total: Int
    }

    /// Questions of one edition (Sirius), in first-appearance order.
    public struct Block: Sendable, Equatable, Identifiable {
        /// nil for questions without an edition.
        public let edition: String?
        public let questions: [QuizQuestion]
        public let answered: Int
        public var total: Int { questions.count }
        public var isFinished: Bool { answeredOrSkipped == total }
        let answeredOrSkipped: Int
        public var id: String { edition ?? "" }
    }

    public let lotDate: String
    public let lotNumber: Int
    public let questions: [QuizQuestion]
    public private(set) var responses: [String: Response]

    public init(lot: QuizLot) {
        lotDate = lot.date
        lotNumber = lot.number
        var seen = Set<String>()
        // Duplicate ids would make answers ambiguous: keep the first.
        questions = lot.quizzes.filter { $0.isPlayable && seen.insert($0.id).inserted }
        responses = [:]
    }

    // MARK: Actions

    @discardableResult
    public mutating func answer(questionId: String, choice: Int) -> AnswerOutcome {
        guard let q = question(id: questionId), q.choices.indices.contains(choice) else { return .rejected }
        if case .answered? = responses[questionId] { return .rejected }
        responses[questionId] = .answered(choice: choice)
        guard let correct = q.answerIndex else { return .unscored }
        return choice == correct ? .correct : .incorrect(correctIndex: correct)
    }

    /// Skips a question not answered yet. A skipped question can still be answered later.
    @discardableResult
    public mutating func skip(questionId: String) -> Bool {
        guard question(id: questionId) != nil else { return false }
        if case .answered? = responses[questionId] { return false }
        responses[questionId] = .skipped
        return true
    }

    // MARK: State

    public func question(id: String) -> QuizQuestion? {
        questions.first { $0.id == id }
    }

    /// The choice given, nil if skipped or untouched.
    public func choice(for questionId: String) -> Int? {
        if case .answered(let c)? = responses[questionId] { return c }
        return nil
    }

    public func isSkipped(_ questionId: String) -> Bool { responses[questionId] == .skipped }

    public var progress: Progress {
        var answered = 0, skipped = 0
        for q in questions {
            switch responses[q.id] {
            case .answered?: answered += 1
            case .skipped?: skipped += 1
            case nil: break
            }
        }
        return Progress(answered: answered, skipped: skipped, total: questions.count)
    }

    /// Every question answered or skipped. True for an empty session (check `questions.isEmpty`).
    public var isFinished: Bool { questions.allSatisfy { responses[$0.id] != nil } }

    /// nil when no question carries an `answerIndex`.
    public var score: Score? {
        var correct = 0, total = 0
        for q in questions {
            guard let a = q.answerIndex else { continue }
            total += 1
            if case .answered(let c)? = responses[q.id], c == a { correct += 1 }
        }
        return total == 0 ? nil : Score(correct: correct, total: total)
    }

    // MARK: Resume

    /// Questions neither answered nor skipped, in lot order.
    public var pending: [QuizQuestion] { questions.filter { responses[$0.id] == nil } }

    /// Questions skipped and not answered since.
    public var skippedQuestions: [QuizQuestion] { questions.filter { responses[$0.id] == .skipped } }

    /// First pending question strictly after `questionId` in lot order, wrapping
    /// to the start. With nil (or an unknown id) it is the first pending one.
    /// When nothing is pending, the first skipped one (a second chance), then nil.
    public func nextQuestion(after questionId: String? = nil) -> QuizQuestion? {
        let start = questionId.flatMap { id in questions.firstIndex { $0.id == id } }.map { $0 + 1 } ?? 0
        let order = Array(questions[start...]) + Array(questions[..<start])
        return order.first { responses[$0.id] == nil } ?? order.first { responses[$0.id] == .skipped }
    }

    // MARK: Editions

    /// Questions grouped by `edition`, in order of first appearance.
    public var blocks: [Block] {
        var order: [String?] = []
        var groups: [String?: [QuizQuestion]] = [:]
        for q in questions {
            if groups[q.edition] == nil { order.append(q.edition) }
            groups[q.edition, default: []].append(q)
        }
        return order.map { ed in
            let qs = groups[ed] ?? []
            var answered = 0, done = 0
            for q in qs {
                switch responses[q.id] {
                case .answered?: answered += 1; done += 1
                case .skipped?: done += 1
                case nil: break
                }
            }
            return Block(edition: ed, questions: qs, answered: answered, answeredOrSkipped: done)
        }
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey { case lotDate, lotNumber, questions, responses }

    /// Restoring drops responses whose question or choice no longer fits, so a
    /// stale or hand-edited blob cannot produce an impossible state.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lotDate = try c.decode(String.self, forKey: .lotDate)
        lotNumber = try c.decode(Int.self, forKey: .lotNumber)
        let qs = try c.decode([QuizLossy<QuizQuestion>].self, forKey: .questions).compactMap(\.value)
        var seen = Set<String>()
        questions = qs.filter { $0.isPlayable && seen.insert($0.id).inserted }
        let raw = (try? c.decode([String: Response].self, forKey: .responses)) ?? [:]
        let byId = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
        responses = raw.filter { id, r in
            guard let q = byId[id] else { return false }
            if case .answered(let ch) = r { return q.choices.indices.contains(ch) }
            return true
        }
    }
}
