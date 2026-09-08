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

print("\n题库批量抽样(9×9 中等 × 10)")
let gen9 = Generator(.nine)
var clues: [Int] = []
var scores: [Int] = []
let batchStart = Date()
for _ in 0..<10 {
    guard let p = gen9.generate(target: .medium, using: &rng) else { continue }
    clues.append(p.clueCount)
    scores.append(p.score)
}
check(clues.count == 10, "10 题全部生成成功")
if !clues.isEmpty {
    let ms = Int(Date().timeIntervalSince(batchStart) * 1000)
    print("    提示数 \(clues.min()!)–\(clues.max()!) · 难度分 \(scores.min()!)–\(scores.max()!) · 共 \(ms)ms")
}

print("\n" + (failures == 0 ? "全部通过" : "\(failures) 项失败"))
exit(failures == 0 ? 0 : 1)
