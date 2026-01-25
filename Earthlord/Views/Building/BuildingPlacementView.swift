//
//  BuildingPlacementView.swift
//  Earthlord
//
//  建造确认页 - 资源检查和位置选择
//

import SwiftUI
import MapKit

/// 建造确认页
struct BuildingPlacementView: View {

    // MARK: - Environment

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var buildingManager: BuildingManager
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - Properties

    let template: BuildingTemplate
    let territory: Territory
    let existingBuildings: [PlayerBuilding]

    // MARK: - State

    @State private var selectedCoordinate: CLLocationCoordinate2D? = nil
    @State private var showLocationPicker = false
    @State private var isBuilding = false
    @State private var errorMessage: String? = nil
    @State private var showError = false

    // MARK: - Computed Properties

    private var categoryColor: Color {
        switch template.category {
        case .survival:
            return .orange
        case .storage:
            return .blue
        case .production:
            return .green
        case .energy:
            return .yellow
        }
    }

    private var canBuild: Bool {
        // 必须选择位置
        guard selectedCoordinate != nil else { return false }

        // 检查资源是否足够
        for resource in template.resources {
            let owned = getOwnedAmount(for: resource.resourceId)
            if owned < resource.amount {
                return false
            }
        }

        return true
    }

    private var buildTimeFormatted: String {
        let totalSeconds = template.buildTime
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// 领地坐标（转换为 GCJ-02）
    private var territoryCoordinates: [CLLocationCoordinate2D] {
        let coords = territory.toCoordinates()
        return CoordinateConverter.wgs84ToGcj02(coords)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 建筑预览
                    buildingPreview

                    // 位置选择
                    locationSection

                    // 资源消耗
                    resourcesSection

                    // 建造时间
                    buildTimeSection

                    // 确认按钮
                    confirmButton
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("确认建造")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                locationPickerSheet
            }
            .alert("建造失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }

    // MARK: - Subviews

    /// 建筑预览
    private var buildingPreview: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: template.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(categoryColor)
            }

            // 信息
            VStack(alignment: .leading, spacing: 6) {
                Text(template.name)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 8) {
                    Text(template.category.displayName)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("T\(template.tier)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(categoryColor)
                        .cornerRadius(4)
                }
            }

            Spacer()
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 位置选择区域
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建造位置")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Button {
                showLocationPicker = true
            } label: {
                HStack {
                    Image(systemName: selectedCoordinate != nil ? "mappin.circle.fill" : "mappin.circle")
                        .font(.title2)
                        .foregroundColor(selectedCoordinate != nil ? ApocalypseTheme.success : ApocalypseTheme.textMuted)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedCoordinate != nil ? "已选择位置" : "点击选择建造位置")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        if let coord = selectedCoordinate {
                            Text(String(format: "%.6f, %.6f", coord.latitude, coord.longitude))
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textMuted)
                        } else {
                            Text("必须在领地范围内选择")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding()
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedCoordinate != nil ? ApocalypseTheme.success : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// 资源消耗区域
    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("资源消耗")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            if template.resources.isEmpty {
                Text("无需资源")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(template.resources) { resource in
                        let owned = getOwnedAmount(for: resource.resourceId)
                        let definition = inventoryManager.itemDefinitions[resource.resourceId]

                        ResourceRow(
                            resourceId: resource.resourceId,
                            requiredAmount: resource.amount,
                            ownedAmount: owned,
                            itemDefinition: definition
                        )
                    }
                }
            }
        }
    }

    /// 建造时间区域
    private var buildTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建造时间")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            HStack {
                Image(systemName: "clock")
                    .foregroundColor(ApocalypseTheme.info)

                Text(buildTimeFormatted)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    /// 确认按钮
    private var confirmButton: some View {
        Button {
            Task {
                await startConstruction()
            }
        } label: {
            HStack {
                if isBuilding {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "hammer.fill")
                }
                Text(isBuilding ? "建造中..." : "确认建造")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(canBuild && !isBuilding ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            .cornerRadius(12)
        }
        .disabled(!canBuild || isBuilding)
    }

    /// 位置选择 Sheet
    private var locationPickerSheet: some View {
        NavigationStack {
            ZStack {
                BuildingLocationPickerView(
                    territoryCoordinates: territoryCoordinates,
                    existingBuildings: existingBuildings,
                    buildingTemplates: buildingManager.templates,
                    selectedCoordinate: $selectedCoordinate,
                    onSelectLocation: { coord in
                        selectedCoordinate = coord
                    },
                    onCancel: {
                        showLocationPicker = false
                    }
                )
                .ignoresSafeArea()

                // 底部确认栏
                VStack {
                    Spacer()

                    HStack(spacing: 16) {
                        Button("取消") {
                            showLocationPicker = false
                        }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)

                        Button("确定") {
                            showLocationPicker = false
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(selectedCoordinate != nil ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        .cornerRadius(12)
                        .disabled(selectedCoordinate == nil)
                    }
                    .padding()
                    .background(ApocalypseTheme.background.opacity(0.95))
                }
            }
            .navigationTitle("选择位置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Methods

    private func getOwnedAmount(for resourceId: String) -> Int {
        inventoryManager.inventoryItems
            .filter { $0.definitionId == resourceId }
            .reduce(0) { $0 + $1.quantity }
    }

    private func startConstruction() async {
        guard let coord = selectedCoordinate else { return }

        isBuilding = true

        do {
            try await buildingManager.startConstruction(
                templateId: template.id,
                territoryId: territory.id,
                customName: nil,
                locationLat: coord.latitude,
                locationLon: coord.longitude
            )

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isBuilding = false
    }
}

#Preview {
    BuildingPlacementView(
        template: BuildingTemplate(
            id: "building_campfire",
            name: "篝火",
            description: "提供温暖和照明",
            category: .survival,
            tier: 1,
            buildTime: 60,
            maxPerTerritory: 3,
            resources: [],
            effects: nil,
            iconName: "flame.fill",
            upgradeToId: nil
        ),
        territory: Territory(
            id: "1",
            userId: "user1",
            name: "测试领地",
            path: [["lat": 31.2, "lon": 121.4]],
            area: 10000,
            pointCount: 10,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: nil
        ),
        existingBuildings: []
    )
    .environmentObject(BuildingManager.shared)
    .environmentObject(InventoryManager())
}
