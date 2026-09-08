import SwiftUI

struct GameView: View {
    @StateObject var game: GameState
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var progress: ProgressStore
    @Environment(\.colorScheme) private var scheme

    let onExit: () -> Void
    let onNext: (() -> Void)?

    @State private var hintText: String?
    @State private var hintFocus: Set<Int> = []
    @State private var showingAnswer = false
    @State private var askAnswer = false

    private var theme: Theme { settings.theme(for: scheme) }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack(spacing: 12) {
                header
                statusRow
                BoardView(game: game, theme: theme, colorful: settings.colorfulDigits,
                          showingAnswer: showingAnswer, focus: hintFocus)
                    .padding(.horizontal, 2)
                hintBar
                tools
                NumberPad(game: game, theme: theme, colorful: settings.colorfulDigits) { value in
                    Haptics.tap(settings.hapticsEnabled)
                    game.input(value)
                    clearHint()
                    if game.isComplete {
                        Haptics.win(settings.hapticsEnabled)
                        progress.finish(game)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: 560)

            if game.isComplete { completionOverlay }
        }
        .alert("看参考答案？", isPresented: $askAnswer) {
            Button("取消", role: .cancel) {}
            Button("看答案") {
                showingAnswer = true
                game.revealAnswer()
            }
        } message: {
            Text("这题会标成「看过答案」，但仍然计入你做过的题目，记录不会被清空。")
        }
        .onDisappear {
            game.stopTicking()
            progress.store(game)
        }
    }

