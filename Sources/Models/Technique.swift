import Foundation

enum Technique: Int, CaseIterable, Comparable, Codable {
    case nakedSingle
    case hiddenSingle
    case lockedCandidates
    case nakedPair
    case hiddenPair
    case nakedTriple
    case xWing

    static func < (a: Technique, b: Technique) -> Bool { a.rawValue < b.rawValue }

    var name: String {
        switch self {
        case .nakedSingle: return "唯一候选"
        case .hiddenSingle: return "隐性唯一"
        case .lockedCandidates: return "区块摒除"
        case .nakedPair: return "显性数对"
        case .hiddenPair: return "隐性数对"
        case .nakedTriple: return "显性三链"
        case .xWing: return "矩形对角线"
        }
    }

    /// 同一档里再按总工作量排序,避免「用一次 X-Wing」和「用五次」都叫困难。
    var cost: Int {
        switch self {
        case .nakedSingle: return 1
        case .hiddenSingle: return 2
        case .lockedCandidates: return 5
        case .nakedPair: return 8
        case .hiddenPair: return 10
        case .nakedTriple: return 14
        case .xWing: return 20
        }
    }
}

enum Difficulty: String, CaseIterable, Codable {
    case starter
    case easy
    case medium
    case hard

    var label: String {
        switch self {
        case .starter: return "入门"
        case .easy: return "简单"
        case .medium: return "中等"
        case .hard: return "困难"
        }
    }

    static func of(hardest: Technique) -> Difficulty {
        switch hardest {
        case .nakedSingle, .hiddenSingle: return .starter
        case .lockedCandidates: return .easy
        case .nakedPair, .hiddenPair: return .medium
        case .nakedTriple, .xWing: return .hard
        }
    }
}

struct Deduction {
    let technique: Technique
    let placement: (cell: Int, value: Int)?
    let eliminations: [(cell: Int, value: Int)]
    let focus: [Int]
    let detail: String
}

struct Rating {
    let solved: Bool
    let hardest: Technique?
    let score: Int
    let counts: [Technique: Int]

    var difficulty: Difficulty? {
        guard solved, let hardest else { return nil }
        return .of(hardest: hardest)
    }
}

/// 只用人类技巧推,不回溯猜。既用来给谜题定难度,也用来出提示——一份代码两用。
struct HumanSolver {
    let geo: Geometry
    var size: BoardSize { geo.size }

    init(_ size: BoardSize) { self.geo = Geometry(size) }
    init(geometry: Geometry) { self.geo = geometry }

    struct Work {
        var cells: [Int]
        var cand: [UInt16]
    }

    func makeWork(_ grid: [Int]) -> Work {
        var w = Work(cells: grid, cand: [UInt16](repeating: 0, count: size.cellCount))
        for i in 0..<size.cellCount where grid[i] == 0 {
            var mask = size.fullMask
            for p in geo.peers[i] where grid[p] != 0 { mask &= ~(UInt16(1) << grid[p]) }
            w.cand[i] = mask
        }
        return w
    }

    func apply(_ d: Deduction, to w: inout Work) {
        if let p = d.placement {
            w.cells[p.cell] = p.value
            w.cand[p.cell] = 0
            for peer in geo.peers[p.cell] { w.cand[peer] &= ~(UInt16(1) << p.value) }
        }
        for e in d.eliminations { w.cand[e.cell] &= ~(UInt16(1) << e.value) }
    }

    func nextStep(_ w: Work) -> Deduction? {
        for finder in [findNakedSingle, findHiddenSingle, findLockedCandidates,
                       findNakedPair, findHiddenPair, findNakedTriple, findXWing] {
            if let d = finder(w) { return d }
        }
        return nil
    }

    func rate(_ grid: [Int]) -> Rating {
        var w = makeWork(grid)
        var counts: [Technique: Int] = [:]
        var score = 0
        var hardest: Technique?
        while w.cells.contains(0) {
            guard let d = nextStep(w) else {
                return Rating(solved: false, hardest: hardest, score: score, counts: counts)
            }
            counts[d.technique, default: 0] += 1
            score += d.technique.cost
            if hardest == nil || d.technique > hardest! { hardest = d.technique }
            apply(d, to: &w)
        }
        return Rating(solved: true, hardest: hardest, score: score, counts: counts)
    }

    // MARK: - techniques

    private func findNakedSingle(_ w: Work) -> Deduction? {
        for i in 0..<size.cellCount where w.cells[i] == 0 && w.cand[i].nonzeroBitCount == 1 {
            let v = w.cand[i].trailingZeroBitCount
            return Deduction(
                technique: .nakedSingle, placement: (cell: i, value: v), eliminations: [], focus: [i],
                detail: "\(coord(i)) 所在的行、列、宫合起来排掉了其余数字，只剩 \(v)"
            )
        }
        return nil
    }

