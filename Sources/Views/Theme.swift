import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let source: String
    let isDark: Bool
    let design: Font.Design
    let corner: CGFloat

    let background: Color
    let panel: Color
    let ink: Color
    let muted: Color
    let accent: Color
    let onAccent: Color
    let soft: Color
    let cell: Color
    let line: Color
    let boxLine: Color
    let given: Color
    let user: Color
    let note: Color
    let selection: Color
    let peer: Color
    let track: Color
    let done: Color

    static func == (a: Theme, b: Theme) -> Bool { a.id == b.id }

    init(id: String, name: String, source: String, isDark: Bool, design: Font.Design,
         bg: UInt32, panel: UInt32, ink: UInt32, muted: UInt32, accent: UInt32, onAccent: UInt32,
         soft: UInt32, cell: UInt32, line: UInt32, boxLine: UInt32, given: UInt32, user: UInt32,
         note: UInt32, selection: UInt32, peer: UInt32, track: UInt32, done: UInt32) {
        self.id = id
        self.name = name
        self.source = source
        self.isDark = isDark
        self.design = design
        self.corner = design == .serif ? 5 : (design == .rounded ? 16 : 10)
        self.background = Color(hex: bg)
        self.panel = Color(hex: panel)
        self.ink = Color(hex: ink)
        self.muted = Color(hex: muted)
        self.accent = Color(hex: accent)
        self.onAccent = Color(hex: onAccent)
        self.soft = Color(hex: soft)
        self.cell = Color(hex: cell)
        self.line = Color(hex: line)
        self.boxLine = Color(hex: boxLine)
        self.given = Color(hex: given)
        self.user = Color(hex: user)
        self.note = Color(hex: note)
        self.selection = Color(hex: selection)
        self.peer = Color(hex: peer)
        self.track = Color(hex: track)
        self.done = Color(hex: done)
    }
}

