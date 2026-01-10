//
//  POIDetailView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-10.
//
//  POI 详情页面

import SwiftUI

struct POIDetailView: View {
    // MARK: - Properties

    /// POI 数据
    let poi: POI

    /// 假数据：距离
    @State private var distance: Double = 350.0 // 米

    /// 假数据：来源
    @State private var source: String = "地图数据"

    /// 是否显示探索结果页（TODO）
    @State private var showExplorationResult = false

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
        poi.status != .looted
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
        .sheet(isPresented: $showExplorationResult) {
            ExplorationResultView(result: MockExplorationData.mockExplorationResult)
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
                icon: poi.hasLoot ? "shippingbox.fill" : "xmark.bin.fill",
                iconColor: poi.hasLoot ? ApocalypseTheme.warning : ApocalypseTheme.textMuted,
                title: "物资状态",
                value: poi.hasLoot ? "有物资" : "已清空"
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
                icon: statusIcon,
                iconColor: statusColor,
                title: "发现状态",
                value: poi.status.rawValue
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
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 20, weight: .bold))

                    Text(poi.status == .looted ? "已搜空" : "搜寻此POI")
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

    /// 搜寻 POI
    private func handleSearchPOI() {
        print("🔍 开始搜寻 POI: \(poi.name)")
        // TODO: 显示探索结果页面
        showExplorationResult = true
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

// MARK: - Preview

#Preview {
    NavigationView {
        POIDetailView(poi: MockExplorationData.mockPOIs[0])
    }
}
