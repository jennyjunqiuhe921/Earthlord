//
//  BuildingBrowserView.swift
//  Earthlord
//
//  建筑浏览器视图 - 显示可建造的建筑列表
//

import SwiftUI

/// 建筑浏览器
struct BuildingBrowserView: View {

    // MARK: - Environment

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var buildingManager: BuildingManager

    // MARK: - Properties

    let onDismiss: (() -> Void)?
    let onStartConstruction: ((BuildingTemplate) -> Void)?

    // MARK: - State

    @State private var selectedCategory: BuildingCategory? = nil
    @State private var selectedTemplate: BuildingTemplate? = nil

    // MARK: - Computed Properties

    private var filteredTemplates: [BuildingTemplate] {
        let allTemplates = Array(buildingManager.templates.values)

        if let category = selectedCategory {
            return allTemplates
                .filter { $0.category == category }
                .sorted { $0.tier < $1.tier }
        }

        return allTemplates.sorted { $0.tier < $1.tier }
    }

    private var columns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分类筛选栏
                categoryFilterBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 建筑网格
                if filteredTemplates.isEmpty {
                    emptyStateView
                } else {
                    buildingGrid
                }
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("建造")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        onDismiss?()
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .sheet(item: $selectedTemplate) { template in
                BuildingDetailView(
                    template: template,
                    onStartConstruction: { selectedTemplate in
                        dismiss()
                        onStartConstruction?(selectedTemplate)
                    }
                )
            }
        }
    }

    // MARK: - Subviews

    /// 分类筛选栏
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部按钮
                CategoryButton(
                    category: nil,
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )

                // 各分类按钮
                ForEach(BuildingCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
        }
    }

    /// 建筑网格
    private var buildingGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredTemplates) { template in
                    BuildingCard(template: template) {
                        selectedTemplate = template
                    }
                }
            }
            .padding()
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无可建造的建筑")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("请先加载建筑模板")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    BuildingBrowserView(
        onDismiss: nil,
        onStartConstruction: nil
    )
    .environmentObject(BuildingManager.shared)
}
