import Foundation

struct Puzzle: Codable {
    let size: BoardSize
    let givens: [Int]
    let solution: [Int]
    let difficulty: Difficulty
    let score: Int

    var clueCount: Int { givens.reduce(0) { $1 != 0 ? $0 + 1 : $0 } }

    var encoded: String {
        givens.map { $0 == 0 ? "." : String($0) }.joined()
    }
}

struct Generator {
    let size: BoardSize
    private let solver: Solver
    private let human: HumanSolver

    init(_ size: BoardSize) {
        self.size = size
        let geo = Geometry(size)
        self.solver = Solver(geometry: geo)
        self.human = HumanSolver(geometry: geo)
    }

    /// 挖到理论下限对人不友好:4×4 能挖到只剩 4 格,但那是给求解器看的,不是给孩子做的。
    func minClues(for target: Difficulty) -> Int {
        switch size.n {
        case 4: return 8
        case 6: return target == .starter ? 14 : 11
        default:
            switch target {
            case .starter: return 36
            case .easy: return 30
            case .medium: return 26
            case .hard: return 22
            }
        }
    }

    /// 一次尝试:随机完整解 → 中心对称挖洞(每挖一对都验唯一解) → 评级。
    /// 命中不了目标难度就返回 nil,由调用方重试——难档本来就要碰运气。
    func attempt(target: Difficulty, using rng: inout SplitMix64) -> Puzzle? {
        let solution = solver.randomSolution(using: &rng)
        guard !solution.contains(0) else { return nil }

        var grid = solution
        var clues = size.cellCount
        let floor = minClues(for: target)
        var order = Array(0..<size.cellCount)
        order.shuffle(using: &rng)

        for i in order {
            let mirror = size.cellCount - 1 - i
            guard grid[i] != 0 else { continue }
            let removing = i == mirror ? 1 : 2
            guard clues - removing >= floor else { continue }
            let saved = (grid[i], grid[mirror])
            grid[i] = 0
            grid[mirror] = 0
            if solver.hasUniqueSolution(grid) {
                clues -= removing
            } else {
                grid[i] = saved.0
                grid[mirror] = saved.1
            }
        }

        let rating = human.rate(grid)
        guard rating.solved, rating.difficulty == target else { return nil }
        return Puzzle(size: size, givens: grid, solution: solution,
                      difficulty: target, score: rating.score)
    }

    func generate(target: Difficulty, using rng: inout SplitMix64, maxAttempts: Int = 400) -> Puzzle? {
        for _ in 0..<maxAttempts {
            if let p = attempt(target: target, using: &rng) { return p }
        }
        return nil
    }

    /// 小盘只有入门/简单两档有意义——4×4 撑不起数对以上的技巧。
    var supportedDifficulties: [Difficulty] {
        switch size.n {
        case 4: return [.starter]
        case 6: return [.starter, .easy]
        default: return Difficulty.allCases
        }
    }
}
