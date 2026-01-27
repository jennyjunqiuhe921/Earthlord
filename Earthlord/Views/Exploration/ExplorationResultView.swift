//
//  ExplorationResultView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-10.
//
//  探索结束后显示收获的弹窗页面

import SwiftUI

struct ExplorationResultView: View {
    // MARK: - Properties

    /// 探索结果数据（可选，失败时为 nil）
    let result: ExplorationResult?

    /// 错误信息（可选，成功时为 nil）
    let errorMessage: String?

    /// 重试回调
    let onRetry: (() -> Void)?

    /// 用于关闭弹窗
    @Environment(\.dismiss) var dismiss

    /// 背包管理器（用于获取物品定义）
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - Initializers

    /// 成功状态初始化
    init(result: ExplorationResult) {
        self.result = result
        self.errorMessage = nil
        self.onRetry = nil
    }

    /// 失败状态初始化
    init(errorMessage: String, onRetry: (() -> Void)? = nil) {
        self.result = nil
        self.errorMessage = errorMessage
        self.onRetry = onRetry
    }

    // MARK: - Computed Properties

    /// 是否为错误状态
    private var isError: Bool {
        result == nil
    }

    // MARK: - Animation State

    /// 动画用的距离数值
    @State private var animatedDistance: Double = 0