    private func findHiddenSingle(_ w: Work) -> Deduction? {
        for (ui, unit) in geo.units.enumerated() {
            for v in 1...size.n {
                let bit = UInt16(1) << v
                if unit.contains(where: { w.cells[$0] == v }) { continue }
                var spot = -1
                var count = 0
                for cell in unit where w.cells[cell] == 0 && w.cand[cell] & bit != 0 {
                    spot = cell
                    count += 1
                    if count > 1 { break }
                }
                if count == 1 {
                    return Deduction(
                        technique: .hiddenSingle, placement: (cell: spot, value: v), eliminations: [], focus: unit,
                        detail: "\(unitName(ui))里只有 \(coord(spot)) 能放 \(v)"
                    )
                }
            }
        }
        return nil
    }

    private func findLockedCandidates(_ w: Work) -> Deduction? {
        for v in 1...size.n {
            let bit = UInt16(1) << v
            for b in geo.boxUnits {
                let spots = geo.units[b].filter { w.cells[$0] == 0 && w.cand[$0] & bit != 0 }
                guard spots.count >= 2 else { continue }
                for (axis, keyPath) in [("行", size.row(of:)), ("列", size.col(of:))] {
                    let line = keyPath(spots[0])
                    guard spots.allSatisfy({ keyPath($0) == line }) else { continue }
                    let lineUnit = axis == "行" ? geo.units[line] : geo.units[size.n + line]
                    let kills = lineUnit.filter {
                        !spots.contains($0) && w.cells[$0] == 0 && w.cand[$0] & bit != 0
                    }
                    if !kills.isEmpty {
                        return Deduction(
                            technique: .lockedCandidates, placement: nil,
                            eliminations: kills.map { (cell: $0, value: v) }, focus: spots,
                            detail: "这一宫的 \(v) 只可能落在同一\(axis)上，这\(axis)其他格就不用再考虑 \(v)"
                        )
                    }
                }
            }
            for li in geo.rowUnits.lowerBound..<geo.boxUnits.lowerBound {
                let spots = geo.units[li].filter { w.cells[$0] == 0 && w.cand[$0] & bit != 0 }
                guard spots.count >= 2 else { continue }
                let b = size.box(of: spots[0])
                guard spots.allSatisfy({ size.box(of: $0) == b }) else { continue }
                let kills = geo.units[2 * size.n + b].filter {
                    !spots.contains($0) && w.cells[$0] == 0 && w.cand[$0] & bit != 0
                }
                if !kills.isEmpty {
                    return Deduction(
                        technique: .lockedCandidates, placement: nil,
                        eliminations: kills.map { (cell: $0, value: v) }, focus: spots,
                        detail: "\(unitName(li))的 \(v) 只可能落在同一宫里，这一宫其他格就不用再考虑 \(v)"
                    )
                }
            }
        }
        return nil
    }

    private func findNakedPair(_ w: Work) -> Deduction? {
        for (ui, unit) in geo.units.enumerated() {
            let open = unit.filter { w.cells[$0] == 0 && w.cand[$0].nonzeroBitCount == 2 }
            guard open.count >= 2 else { continue }
            for a in 0..<(open.count - 1) {
                for b in (a + 1)..<open.count where w.cand[open[a]] == w.cand[open[b]] {
                    let mask = w.cand[open[a]]
                    var kills: [(cell: Int, value: Int)] = []
                    for cell in unit where cell != open[a] && cell != open[b] && w.cells[cell] == 0 {
                        var rest = w.cand[cell] & mask
                        while rest != 0 {
                            kills.append((cell: cell, value: rest.trailingZeroBitCount))
                            rest &= rest - 1
                        }
                    }
                    if !kills.isEmpty {
                        return Deduction(
                            technique: .nakedPair, placement: nil, eliminations: kills,
                            focus: [open[a], open[b]],
                            detail: "\(unitName(ui))里 \(coord(open[a])) 和 \(coord(open[b])) 只能填 \(digits(mask))，这两个数被它们占了"
                        )
                    }
                }
            }
        }
        return nil
    }

