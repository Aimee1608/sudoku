import Foundation

/// 题库是离线生成好打包进 app 的:难档一题要碰几十次运气,不能让用户点「新游戏」时干等。
/// 一行一题 `givens|solution|score`,空格写成点。
enum PuzzleBank {
    static func fileName(size: BoardSize, difficulty: Difficulty) -> String {
        "bank-\(size.n)-\(difficulty.rawValue)"
    }

    static func encode(_ p: Puzzle) -> String {
        let givens = p.givens.map { $0 == 0 ? "." : String($0) }.joined()
        let solution = p.solution.map(String.init).joined()
        return "\(givens)|\(solution)|\(p.score)"
    }

    static func decode(_ line: String, size: BoardSize, difficulty: Difficulty) -> Puzzle? {
        let parts = line.split(separator: "|")
        guard parts.count == 3,
              parts[0].count == size.cellCount,
              parts[1].count == size.cellCount,
              let score = Int(parts[2]) else { return nil }
        let givens = parts[0].map { $0 == "." ? 0 : Int(String($0)) ?? 0 }
        let solution = parts[1].map { Int(String($0)) ?? 0 }
        guard !solution.contains(0) else { return nil }
        return Puzzle(size: size, givens: givens, solution: solution,
                      difficulty: difficulty, score: score)
    }

    /// 题库文件按难度分升序存,序号就是关卡号——第 1 关一定比第 75 关轻松。
    static func load(size: BoardSize, difficulty: Difficulty, bundle: Bundle = .main) -> [Puzzle] {
        let name = fileName(size: size, difficulty: difficulty)
        guard let url = bundle.url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap {
            decode(String($0), size: size, difficulty: difficulty)
        }
    }
}

extension Difficulty {
    static func available(for size: BoardSize) -> [Difficulty] {
        switch size.n {
        case 4: return [.starter]
        case 6: return [.starter, .easy]
        default: return Difficulty.allCases
        }
    }
}