extension Theme {
    /// 浅色 8 套。除「纸与铅笔」「积木彩虹」和三套儿童向配色外,色值取自公开配色方案,
    /// 蓝色系取自 Tailwind 官方色阶——开源代码配色普遍低饱和,没有给孩子看的亮色。
    static let light: [Theme] = [
        Theme(id: "ocean", name: "海洋泡泡", source: "Tailwind sky", isDark: false, design: .rounded,
              bg: 0xEDF7FD, panel: 0xFFFFFF, ink: 0x0F3A52, muted: 0x79A7BF, accent: 0x0EA5E9,
              onAccent: 0xFFFFFF, soft: 0xDCEFFB, cell: 0xFFFFFF, line: 0xCFE6F4, boxLine: 0x4BA3CC,
              given: 0x0F3A52, user: 0xF97316, note: 0x9AC2D8, selection: 0xFFE0BE, peer: 0xE6F4FC,
              track: 0xD8ECF8, done: 0x0E8F5C),
        Theme(id: "blueberry", name: "蓝莓牛奶", source: "Tailwind indigo", isDark: false, design: .default,
              bg: 0xF2F4FC, panel: 0xFFFFFF, ink: 0x35386B, muted: 0x8B90B8, accent: 0x6366F1,
              onAccent: 0xFFFFFF, soft: 0xE7EAFA, cell: 0xFFFFFF, line: 0xDCE0F2, boxLine: 0x7C82B8,
              given: 0x35386B, user: 0x0EA5E9, note: 0xA5AAD0, selection: 0xDCDCFA, peer: 0xECEEFA,
              track: 0xE0E4F5, done: 0x2E9E63),
        Theme(id: "strawberry", name: "草莓牛奶", source: "Tailwind rose", isDark: false, design: .rounded,
              bg: 0xFFF4F6, panel: 0xFFFFFF, ink: 0x4A2C38, muted: 0xB58F9C, accent: 0xF43F5E,
              onAccent: 0xFFFFFF, soft: 0xFFE4EA, cell: 0xFFFFFF, line: 0xF7DCE3, boxLine: 0xDBA5B4,
              given: 0x4A2C38, user: 0x0E9BB5, note: 0xD3B3BD, selection: 0xFFE1C7, peer: 0xFFF0F3,
              track: 0xFBE2E8, done: 0x37A06A),
        Theme(id: "blocks", name: "积木彩虹", source: "自配", isDark: false, design: .rounded,
              bg: 0xFFF8EE, panel: 0xFFFFFF, ink: 0x413A4A, muted: 0x9C8FA6, accent: 0xF0883B,
              onAccent: 0xFFFFFF, soft: 0xFFF0DC, cell: 0xFFFFFF, line: 0xF1E3D0, boxLine: 0xD9BE99,
              given: 0x413A4A, user: 0x3DA5C4, note: 0xBDAFC6, selection: 0xFFE6B8, peer: 0xFFF4E3,
              track: 0xF6EADA, done: 0x3F9457),
        Theme(id: "paper", name: "纸与铅笔", source: "自配", isDark: false, design: .serif,
              bg: 0xFAF7F0, panel: 0xFFFFFF, ink: 0x22201C, muted: 0x8C8579, accent: 0x2E5C8A,
              onAccent: 0xFFFFFF, soft: 0xF1EEE5, cell: 0xFFFFFF, line: 0xDCD6C8, boxLine: 0x3A362E,
              given: 0x22201C, user: 0x2E5C8A, note: 0xA9A296, selection: 0xF3E4C0, peer: 0xF5F2E9,
              track: 0xEAE5D9, done: 0x2E5C8A),
        Theme(id: "solarLight", name: "复古纸黄", source: "Solarized Light", isDark: false, design: .serif,
              bg: 0xFDF6E3, panel: 0xFFFDF6, ink: 0x586E75, muted: 0x93A1A1, accent: 0x268BD2,
              onAccent: 0xFDF6E3, soft: 0xEEE8D5, cell: 0xFFFDF6, line: 0xE3DCC6, boxLine: 0x93A1A1,
              given: 0x073642, user: 0x268BD2, note: 0xA9B0A2, selection: 0xF0E4BE, peer: 0xF6F0DC,
              track: 0xEEE8D5, done: 0x6C7C00),
        Theme(id: "dawn", name: "晨曦玫瑰", source: "Rosé Pine Dawn", isDark: false, design: .serif,
              bg: 0xFAF4ED, panel: 0xFFFAF3, ink: 0x575279, muted: 0x9893A5, accent: 0x907AA9,
              onAccent: 0xFFFAF3, soft: 0xF2E9E1, cell: 0xFFFAF3, line: 0xE7DED6, boxLine: 0x9893A5,
              given: 0x575279, user: 0x286983, note: 0xB4AEBE, selection: 0xF0DFE9, peer: 0xF6EFE9,
              track: 0xE7DED6, done: 0x286983),
        Theme(id: "latte", name: "摩卡拿铁", source: "Catppuccin Latte", isDark: false, design: .default,
              bg: 0xEFF1F5, panel: 0xFFFFFF, ink: 0x4C4F69, muted: 0x8C8FA1, accent: 0x8839EF,
              onAccent: 0xFFFFFF, soft: 0xE6E9EF, cell: 0xFFFFFF, line: 0xDCE0E8, boxLine: 0x8C8FA1,
              given: 0x4C4F69, user: 0x1E66F5, note: 0x9CA0B0, selection: 0xE4D8F8, peer: 0xEDEFF4,
              track: 0xDCE0E8, done: 0x40A02B),
    ]

