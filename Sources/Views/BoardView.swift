import SwiftUI

struct BoardView: View {
    @ObservedObject var game: GameState
    let theme: Theme
    let colorful: Bool
    var showingAnswer = false
    var focus: Set<Int> = []

    private var n: Int { game.size.n }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = (side - 4) / CGFloat(n)
            ZStack {
                theme.cell
                VStack(spacing: 0) {
                    ForEach(0..<n, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(0..<n, id: \.self) { c in
                                let i = r * n + c
                                cellView(i, edge: cell)
                                    .frame(width: cell, height: cell)
                                    .contentShape(Rectangle())
                                    .onTapGesture { game.select(i) }
                                    .accessibilityIdentifier("cell-\(i)")
                            }
                        }
                    }
                }
                .padding(2)
                grid(side: side, cell: cell)
                    .allowsHitTesting(false)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: frameRadius, style: .continuous))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var frameRadius: CGFloat { theme.corner * 0.7 }

    private func grid(side: CGFloat, cell: CGFloat) -> some View {
        Canvas { ctx, _ in
            for i in 1..<n where i % game.size.boxCols != 0 {
                let x = 2 + cell * CGFloat(i)
                ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: side)) },
                           with: .color(theme.line), lineWidth: 1)
            }
            for i in 1..<n where i % game.size.boxRows != 0 {
                let y = 2 + cell * CGFloat(i)
                ctx.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: side, y: y)) },
                           with: .color(theme.line), lineWidth: 1)
            }
            for i in stride(from: game.size.boxCols, to: n, by: game.size.boxCols) {
                let x = 2 + cell * CGFloat(i)
                ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: side)) },
                           with: .color(theme.boxLine), lineWidth: 2)
            }
            for i in stride(from: game.size.boxRows, to: n, by: game.size.boxRows) {
                let y = 2 + cell * CGFloat(i)
                ctx.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: side, y: y)) },
                           with: .color(theme.boxLine), lineWidth: 2)
            }
            // 外框必须跟容器的 clipShape 用同一个圆角,画直角矩形的话四个角的描边会被裁掉
            let outline = RoundedRectangle(cornerRadius: frameRadius, style: .continuous)
            ctx.stroke(outline.path(in: CGRect(x: 1.5, y: 1.5, width: side - 3, height: side - 3)),
                       with: .color(theme.boxLine), lineWidth: 3)
        }
    }

    @ViewBuilder
    private func cellView(_ i: Int, edge: CGFloat) -> some View {
        let value = showingAnswer && game.cells[i] == 0 ? game.puzzle.solution[i] : game.cells[i]
        ZStack {
            background(i)
            if value != 0 {
                Text("\(value)")
                    .font(.system(size: edge * 0.56, weight: weight(i), design: theme.design))
                    .foregroundColor(color(i, value: value))
                    .overlay(alignment: .bottom) {
                        // 彩色数字开着时题面和填入没法再靠颜色分,用格底小圆点标出「这是我填的」
                        if colorful && !game.isGiven(i) && game.cells[i] != 0 {
                            Circle()
                                .fill(color(i, value: value).opacity(0.45))
                                .frame(width: edge * 0.11, height: edge * 0.11)
                                .padding(.bottom, edge * 0.07)
                        }
                    }
            } else if !game.notes[i].isEmpty {
                noteGrid(i, edge: edge)
            }
        }
    }

    @ViewBuilder
    private func background(_ i: Int) -> some View {
        if focus.contains(i) {
            theme.accent.opacity(0.22)
        } else if game.selected == i {
            theme.selection
        } else if let sel = game.selected, game.cells[sel] != 0, game.cells[i] == game.cells[sel] {
            theme.selection.opacity(0.55)
        } else if let sel = game.selected, game.isPeer(of: sel, i) {
            theme.peer
        } else {
            Color.clear
        }
    }

    private func noteGrid(_ i: Int, edge: CGFloat) -> some View {
        let cols = n <= 4 ? 2 : 3
        let rows = (n + cols - 1) / cols
        return VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<cols, id: \.self) { c in
                        let v = r * cols + c + 1
                        Text(v <= n && game.notes[i].contains(v) ? "\(v)" : " ")
                            .font(.system(size: edge * 0.24, weight: .semibold, design: theme.design))
                            .foregroundColor(colorful ? theme.digitColor(v).opacity(0.75) : theme.note)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(edge * 0.06)
    }

    private func weight(_ i: Int) -> Font.Weight {
        game.isGiven(i) ? (theme.isDark ? .heavy : .bold) : .semibold
    }

    private func color(_ i: Int, value: Int) -> Color {
        if showingAnswer && game.cells[i] == 0 { return theme.user.opacity(0.55) }
        if game.isWrong(i) || game.conflicts(i) { return Color(hex: 0xE5484D) }
        if colorful { return theme.digitColor(value) }
        return game.isGiven(i) ? theme.given : theme.user
    }
}