    private func findHiddenPair(_ w: Work) -> Deduction? {
        for (ui, unit) in geo.units.enumerated() {
            let open = unit.filter { w.cells[$0] == 0 }
            guard open.count > 2 else { continue }
            var spots: [Int: [Int]] = [:]
            for v in 1...size.n {
                let bit = UInt16(1) << v
                let s = open.filter { w.cand[$0] & bit != 0 }
                if s.count == 2 { spots[v] = s }
            }
            let values = spots.keys.sorted()
            guard values.count >= 2 else { continue }
            for a in 0..<(values.count - 1) {
                for b in (a + 1)..<values.count where spots[values[a]]! == spots[values[b]]! {
                    let cells = spots[values[a]]!
                    let keep = (UInt16(1) << values[a]) | (UInt16(1) << values[b])
                    var kills: [(cell: Int, value: Int)] = []
                    for cell in cells {
                        var rest = w.cand[cell] & ~keep
                        while rest != 0 {
                            kills.append((cell: cell, value: rest.trailingZeroBitCount))
                            rest &= rest - 1
                        }
                    }
                    if !kills.isEmpty {
                        return Deduction(
                            technique: .hiddenPair, placement: nil, eliminations: kills, focus: cells,
                            detail: "\(unitName(ui))里 \(values[a]) 和 \(values[b]) 都只能落在 \(coord(cells[0]))、\(coord(cells[1]))，这两格就只剩这两个数"
                        )
                    }
                }
            }
        }
        return nil
    }

    private func findNakedTriple(_ w: Work) -> Deduction? {
        for (ui, unit) in geo.units.enumerated() {
            let open = unit.filter { w.cells[$0] == 0 && (2...3).contains(w.cand[$0].nonzeroBitCount) }
            guard open.count >= 3 else { continue }
            for a in 0..<(open.count - 2) {
                for b in (a + 1)..<(open.count - 1) {
                    for c in (b + 1)..<open.count {
                        let mask = w.cand[open[a]] | w.cand[open[b]] | w.cand[open[c]]
                        guard mask.nonzeroBitCount == 3 else { continue }
                        let trio = [open[a], open[b], open[c]]
                        var kills: [(cell: Int, value: Int)] = []
                        for cell in unit where !trio.contains(cell) && w.cells[cell] == 0 {
                            var rest = w.cand[cell] & mask
                            while rest != 0 {
                                kills.append((cell: cell, value: rest.trailingZeroBitCount))
                                rest &= rest - 1
                            }
                        }
                        if !kills.isEmpty {
                            return Deduction(
                                technique: .nakedTriple, placement: nil, eliminations: kills, focus: trio,
                                detail: "\(unitName(ui))里这三格合起来只能填 \(digits(mask))，其他格就轮不到这三个数"
                            )
                        }
                    }
                }
            }
        }
        return nil
    }

    private func findXWing(_ w: Work) -> Deduction? {
        for v in 1...size.n {
            let bit = UInt16(1) << v
            for byRow in [true, false] {
                var lines: [Int: [Int]] = [:]
                for li in 0..<size.n {
                    let unit = geo.units[byRow ? li : size.n + li]
                    let spots = unit.filter { w.cells[$0] == 0 && w.cand[$0] & bit != 0 }
                    if spots.count == 2 { lines[li] = spots }
                }
                let keys = lines.keys.sorted()
                guard keys.count >= 2 else { continue }
                for a in 0..<(keys.count - 1) {
                    for b in (a + 1)..<keys.count {
                        let s1 = lines[keys[a]]!, s2 = lines[keys[b]]!
                        let cross1 = s1.map { byRow ? size.col(of: $0) : size.row(of: $0) }
                        let cross2 = s2.map { byRow ? size.col(of: $0) : size.row(of: $0) }
                        guard cross1 == cross2 else { continue }
                        var kills: [(cell: Int, value: Int)] = []
                        for x in cross1 {
                            let unit = geo.units[byRow ? size.n + x : x]
                            for cell in unit where w.cells[cell] == 0 && w.cand[cell] & bit != 0
                                && !s1.contains(cell) && !s2.contains(cell) {
                                kills.append((cell: cell, value: v))
                            }
                        }
                        if !kills.isEmpty {
                            return Deduction(
                                technique: .xWing, placement: nil, eliminations: kills, focus: s1 + s2,
                                detail: "\(v) 在两\(byRow ? "行" : "列")里都只剩相同的两个位置，四个角连成矩形，另外两\(byRow ? "列" : "行")上的 \(v) 全部排除"
                            )
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - text

    func coord(_ i: Int) -> String { "R\(size.row(of: i) + 1)C\(size.col(of: i) + 1)" }

    func unitName(_ ui: Int) -> String {
        if geo.rowUnits.contains(ui) { return "第 \(ui + 1) 行" }
        if geo.colUnits.contains(ui) { return "第 \(ui - size.n + 1) 列" }
        return "第 \(ui - 2 * size.n + 1) 宫"
    }

    private func digits(_ mask: UInt16) -> String {
        var out: [String] = []
        var rest = mask
        while rest != 0 {
            out.append(String(rest.trailingZeroBitCount))
            rest &= rest - 1
        }
        return out.joined(separator: "、")
    }
}
