import Foundation

var failures = 0

func check(_ condition: Bool, _ label: String) {
    print(condition ? "  ✓ \(label)" : "  ✗ \(label)")
    if !condition { failures += 1 }
}

func isValid(_ grid: [Int], _ size: BoardSize) -> Bool {
    let geo = Geometry(size)
    for unit in geo.units {
        let values = unit.map { grid[$0] }
        if values.contains(0) { return false }
        if Set(values).count != size.n { return false }
    }
    return true
}

@MainActor
func runSmoke() {
    print("几何")
    for size in BoardSize.all {
        let geo = Geometry(size)
        check(geo.units.count == 3 * size.n, "\(size.label) 共 \(3 * size.n) 个 unit")
        check(geo.units.allSatisfy { $0.count == size.n }, "\(size.label) 每个 unit \(size.n) 格")
        let expectedPeers = 2 * (size.n - 1) + (size.boxRows * size.boxCols - 1)
            - (size.boxRows - 1) - (size.boxCols - 1)
        check(geo.peers.allSatisfy { $0.count == expectedPeers }, "\(size.label) 每格 \(expectedPeers) 个关联格")
    }

    print("\n求解器")
    let classic = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    let classicSolution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
    let grid9 = classic.map { Int(String($0))! }
    let solver9 = Solver(.nine)
    let solved = solver9.solutions(of: grid9, limit: 2)
    check(solved.count == 1, "经典 30 提示题只有一个解")
    check(solved.first.map { $0.map(String.init).joined() } == classicSolution, "解跟已知答案一致")

    var emptyBoard = [Int](repeating: 0, count: 81)
    check(solver9.solutions(of: emptyBoard, limit: 2).count == 2, "空盘能提前在第 2 个解收手")
    emptyBoard[0] = 5
    emptyBoard[1] = 5
    check(solver9.solutions(of: emptyBoard, limit: 1).isEmpty, "同行重复的盘面判为无解")

    print("\n随机完整解")
    var rng = SplitMix64(seed: 20260908)
    for size in BoardSize.all {
        let s = Solver(size)
        var ok = true
        for _ in 0..<20 where !isValid(s.randomSolution(using: &rng), size) { ok = false }
        check(ok, "\(size.label) 连出 20 个合法完整解")
    }

    print("\n人类技巧评级")
    let human9 = HumanSolver(.nine)
    let rating = human9.rate(grid9)
    check(rating.solved, "经典题能纯靠技巧解出,不用猜")
    if let d = rating.difficulty {
        print("    最难技巧 \(rating.hardest!.name) · 难度 \(d.label) · 总分 \(rating.score)")
    }
    if let step = human9.nextStep(human9.makeWork(grid9)) {
        print("    第一步提示:\(step.detail)")
    }

    print("\n生成器")
    for size in BoardSize.all {
        let gen = Generator(size)
        for target in gen.supportedDifficulties {
            let started = Date()
            guard let p = gen.generate(target: target, using: &rng) else {
                check(false, "\(size.label) \(target.label) 生成失败")
                continue
            }
            let unique = Solver(size).hasUniqueSolution(p.givens)
            let matches = zip(p.givens, p.solution).allSatisfy { $0 == 0 || $0 == $1 }
            let ms = Int(Date().timeIntervalSince(started) * 1000)
            check(unique && matches && isValid(p.solution, size),
                  "\(size.label) \(target.label) · \(p.clueCount) 提示 · 分 \(p.score) · \(ms)ms")
        }
    }

    print("\n题库编解码")
    let gen = Generator(.nine)
    if let p = gen.generate(target: .easy, using: &rng) {
        let line = PuzzleBank.encode(p)
        if let back = PuzzleBank.decode(line, size: .nine, difficulty: .easy) {
            check(back.givens == p.givens && back.solution == p.solution && back.score == p.score,
                  "一行文本编码后解回来完全一致")
        } else {
            check(false, "解码失败")
        }
    }

    print("\n对局反馈事件")
    let gen4 = Generator(.four)
    var frng = SplitMix64(seed: 7)
    if let p = gen4.generate(target: .starter, using: &frng) {
        let game = GameState(puzzle: p, index: 0)
        let blank = p.givens.firstIndex(of: 0)!
        game.select(blank)
        let wrongValue = (1...4).first { $0 != p.solution[blank] }!
        check(game.input(wrongValue) == .wrong, "填错返回 wrong")
        check(game.mistakes == 1, "错误计数 +1")
        check(game.input(p.solution[blank]) != .wrong, "改对之后不再报 wrong")

        var seen: [GameState.Feedback] = []
        for i in 0..<p.size.cellCount where game.cells[i] == 0 {
            game.select(i)
            if let f = game.input(p.solution[i]) { seen.append(f) }
        }
        check(seen.contains(.unitDone), "填满一行/列/宫时给 unitDone")
        check(seen.last == .win, "填完最后一格给 win")
        check(game.isComplete, "标记为完成")
        if case .none = game.hint() {
            check(true, "填完之后再点提示,返回 none 不崩")
        } else {
            check(false, "填完之后提示应该返回 none")
        }
    }

    print("\n" + (failures == 0 ? "全部通过" : "\(failures) 项失败"))
}

func runBank(_ outDir: String) {
    // 小盘的技巧梯度撑不开难度,靠逐段收紧提示数造出关卡递进感;9×9 交给评级器自己分。
    let plan: [(BoardSize, Difficulty, [(Int, Int?)])] = [
        (.four, .starter, [(20, 8), (20, 7), (20, 6)]),
        (.six, .starter, [(30, 16), (30, 13)]),
        (.six, .easy, [(60, nil)]),
        (.nine, .starter, [(75, nil)]),
        (.nine, .easy, [(75, nil)]),
        (.nine, .medium, [(75, nil)]),
        (.nine, .hard, [(75, nil)]),
    ]
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

    for (size, difficulty, segments) in plan {
        let started = Date()
        let gen = Generator(size)
        // 固定 seed:题库要可复现,换机器重跑得到同一批题。
        var rng = SplitMix64(seed: UInt64(size.n) &* 1_000_003 &+ UInt64(difficulty.rawValue.count &* 7919))
        var seen = Set<String>()
        var lines: [String] = []
        for (count, floor) in segments {
            var made = 0
            var guardCount = 0
            while made < count && guardCount < count * 80 {
                guardCount += 1
                guard let p = gen.generate(target: difficulty, using: &rng,
                                           maxAttempts: 60, clueFloor: floor) else { continue }
                if seen.insert(p.encoded).inserted {
                    lines.append(PuzzleBank.encode(p))
                    made += 1
                }
            }
        }
        lines.sort { Int($0.split(separator: "|")[2])! < Int($1.split(separator: "|")[2])! }
        let name = PuzzleBank.fileName(size: size, difficulty: difficulty)
        let path = "\(outDir)/\(name).txt"
        try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
        let scores = lines.compactMap { Int($0.split(separator: "|")[2]) }
        let secs = String(format: "%.1f", Date().timeIntervalSince(started))
        print("\(name).txt  \(lines.count) 题 · 难度分 \(scores.min() ?? 0)–\(scores.max() ?? 0) · \(secs)s")
    }
}

let args = CommandLine.arguments
if args.count > 1 && args[1] == "bank" {
    runBank(args.count > 2 ? args[2] : "./Banks")
} else {
    // 命令行的顶层代码不在 main actor 上,而 GameState 是 @MainActor;主线程本来就是它的执行线程
    MainActor.assumeIsolated { runSmoke() }
    exit(failures == 0 ? 0 : 1)
}
