import Foundation

/// 位掩码约束传播 + MRV 回溯。9×9 单题在 iPhone 上是微秒级,不需要 DLX。
struct Solver {
    let geo: Geometry
    var size: BoardSize { geo.size }

    init(_ size: BoardSize) { self.geo = Geometry(size) }
    init(geometry: Geometry) { self.geo = geometry }

    struct State {
        var cells: [Int]
        var rowMask: [UInt16]
        var colMask: [UInt16]
        var boxMask: [UInt16]
        var empties: Int
    }

    func makeState(_ grid: [Int]) -> State? {
        let n = size.n
        var s = State(
            cells: grid,
            rowMask: [UInt16](repeating: 0, count: n),
            colMask: [UInt16](repeating: 0, count: n),
            boxMask: [UInt16](repeating: 0, count: n),
            empties: grid.reduce(0) { $1 == 0 ? $0 + 1 : $0 }
        )
        for i in 0..<size.cellCount where grid[i] != 0 {
            let bit = UInt16(1) << grid[i]
            let r = size.row(of: i), c = size.col(of: i), b = size.box(of: i)
            if s.rowMask[r] & bit != 0 || s.colMask[c] & bit != 0 || s.boxMask[b] & bit != 0 { return nil }
            s.rowMask[r] |= bit
            s.colMask[c] |= bit
            s.boxMask[b] |= bit
        }
        return s
    }

    func candidates(_ s: State, _ i: Int) -> UInt16 {
        size.fullMask & ~(s.rowMask[size.row(of: i)] | s.colMask[size.col(of: i)] | s.boxMask[size.box(of: i)])
    }

    func place(_ s: inout State, _ i: Int, _ v: Int) {
        let bit = UInt16(1) << v
        s.cells[i] = v
        s.rowMask[size.row(of: i)] |= bit
        s.colMask[size.col(of: i)] |= bit
        s.boxMask[size.box(of: i)] |= bit
        s.empties -= 1
    }

    private func propagate(_ s: inout State) -> Bool {
        var progressed = true
        while progressed {
            progressed = false
            for i in 0..<size.cellCount where s.cells[i] == 0 {
                let cand = candidates(s, i)
                if cand == 0 { return false }
                if cand.nonzeroBitCount == 1 {
                    place(&s, i, cand.trailingZeroBitCount)
                    progressed = true
                }
            }
            for unit in geo.units {
                for v in 1...size.n {
                    let bit = UInt16(1) << v
                    var spot = -1
                    var count = 0
                    var taken = false
                    for cell in unit {
                        if s.cells[cell] == v { taken = true; break }
                        if s.cells[cell] == 0 && candidates(s, cell) & bit != 0 {
                            spot = cell
                            count += 1
                            if count > 1 { break }
                        }
                    }
                    if taken { continue }
                    if count == 0 { return false }
                    if count == 1 {
                        place(&s, spot, v)
                        progressed = true
                    }
                }
            }
        }
        return true
    }

    /// limit 是提前收手的解数上限——验唯一解时传 2 就够,不用把所有解都跑出来。
    func solutions(of grid: [Int], limit: Int = 1) -> [[Int]] {
        guard var s = makeState(grid) else { return [] }
        var found: [[Int]] = []
        search(&s, limit: limit, found: &found)
        return found
    }

    func hasUniqueSolution(_ grid: [Int]) -> Bool {
        solutions(of: grid, limit: 2).count == 1
    }

    private func search(_ s: inout State, limit: Int, found: inout [[Int]]) {
        guard propagate(&s) else { return }
        if s.empties == 0 {
            found.append(s.cells)
            return
        }
        var best = -1
        var bestCand: UInt16 = 0
        var bestCount = Int.max
        for i in 0..<size.cellCount where s.cells[i] == 0 {
            let cand = candidates(s, i)
            let count = cand.nonzeroBitCount
            if count < bestCount {
                best = i
                bestCand = cand
                bestCount = count
                if count == 2 { break }
            }
        }
        var rest = bestCand
        while rest != 0 {
            let v = rest.trailingZeroBitCount
            rest &= rest - 1
            var next = s
            place(&next, best, v)
            search(&next, limit: limit, found: &found)
            if found.count >= limit { return }
        }
    }

    func randomSolution(using rng: inout SplitMix64) -> [Int] {
        var grid = [Int](repeating: 0, count: size.cellCount)
        _ = fill(&grid, using: &rng)
        return grid
    }

    private func fill(_ grid: inout [Int], using rng: inout SplitMix64) -> Bool {
        guard var s = makeState(grid) else { return false }
        guard propagate(&s) else { return false }
        if s.empties == 0 {
            grid = s.cells
            return true
        }
        var best = -1
        var bestCount = Int.max
        for i in 0..<size.cellCount where s.cells[i] == 0 {
            let count = candidates(s, i).nonzeroBitCount
            if count < bestCount { best = i; bestCount = count }
        }
        var values: [Int] = []
        var rest = candidates(s, best)
        while rest != 0 {
            values.append(rest.trailingZeroBitCount)
            rest &= rest - 1
        }
        values.shuffle(using: &rng)
        for v in values {
            var next = s.cells
            next[best] = v
            if fill(&next, using: &rng) {
                grid = next
                return true
            }
        }
        return false
    }
}

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
