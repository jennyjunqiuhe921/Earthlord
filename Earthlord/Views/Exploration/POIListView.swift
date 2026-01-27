//
//  POIListView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-10.
//
//  附近兴趣点列表页面

import SwiftUI
import CoreLocation
import Combine

struct POIListView: View {
    // MARK: - Environment

    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - State

    /// 是否正在搜索
    @State private var isSearching = false

    /// 选中的分类（nil = 全部）
    @State private var selectedCategory: POIType? = nil

    /// POI 数据
    @State private var pois: [POI] = []

    /// 已搜刮的 POI ID
    @State private var scavengedPOIIds: Set<String> = []

    /// GPS 坐标
    @State private var gpsCoordinate: CLLocationCoordinate2D? = nil

    /// 位置管理器
    @StateObject private var locationManager = SimpleLocationManager()

    /// 搜索按钮缩放
    @State private var searchButtonScale: CGFloat = 1.0

    /// POI 列表项是否已显示
    @State private var poiItemsAppeared: Set<String> = []

    // MARK: - Computed Properties

    /// 筛选后的 POI 列表
    private var filteredPOIs: [POI] {
        var result = pois

        // 更新已搜刮状态
        result = result.map { poi in
            var updatedPOI = poi
            if scavengedPOIIds.contains(poi.id) {
                updatedPOI.status = .looted
                updatedPOI.hasLoot = false
            }
            return updatedPOI
        }

        if let category = selectedCategory {
            return result.filter { $0.type == category }
        }
        return result
    }

    /// 发现的 POI 数量
    private var discoveredCount: Int {
        pois.count
    }

    /// 格式化坐标显示
    private var coordinateText: String {
        if let coord = gpsCoordinate {
            return String(format: "%.2f, %.2f", coord.latitude, coord.longitude)
        }
        return "获取中..."
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
        .onAppear {
            locationManager.requestPermission()
            // 初始化时如果有位置就更新坐标
            if let location = locationManager.location {
                gpsCoordinate = location.coordinate
            }
        }
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        VStack(spacing: 8) {
            // GPS 坐标
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .foregroundColor(ApocalypseTheme.info)
                    .font(.system(size: 14))

                Text("GPS: \(coordinateText)")
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
            .scaleEffect(searchButtonScale)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: searchButtonScale)
        }
        .disabled(isSearching)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    searchButtonScale = 0.95
                }
                .onEnded { _ in
                    searchButtonScale = 1.0
                }
        )
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
                ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { index, poi in
                    NavigationLink(destination: POIDetailView(poi: poi, scavengedPOIIds: $scavengedPOIIds)) {
                        POICard(poi: poi)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(poiItemsAppeared.contains(poi.id) ? 1 : 0)
                    .offset(y: poiItemsAppeared.contains(poi.id) ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.1), value: poiItemsAppeared)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                            poiItemsAppeared.insert(poi.id)
                        }
                    }
                }
            }
        }
        .onChange(of: selectedCategory) { _ in
            // 切换分类时重置动画
            poiItemsAppeared.removeAll()
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60, weight: .medium))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 主标题
            Text(emptyStateTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 副标题
            Text(emptyStateSubtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Empty State Helpers

    /// 空状态图标
    private var emptyStateIcon: String {
        if pois.isEmpty {
            return "map.fill"
        } else {
            return "magnifyingglass.circle.fill"
        }
    }

    /// 空状态标题
    private var emptyStateTitle: String {
        if pois.isEmpty {
            return "附近暂无兴趣点"
        } else {
            return "没有找到该类型的地点"
        }
    }

    /// 空状态副标题
    private var emptyStateSubtitle: String {
        if pois.isEmpty {
            return "点击搜索按钮发现周围的废墟"
        } else {
            return "尝试切换其他分类或清除筛选条件"
        }
    }

    // MARK: - Helper Methods

    /// 执行真实 POI 搜索
    private func performSearch() {
        isSearching = true

        Task {
            // 获取当前位置
            guard let location = locationManager.location else {
                print("❌ 无法获取当前位置")
                isSearching = false
                return
            }

            gpsCoordinate = location.coordinate
            print("📍 当前位置: \(location.coordinate.latitude), \(location.coordinate.longitude)")

            // 搜索附近 POI
            let foundPOIs = await POISearchManager.shared.searchNearbyPOIs(
                center: location.coordinate,
                radius: 1000,  // 1公里范围
                maxResults: 10
            )

            await MainActor.run {
                // 更新 POI 列表，保留已搜刮状态
                pois = foundPOIs.map { poi in
                    var updatedPOI = poi
                    if scavengedPOIIds.contains(poi.id) {
                        updatedPOI.status = .looted
                        updatedPOI.hasLoot = false
                    }
                    return updatedPOI
                }
                isSearching = false
                print("✅ 搜索完成，找到 \(pois.count) 个 POI")
            }
        }
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

// MARK: - 简单位置管理器

class SimpleLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        POIListView()
            .environmentObject(InventoryManager())
    }
}
