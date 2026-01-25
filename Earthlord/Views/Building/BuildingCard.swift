//
//  BuildingCard.swift
//  Earthlord
//
//  建筑卡片组件 - 在建筑浏览器中显示
//

import SwiftUI

/// 建筑卡片
struct BuildingCard: View {

    // MARK: - Properties

    let template: BuildingTemplate
    let onTap: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: template.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(categoryColor)
                }

                // 名称
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                // 分类和等级
                HStack(spacing: 6) {
                    Text(template.category.displayName)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("T\(template.tier)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(tierColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tierColor.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.textMuted.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Properties

    private var categoryColor: Color {
        switch template.category {
        case .survival:
            return .orange
        case .storage:
            return .blue
        case .production:
            return .green
        case .energy:
            return .yellow
        }
    }

    private var tierColor: Color {
        switch template.tier {
        case 1:
            return .gray
        case 2:
            return .green
        case 3:
            return .blue
        case 4:
            return .purple
        case 5:
            return .orange
        default:
            return .gray
        }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        BuildingCard(
            template: BuildingTemplate(
                id: "building_campfire",
                name: "篝火",
                description: "提供温暖和照明",
                category: .survival,
                tier: 1,
                buildTime: 60,
                maxPerTerritory: 3,
                resources: [],
                effects: nil,
                iconName: "flame.fill",
                upgradeToId: nil
            ),
            onTap: {}
        )
        BuildingCard(
            template: BuildingTemplate(
                id: "building_warehouse",
                name: "仓库",
                description: "增加储存空间",
                category: .storage,
                tier: 2,
                buildTime: 300,
                maxPerTerritory: 1,
                resources: [],
                effects: nil,
                iconName: "archivebox.fill",
                upgradeToId: nil
            ),
            onTap: {}
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
