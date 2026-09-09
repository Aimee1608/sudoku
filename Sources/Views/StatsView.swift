import SwiftUI

struct StatsView: View {
    let onBack: () -> Void

    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var library: BankLibrary
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var hSize

    @State private var askReset = false

    private var accuracyText: String {
        progress.accuracy.map { "\($0)%" } ?? "—"
    }

    private var theme: Theme { settings.theme(for: scheme) }
    private var wide: Bool { hSize == .regular }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                NavBar(title: "我的记录", theme: theme, onBack: onBack)
                ScrollView {
                    Group {
                        if wide { wideBody } else { narrowBody }
                    }
                    .padding(wide ? 40 : 18)
                    .frame(maxWidth: wide ? .infinity : 620)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var narrowBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            tile("\(progress.totalCompleted)", "已完成的题目", highlight: true, centered: true)
            HStack(spacing: 10) {
                tile("\(progress.streak)", "连续天数")
                tile(accuracyText, "一次做对")
            }
            .fixedSize(horizontal: false, vertical: true)
            section("各册进度")
            ForEach(BoardSize.all, id: \.n) { progressRow($0) }
            section("最近 7 天")
            weekChart
            recent
            resetButton
        }
    }

    /// iPad 一列排下来又长又空,三个数字横过来、进度和柱图并排,才吃得住屏宽。
    private var wideBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                tile("\(progress.totalCompleted)", "已完成的题目", highlight: true)
                tile("\(progress.streak)", "连续天数")
                tile(accuracyText, "一次做对")
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    section("各册进度")
                    ForEach(BoardSize.all, id: \.n) { progressRow($0) }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 12) {
                    section("最近 7 天")
                    weekChart
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            recent
            resetButton
        }
    }

    /// 破坏性操作放在页面最底部,标红但不抢眼。alert 必须挂在按钮自己身上,
    /// 挂外层容器会出现「点了没反应」。
    private var resetButton: some View {
        Button { askReset = true } label: {
            HStack(spacing: 7) {
                Image(systemName: "trash")
                Text("重置全部记录")
            }
            .font(.system(size: wide ? 15 : 14, weight: .semibold, design: theme.design))
            .foregroundColor(Color(hex: 0xE5484D))
            .frame(maxWidth: .infinity)
            .padding(.vertical, wide ? 16 : 13)
            .themedCard(theme)
        }
        .buttonStyle(.plain)
        .padding(.top, wide ? 18 : 12)
        .accessibilityIdentifier("reset-progress")
        .alert("重置全部记录？", isPresented: $askReset) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) { progress.reset() }
        } message: {
            Text("做过的题、用时、错误数、连续天数和没做完的存档会全部清空，无法恢复。主题、音效这些外观设置不受影响。")
        }
    }

    @ViewBuilder
    private var recent: some View {
        let items = progress.recentRecords(limit: wide ? 8 : 3)
        if !items.isEmpty {
            section("最近完成")
            if wide {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2),
                    spacing: 10
                ) {
                    ForEach(items, id: \.key) { recentRow($0.key, $0.record) }
                }
            } else {
                ForEach(items, id: \.key) { recentRow($0.key, $0.record) }
            }
        }
    }

    private func tile(_ value: String, _ label: String,
                      highlight: Bool = false, centered: Bool = false) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: highlight ? 5 : 1) {
            Text(value)
                .font(.system(size: highlight ? (wide ? 40 : 46) : (wide ? 28 : 22),
                              weight: highlight ? .heavy : .bold, design: theme.design))
                .foregroundColor(highlight ? theme.accent : theme.ink)
                .monospacedDigit()
            Text(label)
                .font(.system(size: wide ? 13 : (highlight ? 12 : 11), design: theme.design))
                .foregroundColor(theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
        .padding(wide ? 22 : (highlight ? 18 : 13))
        .frame(maxHeight: .infinity)
        .themedCard(theme)
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.system(size: wide ? 14 : 12, weight: .semibold, design: theme.design))
            .foregroundColor(theme.muted)
            .padding(.top, wide ? 0 : 6)
    }

    private func progressRow(_ size: BoardSize) -> some View {
        let done = progress.completed(size)
        let total = max(library.total(size), 1)
        return HStack(spacing: 11) {
            Text(size.label)
                .font(.system(size: wide ? 14 : 12, weight: .bold, design: theme.design))
                .foregroundColor(theme.ink)
                .frame(width: wide ? 48 : 42, alignment: .leading)
                .monospacedDigit()
            ProgressBar(value: Double(done) / Double(total), theme: theme)
                .frame(height: wide ? 9 : 7)
            Text("\(done)/\(library.total(size))")
                .font(.system(size: wide ? 14 : 12, design: theme.design))
                .foregroundColor(theme.muted)
                .monospacedDigit()
        }
    }

    private var weekChart: some View {
        let days = progress.lastSevenDays()
        let peak = max(days.map(\.count).max() ?? 1, 1)
        return VStack(spacing: 5) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.accent.opacity(day.count == 0 ? 0.18 : 0.85))
                        .frame(height: max(4, (wide ? 72 : 54) * CGFloat(day.count) / CGFloat(peak)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: wide ? 72 : 54, alignment: .bottom)
            HStack(spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    Text(day.label)
                        .font(.system(size: wide ? 12 : 10, design: theme.design))
                        .foregroundColor(theme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func recentRow(_ key: String, _ record: LevelRecord) -> some View {
        let parts = key.split(separator: "-")
        let title = parts.count == 3
            ? "\(parts[0])×\(parts[0]) \(Difficulty(rawValue: String(parts[1]))?.label ?? "") · 第 \((Int(parts[2]) ?? 0) + 1) 题"
            : key
        return HStack {
            Text(title)
                .font(.system(size: wide ? 14 : 12, design: theme.design))
                .foregroundColor(theme.ink)
            Spacer()
            Text(formatTime(record.seconds))
                .font(.system(size: wide ? 14 : 12, design: theme.design))
                .foregroundColor(theme.muted)
                .monospacedDigit()
        }
        .padding(.horizontal, wide ? 16 : 0)
        .padding(.vertical, wide ? 13 : 0)
        .background(wide ? theme.panel : .clear)
        .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
    }
}

struct SettingsView: View {
    let onBack: () -> Void

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var hSize

    private var theme: Theme { settings.theme(for: scheme) }
    private var wide: Bool { hSize == .regular }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                NavBar(title: "外观设置", theme: theme, onBack: onBack)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        toggleRow("彩色数字", "1 永远红、5 永远青。还不熟悉字形的孩子靠颜色认位置，"
                                  + "开了之后题面和填入改用格底小圆点区分。",
                                  isOn: $settings.colorfulDigits)
                        toggleRow("跟随系统深浅", "白天用你挑的浅色主题，晚上自动换成配对的深色主题。",
                                  isOn: $settings.followSystem)
                        toggleRow("音效", "选格、填数、填错、凑齐一行各有不同的提示音。没有背景音乐。",
                                  isOn: $settings.soundEnabled)
                        toggleRow("触感反馈", "点数字和按钮时轻震一下。", isOn: $settings.hapticsEnabled)

                        group("浅色 · 白天做题", themes: Theme.light)
                        group("深色 · 夜里不刺眼", themes: Theme.dark)
                    }
                    .padding(wide ? 40 : 18)
                    .frame(maxWidth: wide ? .infinity : 620)
                }
            }
        }
    }

    private func toggleRow(_ title: String, _ detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: theme.design))
                    .foregroundColor(theme.ink)
                Text(detail)
                    .font(.system(size: 11.5, design: theme.design))
                    .foregroundColor(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(theme.accent)
                .accessibilityIdentifier("toggle-\(title)")
        }
        .padding(14)
        .themedCard(theme)
    }

    private func group(_ title: String, themes: [Theme]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: theme.design))
                .foregroundColor(theme.muted)
                .padding(.top, 6)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: wide ? 4 : 2), spacing: 8) {
                ForEach(themes) { option in
                    Button { settings.themeId = option.id } label: {
                        themeChip(option)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("theme-\(option.id)")
                }
            }
        }
    }

    private func themeChip(_ option: Theme) -> some View {
        let picked = settings.themeId == option.id
        return HStack(spacing: 9) {
            HStack(spacing: 0) {
                ForEach([option.background, option.given, option.accent, option.user], id: \.self) { color in
                    color.frame(width: 8, height: 26)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(theme.line, lineWidth: 1)
            )
            Text(option.name)
                .font(.system(size: wide ? 15.5 : 13.5, weight: .semibold, design: theme.design))
                .foregroundColor(theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 11)
        .background(theme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                .strokeBorder(picked ? theme.accent : theme.line, lineWidth: picked ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
    }
}

struct NavBar: View {
    let title: String
    let theme: Theme
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.accent)
                    .frame(width: 36, height: 36)
            }
            .accessibilityIdentifier("back")
            Spacer()
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: theme.design))
                .foregroundColor(theme.ink)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }
}
