//
//  POIListView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-10.
//
//  附近兴趣点列表页面

import SwiftUI

struct POIListView: View {
    // MARK: - State

    /// 是否正在搜索
    @State private var isSearching = false

    /// 选中的分类（nil = 全部）
    @State private var selectedCategory: POIType? = nil

    /// POI 数据
    @State private var pois: [POI] = MockExplorationData.mockPOIs

    /// GPS 坐标（假数据）
    @State private var gpsCoordinate = (latitude: 22.54, longitude: 114.06)

    // MARK: - Computed Properties

    /// 筛选后的 POI 列表
    private var filteredPOIs: [POI] {
        if let category = selectedCategory {
            return pois.filter { $0.type == category }
        }
        return pois
    }

    /// 发现的 POI 数量
    private var discoveredCount: Int {
        pois.filter { $0.status == .discovered || $0.status == .looted }.count
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 状态栏
                    statusBar

                    // 搜索按钮
                    searchButton

                    // 筛选工具栏
                    filterToolbar

                    // POI 列表
                    poiList
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("附近地点")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        VStack(spacing: 8) {
            // GPS 坐标
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .foregroundColor(ApocalypseTheme.info)
                    .font(.system(size: 14))

                Text("GPS: \(String(format: "%.2f", gpsCoordinate.latitude)), \(String(format: "%.2f", gpsCoordinate.longitude))")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()
            }

            // 发现数量
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                    .font(.system(size: 16))

                Text("附近发现 \(discoveredCount) 个地点")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 搜索按钮

    private var searchButton: some View {
        Button(action: performSearch) {
            HStack(spacing: 12) {
                if isSearching {
                    // 加载动画
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)

                    Text("搜索中...")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text("搜索附近POI")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
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
        .disabled(isSearching)
    }

    // MARK: - 筛选工具栏

    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部" 按钮
                FilterButton(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil,
                    color: ApocalypseTheme.info
                ) {
                    selectedCategory = nil
                }

                // 各类型按钮
                ForEach([POIType.hospital, .supermarket, .factory, .pharmacy, .gasStation], id: \.self) { type in
                    FilterButton(
                        title: type.rawValue,
                        icon: poiIcon(for: type),
                        isSelected: selectedCategory == type,
                        color: poiColor(for: type)
                    ) {
                        selectedCategory = type
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - POI 列表

    private var poiList: some View {
        VStack(spacing: 16) {
            if filteredPOIs.isEmpty {
                // 空状态
                emptyState
            } else {
                ForEach(filteredPOIs) { poi in
                    POICard(poi: poi)
                        .onTapGesture {
                            handlePOITap(poi)
                        }
                }
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("未找到符合条件的地点")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helper Methods

    /// 执行搜索（模拟网络请求）
    private func performSearch() {
        isSearching = true

        // 模拟 1.5 秒的网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
            print("✅ 搜索完成")
        }
    }

    /// 处理 POI 点击
    private func handlePOITap(_ poi: POI) {
        print("🗺️ 点击了 POI: \(poi.name) (类型: \(poi.type.rawValue), 状态: \(poi.status.rawValue))")
        // TODO: 跳转到 POI 详情页
    }

    /// 获取 POI 图标
    private func poiIcon(for type: POIType) -> String {
        switch type {
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

    /// 获取 POI 颜色
    private func poiColor(for type: POIType) -> Color {
        switch type {
        case .hospital:
            return ApocalypseTheme.danger // 红色
        case .supermarket:
            return ApocalypseTheme.success // 绿色
        case .factory:
            return Color.gray // 灰色
        case .pharmacy:
            return Color.purple // 紫色
        case .gasStation:
            return Color.orange // 橙色
        default:
            return ApocalypseTheme.textMuted
        }
    }
}

// MARK: - 筛选按钮组件

struct FilterButton: View {
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

// MARK: - POI 卡片组件

struct POICard: View {
    let poi: POI

    var body: some View {
        HStack(spacing: 16) {
            // 左侧图标
            ZStack {
                Circle()
                    .fill(poiColor.opacity(0.2))
                    .frame(width: 56, height: 56)

                Image(systemName: poiIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(poiColor)
            }

            // 中间信息
            VStack(alignment: .leading, spacing: 6) {
                // 名称
                Text(poi.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 类型
                Text(poi.type.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(poiColor)

                // 状态标签
                HStack(spacing: 8) {
                    // 发现状态
                    statusBadge

                    // 物资状态
                    if poi.hasLoot {
                        lootBadge
                    }
                }
            }

            Spacer()

            // 右侧箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(poiColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Computed Properties

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

    /// POI 颜色
    private var poiColor: Color {
        switch poi.type {
        case .hospital:
            return ApocalypseTheme.danger
        case .supermarket:
            return ApocalypseTheme.success
        case .factory:
            return Color.gray
        case .pharmacy:
            return Color.purple
        case .gasStation:
            return Color.orange
        default:
            return ApocalypseTheme.textMuted
        }
    }

    /// 状态徽章
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.system(size: 10, weight: .bold))

            Text(poi.status.rawValue)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .foregroundColor(statusColor)
        .cornerRadius(6)
    }

    /// 物资徽章
    private var lootBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 10, weight: .bold))

            Text("有物资")
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ApocalypseTheme.warning.opacity(0.2))
        .foregroundColor(ApocalypseTheme.warning)
        .cornerRadius(6)
    }

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
}

// MARK: - Preview

#Preview {
    NavigationView {
        POIListView()
    }
}
