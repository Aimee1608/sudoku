import SwiftUI

struct LevelsView: View {
    let size: BoardSize
    let onBack: () -> Void
    let onPlay: (Puzzle, Int) -> Void

    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var library: BankLibrary
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var hSize

    @State private var difficulty: Difficulty = .starter

    private var theme: Theme { settings.theme(for: scheme) }
    private var wide: Bool { hSize == .regular }
    private func fs(_ compact: CGFloat) -> CGFloat { compact * (wide ? 1.3 : 1) }
    private var levels: [Difficulty] { Difficulty.available(for: size) }
    private var puzzles: [Puzzle] { library.puzzles(size, difficulty) }
    private var current: Int { progress.nextIndex(size, difficulty, total: puzzles.count) }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if levels.count > 1 {
                    tabs.padding(.horizontal, wide ? 40 : 18).padding(.bottom, 14)
                }
                countRow.padding(.horizontal, wide ? 40 : 18).padding(.bottom, 10)
                ScrollView {
                    grid.padding(.horizontal, wide ? 40 : 18)
                    freeNote.padding(wide ? 40 : 18)
                }
            }
            .frame(maxWidth: wide ? .infinity : 520)
        }
        .onAppear { difficulty = levels.first ?? .starter }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.accent)
                    .frame(width: 36, height: 36)
            }
            .accessibilityIdentifier("back")
            Spacer()
            Text("\(size.label) 练习册")
                .font(.system(size: fs(16), weight: .semibold, design: theme.design))
                .foregroundColor(theme.ink)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var tabs: some View {
        HStack(spacing: 6) {
            ForEach(levels, id: \.self) { level in
                Button { difficulty = level } label: {
                    Text(level.label)
                        .font(.system(size: fs(13), weight: .semibold, design: theme.design))
                        .foregroundColor(difficulty == level ? theme.onAccent : theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, fs(8))
                        .background(difficulty == level ? theme.accent : theme.track)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab-\(level.rawValue)")
            }
        }
    }

    private var countRow: some View {
        HStack {
            Text("\(difficulty.label) · 共 \(puzzles.count) 题")
            Spacer()
            Text("已完成 \(progress.completed(size, difficulty))/\(puzzles.count)")
                .foregroundColor(theme.ink)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.system(size: fs(12), design: theme.design))
        .foregroundColor(theme.muted)
    }

    private var grid: some View {
        let columns = wide ? 10 : 5
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(puzzles.indices, id: \.self) { i in
                Button {
                    onPlay(puzzles[i], i)
                } label: {
                    levelCell(i)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("level-\(i)")
            }
        }
    }

    private func levelCell(_ i: Int) -> some View {
        let done = progress.isDone(size, difficulty, i)
        let isCurrent = i == current
        return ZStack {
            RoundedRectangle(cornerRadius: theme.corner * 0.8, style: .continuous)
                .fill(done ? theme.done.opacity(0.18) : (isCurrent ? theme.accent : theme.panel))
            if isCurrent && !done {
                RoundedRectangle(cornerRadius: theme.corner * 0.8, style: .continuous)
                    .strokeBorder(theme.selection, lineWidth: 3)
            }
            if done {
                Image(systemName: progress.record(size, difficulty, i)?.usedAnswer == true
                      ? "eye.fill" : "checkmark")
                    .font(.system(size: fs(14), weight: .bold))
                    .foregroundColor(theme.done)
            } else {
                Text("\(i + 1)")
                    .font(.system(size: fs(14), weight: .bold, design: theme.design))
                    .foregroundColor(isCurrent ? theme.onAccent : theme.muted)
                    .monospacedDigit()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var freeNote: some View {
        Text("全部题目从第一天起就是开着的，不用解锁、不用等体力。记录只是记录：做过哪些、用了多久、错在哪。")
            .font(.system(size: fs(11.5), design: theme.design))
            .foregroundColor(theme.muted)
            .lineSpacing(2)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.soft)
            .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
    }
}
