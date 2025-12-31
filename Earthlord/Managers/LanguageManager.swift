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

    /// 语言代码
    var languageCode: String? {
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

/// 语言管理器 - 管理 App 内的语言切换
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
            updateBundle()
        }
    }

    /// 当前语言的 Bundle（用于获取本地化字符串）
    @Published private(set) var bundle: Bundle = Bundle.main

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

        // 初始化 Bundle
        updateBundle()
    }

    // MARK: - Public Methods

    /// 切换语言
    /// - Parameter language: 目标语言
    func switchLanguage(to language: AppLanguage) {
        print("🌍 准备切换语言到: \(language.displayName)")
        currentLanguage = language
    }

    /// 获取本地化字符串
    /// - Parameters:
    ///   - key: 字符串 key
    ///   - comment: 注释（可选）
    /// - Returns: 本地化后的字符串
    func localizedString(_ key: String, comment: String = "") -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    // MARK: - Private Methods

    /// 保存语言偏好到 UserDefaults
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: userDefaultsKey)
        print("✅ 语言设置已保存: \(currentLanguage.rawValue)")
    }

    /// 更新 Bundle（用于获取对应语言的本地化资源）
    private func updateBundle() {
        let languageCode: String

        if let code = currentLanguage.languageCode {
            // 使用用户选择的语言
            languageCode = code
            print("🌍 使用指定语言: \(code)")
        } else {
            // 跟随系统语言
            languageCode = Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "zh-Hans"
            print("🌍 跟随系统语言: \(languageCode)")
        }

        // 查找对应语言的 Bundle
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
            print("✅ 成功加载语言包: \(languageCode)")
        } else {
            // 如果找不到对应语言包，使用主 Bundle
            self.bundle = Bundle.main
            print("⚠️ 未找到语言包 \(languageCode)，使用默认语言包")
        }

        // 发送通知，让 UI 刷新
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
        print("📢 已发送语言切换通知")
    }

    /// 获取当前有效的语言代码
    var effectiveLanguageCode: String {
        if let code = currentLanguage.languageCode {
            return code
        } else {
            return Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "zh-Hans"
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    /// 语言切换通知
    static let languageDidChange = Notification.Name("LanguageDidChangeNotification")
}

// MARK: - String Extension (本地化便捷方法)

extension String {
    /// 获取本地化字符串
    var localized: String {
        return LanguageManager.shared.localizedString(self)
    }

    /// 获取本地化字符串（带参数）
    /// - Parameter arguments: 格式化参数
    /// - Returns: 本地化后的字符串
    func localized(with arguments: CVarArg...) -> String {
        let format = LanguageManager.shared.localizedString(self)
        return String(format: format, arguments: arguments)
    }
}
