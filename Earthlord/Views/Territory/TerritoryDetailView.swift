//
//  TerritoryDetailView.swift
//  Earthlord
//
//  领地详情页 - 显示领地信息、地图预览、管理功能
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

    // MARK: - State

    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var mapRegion: MKCoordinateRegion

    // MARK: - Initialization

    init(territory: Territory, onDelete: (() -> Void)? = nil) {
        self.territory = territory
        self.onDelete = onDelete

        // 初始化地图区域
        let coordinates = territory.toCoordinates()
        if let firstCoord = coordinates.first {
            _mapRegion = State(initialValue: MKCoordinateRegion(
                center: firstCoord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            _mapRegion = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 地图预览
                    mapPreview

                    // 领地信息
                    territoryInfoSection

                    // 管理功能
                    managementSection

                    // 未来功能
                    futureFeaturesSection
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task {
                        await deleteTerritory()
                    }
                }
            } message: {
                Text("确定要删除这个领地吗？此操作无法撤销。")
            }
        }
    }

    // MARK: - Subviews

    /// 地图预览
    private var mapPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("地图预览")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 简化的地图视图，显示领地中心位置
            ZStack {
                Map(coordinateRegion: .constant(mapRegion))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                    )

                // 显示领地中心标记
                Image(systemName: "flag.fill")
                    .foregroundColor(.green)
                    .font(.largeTitle)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 领地信息区域
    private var territoryInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("领地信息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 12) {
                InfoRow(icon: "square.grid.3x3", title: "面积", value: territory.formattedArea)

                if let pointCount = territory.pointCount {
                    InfoRow(icon: "point.3.connected.trianglepath.dotted", title: "坐标点数", value: "\(pointCount) 个")
                }

                if let createdAt = territory.createdAt {
                    InfoRow(icon: "calendar", title: "创建时间", value: formatDate(createdAt))
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 管理功能区域
    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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

    /// 未来功能区域
    private var futureFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("即将推出")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 12) {
                FutureFeatureRow(icon: "pencil", title: "重命名领地", description: "自定义领地名称")
                FutureFeatureRow(icon: "building.2", title: "建筑系统", description: "在领地上建造设施")
                FutureFeatureRow(icon: "arrow.left.arrow.right", title: "领地交易", description: "与其他玩家交易领地")
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .opacity(0.6)
    }

    // MARK: - Methods

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

// MARK: - Future Feature Row

struct FutureFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 40, height: 40)
                .background(ApocalypseTheme.textSecondary.opacity(0.2))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            Text("敬请期待")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.textMuted.opacity(0.2))
                .cornerRadius(6)
        }
        .padding()
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(8)
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
}
