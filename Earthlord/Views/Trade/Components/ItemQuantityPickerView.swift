//
//  ItemQuantityPickerView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-26.
//
//  物品数量选择器视图

import SwiftUI

/// 物品数量选择器视图
struct ItemQuantityPickerView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - Properties

    let itemId: String
    let maxQuantity: Int
    let showMaxHint: Bool
    let onConfirm: (Int) -> Void

    // MARK: - State

    /// 选择的数量
    @State private var quantity: Int = 1

    // MARK: - Computed Properties

    /// 物品定义
    private var definition: ItemDefinition? {
        inventoryManager.getDefinition(for: itemId)
    }

    /// 物品名称
    private var itemName: String {
        definition?.name ?? itemId
    }

    /// 分类图标
    private var categoryIcon: String {
        guard let def = definition else { return "cube.box.fill" }
        switch def.category {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.fill"
        case .material: return "cube.box.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        case .weapon: return "shield.fill"
        }
    }

    /// 分类颜色
    private var categoryColor: Color {
        guard let def = definition else { return .gray }
        switch def.category {
        case .water: return .blue
        case .food: return .brown
        case .medical: return ApocalypseTheme.danger
        case .material: return .gray
        case .tool: return .orange
        case .weapon: return ApocalypseTheme.primaryDark
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 物品信息
                    itemInfoCard

                    // 数量选择
                    quantitySelector

                    // 快捷按钮
                    quickButtons

                    Spacer()

                    // 确认按钮
                    confirmButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .navigationTitle("选择数量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // MARK: - 物品信息卡片

    private var itemInfoCard: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: categoryIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(categoryColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(itemName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let def = definition {
                    Text(def.rarity.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(rarityColor(def.rarity))
                }

                if showMaxHint {
                    Text("库存中有 \(maxQuantity) 个")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 数量选择器

    private var quantitySelector: some View {
        VStack(spacing: 16) {
            Text("选择数量")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            HStack(spacing: 24) {
                // 减少按钮
                Button(action: {
                    if quantity > 1 {
                        quantity -= 1
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(quantity > 1 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.3))
                            .frame(width: 50, height: 50)

                        Image(systemName: "minus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(quantity <= 1)

                // 数量显示
                Text("\(quantity)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(minWidth: 100)

                // 增加按钮
                Button(action: {
                    if quantity < maxQuantity {
                        quantity += 1
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(quantity < maxQuantity ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.3))
                            .frame(width: 50, height: 50)

                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(quantity >= maxQuantity)
            }
        }
        .padding(20)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 快捷按钮

    private var quickButtons: some View {
        HStack(spacing: 12) {
            quickButton(value: 1, label: "1")
            quickButton(value: 10, label: "10")
            quickButton(value: 50, label: "50")
            quickButton(value: maxQuantity, label: "全部")
        }
    }

    private func quickButton(value: Int, label: String) -> some View {
        Button(action: {
            quantity = min(value, maxQuantity)
        }) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(quantity == value ? .white : ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(quantity == value ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(quantity == value ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - 确认按钮

    private var confirmButton: some View {
        Button(action: {
            onConfirm(quantity)
            dismiss()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))

                Text("确认添加 \(quantity) 个")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.primary)
            .cornerRadius(12)
        }
    }

    // MARK: - Helper

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

// MARK: - Preview

#Preview {
    ItemQuantityPickerView(
        itemId: "item_wood",
        maxQuantity: 100,
        showMaxHint: true
    ) { quantity in
        print("Selected quantity: \(quantity)")
    }
    .environmentObject(InventoryManager())
}
