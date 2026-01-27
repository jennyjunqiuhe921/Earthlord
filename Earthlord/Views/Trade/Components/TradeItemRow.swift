//
//  TradeItemRow.swift
//  Earthlord
//
//  Created by Claude on 2026-01-26.
//
//  交易物品行组件

import SwiftUI

/// 交易物品行组件
struct TradeItemRow: View {

    // MARK: - Environment

    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - Properties

    let item: TradeItem
    let showDelete: Bool
    var onDelete: (() -> Void)? = nil

    // MARK: - Computed Properties

    /// 物品定义
    private var definition: ItemDefinition? {
        inventoryManager.getDefinition(for: item.itemId)
    }

    /// 物品名称
    private var itemName: String {
        definition?.name ?? Self.itemIdToChineseName(item.itemId)
    }

    /// 分类图标
    private var categoryIcon: String {
        if let def = definition {
            switch def.category {
            case .water: return "drop.fill"
            case .food: return "fork.knife"
            case .medical: return "cross.fill"
            case .material: return "cube.box.fill"
            case .tool: return "wrench.and.screwdriver.fill"
            case .weapon: return "shield.fill"
            }
        }
        // 降级：根据物品ID推断图标
        return Self.inferIcon(from: item.itemId)
    }

    /// 分类颜色
    private var categoryColor: Color {
        if let def = definition {
            switch def.category {
            case .water: return .blue
            case .food: return .brown
            case .medical: return ApocalypseTheme.danger
            case .material: return .gray
            case .tool: return .orange
            case .weapon: return ApocalypseTheme.primaryDark
            }
        }
        // 降级：根据物品ID推断颜色
        return Self.inferColor(from: item.itemId)
    }

    /// 物品 ID 到中文名称的映射
    private static func itemIdToChineseName(_ itemId: String) -> String {
        let mapping: [String: String] = [
            "item_water": "矿泉水",
            "item_water_bottle": "矿泉水",
            "item_purified_water": "净化水",
            "item_biscuit": "饼干",
            "item_canned_food": "罐头食品",
            "item_energy_bar": "能量棒",
            "item_mre": "军用口粮",
            "item_bandage": "绷带",
            "item_first_aid_kit": "急救包",
            "item_antibiotics": "抗生素",
            "item_medicine": "抗生素药品",
            "item_painkillers": "止痛药",
            "item_surgical_kit": "手术套件",
            "item_matches": "火柴",
            "item_flashlight": "手电筒",
            "item_gas_mask": "防毒面具",
            "item_toolbox": "工具箱",
            "item_rope": "绳索",
            "item_compass": "指南针",
            "item_radio": "对讲机",
            "item_wood": "木头",
            "item_stone": "石头",
            "item_metal_scrap": "金属碎片",
            "item_scrap_metal": "废金属",
            "item_cloth": "布料",
            "item_electronics": "电子元件",
            "item_generator_parts": "发电机零件",
            "item_fuel": "燃料",
            "item_knife": "小刀",
            "item_bat": "棒球棒",
            "item_axe": "斧头"
        ]
        return mapping[itemId] ?? itemId
    }

    /// 从物品ID推断图标
    private static func inferIcon(from itemId: String) -> String {
        if itemId.contains("water") { return "drop.fill" }
        if itemId.contains("food") || itemId.contains("biscuit") || itemId.contains("canned") { return "fork.knife" }
        if itemId.contains("bandage") || itemId.contains("medicine") || itemId.contains("aid") { return "cross.fill" }
        if itemId.contains("wood") || itemId.contains("stone") || itemId.contains("metal") { return "cube.box.fill" }
        if itemId.contains("knife") || itemId.contains("axe") || itemId.contains("weapon") { return "shield.fill" }
        return "wrench.and.screwdriver.fill"
    }

    /// 从物品ID推断颜色
    private static func inferColor(from itemId: String) -> Color {
        if itemId.contains("water") { return .blue }
        if itemId.contains("food") || itemId.contains("biscuit") || itemId.contains("canned") { return .brown }
        if itemId.contains("bandage") || itemId.contains("medicine") || itemId.contains("aid") { return .red }
        if itemId.contains("knife") || itemId.contains("axe") || itemId.contains("weapon") { return .purple }
        return .gray
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: categoryIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(categoryColor)
            }

            // 名称和稀有度
            VStack(alignment: .leading, spacing: 2) {
                Text(itemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                if let def = definition {
                    Text(def.rarity.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(rarityColor(def.rarity))
                }
            }

            Spacer()

            // 数量
            Text("x\(item.quantity)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 删除按钮
            if showDelete, let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.danger.opacity(0.8))
                }
            }
        }
        .padding(.vertical, 8)
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
    VStack(spacing: 8) {
        TradeItemRow(
            item: TradeItem(itemId: "item_wood", quantity: 50),
            showDelete: true,
            onDelete: {}
        )

        TradeItemRow(
            item: TradeItem(itemId: "item_water", quantity: 10),
            showDelete: false
        )
    }
    .padding()
    .background(ApocalypseTheme.cardBackground)
    .environmentObject(InventoryManager())
}
