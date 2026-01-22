//
//  ScavengeResultView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-13.
//
//  搜刮结果展示视图 - 支持 AI 生成的独特物品
//

import SwiftUI
import CoreLocation

/// 搜刮结果视图
/// 显示搜刮 POI 获得的 AI 生成物品
struct ScavengeResultView: View {

    // MARK: - Properties

    /// 搜刮的 POI
    let poi: POI

    /// 获得的物品列表（传统方式，保留兼容）
    let items: [ItemLoot]

    /// 关闭回调
    let onDismiss: () -> Void

    /// 探索管理器（用于获取 AI 生成的物品）
    @EnvironmentObject var explorationManager: ExplorationManager

    /// 背包管理器（用于获取物品定义）
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - State

    @State private var showItems = false
    @State private var itemsAppeared: Set<String> = []
    @State private var expandedStories: Set<String> = []

    // MARK: - Computed Properties

    /// AI 生成的物品
    private var aiItems: [AIGeneratedItem] {
        explorationManager.aiGeneratedItems
    }

    /// 是否有 AI 生成的物品
    private var hasAIItems: Bool {
        !aiItems.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    // 点击背景不关闭
                }

            // 内容卡片
            VStack(spacing: 0) {
                // 顶部成功横幅
                successBanner
                    .padding(.bottom, 20)

                // POI 信息
                poiInfo
                    .padding(.bottom, 16)

                // 分隔线
                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))
                    .padding(.horizontal, 20)

                // 物品列表标题
                HStack {
                    Text("获得物品")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text("\(hasAIItems ? aiItems.count : items.count) 件")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // 物品列表
                ScrollView {
                    VStack(spacing: 12) {
                        if hasAIItems {
                            // 显示 AI 生成的物品
                            ForEach(Array(aiItems.enumerated()), id: \.element.id) { index, item in
                                aiItemRow(item: item, index: index)
                            }
                        } else {
                            // 降级：显示传统物品
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                legacyItemRow(item: item, index: index)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .frame(maxHeight: 350)

                // 确认按钮
                Button(action: onDismiss) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text("确认")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [ApocalypseTheme.success, ApocalypseTheme.success.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.3), radius: 20)
            .padding(.horizontal, 24)
            .onAppear {
                // 延迟显示物品动画
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showItems = true
                }
            }
        }
    }

    // MARK: - Subviews

    /// 成功横幅
    private var successBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundColor(.yellow)

            Text("搜刮成功！")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundColor(.yellow)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [ApocalypseTheme.success, ApocalypseTheme.success.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24, corners: [.topLeft, .topRight])
    }

    /// POI 信息
    private var poiInfo: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(poiColor.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: poi.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(poiColor)
            }

            // 名称和危险等级
            VStack(alignment: .leading, spacing: 4) {
                Text(poi.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(poi.type.rawValue)
                        .font(.system(size: 13))
                        .foregroundColor(poiColor)

                    Text("·")
                        .foregroundColor(ApocalypseTheme.textMuted)

                    // 危险等级指示
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { level in
                            Circle()
                                .fill(level <= poi.dangerLevel ? dangerLevelColor(poi.dangerLevel) : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    /// AI 生成的物品行
    private func aiItemRow(item: AIGeneratedItem, index: Int) -> some View {
        let isExpanded = expandedStories.contains(item.id)

        return VStack(alignment: .leading, spacing: 0) {
            // 主行
            HStack(spacing: 12) {
                // 物品图标
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(aiRarityColor(item.rarity).opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: aiCategoryIcon(item.category))
                        .font(.system(size: 22))
                        .foregroundColor(aiRarityColor(item.rarity))
                }

                // 物品名称和稀有度
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        // 稀有度标签
                        Text(aiRarityText(item.rarity))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(aiRarityColor(item.rarity))
                            .cornerRadius(4)

                        // 分类标签
                        Text(item.category)
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                // 展开/收起按钮
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedStories.remove(item.id)
                        } else {
                            expandedStories.insert(item.id)
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(ApocalypseTheme.background.opacity(0.5))
                        .cornerRadius(8)
                }
            }
            .padding(12)

            // 故事展开区域
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.2))

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text(item.story)
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .italic()
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(aiRarityColor(item.rarity).opacity(0.3), lineWidth: 1)
        )
        .opacity(itemsAppeared.contains(item.id) ? 1 : 0)
        .offset(x: itemsAppeared.contains(item.id) ? 0 : 30)
        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.15), value: itemsAppeared)
        .onAppear {
            if showItems {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                    itemsAppeared.insert(item.id)
                }
            }
        }
        .onChange(of: showItems) { newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                    itemsAppeared.insert(item.id)
                }
            }
        }
    }

    /// 传统物品行（降级方案）
    private func legacyItemRow(item: ItemLoot, index: Int) -> some View {
        let definition = inventoryManager.getDefinition(for: item.definitionId)

        return HStack(spacing: 12) {
            // 物品图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(rarityColor(definition?.rarity).opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: itemIcon(definition?.category))
                    .font(.system(size: 22))
                    .foregroundColor(rarityColor(definition?.rarity))
            }

            // 物品名称和稀有度
            VStack(alignment: .leading, spacing: 4) {
                Text(definition?.name ?? "未知物品")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let rarity = definition?.rarity {
                    Text(rarity.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(rarityColor(rarity))
                }
            }

            Spacer()

            // 数量
            Text("x\(item.quantity)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(12)
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(12)
        .opacity(itemsAppeared.contains(item.id) ? 1 : 0)
        .offset(x: itemsAppeared.contains(item.id) ? 0 : 30)
        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.15), value: itemsAppeared)
        .onAppear {
            if showItems {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                    itemsAppeared.insert(item.id)
                }
            }
        }
        .onChange(of: showItems) { newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                    itemsAppeared.insert(item.id)
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// POI 类型颜色
    private var poiColor: Color {
        switch poi.type {
        case .supermarket:
            return ApocalypseTheme.success
        case .hospital:
            return ApocalypseTheme.danger
        case .pharmacy:
            return Color.purple
        case .gasStation:
            return Color.orange
        case .restaurant:
            return Color.yellow
        default:
            return ApocalypseTheme.info
        }
    }

    /// 危险等级颜色
    private func dangerLevelColor(_ level: Int) -> Color {
        switch level {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .gray
        }
    }

    /// AI 稀有度颜色
    private func aiRarityColor(_ rarity: String) -> Color {
        switch rarity.lowercased() {
        case "common":
            return Color.gray
        case "uncommon":
            return Color.green
        case "rare":
            return Color.blue
        case "epic":
            return Color.purple
        case "legendary":
            return Color.orange
        default:
            return Color.gray
        }
    }

    /// AI 稀有度文字
    private func aiRarityText(_ rarity: String) -> String {
        switch rarity.lowercased() {
        case "common": return "普通"
        case "uncommon": return "优秀"
        case "rare": return "稀有"
        case "epic": return "史诗"
        case "legendary": return "传奇"
        default: return "普通"
        }
    }

    /// AI 分类图标
    private func aiCategoryIcon(_ category: String) -> String {
        switch category {
        case "医疗":
            return "cross.case.fill"
        case "食物":
            return "fork.knife"
        case "工具":
            return "wrench.fill"
        case "武器":
            return "shield.fill"
        case "材料":
            return "cube.fill"
        case "水":
            return "drop.fill"
        default:
            return "shippingbox.fill"
        }
    }

    /// 传统稀有度颜色
    private func rarityColor(_ rarity: ItemRarity?) -> Color {
        guard let rarity = rarity else { return Color.gray }
        switch rarity {
        case .common:
            return Color.gray
        case .uncommon:
            return Color.green
        case .rare:
            return Color.blue
        case .epic:
            return Color.purple
        case .legendary:
            return Color.orange
        }
    }

    /// 传统物品分类图标
    private func itemIcon(_ category: ItemCategory?) -> String {
        guard let category = category else { return "shippingbox.fill" }
        switch category {
        case .water:
            return "drop.fill"
        case .food:
            return "fork.knife"
        case .medical:
            return "cross.case.fill"
        case .material:
            return "cube.fill"
        case .tool:
            return "wrench.fill"
        case .weapon:
            return "shield.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    ScavengeResultView(
        poi: POI(
            id: "test",
            name: "协和医院急诊室",
            type: .hospital,
            coordinate: .init(latitude: 22.54, longitude: 114.06),
            status: .looted,
            hasLoot: false,
            description: "已被搜刮",
            dangerLevel: 4
        ),
        items: [],
        onDismiss: { print("关闭") }
    )
    .environmentObject(ExplorationManager())
    .environmentObject(InventoryManager())
}
