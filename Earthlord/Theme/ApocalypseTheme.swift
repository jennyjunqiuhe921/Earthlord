//
//  ApocalypseTheme.swift
//  Earthlord
//
//  Created by Claude Code on 2025/12/24.
//

import SwiftUI

/// 末日主题配色
enum ApocalypseTheme {
    // MARK: - 背景色
    static let background = Color(red: 0.25, green: 0.25, blue: 0.28)      // 主背景（中灰色，大幅提高可见度）
    static let cardBackground = Color(red: 0.32, green: 0.32, blue: 0.35)  // 卡片背景（更亮的灰色）
    static let tabBarBackground = Color(red: 0.95, green: 0.95, blue: 0.95) // Tab栏背景（浅色）

    // MARK: - 强调色
    static let primary = Color(red: 1.0, green: 0.45, blue: 0.15)          // 主题橙色（稍微调亮）
    static let primaryDark = Color(red: 0.8, green: 0.3, blue: 0.0)        // 深橙色

    // MARK: - 文字色
    static let textPrimary = Color.white                                    // 主文字
    static let textSecondary = Color(white: 0.7)                           // 次要文字（提高对比度）
    static let textMuted = Color(white: 0.5)                               // 弱化文字（提高可见度）

    // MARK: - 状态色
    static let success = Color(red: 0.2, green: 0.8, blue: 0.4)            // 成功/绿色
    static let warning = Color(red: 1.0, green: 0.8, blue: 0.0)            // 警告/黄色
    static let danger = Color(red: 1.0, green: 0.3, blue: 0.3)             // 危险/红色
    static let info = Color(red: 0.3, green: 0.7, blue: 1.0)               // 信息/蓝色
}