    /// 深色 7 套。带 Catppuccin / Nord / Dracula / Solarized / Tokyo Night 的五套跟彩虹跳跳棋同源。
    static let dark: [Theme] = [
        Theme(id: "deepsea", name: "深海探险", source: "自配", isDark: true, design: .rounded,
              bg: 0x0B2740, panel: 0x123754, ink: 0xD6ECF7, muted: 0x6D93AC, accent: 0x2DD4BF,
              onAccent: 0x08202F, soft: 0x123754, cell: 0x0F3049, line: 0x1D4867, boxLine: 0x4C7695,
              given: 0xEAF6FC, user: 0xFDE047, note: 0x5A83A0, selection: 0x1E5378, peer: 0x12354E,
              track: 0x1A4260, done: 0x2DD4BF),
        Theme(id: "starry", name: "星空夜航", source: "自配", isDark: true, design: .default,
              bg: 0x131A33, panel: 0x1D2647, ink: 0xC7D2F0, muted: 0x6976A3, accent: 0x818CF8,
              onAccent: 0x131A33, soft: 0x1D2647, cell: 0x182040, line: 0x29325A, boxLine: 0x566190,
              given: 0xDDE4FA, user: 0xFBBF24, note: 0x566190, selection: 0x2E3A6B, peer: 0x1B2344,
              track: 0x262E52, done: 0x4ADE80),
        Theme(id: "mocha", name: "摩卡糖果", source: "Catppuccin Mocha", isDark: true, design: .rounded,
              bg: 0x1E1E2E, panel: 0x282A3C, ink: 0xCDD6F4, muted: 0x7F849C, accent: 0xCBA6F7,
              onAccent: 0x1E1E2E, soft: 0x2A2C3E, cell: 0x252739, line: 0x3B3E52, boxLine: 0x6C7086,
              given: 0xCDD6F4, user: 0xA6E3A1, note: 0x6C7086, selection: 0x414463, peer: 0x2E3145,
              track: 0x33364A, done: 0xA6E3A1),
        Theme(id: "nord", name: "北欧极光", source: "Nord", isDark: true, design: .default,
              bg: 0x2E3440, panel: 0x3B4252, ink: 0xECEFF4, muted: 0x7B8494, accent: 0x88C0D0,
              onAccent: 0x2E3440, soft: 0x3B4252, cell: 0x353C4A, line: 0x454D5E, boxLine: 0x6B7488,
              given: 0xECEFF4, user: 0xA3BE8C, note: 0x6B7488, selection: 0x4C566A, peer: 0x3A4250,
              track: 0x434C5E, done: 0xA3BE8C),
        Theme(id: "dracula", name: "德古拉", source: "Dracula", isDark: true, design: .default,
              bg: 0x282A36, panel: 0x343746, ink: 0xF8F8F2, muted: 0x6272A4, accent: 0xBD93F9,
              onAccent: 0x282A36, soft: 0x343746, cell: 0x2F3140, line: 0x44475A, boxLine: 0x6272A4,
              given: 0xF8F8F2, user: 0x50FA7B, note: 0x6272A4, selection: 0x4A4D63, peer: 0x33364A,
              track: 0x44475A, done: 0x50FA7B),
        Theme(id: "solarDark", name: "复古暗调", source: "Solarized Dark", isDark: true, design: .default,
              bg: 0x002B36, panel: 0x073642, ink: 0x93A1A1, muted: 0x5E7379, accent: 0x2AA198,
              onAccent: 0x002B36, soft: 0x073642, cell: 0x04303C, line: 0x0E4351, boxLine: 0x586E75,
              given: 0xEEE8D5, user: 0xB5C000, note: 0x586E75, selection: 0x12505F, peer: 0x093B48,
              track: 0x0E4351, done: 0xB5C000),
        Theme(id: "tokyo", name: "东京夜色", source: "Tokyo Night", isDark: true, design: .default,
              bg: 0x1A1B26, panel: 0x24283B, ink: 0xC0CAF5, muted: 0x565F89, accent: 0x7AA2F7,
              onAccent: 0x1A1B26, soft: 0x24283B, cell: 0x1F2233, line: 0x2F344A, boxLine: 0x565F89,
              given: 0xC0CAF5, user: 0x9ECE6A, note: 0x565F89, selection: 0x3B4261, peer: 0x262B40,
              track: 0x2F344A, done: 0x9ECE6A),
    ]

    static let all: [Theme] = light + dark
    static let fallback = light[0]

    static func named(_ id: String) -> Theme { all.first { $0.id == id } ?? fallback }

    /// 跟随系统深浅时的明暗配对,同一套配色的两面优先。
    var counterpart: Theme {
        let pairs = ["ocean": "deepsea", "blueberry": "starry", "latte": "mocha",
                     "solarLight": "solarDark", "dawn": "tokyo", "paper": "nord",
                     "strawberry": "dracula", "blocks": "deepsea"]
        if let mate = pairs[id] { return .named(mate) }
        if let mate = pairs.first(where: { $0.value == id })?.key { return .named(mate) }
        return self
    }

    /// 彩色数字是独立开关,跟主题无关。深底那套是提亮过的,不然 9 的灰蓝直接糊进背景。
    func digitColor(_ value: Int) -> Color {
        let lightSet: [UInt32] = [0xE8523F, 0xF0883B, 0xD8A200, 0x58B368, 0x3DA5C4,
                                  0x4A6FD1, 0x8B5CC7, 0xD9599C, 0x5F7183]
        let darkSet: [UInt32] = [0xFF8071, 0xFFB273, 0xF2D064, 0x8CDCA0, 0x74D6EA,
                                 0x8FAAFF, 0xC6A1F2, 0xF793C2, 0xAEBBC9]
        guard (1...9).contains(value) else { return ink }
        return Color(hex: (isDark ? darkSet : lightSet)[value - 1])
    }
}
