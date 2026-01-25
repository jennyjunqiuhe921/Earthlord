//
//  TerritoryBuildingRow.swift
//  Earthlord
//
//  领地建筑行组件 - 显示建筑状态和操作菜单
//

import SwiftUI
import Combine

/// 领地建筑行
struct TerritoryBuildingRow: View {

    // MARK: - Properties

    let building: PlayerBuilding
    let template: BuildingTemplate?
    let onUpgrade: (() -> Void)?
    let onDemolish: (() -> Void)?
    let onComplete: (() -> Void)?  // 建造完成回调

    // MARK: - State

    @State private var showMenu = false
    @State private var currentTime = Date()

    // 定时器 - 每秒更新一次
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Computed Properties

    private var categoryColor: Color {
        guard let template = template else { return .gray }

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

    private var isConstructing: Bool {
        building.status == .constructing
    }

    private var progress: Double {
        guard let template = template, building.status == .constructing else { return 1.0 }
        let elapsed = currentTime.timeIntervalSince(building.buildStartedAt)
        return min(1.0, max(0.0, elapsed / Double(template.buildTime)))
    }

    private var remainingSeconds: Int {
        guard let template = template, building.status == .constructing else { return 0 }
        let elapsed = currentTime.timeIntervalSince(building.buildStartedAt)
        let remaining = Double(template.buildTime) - elapsed
        return max(0, Int(remaining))
    }

    private var remainingTimeText: String {
        let seconds = remainingSeconds
        if seconds <= 0 { return "完成" }
        if seconds < 60 { return "\(seconds)秒" }
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes < 60 {
            return secs > 0 ? "\(minutes)分\(secs)秒" : "\(minutes)分"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)时\(mins)分"
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // 左侧图标
            buildingIcon

            // 中间信息
            buildingInfo

            Spacer()

            // 右侧状态/操作
            if isConstructing {
                constructionStatus
            } else {
                actionMenu
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .onReceive(timer) { time in
            // 只在建造中时更新
            if isConstructing {
                currentTime = time

                // 当进度达到 100% 时，触发完成回调
                if progress >= 1.0 {
                    onComplete?()
                }
            }
        }
    }

    // MARK: - Subviews

    /// 建筑图标
    private var buildingIcon: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.2))
                .frame(width: 44, height: 44)

            Image(systemName: template?.iconName ?? "building.fill")
                .font(.system(size: 20))
                .foregroundColor(categoryColor)
        }
    }

    /// 建筑信息
    private var buildingInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 第一行：名称 + 等级
            HStack(spacing: 6) {
                Text(building.buildingName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 等级徽章（始终显示）
                Text("Lv.\(building.level)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ApocalypseTheme.info)
                    .cornerRadius(4)
            }

            // 第二行：状态徽章 + 剩余时间
            HStack(spacing: 6) {
                // 状态徽章
                statusBadge

                // 建造中时显示剩余时间
                if isConstructing && progress < 1.0 {
                    Text(remainingTimeText)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    /// 状态文本
    private var statusText: String {
        if !isConstructing {
            return "运行中"
        }
        if progress >= 1.0 {
            return "已完成"
        } else if progress < 0.1 {
            return "开始建造"
        } else {
            return "建造中"
        }
    }

    /// 状态颜色
    private var statusColor: Color {
        if !isConstructing {
            return ApocalypseTheme.success
        }
        if progress >= 1.0 {
            return ApocalypseTheme.primary
        } else {
            return ApocalypseTheme.warning
        }
    }

    /// 状态徽章
    private var statusBadge: some View {
        Text(statusText)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor)
            .cornerRadius(4)
    }

    /// 建造中状态 - 进度环
    private var constructionStatus: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 4)
                .frame(width: 44, height: 44)

            // 进度圆环
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progress >= 1.0 ? ApocalypseTheme.success : ApocalypseTheme.primary,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-90))

            // 百分比文字
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(progress >= 1.0 ? ApocalypseTheme.success : ApocalypseTheme.primary)
        }
    }

    /// 操作菜单
    private var actionMenu: some View {
        Menu {
            if let upgradeId = template?.upgradeToId, !upgradeId.isEmpty {
                Button {
                    onUpgrade?()
                } label: {
                    Label("升级", systemImage: "arrow.up.circle")
                }
            }

            Button(role: .destructive) {
                onDemolish?()
            } label: {
                Label("拆除", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 44, height: 44)  // 增大点击区域
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        // 建造中的建筑
        TerritoryBuildingRow(
            building: PlayerBuilding(
                id: "1",
                userId: "user1",
                territoryId: "t1",
                templateId: "building_campfire",
                buildingName: "篝火",
                status: .constructing,
                level: 1,
                locationLat: 31.2,
                locationLon: 121.4,
                buildStartedAt: Date().addingTimeInterval(-30),
                buildCompletedAt: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            template: BuildingTemplate(
                id: "building_campfire",
                name: "篝火",
                description: "提供温暖",
                category: .survival,
                tier: 1,
                buildTime: 60,
                maxPerTerritory: 3,
                resources: [],
                effects: nil,
                iconName: "flame.fill",
                upgradeToId: nil
            ),
            onUpgrade: nil,
            onDemolish: nil,
            onComplete: nil
        )

        // 已完成的建筑
        TerritoryBuildingRow(
            building: PlayerBuilding(
                id: "2",
                userId: "user1",
                territoryId: "t1",
                templateId: "building_warehouse",
                buildingName: "仓库",
                status: .active,
                level: 2,
                locationLat: 31.2,
                locationLon: 121.4,
                buildStartedAt: Date().addingTimeInterval(-300),
                buildCompletedAt: Date(),
                createdAt: Date(),
                updatedAt: Date()
            ),
            template: BuildingTemplate(
                id: "building_warehouse",
                name: "仓库",
                description: "储存物品",
                category: .storage,
                tier: 2,
                buildTime: 300,
                maxPerTerritory: 1,
                resources: [],
                effects: nil,
                iconName: "archivebox.fill",
                upgradeToId: "building_warehouse_2"
            ),
            onUpgrade: nil,
            onDemolish: nil,
            onComplete: nil
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
