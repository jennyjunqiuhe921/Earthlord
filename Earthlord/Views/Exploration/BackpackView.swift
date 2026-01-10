//
//  BackpackView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-10.
//
//  玩家背包管理页面

import SwiftUI

struct BackpackView: View {
    // MARK: - State

    /// 搜索文本
    @State private var searchText = ""

    /// 选中的分类（nil = 全部）
    @State private var selectedCategory: ItemCategory? = nil

    /// 背包物品数据
    @State private var inventoryItems: [InventoryItem] = MockExplorationData.mockInventoryItems

    /// 背包容量配置
    private let maxCapacity = 100.0  // 最大容量（单位可以是格子数或重量）

    /// 动画用的当前容量
    @State private var animatedCapacity: Double = 0

    /// 物品列表过渡 ID
    @State private var itemListTransitionID = UUID()

    // MARK: - Computed Properties

    /// 当前使用的容量（这里简单用物品种类数量，实际应该用重量或体积）
    private var currentCapacity: Double {
        Double(inventoryItems.count) * 8  // 假设每种物品占8个单位
    }

    /// 容量使用百分比
    private var capacityPercentage: Double {
        currentCapacity / maxCapacity
    }

    /// 容量进度条颜色
    private var capacityColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    /// 是否显示警告
    private var showCapacityWarning: Bool {
        capacityPercentage > 0.9
    }

    /// 筛选后的物品列表
    private var filteredItems: [InventoryItem] {
        var items = inventoryItems

        // 按分类筛选
        if let category = selectedCategory {
            items = items.filter { item in
                if let definition = MockExplorationData.getItemDefinition(by: item.definitionId) {
                    return definition.category == category
                }
                return false
            }
        }

        // 按搜索文本筛选
        if !searchText.isEmpty {
            items = items.filter { item in
                if let definition = MockExplorationData.getItemDefinition(by: item.definitionId) {
                    return definition.name.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }

        return items
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 容量状态卡
                    capacityCard

                    // 搜索框
                    searchBar

                    // 筛选工具栏
                    filterToolbar

                    // 物品列表
                    itemList
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // 启动容量动画
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                animatedCapacity = currentCapacity
            }
        }
        .onChange(of: currentCapacity) { newValue in
            // 容量变化时的动画
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedCapacity = newValue
            }
        }
    }

    // MARK: - 容量状态卡

    private var capacityCard: some View {
        VStack(spacing: 12) {
            // 容量文字
            HStack {
                Image(systemName: "backpack.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(capacityColor)

                Text("背包容量：\(Int(animatedCapacity)) / \(Int(maxCapacity))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(Int((animatedCapacity / maxCapacity) * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(capacityColor)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.textMuted.opacity(0.2))
                        .frame(height: 12)

                    // 进度
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    capacityColor,
                                    capacityColor.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(animatedCapacity / maxCapacity, 1.0), height: 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedCapacity)
                }
            }
            .frame(height: 12)

            // 警告文字
            if showCapacityWarning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ApocalypseTheme.danger)

                    Text("背包快满了！")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.danger)

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 筛选工具栏

    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部" 按钮
                CategoryFilterButton(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil,
                    color: ApocalypseTheme.info
                ) {
                    selectedCategory = nil
                }

                // 各分类按钮
                CategoryFilterButton(
                    title: "食物",
                    icon: "fork.knife",
                    isSelected: selectedCategory == .food,
                    color: Color.brown
                ) {
                    selectedCategory = .food
                }

                CategoryFilterButton(
                    title: "水",
                    icon: "drop.fill",
                    isSelected: selectedCategory == .water,
                    color: Color.blue
                ) {
                    selectedCategory = .water
                }

                CategoryFilterButton(
                    title: "材料",
                    icon: "cube.box.fill",
                    isSelected: selectedCategory == .material,
                    color: Color.gray
                ) {
                    selectedCategory = .material
                }

                CategoryFilterButton(
                    title: "工具",
                    icon: "wrench.and.screwdriver.fill",
                    isSelected: selectedCategory == .tool,
                    color: Color.orange
                ) {
                    selectedCategory = .tool
                }

                CategoryFilterButton(
                    title: "医疗",
                    icon: "cross.fill",
                    isSelected: selectedCategory == .medical,
                    color: ApocalypseTheme.danger
                ) {
                    selectedCategory = .medical
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - 物品列表

    private var itemList: some View {
        VStack(spacing: 12) {
            if filteredItems.isEmpty {
                // 空状态
                emptyState
            } else {
                ForEach(filteredItems) { item in
                    if let definition = MockExplorationData.getItemDefinition(by: item.definitionId) {
                        ItemCard(item: item, definition: definition)
                    }
                }
            }
        }
        .id(itemListTransitionID)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        ))
        .animation(.easeInOut(duration: 0.3), value: itemListTransitionID)
        .onChange(of: selectedCategory) { _ in
            // 切换分类时更新 ID，触发过渡动画
            withAnimation(.easeInOut(duration: 0.3)) {
                itemListTransitionID = UUID()
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60, weight: .medium))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 主标题
            Text(emptyStateTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 副标题
            Text(emptyStateSubtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Empty State Helpers

    /// 空状态图标
    private var emptyStateIcon: String {
        if inventoryItems.isEmpty {
            return "backpack.fill"
        } else if !searchText.isEmpty {
            return "magnifyingglass.circle.fill"
        } else {
            return "tray.fill"
        }
    }

    /// 空状态标题
    private var emptyStateTitle: String {
        if inventoryItems.isEmpty {
            return "背包空空如也"
        } else if !searchText.isEmpty {
            return "没有找到相关物品"
        } else {
            return "该分类暂无物品"
        }
    }

    /// 空状态副标题
    private var emptyStateSubtitle: String {
        if inventoryItems.isEmpty {
            return "去探索收集物资吧"
        } else if !searchText.isEmpty {
            return "尝试使用其他关键词或清除搜索"
        } else {
            return "切换其他分类查看物品"
        }
    }
}

// MARK: - 分类筛选按钮组件

struct CategoryFilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected ? color : ApocalypseTheme.cardBackground
            )
            .foregroundColor(
                isSelected ? .white : ApocalypseTheme.textSecondary
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1.5)
            )
        }
    }
}

