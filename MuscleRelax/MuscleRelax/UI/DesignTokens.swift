import SwiftUI

// MARK: - 设计 Token（需求 §7.2 定稿数值）

enum DT {
    enum Color {
        static let primary = SwiftUI.Color(hex: 0x3D8BFF)      // 清爽健康蓝
        static let primaryLight = SwiftUI.Color(hex: 0xE8F1FF) // 选中底色
        static let background = SwiftUI.Color.white
        static let layeredBackground = SwiftUI.Color(hex: 0xF7F8FA)
        static let levelMild = SwiftUI.Color(hex: 0xF5A623)
        static let levelModerate = SwiftUI.Color(hex: 0xF07C2E)
        static let levelSevere = SwiftUI.Color(hex: 0xD64541)
        static let textPrimary = SwiftUI.Color(hex: 0x1A1A1A)
        static let textBody = SwiftUI.Color(hex: 0x4A4A4A)
        static let textSecondary = SwiftUI.Color(hex: 0x9B9B9B)
    }

    enum Radius {
        static let card: CGFloat = 16
        static let button: CGFloat = 12
        static let tag: CGFloat = 8
    }

    enum Font {
        static let largeTitle = SwiftUI.Font.system(size: 28, weight: .bold)
        static let title = SwiftUI.Font.system(size: 20, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 16)
        static let auxiliary = SwiftUI.Font.system(size: 13)
        /// 按摩师展示字（需求 §6.4：≥34pt 加粗）
        static let broadcast = SwiftUI.Font.system(size: 34, weight: .bold)
    }

    /// 等级色标
    static func levelColor(_ level: SoreLevel) -> SwiftUI.Color {
        switch level {
        case .mild: return Color.levelMild
        case .moderate: return Color.levelModerate
        case .severe: return Color.levelSevere
        }
    }
}

extension SwiftUI.Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// 轻阴影（opacity 0.06, radius 8, y 2）
struct CardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

extension View {
    func cardShadow() -> some View { modifier(CardShadow()) }
}