    /// 已显示的奖励物品索引
    @State private var visibleRewardIndices: Set<Int> = []

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            if isError {
                // 错误状态
                errorStateView
            } else {
                // 成功状态
                successStateView
            }
        }
        .onAppear {
            if !isError {
                startAnimations()
            }
        }
    }

    // MARK: - Success State View

    private var successStateView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 成就标题
                achievementHeader

                // 统计数据卡片
                statsCard

                // 奖励物品卡片
                rewardItemsCard

                // 确认按钮
                confirmButton

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Error State View

    private var errorStateView: some View {
        VStack(spacing: 30) {
            Spacer()

            // 错误图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.danger.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 错误标题
            Text("探索失败")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 错误信息
            Text(errorMessage ?? "未知错误")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 按钮组
            VStack(spacing: 12) {
                // 重试按钮（如果有重试回调）
                if let onRetry = onRetry {
                    Button(action: {
                        onRetry()
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 20, weight: .bold))

                            Text("重试")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ApocalypseTheme.primary,
                                    ApocalypseTheme.primaryDark
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }

                // 关闭按钮
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .bold))

                        Text(onRetry == nil ? "确认" : "取消")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1.5)
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.vertical, 40)
    }

    // MARK: - Formatting Helpers

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f米", meters)
        } else {
            return String(format: "%.2f公里", meters / 1000)
        }
    }

    /// 格式化时长
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)分\(secs)秒"
        } else {
            return "\(secs)秒"
        }
    }

    // MARK: - Animation Methods

    /// 启动所有动画
    private func startAnimations() {
        guard let result = result else { return }

        // 延迟 0.3 秒后开始数字跳动动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animatedDistance = result.stats.distanceThisSession
            }
        }

        // 延迟 0.5 秒后开始显示奖励物品（每个间隔 0.2 秒）
        for (index, _) in result.stats.itemsFoundThisSession.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(index) * 0.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    _ = visibleRewardIndices.insert(index)
                }
            }
        }
    }

    // MARK: - 成就标题

    private var achievementHeader: some View {
        VStack(spacing: 20) {
            // 大图标（带动画效果）
            ZStack {
                // 背景光圈
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                tierColor.opacity(0.3),
                                tierColor.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // 主图标
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    tierColor,
                                    tierColor.opacity(0.7)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: tierColor.opacity(0.4), radius: 20, x: 0, y: 10)

                    Image(systemName: result?.rewardTier.icon ?? "map.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            // 标题文字
            VStack(spacing: 8) {
                Text("探索完成！")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 奖励等级
                if let tier = result?.rewardTier {
                    HStack(spacing: 8) {
                        Image(systemName: tier.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(tierColor)

                        Text(tier.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(tierColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(tierColor.opacity(0.2))
                    .cornerRadius(20)
                }
            }
        }
        .padding(.vertical, 20)
    }

    /// 奖励等级对应的颜色
    private var tierColor: Color {
        guard let tier = result?.rewardTier else { return ApocalypseTheme.primary }
        switch tier {
        case .none:
            return Color.gray
        case .bronze:
            return Color.brown
        case .silver:
            return Color.gray
        case .gold:
            return Color.yellow
        case .diamond:
            return Color.cyan
        }
    }

    // MARK: - 统计数据卡片

    private var statsCard: some View {
        VStack(spacing: 0) {
            // 卡片标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.info)

                Text("探索统计")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.cardBackground)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))

            // 统计数据
            VStack(spacing: 16) {
                // 行走距离
                HStack(spacing: 12) {
                    // 图标
                    ZStack {
                        Circle()
                            .fill(ApocalypseTheme.primary.opacity(0.2))
                            .frame(width: 40, height: 40)

                        Image(systemName: "figure.walk")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.primary)
                    }

                    // 标题
                    Text("行走距离")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    // 数值
                    Text(formatDistance(animatedDistance))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .padding(.horizontal, 20)

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.2))

                // 探索时长
                HStack(spacing: 12) {
                    // 图标
                    ZStack {
                        Circle()
                            .fill(ApocalypseTheme.warning.opacity(0.2))
                            .frame(width: 40, height: 40)

                        Image(systemName: "clock.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.warning)
                    }

                    // 标题
                    Text("探索时长")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    // 时长
                    Text(formatDuration(result!.stats.durationThisSession))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .padding(.horizontal, 20)

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.2))

                // 获得物品数量
                HStack(spacing: 12) {
                    // 图标
                    ZStack {
                        Circle()
                            .fill(ApocalypseTheme.success.opacity(0.2))
                            .frame(width: 40, height: 40)

                        Image(systemName: "gift.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.success)
                    }

                    // 标题
                    Text("获得物品")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    // 数量
                    Text("\(result!.stats.itemsFoundThisSession.count) 件")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
            .background(ApocalypseTheme.cardBackground)
        }
        .cornerRadius(12)
    }

    // MARK: - 奖励物品卡片

    private var rewardItemsCard: some View {
        VStack(spacing: 0) {
            // 卡片标题
            HStack {
                Image(systemName: "gift.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("获得物品")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.cardBackground)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))

            // 物品列表
            if result!.stats.itemsFoundThisSession.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("距离不足，未获得物品")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("行走超过200米才能获得奖励")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(ApocalypseTheme.cardBackground)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(result!.stats.itemsFoundThisSession.enumerated()), id: \.element.id) { index, loot in
                        let definition = inventoryManager.getDefinition(for: loot.definitionId)
                        RewardItemRow(
                            loot: loot,
                            definition: definition,
                            isVisible: visibleRewardIndices.contains(index)
                        )

                        if loot.id != result!.stats.itemsFoundThisSession.last?.id {
                            Divider()
                                .background(ApocalypseTheme.textMuted.opacity(0.2))
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 12)
                .background(ApocalypseTheme.cardBackground)

                // 底部提示
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.success)

                    Text("已添加到背包")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.success)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.success.opacity(0.1))
            }
        }
        .cornerRadius(12)
    }

    // MARK: - 确认按钮

    private var confirmButton: some View {
        Button(action: {
            dismiss()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))

                Text("确认")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        ApocalypseTheme.primary,
                        ApocalypseTheme.primaryDark
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - 奖励物品行组件

struct RewardItemRow: View {
    let loot: ItemLoot
    let definition: ItemDefinition?
    let isVisible: Bool

    @State private var checkmarkScale: CGFloat = 0.1

    /// 显示的物品名称（优先使用自定义名称，然后是定义名称，最后是中文映射或 ID）
    private var displayName: String {
        if let customName = loot.customName, !customName.isEmpty {
            return customName
        }
        if let def = definition {
            return def.name
        }
        // 降级：将常见物品 ID 映射到中文名称
        return Self.itemIdToChineseName(loot.definitionId)
    }

    /// 物品 ID 到中文名称的映射（降级方案）
    private static func itemIdToChineseName(_ itemId: String) -> String {
        let mapping: [String: String] = [
            // 水类
            "item_water": "矿泉水",
            "item_water_bottle": "矿泉水",
            "item_purified_water": "净化水",
            // 食物类
            "item_biscuit": "饼干",
            "item_canned_food": "罐头食品",
            "item_energy_bar": "能量棒",
            "item_mre": "军用口粮",
            // 医疗类
            "item_bandage": "绷带",
            "item_first_aid_kit": "急救包",
            "item_antibiotics": "抗生素",
            "item_medicine": "抗生素药品",
            "item_painkillers": "止痛药",
            "item_surgical_kit": "手术套件",
            // 工具类
            "item_matches": "火柴",
            "item_flashlight": "手电筒",
            "item_gas_mask": "防毒面具",
            "item_toolbox": "工具箱",
            "item_rope": "绳索",
            "item_compass": "指南针",
            "item_radio": "对讲机",
            // 材料类
            "item_wood": "木头",
            "item_stone": "石头",
            "item_metal_scrap": "金属碎片",
            "item_scrap_metal": "废金属",
            "item_cloth": "布料",
            "item_electronics": "电子元件",
            "item_generator_parts": "发电机零件",
            "item_fuel": "燃料",
            // 武器类
            "item_knife": "小刀",
            "item_bat": "棒球棒",
            "item_axe": "斧头"
        ]
        return mapping[itemId] ?? itemId
    }

    /// 显示的稀有度
    private var displayRarity: String {
        if let customRarity = loot.customRarity, !customRarity.isEmpty {
            return customRarity
        }
        return definition?.rarity.rawValue ?? "普通"
    }

    var body: some View {
        HStack(spacing: 16) {
            // 左侧图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: categoryIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(categoryColor)
            }

            // 中间信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // AI 物品标识
                    if loot.customName != nil {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.purple)
                    }

                    // 稀有度标签
                    Text(displayRarity)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rarityColor)
                        .cornerRadius(4)
                }

                Text("x\(loot.quantity)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 右侧对勾 - 带弹跳效果
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(checkmarkScale)
        }
        .padding(.horizontal, 20)
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -20)
        .onChange(of: isVisible) { visible in
            if visible {
                // 弹跳动画
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.2)) {
                    checkmarkScale = 1.0
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// 分类图标
    private var categoryIcon: String {
        // 先检查自定义分类
        if let customCategory = loot.customCategory {
            let lowercased = customCategory.lowercased()
            if lowercased.contains("水") || lowercased.contains("water") { return "drop.fill" }
            if lowercased.contains("食") || lowercased.contains("food") { return "fork.knife" }
            if lowercased.contains("医") || lowercased.contains("medical") { return "cross.fill" }
            if lowercased.contains("工具") || lowercased.contains("tool") { return "wrench.and.screwdriver.fill" }
            if lowercased.contains("武") || lowercased.contains("weapon") { return "shield.fill" }
        }

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
        // 先检查自定义分类
        if let customCategory = loot.customCategory {
            let lowercased = customCategory.lowercased()
            if lowercased.contains("水") || lowercased.contains("water") { return .blue }
            if lowercased.contains("食") || lowercased.contains("food") { return .brown }
            if lowercased.contains("医") || lowercased.contains("medical") { return ApocalypseTheme.danger }
            if lowercased.contains("工具") || lowercased.contains("tool") { return .orange }
            if lowercased.contains("武") || lowercased.contains("weapon") { return ApocalypseTheme.primaryDark }
        }

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

    /// 稀有度颜色
    private var rarityColor: Color {
        // 先检查自定义稀有度
        if let customRarity = loot.customRarity {
            let lowercased = customRarity.lowercased()
            if lowercased.contains("传说") || lowercased.contains("legendary") { return .orange }
            if lowercased.contains("史诗") || lowercased.contains("epic") { return .purple }
            if lowercased.contains("稀有") || lowercased.contains("rare") { return .blue }
            if lowercased.contains("罕见") || lowercased.contains("uncommon") { return .green }
            return .gray
        }

        guard let def = definition else { return .gray }
        switch def.rarity {
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
    ExplorationResultView(result: ExplorationResult(
        id: "preview",
        userId: "user1",
        startTime: Date(),
        endTime: Date(),
        stats: ExplorationStats(
            distanceThisSession: 1500,
            durationThisSession: 900,
            itemsFoundThisSession: [],
            totalDistance: 10000,
            totalDuration: 3600
        ),
        rewardTier: .gold
    ))
    .environmentObject(InventoryManager())
}
