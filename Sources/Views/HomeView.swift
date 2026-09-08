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

    let onPick: (BoardSize) -> Void
    let onResume: (SavedGame) -> Void
    let onStats: () -> Void
    let onSettings: () -> Void

    private var theme: Theme { settings.theme(for: scheme) }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    ForEach(BoardSize.all, id: \.n) { size in
                        sizeCard(size)
                    }
                    if let saved = progress.savedGame {
                        resumeCard(saved)
                    }
                    todayRow
                    Spacer(minLength: 8)
                    footer
                }
                .padding(18)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("数独练习册")
                .font(.system(size: 28, weight: .bold, design: theme.design))
                .foregroundColor(theme.ink)
            Text("4×4 · 6×6 · 9×9")
                .font(.system(size: 12, weight: .medium, design: theme.design))
                .foregroundColor(theme.muted)
                .tracking(1.5)
        }
        .padding(.bottom, 6)
    }

    private func sizeCard(_ size: BoardSize) -> some View {
        let done = progress.completed(size)
        let total = max(library.total(size), 1)
        return Button { onPick(size) } label: {
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
            .padding(14)
            .themedCard(theme)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("size-\(size.n)")
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
        .frame(width: 46, height: 46)
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
                        .font(.system(size: 15, weight: .bold, design: theme.design))
                    Text("\(saved.size.label) \(saved.difficulty.label) · 已用 \(formatTime(saved.seconds))")
                        .font(.system(size: 11.5, design: theme.design))
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
        .font(.system(size: 12.5, design: theme.design))
        .foregroundColor(theme.muted)
        .padding(.horizontal, 15).padding(.vertical, 12)
        .overlay(
            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                .strokeBorder(theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .padding(.top, 5)
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
            Image(systemName: icon).font(.system(size: 13, weight: .medium))
            Text(title).font(.system(size: 13, weight: .semibold, design: theme.design))
        }
        .foregroundColor(theme.muted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
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
