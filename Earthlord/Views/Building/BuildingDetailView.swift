//
//  BuildingDetailView.swift
//  Earthlord
//
//  建筑详情视图 - 显示建筑信息和资源需求
//

import SwiftUI

/// 建筑详情视图
struct BuildingDetailView: View {

    // MARK: - Environment

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var buildingManager: BuildingManager
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - Properties

    let template: BuildingTemplate
    let onStartConstruction: ((BuildingTemplate) -> Void)?

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

    private var buildTimeFormatted: String {
        let totalSeconds = template.buildTime
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 建筑图标和基本信息
                    headerSection

                    // 描述
                    descriptionSection

                    // 效果列表
                    if let effects = template.effects, !effects.isEmpty {
                        effectsSection(effects: effects)
                    }

                    // 资源需求
                    resourcesSection

                    // 建造按钮
                    buildButton
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("建筑详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
        }
        .task {
            // 确保库存数据已加载
            if inventoryManager.inventoryItems.isEmpty {
                try? await inventoryManager.loadInventory()
            }
            // 确保物品定义已加载
            if inventoryManager.itemDefinitions.isEmpty {
                try? await inventoryManager.loadItemDefinitions()
            }
        }
    }

    // MARK: - Subviews

    /// 头部区域（图标、名称、分类）
    private var headerSection: some View {
        VStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: template.iconName)
                    .font(.system(size: 50))
                    .foregroundColor(categoryColor)
            }

            // 名称
            Text(template.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 分类和等级
            HStack(spacing: 12) {
                Label(template.category.displayName, systemImage: template.category.icon)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("T\(template.tier)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(categoryColor)
                    .cornerRadius(6)

                Label(buildTimeFormatted, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 描述区域
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("描述")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(template.description)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 效果列表
    private func effectsSection(effects: [BuildingEffect]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("效果")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 8) {
                ForEach(effects, id: \.effectType) { effect in
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(ApocalypseTheme.success)

                        Text(formatEffectType(effect.effectType))
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Spacer()

                        Text("+\(Int(effect.value))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ApocalypseTheme.success)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ApocalypseTheme.success.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 资源需求区域
    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建造资源")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            if template.resources.isEmpty {
                Text("无需资源")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                VStack(spacing: 8) {
                    ForEach(template.resources) { resource in
                        let owned = getOwnedAmount(for: resource.resourceId)
                        let definition = inventoryManager.itemDefinitions[resource.resourceId]

                        ResourceRow(
                            resourceId: resource.resourceId,
                            requiredAmount: resource.amount,
                            ownedAmount: owned,
                            itemDefinition: definition
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 建造按钮
    private var buildButton: some View {
        Button {
            onStartConstruction?(template)
            dismiss()
        } label: {
            HStack {
                Image(systemName: "hammer.fill")
                Text("开始建造")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(ApocalypseTheme.primary)
            .cornerRadius(12)
        }
    }

    // MARK: - Helper Methods

    private func getOwnedAmount(for resourceId: String) -> Int {
        inventoryManager.inventoryItems
            .filter { $0.definitionId == resourceId }
            .reduce(0) { $0 + $1.quantity }
    }

    private func formatEffectType(_ effectType: String) -> String {
        switch effectType {
        case "storage_capacity":
            return "储存容量"
        case "production_rate":
            return "生产效率"
        case "energy_output":
            return "能源输出"
        case "warmth":
            return "温暖度"
        case "light":
            return "照明"
        case "light_radius":
            return "照明范围"
        case "shelter":
            return "庇护等级"
        case "rest_bonus":
            return "休息加成"
        case "food_production":
            return "食物产出"
        case "crop_slots":
            return "作物槽位"
        case "water_production":
            return "水产出"
        case "energy_capacity":
            return "能源容量"
        default:
            return effectType
        }
    }
}

#Preview {
    BuildingDetailView(
        template: BuildingTemplate(
            id: "building_campfire",
            name: "篝火",
            description: "一个简单的篝火，能提供温暖和照明。在末世中，篝火是最基本的生存设施。",
            category: .survival,
            tier: 1,
            buildTime: 60,
            maxPerTerritory: 3,
            resources: [],
            effects: [
                BuildingEffect(effectType: "warmth", value: 10),
                BuildingEffect(effectType: "light", value: 5)
            ],
            iconName: "flame.fill",
            upgradeToId: nil
        ),
        onStartConstruction: nil
    )
    .environmentObject(BuildingManager.shared)
    .environmentObject(InventoryManager())
}
