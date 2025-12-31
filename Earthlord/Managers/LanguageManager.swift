//
//  LanguageManager.swift
//  Earthlord
//
//  Created by Claude Code on 2025/12/31.
//

import SwiftUI
import Combine

/// 语言选项
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"      // 跟随系统
    case chinese = "zh-Hans"    // 简体中文
    case english = "en"         // English

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .system:
            return "跟随系统 / Follow System"
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    /// Locale 标识符
    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil  // nil 表示使用系统语言
        case .chinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }
}

/// 语言管理器 - 使用 Locale 方式管理 App 内的语言切换
@MainActor
class LanguageManager: ObservableObject {

    // MARK: - Singleton

    static let shared = LanguageManager()

    // MARK: - Published Properties

    /// 当前选择的语言
    @Published var currentLanguage: AppLanguage {
        didSet {
            print("🌍 语言切换: \(oldValue.displayName) → \(currentLanguage.displayName)")
            saveLanguagePreference()
            updateLocale()
        }
    }

    /// 当前的 Locale（SwiftUI 会使用这个来查找 Localizable.xcstrings 中的翻译）
    @Published var currentLocale: Locale = .current

    // MARK: - Private Properties

    private let userDefaultsKey = "AppLanguagePreference"

    // MARK: - Initialization

    private init() {
        // 从 UserDefaults 读取用户上次选择的语言
        if let savedLanguage = UserDefaults.standard.string(forKey: userDefaultsKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
            print("🌍 加载保存的语言设置: \(language.displayName)")
        } else {
            // 默认跟随系统
            self.currentLanguage = .system
            print("🌍 使用默认语言设置: 跟随系统")
        }

        // 初始化 Locale
        updateLocale()
    }

    // MARK: - Public Methods

    /// 切换语言
    /// - Parameter language: 目标语言
    func switchLanguage(to language: AppLanguage) {
        print("🌍 准备切换语言到: \(language.displayName)")
        currentLanguage = language
    }

    // MARK: - Private Methods

    /// 保存语言偏好到 UserDefaults
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: userDefaultsKey)
        print("✅ 语言设置已保存: \(currentLanguage.rawValue)")
    }

    /// 更新 Locale（SwiftUI 会使用新的 Locale 查找 Localizable.xcstrings）
    private func updateLocale() {
        if let identifier = currentLanguage.localeIdentifier {
            // 使用用户选择的语言
            currentLocale = Locale(identifier: identifier)
            print("🌍 切换到指定 Locale: \(identifier)")
        } else {
            // 跟随系统语言
            currentLocale = Locale.current
            print("🌍 跟随系统 Locale: \(Locale.current.identifier)")
        }
        print("📢 Locale 已更新，SwiftUI 会自动从 Localizable.xcstrings 查找翻译")
    }

    /// 获取当前有效的语言代码（用于显示）
    var effectiveLanguageCode: String {
        return currentLocale.language.languageCode?.identifier ?? "zh-Hans"
    }
}
