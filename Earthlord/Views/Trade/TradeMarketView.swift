//
//  TradeMarketView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-26.
//
//  交易市场视图 - 浏览其他玩家的挂单

import SwiftUI

/// 交易市场视图
struct TradeMarketView: View {

    // MARK: - Environment

    @EnvironmentObject var tradeManager: TradeManager
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - State

    /// 选中的挂单（用于导航到详情）
    @State private var selectedOffer: TradeOffer?

    /// 是否显示详情页
    @State private var showingDetail = false

    // MARK: - Body

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            if tradeManager.isLoading && tradeManager.availableOffers.isEmpty {
                loadingView
            } else if tradeManager.availableOffers.isEmpty {
                emptyView
            } else {
                offerList
            }
        }
        .refreshable {
            await tradeManager.loadAvailableOffers()
        }
        .sheet(isPresented: $showingDetail) {
            if let offer = selectedOffer {
                TradeOfferDetailView(offer: offer)
                    .environmentObject(tradeManager)
                    .environmentObject(inventoryManager)
            }
        }
    }

    // MARK: - 加载中视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.2)

            Text("加载中...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 空状态视图

    private var emptyView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: "storefront.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            Text("暂无挂单")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("市场上还没有其他玩家发布的挂单\n下拉刷新或稍后再来看看")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - 挂单列表

    private var offerList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 统计信息
                HStack {
                    Text("共 \(tradeManager.availableOffers.count) 个挂单")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // 挂单卡片列表
                ForEach(tradeManager.availableOffers) { offer in
                    TradeOfferCard(offer: offer, mode: .market) {
                        selectedOffer = offer
                        showingDetail = true
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Preview

#Preview {
    TradeMarketView()
        .environmentObject(TradeManager.shared)
        .environmentObject(InventoryManager())
}
