import Foundation
import Combine

@MainActor
final class GameState: ObservableObject {
    enum HintResult {
        case fixMistake(cell: Int)
        case step(Deduction)
        case none
    }

    private enum Action {
        case place(cell: Int, from: Int, to: Int)
        case note(cell: Int, from: Set<Int>, to: Set<Int>)
    }

    let puzzle: Puzzle
    let index: Int
    var size: BoardSize { puzzle.size }

    @Published private(set) var cells: [Int]
    @Published private(set) var notes: [Set<Int>]
    @Published private(set) var mistakes = 0
    @Published private(set) var hintsUsed = 0
    @Published private(set) var seconds = 0
    @Published private(set) var isComplete = false
    @Published private(set) var usedAnswer = false
    @Published var selected: Int?
    @Published var noteMode = false
    @Published var paused = false

    private let human: HumanSolver
    private let geo: Geometry
    private var undoStack: [Action] = []
    private var ticker: AnyCancellable?

    init(puzzle: Puzzle, index: Int, restoring save: SavedGame? = nil) {
        self.puzzle = puzzle
        self.index = index
        let geo = Geometry(puzzle.size)
        self.geo = geo
        self.human = HumanSolver(geometry: geo)
        self.cells = save?.cells ?? puzzle.givens
        self.notes = save.map { $0.notes.map(Set.init) }
            ?? [Set<Int>](repeating: [], count: puzzle.size.cellCount)
        self.mistakes = save?.mistakes ?? 0
        self.hintsUsed = save?.hintsUsed ?? 0
        self.seconds = save?.seconds ?? 0
        self.usedAnswer = save?.usedAnswer ?? false
        self.isComplete = !cells.contains(0) && cells == puzzle.solution
        startTicking()
    }

    func startTicking() {
        ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self, !self.isComplete, !self.paused else { return }
            self.seconds += 1
        }
    }

    func stopTicking() { ticker = nil }

    // MARK: - board queries

    func isGiven(_ i: Int) -> Bool { puzzle.givens[i] != 0 }

    func isWrong(_ i: Int) -> Bool { cells[i] != 0 && cells[i] != puzzle.solution[i] }

    /// 同行/列/宫里撞了同一个数字——跟「填错」是两回事,填对的格子也可能暂时看着冲突。
    func conflicts(_ i: Int) -> Bool {
        guard cells[i] != 0 else { return false }
        return geo.peers[i].contains { cells[$0] == cells[i] }
    }

    func isPeer(of anchor: Int, _ i: Int) -> Bool {
        i != anchor && geo.peers[anchor].contains(i)
    }

    func remaining(_ value: Int) -> Int {
        size.n - cells.reduce(0) { $1 == value ? $0 + 1 : $0 }
    }

    var filledCount: Int { cells.reduce(0) { $1 != 0 ? $0 + 1 : $0 } }

    // MARK: - input

    func select(_ i: Int) {
        guard !isComplete else { return }
        selected = (selected == i) ? nil : i
    }

    func input(_ value: Int) {
        guard let i = selected, !isGiven(i), !isComplete else { return }
        if noteMode {
            guard cells[i] == 0 else { return }
            let before = notes[i]
            if notes[i].contains(value) { notes[i].remove(value) } else { notes[i].insert(value) }
            undoStack.append(.note(cell: i, from: before, to: notes[i]))
            return
        }
        let before = cells[i]
        guard before != value else { return }
        undoStack.append(.place(cell: i, from: before, to: value))
        cells[i] = value
        notes[i] = []
        if value != puzzle.solution[i] { mistakes += 1 }
        clearNotes(around: i, value: value)
        checkCompletion()
    }

    func erase() {
        guard let i = selected, !isGiven(i), !isComplete else { return }
        if cells[i] != 0 {
            undoStack.append(.place(cell: i, from: cells[i], to: 0))
            cells[i] = 0
        } else if !notes[i].isEmpty {
            undoStack.append(.note(cell: i, from: notes[i], to: []))
            notes[i] = []
        }
    }

    func undo() {
        guard let action = undoStack.popLast(), !isComplete else { return }
        switch action {
        case let .place(cell, from, _):
            cells[cell] = from
            selected = cell
        case let .note(cell, from, _):
            notes[cell] = from
            selected = cell
        }
    }

    var canUndo: Bool { !undoStack.isEmpty && !isComplete }

    private func clearNotes(around i: Int, value: Int) {
        for p in geo.peers[i] { notes[p].remove(value) }
    }

    private func checkCompletion() {
        guard !cells.contains(0) else { return }
        if cells == puzzle.solution {
            isComplete = true
            selected = nil
            stopTicking()
        }
    }

    // MARK: - hint & answer

    /// 提示走的是评级用的同一个 HumanSolver。玩家有填错的格子时先别推理——
    /// 错值会把候选算歪,给出的「下一步」是错的。
    func hint() -> HintResult {
        if let wrong = cells.indices.first(where: { isWrong($0) }) {
            hintsUsed += 1
            selected = wrong
            return .fixMistake(cell: wrong)
        }
        var work = human.makeWork(cells)
        work.cells = cells
        guard let step = human.nextStep(work) else { return .none }
        hintsUsed += 1
        if let placement = step.placement { selected = placement.cell }
        return .step(step)
    }

    func applyHint(_ deduction: Deduction) {
        guard let placement = deduction.placement else { return }
        selected = placement.cell
        input(placement.value)
    }

    func revealAnswer() {
        usedAnswer = true
    }

    // MARK: - persistence

    var snapshot: SavedGame {
        SavedGame(
            sizeN: size.n, difficulty: puzzle.difficulty, index: index,
            cells: cells, notes: notes.map { Array($0).sorted() },
            seconds: seconds, mistakes: mistakes, hintsUsed: hintsUsed, usedAnswer: usedAnswer
        )
    }
}

func formatTime(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}
