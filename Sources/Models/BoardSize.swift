import Foundation

struct BoardSize: Equatable, Hashable, Codable {
    let boxRows: Int
    let boxCols: Int

    static let four = BoardSize(boxRows: 2, boxCols: 2)
    static let six = BoardSize(boxRows: 2, boxCols: 3)
    static let nine = BoardSize(boxRows: 3, boxCols: 3)

    static let all: [BoardSize] = [.four, .six, .nine]

    var n: Int { boxRows * boxCols }
    var cellCount: Int { n * n }
    var boxesPerRow: Int { n / boxCols }
    var fullMask: UInt16 { UInt16((1 << (n + 1)) - 2) }

    var label: String { "\(n)×\(n)" }

    func row(of i: Int) -> Int { i / n }
    func col(of i: Int) -> Int { i % n }
    func box(of i: Int) -> Int { (row(of: i) / boxRows) * boxesPerRow + col(of: i) / boxCols }
}

struct Geometry {
    let size: BoardSize
    let units: [[Int]]
    let unitsOfCell: [[Int]]
    let peers: [[Int]]
    let rowUnits: Range<Int>
    let colUnits: Range<Int>
    let boxUnits: Range<Int>

    init(_ size: BoardSize) {
        self.size = size
        let n = size.n
        var units: [[Int]] = []
        for r in 0..<n { units.append((0..<n).map { r * n + $0 }) }
        for c in 0..<n { units.append((0..<n).map { $0 * n + c }) }
        for b in 0..<n {
            let baseRow = (b / size.boxesPerRow) * size.boxRows
            let baseCol = (b % size.boxesPerRow) * size.boxCols
            var cells: [Int] = []
            for dr in 0..<size.boxRows {
                for dc in 0..<size.boxCols { cells.append((baseRow + dr) * n + baseCol + dc) }
            }
            units.append(cells)
        }
        self.units = units
        self.rowUnits = 0..<n
        self.colUnits = n..<(2 * n)
        self.boxUnits = (2 * n)..<(3 * n)

        var unitsOfCell = [[Int]](repeating: [], count: size.cellCount)
        for (ui, unit) in units.enumerated() {
            for cell in unit { unitsOfCell[cell].append(ui) }
        }
        self.unitsOfCell = unitsOfCell

        self.peers = (0..<size.cellCount).map { i in
            var set = Set<Int>()
            for ui in unitsOfCell[i] { set.formUnion(units[ui]) }
            set.remove(i)
            return Array(set)
        }
    }
}
