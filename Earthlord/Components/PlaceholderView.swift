//
//  PlaceholderView.swift
//  Earthlord
//
//  Created by Claude Code on 2025/12/24.
//

import SwiftUI

/// 通用占位视图
struct PlaceholderView: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // 卡片容器，提供更好的对比度
                VStack(spacing: 28) {
                    // 图标容器 - 添加背景圆形突出显示
                    ZStack {
                        // 背景发光圆形
                        Circle()
                            .fill(ApocalypseTheme.primary.opacity(0.15))
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)

                        Circle()
                            .fill(ApocalypseTheme.primary.opacity(0.08))
                            .frame(width: 160, height: 160)

                        // 图标
                        Image(systemName: icon)
                            .font(.system(size: 100, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.primary)
                            .shadow(color: ApocalypseTheme.primary.opacity(0.8), radius: 20, x: 0, y: 0)
                            .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 35, x: 0, y: 0)
                            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 50, x: 0, y: 0)
                    }

                    VStack(spacing: 12) {
                        Text(title)
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)

                        Text(subtitle)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                    }
                }
                .padding(50)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(ApocalypseTheme.cardBackground)
                        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 2)
                )
            }
            .padding(.horizontal, 30)
        }
    }
}

#Preview {
    PlaceholderView(
        icon: "map.fill",
        title: "地图",
        subtitle: "探索和圈占领地"
    )
}
