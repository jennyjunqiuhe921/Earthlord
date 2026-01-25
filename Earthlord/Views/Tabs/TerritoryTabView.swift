//
//  TerritoryTabView.swift
//  Earthlord
//
//  领地管理页面 - 显示我的领地列表和统计信息
//

import SwiftUI

struct TerritoryTabView: View {

    // MARK: - Environment Objects

    @EnvironmentObject var territoryManager: TerritoryManager
    @EnvironmentObject var buildingManager: BuildingManager
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - State

    @State private var myTerritories: [Territory] = []
    @State private var selectedTerritory: Territory?
    @State private var isRefreshing = false
    @State private var showError = false
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    ScrollView {
                        VStack(spacing: 20) {
                            // 统计头部
                            statisticsHeader

                            // 领地卡片列表
                            VStack(spacing: 12) {
                                ForEach(myTerritories) { territory in
                                    TerritoryCard(territory: territory)
                                        .onTapGesture {
                                            selectedTerritory = territory
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                    }
                    .refreshable {
                        await loadMyTerritories()
                    }
                }
            }
            .navigationTitle("我的领地")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task {
                    await loadMyTerritories()
                }
            }
            .sheet(item: $selectedTerritory) { territory in
                TerritoryDetailView(
                    territory: territory,
                    onDelete: {
                        Task {
                            await loadMyTerritories()
                        }
                    }
                )
                .environmentObject(territoryManager)
                .environmentObject(buildingManager)
                .environmentObject(inventoryManager)
            }
            .onReceive(NotificationCenter.default.publisher(for: .territoryUpdated)) { _ in
                Task { await loadMyTerritories() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .territoryDeleted)) { _ in
                Task { await loadMyTerritories() }
            }
            .alert("加载失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }

    // MARK: - Subviews

    /// 统计头部
    private var statisticsHeader: some View {
        HStack(spacing: 20) {
            // 领地数量
            TerritoryStatCard(
                icon: "flag.fill",
                title: "领地数量",
                value: "\(myTerritories.count)",
                color: .green
            )

            // 总面积
            TerritoryStatCard(
                icon: "square.grid.3x3.fill",
                title: "总面积",
                value: totalAreaFormatted,
                color: .orange
            )
        }
        .padding(.horizontal)
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.slash")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("还没有领地")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("前往地图页面开始圈地吧")
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Computed Properties

    /// 格式化的总面积
    private var totalAreaFormatted: String {
        let totalArea = myTerritories.reduce(0) { $0 + $1.area }
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        } else {
            return String(format: "%.0f m²", totalArea)
        }
    }

    // MARK: - Methods

    /// 加载我的领地
    private func loadMyTerritories() async {
        isRefreshing = true
        do {
            myTerritories = try await territoryManager.loadMyTerritories()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isRefreshing = false
    }
}

// MARK: - Territory Stat Card

struct TerritoryStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(title)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
}

// MARK: - Territory Card

struct TerritoryCard: View {
    let territory: Territory

    var body: some View {
        HStack(spacing: 16) {
            // 左侧图标
            Image(systemName: "flag.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
                .frame(width: 50, height: 50)
                .background(Color.green.opacity(0.2))
                .cornerRadius(10)

            // 中间信息
            VStack(alignment: .leading, spacing: 6) {
                Text(territory.displayName)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 12) {
                    Label(territory.formattedArea, systemImage: "square.grid.3x3")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    if let pointCount = territory.pointCount {
                        Label("\(pointCount) 点", systemImage: "point.3.connected.trianglepath.dotted")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }

            Spacer()

            // 右侧箭头
            Image(systemName: "chevron.right")
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
}

#Preview {
    TerritoryTabView()
        .environmentObject(TerritoryManager())
}
