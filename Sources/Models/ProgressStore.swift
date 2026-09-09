import Foundation
import Combine

struct SavedGame: Codable {
    var sizeN: Int
    var difficulty: Difficulty
    var index: Int
    var cells: [Int]
    var notes: [[Int]]
    var seconds: Int
    var mistakes: Int
    var hintsUsed: Int
    var usedAnswer: Bool

    var size: BoardSize { BoardSize.all.first { $0.n == sizeN } ?? .nine }
}

struct LevelRecord: Codable {
    var seconds: Int
    var mistakes: Int
    var usedAnswer: Bool
    var finishedAt: Date
}

private struct ProgressData: Codable {
    var records: [String: LevelRecord] = [:]
    var dailyCounts: [String: Int] = [:]
    var saved: SavedGame?
}

@MainActor
final class ProgressStore: ObservableObject {
    @Published private var data = ProgressData()

    private let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("progress.json")
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() {
        load()
        #if DEBUG
        if CommandLine.arguments.contains("-demoProgress") { seedDemoProgress() }
        #endif
    }

    #if DEBUG
    /// 上架截图用的演示进度,只存在于 DEBUG 构建,不落盘。空进度的首页和统计页
    /// 拍出来全是 0,说明不了这个 app 在干什么。
    private func seedDemoProgress() {
        var fresh = ProgressData()
        let cal = Calendar.current
        let plan: [(BoardSize, Difficulty, Int)] = [
            (.four, .starter, 60), (.six, .starter, 60), (.six, .easy, 28),
            (.nine, .starter, 40), (.nine, .easy, 32), (.nine, .medium, 27),
        ]
        let now = Date()
        // 用真随机而不是 i 的取模:后者有周期性,「最近完成」会挤出一串连号的题
        var rng = SplitMix64(seed: 20_260_909)
        for (size, difficulty, count) in plan {
            for i in 0..<count {
                let ago = Double(rng.next() % 2_600_000)
                fresh.records[key(size, difficulty, i)] = LevelRecord(
                    seconds: 55 + Int(rng.next() % 545),
                    mistakes: rng.next() % 6 == 0 ? 1 : 0,
                    usedAnswer: rng.next() % 25 == 0,
                    finishedAt: now.addingTimeInterval(-ago)
                )
            }
        }
        for back in 0..<12 {
            guard let day = cal.date(byAdding: .day, value: -back, to: Date()) else { continue }
            fresh.dailyCounts[Self.dayFormatter.string(from: day)] = [3, 5, 2, 6, 4, 1, 3][back % 7]
        }
        data = fresh
    }
    #endif

    // MARK: - keys

    private func key(_ size: BoardSize, _ difficulty: Difficulty, _ index: Int) -> String {
        "\(size.n)-\(difficulty.rawValue)-\(index)"
    }

    // MARK: - queries

    func record(_ size: BoardSize, _ difficulty: Difficulty, _ index: Int) -> LevelRecord? {
        data.records[key(size, difficulty, index)]
    }

    func isDone(_ size: BoardSize, _ difficulty: Difficulty, _ index: Int) -> Bool {
        data.records[key(size, difficulty, index)] != nil
    }

    func completed(_ size: BoardSize, _ difficulty: Difficulty) -> Int {
        let prefix = "\(size.n)-\(difficulty.rawValue)-"
        return data.records.keys.reduce(0) { $1.hasPrefix(prefix) ? $0 + 1 : $0 }
    }

    func completed(_ size: BoardSize) -> Int {
        Difficulty.available(for: size).reduce(0) { $0 + completed(size, $1) }
    }

    var totalCompleted: Int { data.records.count }

    /// 第一个没做过的关,首页「继续」和选题页的当前关都指它。
    func nextIndex(_ size: BoardSize, _ difficulty: Difficulty, total: Int) -> Int {
        (0..<total).first { !isDone(size, difficulty, $0) } ?? max(total - 1, 0)
    }

    var savedGame: SavedGame? { data.saved }

    var accuracy: Int {
        guard !data.records.isEmpty else { return 100 }
        let clean = data.records.values.reduce(0) { $1.mistakes == 0 && !$1.usedAnswer ? $0 + 1 : $0 }
        return Int((Double(clean) / Double(data.records.count) * 100).rounded())
    }

    /// 从今天(或昨天,今天还没做也算连着)往回数连续有记录的天数。
    var streak: Int {
        let cal = Calendar.current
        var day = Date()
        if count(on: day) == 0 {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day),
                  count(on: yesterday) > 0 else { return 0 }
            day = yesterday
        }
        var n = 0
        while count(on: day) > 0 {
            n += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    func count(on date: Date) -> Int {
        data.dailyCounts[Self.dayFormatter.string(from: date)] ?? 0
    }

    var todayCount: Int { count(on: Date()) }

    func lastSevenDays() -> [(label: String, count: Int)] {
        let cal = Calendar.current
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        return (0..<7).reversed().compactMap { back in
            guard let day = cal.date(byAdding: .day, value: -back, to: Date()) else { return nil }
            let weekday = cal.component(.weekday, from: day) - 1
            return (names[weekday], count(on: day))
        }
    }

    func recentRecords(limit: Int = 3) -> [(key: String, record: LevelRecord)] {
        data.records.sorted { $0.value.finishedAt > $1.value.finishedAt }
            .prefix(limit)
            .map { (key: $0.key, record: $0.value) }
    }

    // MARK: - mutations

    func finish(_ game: GameState) {
        let k = key(game.size, game.puzzle.difficulty, game.index)
        let today = Self.dayFormatter.string(from: Date())
        if data.records[k] == nil { data.dailyCounts[today, default: 0] += 1 }
        data.records[k] = LevelRecord(
            seconds: game.seconds, mistakes: game.mistakes,
            usedAnswer: game.usedAnswer, finishedAt: Date()
        )
        data.saved = nil
        save()
    }

    func store(_ game: GameState) {
        data.saved = game.isComplete ? nil : game.snapshot
        save()
    }

    func dropSave() {
        data.saved = nil
        save()
    }

    func reset() {
        data = ProgressData()
        save()
    }

    // MARK: - disk

    private func load() {
        guard let raw = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ProgressData.self, from: raw) else { return }
        data = decoded
    }

    private func save() {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        try? raw.write(to: url, options: .atomic)
    }
}
