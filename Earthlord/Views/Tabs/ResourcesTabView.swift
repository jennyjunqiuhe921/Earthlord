//
//  ResourcesTabView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-10.
//
//  资源模块主入口页面

import SwiftUI

/// 资源分段
enum ResourceSegment: String, CaseIterable, Identifiable {
    case poi = "POI"
    case backpack = "背包"
    case purchased = "已购"
    case territory = "领地"
    case trading = "交易"

    var id: String { rawValue }
}

struct ResourcesTabView: View {
    // MARK: - State

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态（假数据）
    @State private var isTradingEnabled = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 顶部交易开关
                    topBar

                    // 分段选择器
                    segmentedPicker

                    // 内容区域
                    contentView
                }
            }
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 顶部交易开关

    private var topBar: some View {
        HStack {
            // 交易开关
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isTradingEnabled ? ApocalypseTheme.success : ApocalypseTheme.textMuted)

                Text("交易功能")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Toggle("", isOn: $isTradingEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: ApocalypseTheme.success))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: - 分段选择器

    private var segmentedPicker: some View {
        Picker("资源分段", selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases) { segment in
                Text(segment.rawValue)
                    .tag(segment)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.background)
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .poi:
            // POI 列表页面
            POIListView()

        case .backpack:
            // 背包页面
            BackpackView()

        case .purchased:
            // 已购页面（开发中）
            placeholderView(title: "已购", icon: "bag.fill")

        case .territory:
            // 领地页面（开发中）
            placeholderView(title: "领地", icon: "map.fill")

        case .trading:
            // 交易页面
            TradeMainView()
        }
    }

    // MARK: - 占位视图

    private func placeholderView(title: String, icon: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: icon)
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 标题
            Text("\(title)功能")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 提示文字
            Text("功能开发中，敬请期待")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }
}

// MARK: - Preview

#Preview {
    ResourcesTabView()
}
