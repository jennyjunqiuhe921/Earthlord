//
//  POIDetailView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-10.
//
//  POI 详情页面

import SwiftUI

struct POIDetailView: View {
    // MARK: - Environment

    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    /// POI 数据
    let poi: POI

    /// 已搜刮的 POI ID 绑定
    @Binding var scavengedPOIIds: Set<String>

    /// 距离（米）
    @State private var distance: Double = 350.0

    /// 来源
    @State private var source: String = "地图数据"

    /// 是否显示搜刮结果
    @State private var showScavengeResult = false

    /// 搜刮获得的物品
    @State private var scavengedItems: [ItemLoot] = []

    /// 是否正在搜刮
    @State private var isScavenging = false

    /// 是否已搜刮此 POI
    private var isAlreadyScavenged: Bool {
        scavengedPOIIds.contains(poi.id)
    }

    // MARK: - Computed Properties

    /// POI 类型对应的渐变色
    private var typeGradient: LinearGradient {
        let colors = typeColors
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// POI 类型颜色
    private var typeColors: [Color] {
        switch poi.type {
        case .hospital:
            return [ApocalypseTheme.danger, ApocalypseTheme.danger.opacity(0.7)]
        case .supermarket:
            return [ApocalypseTheme.success, ApocalypseTheme.success.opacity(0.7)]
        case .factory:
            return [Color.gray, Color.gray.opacity(0.7)]
        case .pharmacy:
            return [Color.purple, Color.purple.opacity(0.7)]
        case .gasStation:
            return [Color.orange, Color.orange.opacity(0.7)]
        default:
            return [ApocalypseTheme.primary, ApocalypseTheme.primaryDark]
        }
    }

    /// POI 图标
    private var poiIcon: String {
        switch poi.type {
        case .hospital:
            return "cross.case.fill"
        case .supermarket:
            return "cart.fill"
        case .factory:
            return "building.2.fill"
        case .pharmacy:
            return "pills.fill"
        case .gasStation:
            return "fuelpump.fill"
        default:
            return "mappin.circle.fill"
        }
    }

    /// 危险等级文字
    private var dangerLevelText: String {
        switch poi.dangerLevel {
        case 1:
            return "安全"
        case 2:
            return "低危"
        case 3:
            return "中危"
        case 4:
            return "高危"
        case 5:
            return "极危"
        default:
            return "未知"
        }
    }

    /// 危险等级颜色
    private var dangerLevelColor: Color {
        switch poi.dangerLevel {
        case 1:
            return ApocalypseTheme.success
        case 2:
            return ApocalypseTheme.info
        case 3:
            return ApocalypseTheme.warning
        case 4, 5:
            return ApocalypseTheme.danger
        default:
            return ApocalypseTheme.textMuted
        }
    }

    /// 主按钮是否可点击
    private var isSearchButtonEnabled: Bool {
        !isAlreadyScavenged && poi.status != .looted && !isScavenging
    }

    /// 按钮文字
    private var buttonText: String {
        if isScavenging {
            return "搜寻中..."
        } else if isAlreadyScavenged {
            return "已搜空"
        } else {
            return "搜寻此POI"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大图区域
                    headerSection

                    // 内容区域
                    VStack(spacing: 20) {
                        // 描述卡片
                        descriptionCard

                        // 信息区域
                        infoSection

                        // 操作按钮区域
                        actionButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showScavengeResult) {
            POIScavengeResultView(
                poi: poi,
                items: scavengedItems,
                inventoryManager: inventoryManager,
                onDismiss: {
                    showScavengeResult = false
                }
            )
        }
    }

    // MARK: - 顶部大图区域

    private var headerSection: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 渐变背景
                typeGradient
                    .frame(height: geometry.size.height)

                // 大图标
                Image(systemName: poiIcon)
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 60)

                // 底部半透明黑色遮罩
                VStack(spacing: 8) {
                    // POI 名称
                    Text(poi.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    // POI 类型
                    Text(poi.type.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0),
                            Color.black.opacity(0.6)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(height: UIScreen.main.bounds.height / 3)
    }

    // MARK: - 描述卡片

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.info)

                Text("地点描述")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            Text(poi.description)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineSpacing(4)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 信息区域

    private var infoSection: some View {
        VStack(spacing: 16) {
            // 距离
            POIInfoRow(
                icon: "location.fill",
                iconColor: ApocalypseTheme.info,
                title: "距离",
                value: MockExplorationData.formatDistance(distance)
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 物资状态
            POIInfoRow(
                icon: (poi.hasLoot && !isAlreadyScavenged) ? "shippingbox.fill" : "xmark.bin.fill",
                iconColor: (poi.hasLoot && !isAlreadyScavenged) ? ApocalypseTheme.warning : ApocalypseTheme.textMuted,
                title: "物资状态",
                value: (poi.hasLoot && !isAlreadyScavenged) ? "有物资" : "已清空"
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 危险等级
            POIInfoRow(
                icon: "exclamationmark.triangle.fill",
                iconColor: dangerLevelColor,
                title: "危险等级",
                value: dangerLevelText,
                valueColor: dangerLevelColor
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 发现状态
            POIInfoRow(
                icon: isAlreadyScavenged ? "checkmark.circle.fill" : statusIcon,
                iconColor: isAlreadyScavenged ? ApocalypseTheme.success : statusColor,
                title: "发现状态",
                value: isAlreadyScavenged ? "已搜空" : poi.status.rawValue
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 来源
            POIInfoRow(
                icon: "map.fill",
                iconColor: ApocalypseTheme.primary,
                title: "来源",
                value: source
            )
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 操作按钮区域

    private var actionButtons: some View {
        VStack(spacing: 16) {
            // 主按钮：搜寻此POI
            Button(action: handleSearchPOI) {
                HStack(spacing: 12) {
                    if isScavenging {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: isAlreadyScavenged ? "checkmark.circle.fill" : "magnifyingglass.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                    }

                    Text(buttonText)
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    isSearchButtonEnabled
                        ? LinearGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.textMuted,
                                ApocalypseTheme.textMuted
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
                .cornerRadius(12)
                .shadow(
                    color: isSearchButtonEnabled
                        ? ApocalypseTheme.primary.opacity(0.3)
                        : Color.clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )
            }
            .disabled(!isSearchButtonEnabled)

            // 小按钮组
            HStack(spacing: 12) {
                // 标记已发现
                SecondaryActionButton(
                    icon: "eye.fill",
                    title: "标记已发现",
                    color: ApocalypseTheme.info
                ) {
                    handleMarkDiscovered()
                }

                // 标记无物资
                SecondaryActionButton(
                    icon: "xmark.bin.fill",
                    title: "标记无物资",
                    color: ApocalypseTheme.textMuted
                ) {
                    handleMarkNoLoot()
                }
            }
        }
    }

    // MARK: - Helper Properties

    /// 状态图标
    private var statusIcon: String {
        switch poi.status {
        case .undiscovered:
            return "questionmark.circle.fill"
        case .discovered:
            return "eye.fill"
        case .looted:
            return "checkmark.circle.fill"
        }
    }

    /// 状态颜色
    private var statusColor: Color {
        switch poi.status {
        case .undiscovered:
            return ApocalypseTheme.textMuted
        case .discovered:
            return ApocalypseTheme.info
        case .looted:
            return ApocalypseTheme.textSecondary
        }
    }

    // MARK: - Actions

    /// 搜寻 POI - 真正的搜刮逻辑
    private func handleSearchPOI() {
        guard !isAlreadyScavenged && !isScavenging else { return }

        isScavenging = true
        print("🔍 开始搜寻 POI: \(poi.name)")

        Task {
            // 生成物品
            let items = generateLoot(for: poi)
            scavengedItems = items

            // 添加到背包
            if !items.isEmpty {
                do {
                    try await inventoryManager.addItems(items)
                    print("✅ 物品已添加到背包: \(items.count) 件")
                } catch {
                    print("❌ 添加物品失败: \(error.localizedDescription)")
                }
            }

            // 标记为已搜刮
            await MainActor.run {
                scavengedPOIIds.insert(poi.id)
                isScavenging = false
                showScavengeResult = true
            }
        }
    }

    /// 根据 POI 类型和危险等级生成物品
    private func generateLoot(for poi: POI) -> [ItemLoot] {
        var items: [ItemLoot] = []

        // 根据 POI 类型决定物品池
        let itemPool: [(itemId: String, weight: Double)]
        switch poi.type {
        case .supermarket:
            itemPool = [
                ("item_water", 0.3),
                ("item_canned_food", 0.25),
                ("item_biscuit", 0.25),
                ("item_bandage", 0.1),
                ("item_matches", 0.1)
            ]
        case .hospital, .pharmacy:
            itemPool = [
                ("item_bandage", 0.3),
                ("item_first_aid_kit", 0.25),
                ("item_antibiotics", 0.15),
                ("item_water", 0.15),
                ("item_gas_mask", 0.15)
            ]
        case .factory:
            itemPool = [
                ("item_wood", 0.25),
                ("item_stone", 0.25),
                ("item_toolbox", 0.2),
                ("item_gas_mask", 0.15),
                ("item_matches", 0.15)
            ]
        case .gasStation:
            itemPool = [
                ("item_matches", 0.25),
                ("item_toolbox", 0.2),
                ("item_water", 0.2),
                ("item_wood", 0.2),
                ("item_flashlight", 0.15)
            ]
        default:
            itemPool = [
                ("item_wood", 0.3),
                ("item_stone", 0.3),
                ("item_water", 0.2),
                ("item_biscuit", 0.2)
            ]
        }

        // 根据危险等级决定物品数量（1-5）
        let baseCount = min(poi.dangerLevel + 1, 5)
        let itemCount = Int.random(in: max(1, baseCount - 1)...(baseCount + 1))

        // 随机选择物品
        for _ in 0..<itemCount {
            let roll = Double.random(in: 0...1)
            var cumulative: Double = 0

            for (itemId, weight) in itemPool {
                cumulative += weight
                if roll <= cumulative {
                    // 生成数量（1-5）
                    let quantity = Int.random(in: 1...5)

                    // 检查是否已有该物品
                    if let existingIndex = items.firstIndex(where: { $0.definitionId == itemId }) {
                        let existing = items[existingIndex]
                        items[existingIndex] = ItemLoot(
                            id: existing.id,
                            definitionId: existing.definitionId,
                            quantity: existing.quantity + quantity,
                            quality: existing.quality
                        )
                    } else {
                        items.append(ItemLoot(
                            id: UUID().uuidString,
                            definitionId: itemId,
                            quantity: quantity,
                            quality: nil
                        ))
                    }
                    break
                }
            }
        }

        return items
    }

    /// 标记已发现
    private func handleMarkDiscovered() {
        print("👁️ 标记 POI 已发现: \(poi.name)")
        // TODO: 更新 POI 状态为已发现
    }

    /// 标记无物资
    private func handleMarkNoLoot() {
        print("📦 标记 POI 无物资: \(poi.name)")
        // TODO: 更新 POI 的 hasLoot 为 false
    }
}

// MARK: - 信息行组件

struct POIInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    var valueColor: Color = ApocalypseTheme.textPrimary

    var body: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // 标题
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            // 值
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - 次要操作按钮组件

struct SecondaryActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))

                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.5), lineWidth: 1.5)
            )
        }
    }
}

// MARK: - POI 搜刮结果视图

struct POIScavengeResultView: View {
    let poi: POI
    let items: [ItemLoot]
    let inventoryManager: InventoryManager
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 标题
                VStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(ApocalypseTheme.success)

