//
//  TerritoryDetailView.swift
//  Earthlord
//
//  领地详情页 - 全屏地图布局 + 建筑列表 + 操作菜单
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - Properties

    let territory: Territory
    let onDelete: (() -> Void)?

    // MARK: - Environment

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var territoryManager: TerritoryManager
    @EnvironmentObject var buildingManager: BuildingManager
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - State

    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showInfoPanel = true
    @State private var showBuildingBrowser = false
    @State private var selectedTemplateForConstruction: BuildingTemplate? = nil
    @State private var showRenameAlert = false
    @State private var newTerritoryName = ""
    @State private var isRenaming = false
    @State private var showDemolishAlert = false
    @State private var buildingToDelete: PlayerBuilding? = nil
    @State private var showUpgradeAlert = false
    @State private var buildingToUpgrade: PlayerBuilding? = nil
    @State private var isUpgrading = false

    // MARK: - Computed Properties

    private var buildings: [PlayerBuilding] {
        buildingManager.playerBuildings.filter { $0.territoryId == territory.id }
    }

    // MARK: - Initialization

    init(territory: Territory, onDelete: (() -> Void)? = nil) {
        self.territory = territory
        self.onDelete = onDelete
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 1. 全屏地图（底层）
            TerritoryMapView(
                territory: territory,
                buildings: buildings,
                buildingTemplates: buildingManager.templates
            )
            .ignoresSafeArea()

            // 2. 悬浮工具栏（顶部）
            VStack(spacing: 0) {
                TerritoryToolbarView(
                    territoryName: territory.displayName,
                    onClose: { dismiss() },
                    onBuild: { showBuildingBrowser = true },
                    onTogglePanel: { withAnimation { showInfoPanel.toggle() } },
                    isPanelVisible: showInfoPanel
                )

                Spacer()
            }

            // 3. 可折叠信息面板（底部）
            VStack {
                Spacer()

                if showInfoPanel {
                    infoPanelView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            loadBuildings()
            newTerritoryName = territory.name ?? ""
        }
        // Sheet 管理
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView(
                onDismiss: { showBuildingBrowser = false },
                onStartConstruction: { template in
                    showBuildingBrowser = false
                    // 延迟 0.3s 避免动画冲突
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedTemplateForConstruction = template
                    }
                }
            )
            .environmentObject(buildingManager)
            .environmentObject(inventoryManager)
        }
        .sheet(item: $selectedTemplateForConstruction) { template in
            BuildingPlacementView(
                template: template,
                territory: territory,
                existingBuildings: buildings
            )
            .environmentObject(buildingManager)
            .environmentObject(inventoryManager)
            .onDisappear {
                // 刷新建筑列表
                loadBuildings()
            }
        }
        // 删除确认
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task { await deleteTerritory() }
            }
        } message: {
            Text("确定要删除这个领地吗？领地内的所有建筑也将被删除。此操作无法撤销。")
        }
        // 重命名弹窗
        .alert("重命名领地", isPresented: $showRenameAlert) {
            TextField("领地名称", text: $newTerritoryName)
            Button("取消", role: .cancel) {}
            Button("确定") {
                Task { await renameTerritory() }
            }
            .disabled(newTerritoryName.isEmpty || isRenaming)
        } message: {
            Text("输入新的领地名称")
        }
        // 拆除确认
        .alert("确认拆除", isPresented: $showDemolishAlert) {
            Button("取消", role: .cancel) {
                buildingToDelete = nil
            }
            Button("拆除", role: .destructive) {
                if let building = buildingToDelete {
                    Task { await demolishBuilding(building) }
                }
            }
        } message: {
            if let building = buildingToDelete {
                Text("确定要拆除「\(building.buildingName)」吗？此操作无法撤销。")
            } else {
                Text("确定要拆除这个建筑吗？")
            }
        }
        // 升级确认
        .alert("确认升级", isPresented: $showUpgradeAlert) {
            Button("取消", role: .cancel) {
                buildingToUpgrade = nil
            }
            Button("升级") {
                if let building = buildingToUpgrade {
                    Task { await upgradeBuilding(building) }
                }
            }
            .disabled(isUpgrading)
        } message: {
            if let building = buildingToUpgrade,
               let template = buildingManager.templates[building.templateId],
               let upgradeId = template.upgradeToId,
               let upgradeTemplate = buildingManager.templates[upgradeId] {
                Text("将「\(building.buildingName)」升级为「\(upgradeTemplate.name)」？\n需要消耗升级所需资源。")
            } else {
                Text("确定要升级这个建筑吗？")
            }
        }
    }

    // MARK: - Subviews

    /// 信息面板
    private var infoPanelView: some View {
        VStack(spacing: 0) {
            // 拖动指示器
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 16) {
                    // 领地信息
                    territoryInfoSection

                    // 建筑列表
                    buildingsSection

                    // 管理操作
                    managementSection
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ApocalypseTheme.background)
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        )
    }

    /// 领地信息区域
    private var territoryInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("领地信息")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Button {
                    showRenameAlert = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            VStack(spacing: 8) {
                InfoRow(icon: "square.grid.3x3", title: "面积", value: territory.formattedArea)

                if let pointCount = territory.pointCount {
                    InfoRow(icon: "point.3.connected.trianglepath.dotted", title: "坐标点数", value: "\(pointCount) 个")
                }

                InfoRow(icon: "building.2", title: "建筑数量", value: "\(buildings.count) 个")

                if let createdAt = territory.createdAt {
                    InfoRow(icon: "calendar", title: "创建时间", value: formatDate(createdAt))
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 建筑列表区域
    private var buildingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("建筑")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Button {
                    showBuildingBrowser = true
                } label: {
                    Label("建造", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }

            if buildings.isEmpty {
                emptyBuildingsView
            } else {
                VStack(spacing: 8) {
                    ForEach(buildings) { building in
                        let template = buildingManager.templates[building.templateId]
                        TerritoryBuildingRow(
                            building: building,
                            template: template,
                            onUpgrade: {
                                buildingToUpgrade = building
                                showUpgradeAlert = true
                            },
                            onDemolish: {
                                buildingToDelete = building
                                showDemolishAlert = true
                            },
                            onComplete: {
                                // 建造完成时自动完成并刷新
                                Task {
                                    try? await buildingManager.completeConstruction(buildingId: building.id)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 空建筑视图
    private var emptyBuildingsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("还没有建筑")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Button {
                showBuildingBrowser = true
            } label: {
                Text("开始建造")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    /// 管理操作区域
    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("管理")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Button {
                showDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("删除领地")
                    Spacer()
                    if isDeleting {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .cornerRadius(12)
            }
            .disabled(isDeleting)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Methods

    /// 加载建筑
    private func loadBuildings() {
        Task {
            do {
                // 确保模板已加载
                if buildingManager.templates.isEmpty {
                    await buildingManager.loadTemplates()
                }

                try await buildingManager.loadPlayerBuildings(for: territory.id)

                // 自动完成已到期的建筑
                await buildingManager.checkAndCompleteBuildings()
            } catch {
                print("加载建筑失败: \(error.localizedDescription)")
            }
        }
    }

    /// 删除领地
    private func deleteTerritory() async {
        isDeleting = true
        let success = await territoryManager.deleteTerritory(territoryId: territory.id)
        isDeleting = false

        if success {
            onDelete?()
            dismiss()
        }
    }

    /// 重命名领地
    private func renameTerritory() async {
        guard !newTerritoryName.isEmpty else { return }

        isRenaming = true

        do {
            try await territoryManager.updateTerritoryName(
                territoryId: territory.id,
                newName: newTerritoryName
            )
            // 通知已在 updateTerritoryName 中发送
        } catch {
            print("重命名失败: \(error.localizedDescription)")
        }

        isRenaming = false
    }

    /// 拆除建筑
    private func demolishBuilding(_ building: PlayerBuilding) async {
        do {
            try await buildingManager.demolishBuilding(buildingId: building.id)
            loadBuildings()
        } catch {
            print("拆除失败: \(error.localizedDescription)")
        }
        buildingToDelete = nil
    }

    /// 升级建筑
    private func upgradeBuilding(_ building: PlayerBuilding) async {
        isUpgrading = true
        do {
            try await buildingManager.upgradeBuilding(buildingId: building.id)
            loadBuildings()
        } catch {
            print("升级失败: \(error.localizedDescription)")
        }
        isUpgrading = false
        buildingToUpgrade = nil
    }

    /// 格式化日期
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            displayFormatter.locale = Locale(identifier: "zh_CN")
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }
}

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "1",
            userId: "user1",
            name: "测试领地",
            path: [["lat": 31.2, "lon": 121.4], ["lat": 31.3, "lon": 121.5]],
            area: 10000,
            pointCount: 10,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: "2024-01-01T00:00:00Z"
        )
    )
    .environmentObject(TerritoryManager())
    .environmentObject(BuildingManager.shared)
    .environmentObject(InventoryManager())
}
