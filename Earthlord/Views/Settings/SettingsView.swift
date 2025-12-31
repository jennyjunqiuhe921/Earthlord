//
//  SettingsView.swift
//  Earthlord
//
//  Created by Claude Code on 2025/12/31.
//

import SwiftUI

/// 设置页面
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageManager = LanguageManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color(red: 0.1, green: 0.1, blue: 0.1)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 语言设置卡片
                        SettingsSectionCard(title: "语言设置") {
                            VStack(spacing: 0) {
                                ForEach(AppLanguage.allCases) { language in
                                    LanguageOptionRow(
                                        language: language,
                                        isSelected: languageManager.currentLanguage == language,
                                        onSelect: {
                                            print("🌍 用户选择语言: \(language.displayName)")
                                            languageManager.switchLanguage(to: language)
                                        }
                                    )

                                    if language != AppLanguage.allCases.last {
                                        Divider()
                                            .background(Color.white.opacity(0.1))
                                            .padding(.leading, 60)
                                    }
                                }
                            }
                        }

                        // 提示信息
                        Text("切换语言后将立即生效")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 30)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        print("🌍 关闭设置页面")
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }
}

// MARK: - 设置区块卡片

struct SettingsSectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text(title)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.horizontal, 30)

            // 内容卡片
            VStack(spacing: 0) {
                content
            }
            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 语言选项行

struct LanguageOptionRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 15) {
                // 语言图标
                Image(systemName: languageIcon)
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 30)

                // 语言名称
                Text(language.displayName)
                    .font(.body)
                    .foregroundColor(.white)

                Spacer()

                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(ApocalypseTheme.primary)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 根据语言返回对应的图标
    private var languageIcon: String {
        switch language {
        case .system:
            return "gearshape.fill"
        case .chinese:
            return "character.textbox"
        case .english:
            return "textformat.abc"
        }
    }
}

#Preview {
    SettingsView()
}