                    Text("搜刮完成")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(poi.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.top, 40)

                // 物品列表
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "gift.fill")
                            .foregroundColor(ApocalypseTheme.warning)
                        Text("获得物品")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Spacer()
                    }

                    if items.isEmpty {
                        Text("什么都没找到...")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(items, id: \.id) { item in
                            HStack {
                                // 物品图标
                                ZStack {
                                    Circle()
                                        .fill(categoryColor(for: item.definitionId).opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: categoryIcon(for: item.definitionId))
                                        .foregroundColor(categoryColor(for: item.definitionId))
                                }

                                // 物品名称
                                VStack(alignment: .leading) {
                                    Text(itemName(for: item.definitionId))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(ApocalypseTheme.textPrimary)
                                    Text(itemRarity(for: item.definitionId))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(ApocalypseTheme.textMuted)
                                }

                                Spacer()

                                // 数量
                                Text("x\(item.quantity)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(ApocalypseTheme.textSecondary)

                                // 已添加标记
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(ApocalypseTheme.success)
                            }
                            .padding(.vertical, 8)
                        }
                    }

                    // 提示
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.success)
                        Text("已添加到背包")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ApocalypseTheme.success)
                    }
                    .padding(.top, 8)
                }
                .padding(16)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)

                Spacer()

                // 确认按钮
                Button(action: onDismiss) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("确认")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Helper Methods

    private func itemName(for itemId: String) -> String {
        if let def = inventoryManager.getDefinition(for: itemId) {
            return def.name
        }
        let mapping: [String: String] = [
            "item_water": "矿泉水",
            "item_canned_food": "罐头食品",
            "item_biscuit": "饼干",
            "item_bandage": "绷带",
            "item_first_aid_kit": "急救包",
            "item_antibiotics": "抗生素",
            "item_matches": "火柴",
            "item_flashlight": "手电筒",
            "item_gas_mask": "防毒面具",
            "item_toolbox": "工具箱",
            "item_wood": "木头",
            "item_stone": "石头"
        ]
        return mapping[itemId] ?? itemId
    }

    private func itemRarity(for itemId: String) -> String {
        if let def = inventoryManager.getDefinition(for: itemId) {
            return def.rarity.rawValue
        }
        return "普通"
    }

    private func categoryIcon(for itemId: String) -> String {
        if itemId.contains("water") { return "drop.fill" }
        if itemId.contains("food") || itemId.contains("biscuit") || itemId.contains("canned") { return "fork.knife" }
        if itemId.contains("bandage") || itemId.contains("aid") || itemId.contains("antibiotic") { return "cross.fill" }
        if itemId.contains("wood") || itemId.contains("stone") { return "cube.box.fill" }
        return "wrench.and.screwdriver.fill"
    }

    private func categoryColor(for itemId: String) -> Color {
        if itemId.contains("water") { return .blue }
        if itemId.contains("food") || itemId.contains("biscuit") || itemId.contains("canned") { return .brown }
        if itemId.contains("bandage") || itemId.contains("aid") || itemId.contains("antibiotic") { return .red }
        if itemId.contains("wood") || itemId.contains("stone") { return .gray }
        return .orange
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        POIDetailView(
            poi: MockExplorationData.mockPOIs[0],
            scavengedPOIIds: .constant([])
        )
        .environmentObject(InventoryManager())
    }
}
