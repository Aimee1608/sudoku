import SwiftUI

struct RootView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var progress = ProgressStore()
    @StateObject private var library = BankLibrary()

    @State private var route = Route.home
    @State private var session: Session?

    private enum Route: Equatable {
        case home
        case levels(Int)
        case stats
        case settings
    }

    private struct Session: Identifiable {
        let id = UUID()
        let puzzle: Puzzle
        let index: Int
        let restore: SavedGame?
    }

    var body: some View {
        Group {
            if let session {
                GameView(
                    game: GameState(puzzle: session.puzzle, index: session.index, restoring: session.restore),
                    onExit: { self.session = nil },
                    onNext: nextPuzzle(after: session).map { next in
                        { self.session = Session(puzzle: next.0, index: next.1, restore: nil) }
                    }
                )
                .id(session.id)
            } else {
                switch route {
                case .home:
                    HomeView(
                        onPick: { route = .levels($0.n) },
                        onResume: resume,
                        onStats: { route = .stats },
                        onSettings: { route = .settings }
                    )
                case let .levels(sizeN):
                    LevelsView(
                        size: BoardSize.all.first { $0.n == sizeN } ?? .nine,
                        onBack: { route = .home },
                        onPlay: { puzzle, index in
                            session = Session(puzzle: puzzle, index: index, restore: nil)
                        }
                    )
                case .stats:
                    StatsView(onBack: { route = .home })
                case .settings:
                    SettingsView(onBack: { route = .home })
                }
            }
        }
        .environmentObject(settings)
        .environmentObject(progress)
        .environmentObject(library)
    }

    private func resume(_ saved: SavedGame) {
        guard let puzzle = library.puzzle(saved.size, saved.difficulty, saved.index) else {
            progress.dropSave()
            return
        }
        session = Session(puzzle: puzzle, index: saved.index, restore: saved)
    }

    private func nextPuzzle(after session: Session) -> (Puzzle, Int)? {
        let size = session.puzzle.size
        let difficulty = session.puzzle.difficulty
        let list = library.puzzles(size, difficulty)
        let next = session.index + 1
        guard list.indices.contains(next) else { return nil }
        return (list[next], next)
    }
}