// MARK: - 物品卡片组件

struct ItemCard: View {
    let item: InventoryItem
    let definition: ItemDefinition

    var body: some View {
        HStack(spacing: 16) {
            // 左侧图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 56, height: 56)

                Image(systemName: categoryIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(categoryColor)
            }

            // 中间信息
            VStack(alignment: .leading, spacing: 6) {
                // 第一行：名称 + 稀有度标签
                HStack(spacing: 8) {
                    Text(definition.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    RarityBadge(rarity: definition.rarity)
                }

                // 第二行：数量 + 重量
                HStack(spacing: 12) {
                    // 数量
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text("x\(item.quantity)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    // 重量
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text(MockExplorationData.formatWeight(definition.weight * Double(item.quantity)))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    // 品质（如果有）
                    if let quality = item.quality {
                        QualityBadge(quality: quality)
                    }
                }
            }

            Spacer()

            // 右侧按钮
            VStack(spacing: 8) {
                // 使用按钮
                Button(action: {
                    handleUseItem()
                }) {
                    Text("使用")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(6)
                }

                // 存储按钮
                Button(action: {
                    handleStoreItem()
                }) {
                    Text("存储")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(categoryColor.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Computed Properties

    /// 分类图标
    private var categoryIcon: String {
        switch definition.category {
        case .water:
            return "drop.fill"
        case .food:
            return "fork.knife"
        case .medical:
            return "cross.fill"
        case .material:
            return "cube.box.fill"
        case .tool:
            return "wrench.and.screwdriver.fill"
        case .weapon:
            return "shield.fill"
        }
    }

    /// 分类颜色
    private var categoryColor: Color {
        switch definition.category {
        case .water:
            return Color.blue
        case .food:
            return Color.brown
        case .medical:
            return ApocalypseTheme.danger
        case .material:
            return Color.gray
        case .tool:
            return Color.orange
        case .weapon:
            return ApocalypseTheme.primaryDark
        }
    }

    // MARK: - Actions

    private func handleUseItem() {
        print("🎒 使用物品: \(definition.name) (数量: \(item.quantity))")
        // TODO: 实现使用物品逻辑
    }

    private func handleStoreItem() {
        print("📦 存储物品: \(definition.name) (数量: \(item.quantity))")
        // TODO: 实现存储物品逻辑
    }
}

// MARK: - 稀有度徽章

struct RarityBadge: View {
    let rarity: ItemRarity

    var body: some View {
        Text(rarity.rawValue)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(rarityColor)
            .cornerRadius(4)
    }

    private var rarityColor: Color {
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
}

// MARK: - 品质徽章

struct QualityBadge: View {
    let quality: ItemQuality

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(qualityColor)

            Text(quality.description)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(qualityColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(qualityColor.opacity(0.2))
        .cornerRadius(4)
    }

    private var qualityColor: Color {
        switch quality {
        case .broken:
            return ApocalypseTheme.danger
        case .poor:
            return Color.orange
        case .normal:
            return Color.gray
        case .good:
            return Color.blue
        case .excellent:
            return Color.purple
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        BackpackView()
    }
}
