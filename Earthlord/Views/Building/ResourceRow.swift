//
//  ResourceRow.swift
//  Earthlord
//
//  资源需求显示行组件
//

import SwiftUI

/// 资源需求显示行
struct ResourceRow: View {

    // MARK: - Properties

    let resourceId: String
    let requiredAmount: Int
    let ownedAmount: Int
    let itemDefinition: ItemDefinition?

    // MARK: - Computed Properties

    private var isSufficient: Bool {
        ownedAmount >= requiredAmount
    }

    /// 资源名称中文映射（当 itemDefinition 为空时使用）
    private static let resourceNameMap: [String: String] = [
        "item_wood": "木头",
        "item_stone": "石头",
        "item_cloth": "布料",
        "item_scrap_metal": "废金属",
        "item_water": "水",
        "item_food": "食物",
        "item_medicine": "药品",
        "item_fuel": "燃料",
        "item_electronics": "电子元件",
        "item_glass": "玻璃"
    ]

    private var displayName: String {
        if let name = itemDefinition?.name {
            return name
        }
        return Self.resourceNameMap[resourceId] ?? resourceId
    }

    private var iconName: String {
        guard let definition = itemDefinition else { return "cube.fill" }
        switch definition.category {
        case .water:
            return "drop.fill"
        case .food:
            return "fork.knife"
        case .medical:
            return "cross.case.fill"
        case .material:
            return "cube.fill"
        case .tool:
            return "wrench.and.screwdriver.fill"
        case .weapon:
            return "hammer.fill"
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSufficient ? ApocalypseTheme.success.opacity(0.2) : ApocalypseTheme.danger.opacity(0.2))
                )

            // 名称
            Text(displayName)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 数量（拥有/需要）
            HStack(spacing: 4) {
                Text("\(ownedAmount)")
                    .fontWeight(.semibold)
                    .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)

                Text("/")
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("\(requiredAmount)")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .font(.subheadline)

            // 状态图标
            Image(systemName: isSufficient ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 8) {
        ResourceRow(
            resourceId: "wood",
            requiredAmount: 10,
            ownedAmount: 15,
            itemDefinition: nil
        )
        ResourceRow(
            resourceId: "stone",
            requiredAmount: 5,
            ownedAmount: 3,
            itemDefinition: nil
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
