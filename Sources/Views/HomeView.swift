import SwiftUI

@MainActor
final class BankLibrary: ObservableObject {
    private var cache: [String: [Puzzle]] = [:]

    func puzzles(_ size: BoardSize, _ difficulty: Difficulty) -> [Puzzle] {
        let key = PuzzleBank.fileName(size: size, difficulty: difficulty)
        if let hit = cache[key] { return hit }
        let loaded = PuzzleBank.load(size: size, difficulty: difficulty)
        cache[key] = loaded
        return loaded
    }

    func total(_ size: BoardSize) -> Int {
        Difficulty.available(for: size).reduce(0) { $0 + puzzles(size, $1).count }
    }

    func puzzle(_ size: BoardSize, _ difficulty: Difficulty, _ index: Int) -> Puzzle? {
        let list = puzzles(size, difficulty)
        return list.indices.contains(index) ? list[index] : nil
    }
}

struct HomeView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var library: BankLibrary
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var hSize

    let onPick: (BoardSize) -> Void
    let onResume: (SavedGame) -> Void
    let onStats: () -> Void
    let onSettings: () -> Void

    private var theme: Theme { settings.theme(for: scheme) }
    private var wide: Bool { hSize == .regular }
    private func fs(_ compact: CGFloat) -> CGFloat { compact * (wide ? 1.3 : 1) }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    if wide {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                            spacing: 14
                        ) {
                            ForEach(BoardSize.all, id: \.n) { size in
                                sizeCard(size)
                            }
                        }
                    } else {
                        ForEach(BoardSize.all, id: \.n) { size in
                            sizeCard(size)
                        }
                    }
                    if let saved = progress.savedGame {
                        resumeCard(saved)
                    }
                    todayRow
                    // iPad 屏幕高,三张卡之后还剩大半屏。与其拿空白撑着,不如补一块
                    // 真看得见积累的内容;iPhone 一屏本来就满,不加。
                    if wide { recentSection }
                    if !wide { Spacer(minLength: 8) }
                    footer
                }
                .padding(wide ? 40 : 18)
                .frame(maxWidth: wide ? .infinity : 520)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("彩虹数独")
                .font(.system(size: fs(28), weight: .bold, design: theme.design))
                .foregroundColor(theme.ink)
            Text("4×4 · 6×6 · 9×9")
                .font(.system(size: fs(12), weight: .medium, design: theme.design))
                .foregroundColor(theme.muted)
                .tracking(1.5)
        }
        .padding(.bottom, 6)
    }

    private func sizeCard(_ size: BoardSize) -> some View {
        let done = progress.completed(size)
        let total = max(library.total(size), 1)
        return Button { onPick(size) } label: {
            Group {
                if wide { wideCard(size, done: done, total: total) }
                else { narrowCard(size, done: done, total: total) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(wide ? 22 : 14)
            .themedCard(theme)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("size-\(size.n)")
    }

    /// iPad 上三张卡横排,每列只有三百多点宽,横版会把副标题压到换行——改竖版摆开。
    private func wideCard(_ size: BoardSize, done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sizeBadge(size)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(size.label) \(sizeTitle(size))")
                    .font(.system(size: 22, weight: .bold, design: theme.design))
                    .foregroundColor(theme.ink)
                Text(sizeSubtitle(size))
                    .font(.system(size: 14, design: theme.design))
                    .foregroundColor(theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(done)")
                    .font(.system(size: 26, weight: .bold, design: theme.design))
                    .foregroundColor(theme.ink)
                Text("/\(library.total(size))")
                    .font(.system(size: 14, weight: .semibold, design: theme.design))
                    .foregroundColor(theme.muted)
            }
            .monospacedDigit()
            ProgressBar(value: Double(done) / Double(total), theme: theme)
        }
        .frame(height: 268, alignment: .topLeading)
    }

    private func narrowCard(_ size: BoardSize, done: Int, total: Int) -> some View {
        HStack(spacing: 14) {
            sizeBadge(size)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(size.label) \(sizeTitle(size))")
                    .font(.system(size: 16, weight: .bold, design: theme.design))
                    .foregroundColor(theme.ink)
                Text(sizeSubtitle(size))
                    .font(.system(size: 11.5, design: theme.design))
                    .foregroundColor(theme.muted)
                ProgressBar(value: Double(done) / Double(total), theme: theme)
                    .padding(.top, 5)
            }
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(done)")
                    .font(.system(size: 18, weight: .bold, design: theme.design))
                    .foregroundColor(theme.ink)
                Text("/\(library.total(size))")
                    .font(.system(size: 11, weight: .semibold, design: theme.design))
                    .foregroundColor(theme.muted)
            }
            .monospacedDigit()
        }
    }

    private func sizeBadge(_ size: BoardSize) -> some View {
        VStack(spacing: 1.5) {
            ForEach(0..<size.boxRows, id: \.self) { _ in
                HStack(spacing: 1.5) {
                    ForEach(0..<size.boxCols, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(theme.accent.opacity(0.55))
                    }
                }
            }
        }
        .padding(5)
        .frame(width: wide ? 64 : 46, height: wide ? 64 : 46)
        .background(theme.soft)
        .clipShape(RoundedRectangle(cornerRadius: theme.corner * 0.8, style: .continuous))
    }

    private func sizeTitle(_ size: BoardSize) -> String {
        switch size.n {
        case 4: return "入门"
        case 6: return "进阶"
        default: return "经典"
        }
    }

    private func sizeSubtitle(_ size: BoardSize) -> String {
        switch size.n {
        case 4: return "认得数字就能玩"
        case 6: return "2×3 宫，过渡到标准盘"
        default: return Difficulty.allCases.map(\.label).joined(separator: " / ")
        }
    }

    private func resumeCard(_ saved: SavedGame) -> some View {
        Button { onResume(saved) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("继续第 \(saved.index + 1) 题")
                        .font(.system(size: fs(15), weight: .bold, design: theme.design))
                    Text("\(saved.size.label) \(saved.difficulty.label) · 已用 \(formatTime(saved.seconds))")
                        .font(.system(size: fs(11.5), design: theme.design))
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(theme.onAccent)
            .padding(15)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 5)
    }

    private var todayRow: some View {
        HStack {
            Text("今天已完成")
            Spacer()
            Text("\(progress.todayCount) 题 · 连续 \(progress.streak) 天")
                .foregroundColor(theme.ink)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.system(size: fs(12.5), design: theme.design))
        .foregroundColor(theme.muted)
        .padding(.horizontal, fs(15)).padding(.vertical, fs(12))
        .overlay(
            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                .strokeBorder(theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .padding(.top, 5)
    }

    @ViewBuilder
    private var recentSection: some View {
        let items = progress.recentRecords(limit: 10)
        VStack(alignment: .leading, spacing: 10) {
            Text(items.isEmpty ? "还没有做过的题" : "最近完成")
                .font(.system(size: 14, weight: .semibold, design: theme.design))
                .foregroundColor(theme.muted)
                .padding(.top, 14)
            if items.isEmpty {
                Text("挑一册开始吧。做过的题会记在这里，也会记进「我的记录」。")
                    .font(.system(size: 14, design: theme.design))
                    .foregroundColor(theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .themedCard(theme)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                    spacing: 10
                ) {
                    ForEach(items, id: \.key) { item in
                        recentRow(item.key, item.record)
                    }
                }
            }
        }
    }

    private func recentRow(_ key: String, _ record: LevelRecord) -> some View {
        let parts = key.split(separator: "-")
        let title = parts.count == 3
            ? "\(parts[0])×\(parts[0]) \(Difficulty(rawValue: String(parts[1]))?.label ?? "") · 第 \((Int(parts[2]) ?? 0) + 1) 题"
            : key
        return HStack(spacing: 10) {
            Image(systemName: record.usedAnswer ? "eye" : "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(record.usedAnswer ? theme.muted : theme.accent)
            Text(title)
                .font(.system(size: 14, design: theme.design))
                .foregroundColor(theme.ink)
            Spacer(minLength: 6)
            if record.mistakes > 0 {
                Text("错 \(record.mistakes)")
                    .font(.system(size: 12, design: theme.design))
                    .foregroundColor(theme.muted)
            }
            Text(formatTime(record.seconds))
                .font(.system(size: 14, design: theme.design))
                .foregroundColor(theme.muted)
                .monospacedDigit()
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .themedCard(theme)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button { onStats() } label: {
                footerLabel("我的记录", "chart.bar")
            }
            .accessibilityIdentifier("nav-stats")
            Button { onSettings() } label: {
                footerLabel("外观设置", "paintpalette")
            }
            .accessibilityIdentifier("nav-settings")
        }
        .buttonStyle(.plain)
    }

    private func footerLabel(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: fs(13), weight: .medium))
            Text(title).font(.system(size: fs(13), weight: .semibold, design: theme.design))
        }
        .foregroundColor(theme.muted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, fs(11))
        .themedCard(theme)
    }
}

struct ProgressBar: View {
    let value: Double
    let theme: Theme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.track)
                Capsule().fill(theme.accent)
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 4)
    }
}
