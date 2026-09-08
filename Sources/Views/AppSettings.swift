import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    @Published var themeId: String { didSet { defaults.set(themeId, forKey: "themeId") } }
    @Published var colorfulDigits: Bool { didSet { defaults.set(colorfulDigits, forKey: "colorfulDigits") } }
    @Published var followSystem: Bool { didSet { defaults.set(followSystem, forKey: "followSystem") } }
    @Published var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: "hapticsEnabled") } }

    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            "themeId": "ocean",
            "colorfulDigits": false,
            "followSystem": false,
            "hapticsEnabled": true,
        ])
        themeId = defaults.string(forKey: "themeId") ?? "ocean"
        colorfulDigits = defaults.bool(forKey: "colorfulDigits")
        followSystem = defaults.bool(forKey: "followSystem")
        hapticsEnabled = defaults.bool(forKey: "hapticsEnabled")
    }

    var chosenTheme: Theme { .named(themeId) }

    /// 跟随系统时用配对的明暗版本,配对表在 Theme.counterpart。
    func theme(for scheme: ColorScheme) -> Theme {
        let base = chosenTheme
        guard followSystem else { return base }
        let wantsDark = scheme == .dark
        return base.isDark == wantsDark ? base : base.counterpart
    }
}

enum Haptics {
    static func tap(_ enabled: Bool) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func warn(_ enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func win(_ enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

extension View {
    func themedCard(_ theme: Theme) -> some View {
        background(theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
    }
}
