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

    /// 探索结果数据
    let result: ExplorationResult

    /// 用于关闭弹窗
    @Environment(\.dismiss) var dismiss

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

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
                                ApocalypseTheme.primary.opacity(0.3),
                                ApocalypseTheme.primary.opacity(0)
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
                                    ApocalypseTheme.primary,
                                    ApocalypseTheme.primaryDark
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 20, x: 0, y: 10)

                    Image(systemName: "map.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            // 标题文字
            VStack(spacing: 8) {
                Text("探索完成！")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("成功探索新区域")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.vertical, 20)
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
                StatRow(
                    icon: "figure.walk",
                    iconColor: ApocalypseTheme.primary,
                    title: "行走距离",
                    thisSession: MockExplorationData.formatDistance(result.stats.distanceThisSession),
                    total: MockExplorationData.formatDistance(result.stats.totalDistance),
                    rank: result.stats.distanceRank
                )

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.2))

                // 探索面积
                StatRow(
                    icon: "map",
                    iconColor: ApocalypseTheme.success,
                    title: "探索面积",
                    thisSession: MockExplorationData.formatArea(result.stats.areaThisSession),
                    total: MockExplorationData.formatArea(result.stats.totalArea),
                    rank: result.stats.areaRank
                )

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
                    Text(MockExplorationData.formatDuration(result.stats.durationThisSession))
                        .font(.system(size: 16, weight: .bold))
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
            if result.stats.itemsFoundThisSession.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("未获得任何物品")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(ApocalypseTheme.cardBackground)
            } else {
                VStack(spacing: 12) {
                    ForEach(result.stats.itemsFoundThisSession) { loot in
                        if let definition = MockExplorationData.getItemDefinition(by: loot.definitionId) {
                            RewardItemRow(definition: definition, quantity: loot.quantity)

                            if loot.id != result.stats.itemsFoundThisSession.last?.id {
                                Divider()
                                    .background(ApocalypseTheme.textMuted.opacity(0.2))
                                    .padding(.horizontal, 20)
                            }
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

// MARK: - 统计行组件

struct StatRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let thisSession: String
    let total: String
    let rank: Int

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // 标题和数据
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 8) {
                    // 本次
                    HStack(spacing: 4) {
                        Text("本次:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text(thisSession)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    Text("·")
                        .foregroundColor(ApocalypseTheme.textMuted)

                    // 累计
                    HStack(spacing: 4) {
                        Text("累计:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text(total)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
            }

            Spacer()

            // 排名徽章
            RankBadge(rank: rank)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 排名徽章组件

struct RankBadge: View {
    let rank: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(rankColor)

            Text("#\(rank)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(rankColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(rankColor.opacity(0.2))
        .cornerRadius(8)
    }

    private var rankColor: Color {
        switch rank {
        case 1...10:
            return Color.orange
        case 11...50:
            return ApocalypseTheme.success
        default:
            return ApocalypseTheme.info
        }
    }
}

// MARK: - 奖励物品行组件

struct RewardItemRow: View {
    let definition: ItemDefinition
    let quantity: Int

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
                Text(definition.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("x\(quantity)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 右侧对勾
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(ApocalypseTheme.success)
        }
        .padding(.horizontal, 20)
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
}

// MARK: - Preview

#Preview {
    ExplorationResultView(result: MockExplorationData.mockExplorationResult)
}