    private var header: some View {
        HStack {
            Button {
                progress.store(game)
                onExit()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.accent)
                    .frame(width: 36, height: 36)
            }
            .accessibilityIdentifier("back")
            Spacer()
            Text("\(game.size.label) 第 \(game.index + 1) 题")
                .font(.system(size: 16, weight: .semibold, design: theme.design))
                .foregroundColor(theme.ink)
            Spacer()
            Text(game.puzzle.difficulty.label)
                .font(.system(size: 12, weight: .semibold, design: theme.design))
                .foregroundColor(theme.accent)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(theme.soft, in: Capsule())
                .frame(minWidth: 36, alignment: .trailing)
        }
    }

    private var statusRow: some View {
        HStack {
            Text("用时 \(formatTime(game.seconds))")
            Spacer()
            Text("错 \(game.mistakes) · 提示 \(game.hintsUsed)")
        }
        .font(.system(size: 13, weight: .medium, design: theme.design))
        .foregroundColor(theme.muted)
        .monospacedDigit()
    }

    /// 一直占位,不然提示出现/消失时整个盘面会跳一下。
    private var hintBar: some View {
        Text(hintText ?? "卡住了就点提示，它会告诉你下一格怎么想。")
            .font(.system(size: 13, design: theme.design))
            .foregroundColor(hintText == nil ? theme.muted : theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(minHeight: 54, alignment: .center)
            .background(hintText == nil ? Color.clear : theme.soft)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(hintText == nil ? Color.clear : theme.accent)
                    .frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
    }

    private var tools: some View {
        HStack(spacing: 8) {
            toolButton("撤销", "arrow.uturn.backward", enabled: game.canUndo) {
                game.undo()
                clearHint()
            }
            toolButton("笔记", "pencil", active: game.noteMode) {
                game.noteMode.toggle()
            }
            toolButton("擦除", "eraser", enabled: game.selected != nil) {
                game.erase()
                clearHint()
            }
            toolButton("提示", "lightbulb", enabled: !game.isComplete) { requestHint() }
            toolButton("答案", "checkmark.seal", active: showingAnswer) {
                if showingAnswer { showingAnswer = false } else { askAnswer = true }
            }
        }
    }

    private func toolButton(_ title: String, _ icon: String, enabled: Bool = true,
                            active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.tap(settings.hapticsEnabled)
            action()
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 15, weight: .medium))
                Text(title).font(.system(size: 10, weight: .semibold, design: theme.design))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(active ? theme.accent : theme.panel)
            .foregroundColor(active ? theme.onAccent : (enabled ? theme.muted : theme.muted.opacity(0.4)))
            .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
        }
        .disabled(!enabled)
        .accessibilityIdentifier("tool-\(title)")
    }

    private func requestHint() {
        withAnimation(.easeOut(duration: 0.2)) {
            switch game.hint() {
            case let .fixMistake(cell):
                hintFocus = [cell]
                hintText = smallBoard
                    ? "这一格填的数字不对，先把它改掉，再往下想。"
                    : "\(cellName(cell)) 填的数字跟答案对不上，先改掉它再继续。"
            case let .step(deduction):
                hintFocus = Set(deduction.focus)
                hintText = phrase(deduction)
            case .none:
                hintFocus = []
                hintText = "这一步要用到更难的技巧，可以看看参考答案里的解法。"
            }
        }
    }

    private func clearHint() {
        guard hintText != nil else { return }
        hintText = nil
        hintFocus = []
    }

    /// 小盘是给孩子做的,提示要问出来而不是讲技巧;9×9 直接用评级器写好的技巧陈述。
    private var smallBoard: Bool { game.size.n <= 6 }

    private func phrase(_ d: Deduction) -> String {
        guard smallBoard, let placement = d.placement else { return d.detail }
        let taken = neighbourValues(of: placement.cell)
        if taken.isEmpty { return d.detail }
        let list = taken.map(String.init).joined(separator: "、")
        return "这一格的同一行、同一列和同一个小方块里，已经有 \(list) 了，想想还剩谁？"
    }

    private func neighbourValues(of cell: Int) -> [Int] {
        let geo = Geometry(game.size)
        return Set(geo.peers[cell].map { game.cells[$0] }).filter { $0 != 0 }.sorted()
    }

    private func cellName(_ i: Int) -> String {
        "R\(i / game.size.n + 1)C\(i % game.size.n + 1)"
    }

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("完成！")
                    .font(.system(size: 26, weight: .bold, design: theme.design))
                    .foregroundColor(theme.ink)
                HStack(spacing: 22) {
                    stat("用时", formatTime(game.seconds))
                    stat("错误", "\(game.mistakes)")
                    stat("提示", "\(game.hintsUsed)")
                }
                HStack(spacing: 10) {
                    Button("回选题") { onExit() }
                        .buttonStyle(FilledButton(theme: theme, filled: false))
                    if let onNext {
                        Button("下一题") { onNext() }
                            .buttonStyle(FilledButton(theme: theme, filled: true))
                    }
                }
                .padding(.top, 4)
            }
            .padding(26)
            .background(theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: theme.corner * 1.4, style: .continuous))
            .padding(36)
        }
        .transition(.opacity)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: theme.design))
                .foregroundColor(theme.accent)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11, design: theme.design))
                .foregroundColor(theme.muted)
        }
    }
}

struct NumberPad: View {
    @ObservedObject var game: GameState
    let theme: Theme
    let colorful: Bool
    let onTap: (Int) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...game.size.n, id: \.self) { value in
                let left = game.remaining(value)
                Button { onTap(value) } label: {
                    VStack(spacing: 1) {
                        Text("\(value)")
                            .font(.system(size: game.size.n <= 4 ? 30 : 22,
                                          weight: .bold, design: theme.design))
                            .foregroundColor(colorful ? theme.digitColor(value) : theme.ink)
                        if game.size.n > 4 {
                            Text("\(max(left, 0))")
                                .font(.system(size: 9, weight: .medium, design: theme.design))
                                .foregroundColor(theme.muted)
                                .monospacedDigit()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, game.size.n <= 4 ? 14 : 8)
                    .background(colorful ? theme.digitColor(value).opacity(theme.isDark ? 0.16 : 0.11) : theme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
                    .opacity(left <= 0 ? 0.35 : 1)
                }
                .disabled(left <= 0 && !game.noteMode)
                .accessibilityIdentifier("key-\(value)")
            }
        }
    }
}

struct FilledButton: ButtonStyle {
    let theme: Theme
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: theme.design))
            .foregroundColor(filled ? theme.onAccent : theme.accent)
            .padding(.horizontal, 20).padding(.vertical, 11)
            .background(filled ? theme.accent : theme.soft)
            .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
