//
//  TradeMainView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-26.
//
//  交易系统主视图容器

import SwiftUI

/// 交易子标签
enum TradeTab: String, CaseIterable, Identifiable {
    case market = "交易市场"
    case myOffers = "我的挂单"
    case history = "交易历史"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .market: return "storefront.fill"
        case .myOffers: return "tag.fill"
        case .history: return "clock.fill"
        }
    }
}

/// 交易主视图
struct TradeMainView: View {

    // MARK: - Environment

    @EnvironmentObject var tradeManager: TradeManager
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - State

    /// 当前选中的子标签
    @State private var selectedTab: TradeTab = .market

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 子标签选择器
            tabPicker

            // 内容区域
            tabContent
        }
        .background(ApocalypseTheme.background)
        .onAppear {
            // 设置 InventoryManager 引用
            tradeManager.setInventoryManager(inventoryManager)

            // 加载数据
            Task {
                await tradeManager.loadAvailableOffers()
                await tradeManager.loadMyOffers()
                await tradeManager.loadTradeHistory()
            }
        }
    }

    // MARK: - 子标签选择器

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(TradeTab.allCases) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14, weight: .semibold))

                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(selectedTab == tab ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                        // 指示条
                        Rectangle()
                            .fill(selectedTab == tab ? ApocalypseTheme.primary : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 标签内容

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .market:
            TradeMarketView()

        case .myOffers:
            MyTradeOffersView()

        case .history:
            TradeHistoryView()
        }
    }
}

// MARK: - Preview

#Preview {
    TradeMainView()
        .environmentObject(TradeManager.shared)
        .environmentObject(InventoryManager())
}
