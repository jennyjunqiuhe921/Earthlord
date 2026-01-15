//
//  ScavengeResultView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-13.
//
//  搜刮结果展示视图
//

import SwiftUI
import CoreLocation

/// 搜刮结果视图
/// 显示搜刮 POI 获得的物品
struct ScavengeResultView: View {

    // MARK: - Properties

    /// 搜刮的 POI
    let poi: POI

    /// 获得的物品列表
    let items: [ItemLoot]

    /// 关闭回调
    let onDismiss: () -> Void

    /// 背包管理器（用于获取物品定义）
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - State

    @State private var showItems = false
    @State private var itemsAppeared: Set<String> = []

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

                    Text("\(items.count) 件")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // 物品列表
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            itemRow(item: item, index: index)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .frame(maxHeight: 250)

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

            // 名称
            VStack(alignment: .leading, spacing: 4) {
                Text(poi.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                Text(poi.type.rawValue)
                    .font(.system(size: 13))
                    .foregroundColor(poiColor)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    /// 物品行
    private func itemRow(item: ItemLoot, index: Int) -> some View {
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

    /// 稀有度颜色
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

    /// 物品分类图标
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
            name: "废弃的沃尔玛超市",
            type: .supermarket,
            coordinate: .init(latitude: 22.54, longitude: 114.06),
            status: .looted,
            hasLoot: false,
            description: "已被搜刮",
            dangerLevel: 2
        ),
        items: [
            ItemLoot(id: "1", definitionId: "water_bottle", quantity: 2, quality: nil),
            ItemLoot(id: "2", definitionId: "canned_food", quantity: 1, quality: nil),
            ItemLoot(id: "3", definitionId: "bandage", quantity: 3, quality: nil)
        ],
        onDismiss: { print("关闭") }
    )
    .environmentObject(InventoryManager())
}
