//
//  ItemPickerView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-26.
//
//  物品选择器视图

import SwiftUI

/// 选择器模式
enum ItemPickerMode {
    case inventory      // 从库存选择（用于选择要出的物品）
    case allItems       // 从所有物品选择（用于选择想要的物品）
}

/// 物品选择器视图
struct ItemPickerView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - Properties

    let mode: ItemPickerMode
    let onSelect: (String, Int) -> Void

    // MARK: - State

    /// 搜索文本
    @State private var searchText = ""

    /// 选中的分类
    @State private var selectedCategory: ItemCategory? = nil

    /// 选中的物品ID
    @State private var selectedItemId: String?

    /// 是否显示数量选择器
    @State private var showingQuantityPicker = false

    // MARK: - Computed Properties

    /// 筛选后的物品列表
    private var filteredItems: [PickerItem] {
        var items: [PickerItem] = []

        switch mode {
        case .inventory:
            // 从库存筛选
            for inventoryItem in inventoryManager.inventoryItems {
                if let def = inventoryManager.getDefinition(for: inventoryItem.definitionId) {
                    items.append(PickerItem(
                        id: inventoryItem.definitionId,
                        name: def.name,
                        category: def.category,
                        rarity: def.rarity,
                        maxQuantity: inventoryItem.quantity
                    ))
                }
            }

        case .allItems:
            // 从所有物品定义
            for def in inventoryManager.getAllDefinitions() {
                items.append(PickerItem(
                    id: def.id,
                    name: def.name,
                    category: def.category,
                    rarity: def.rarity,
                    maxQuantity: 999
                ))
            }
        }

        // 去重
        var seen = Set<String>()
        items = items.filter { item in
            if seen.contains(item.id) {
                return false
            }
            seen.insert(item.id)
            return true
        }

        // 按分类筛选
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }

        // 按搜索文本筛选
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return items.sorted { $0.name < $1.name }
    }

    /// 选中物品的最大数量
    private var selectedItemMaxQuantity: Int {
        filteredItems.first { $0.id == selectedItemId }?.maxQuantity ?? 1
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 搜索框
                    searchBar

                    // 分类筛选
                    categoryFilter

                    // 物品列表
                    if filteredItems.isEmpty {
                        emptyView
                    } else {
                        itemList
                    }
                }
            }
            .navigationTitle(mode == .inventory ? "选择库存物品" : "选择物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .sheet(isPresented: $showingQuantityPicker) {
                if let itemId = selectedItemId {
                    ItemQuantityPickerView(
                        itemId: itemId,
                        maxQuantity: selectedItemMaxQuantity,
                        showMaxHint: mode == .inventory
                    ) { quantity in
                        onSelect(itemId, quantity)
                        dismiss()
                    }
                    .environmentObject(inventoryManager)
                }
            }
        }
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
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - 分类筛选

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部
                categoryButton(title: "全部", category: nil, color: ApocalypseTheme.info)

                // 各分类
                categoryButton(title: "食物", category: .food, color: .brown)
                categoryButton(title: "水", category: .water, color: .blue)
                categoryButton(title: "材料", category: .material, color: .gray)
                categoryButton(title: "工具", category: .tool, color: .orange)
                categoryButton(title: "医疗", category: .medical, color: ApocalypseTheme.danger)
                categoryButton(title: "武器", category: .weapon, color: ApocalypseTheme.primaryDark)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func categoryButton(title: String, category: ItemCategory?, color: Color) -> some View {
        Button(action: {
            selectedCategory = category
        }) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selectedCategory == category ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selectedCategory == category ? color : ApocalypseTheme.cardBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedCategory == category ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(mode == .inventory ? "库存中没有该类物品" : "没有找到该物品")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }

    // MARK: - 物品列表

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredItems) { item in
                    Button(action: {
                        selectedItemId = item.id
                        showingQuantityPicker = true
                    }) {
                        HStack(spacing: 12) {
                            // 图标
                            ZStack {
                                Circle()
                                    .fill(categoryColor(item.category).opacity(0.2))
                                    .frame(width: 40, height: 40)

                                Image(systemName: categoryIcon(item.category))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(categoryColor(item.category))
                            }

                            // 名称和稀有度
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(ApocalypseTheme.textPrimary)

                                Text(item.rarity.rawValue)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(rarityColor(item.rarity))
                            }

                            Spacer()

                            // 库存数量（库存模式）
                            if mode == .inventory {
                                Text("库存: \(item.maxQuantity)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                        .padding(12)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Helper Methods

    private func categoryIcon(_ category: ItemCategory) -> String {
        switch category {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.fill"
        case .material: return "cube.box.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        case .weapon: return "shield.fill"
        }
    }

    private func categoryColor(_ category: ItemCategory) -> Color {
        switch category {
        case .water: return .blue
        case .food: return .brown
        case .medical: return ApocalypseTheme.danger
        case .material: return .gray
        case .tool: return .orange
        case .weapon: return ApocalypseTheme.primaryDark
        }
    }

    private func rarityColor(_ rarity: ItemRarity) -> Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

// MARK: - 选择器物品模型

private struct PickerItem: Identifiable {
    let id: String
    let name: String
    let category: ItemCategory
    let rarity: ItemRarity
    let maxQuantity: Int
}

// MARK: - Preview

#Preview {
    ItemPickerView(mode: .inventory) { itemId, quantity in
        print("Selected: \(itemId) x \(quantity)")
    }
    .environmentObject(InventoryManager())
}
