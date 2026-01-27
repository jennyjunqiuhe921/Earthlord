//
//  MyTradeOffersView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-26.
//
//  我的挂单视图

import SwiftUI

/// 我的挂单视图
struct MyTradeOffersView: View {

    // MARK: - Environment

    @EnvironmentObject var tradeManager: TradeManager
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - State

    /// 是否显示发布挂单页面
    @State private var showingCreateOffer = false

    /// 要取消的挂单
    @State private var offerToCancel: TradeOffer?

    /// 是否显示取消确认
    @State private var showingCancelConfirmation = false

    /// 是否正在取消
    @State private var isCancelling = false

    /// 错误消息
    @State private var errorMessage: String?

    /// 是否显示错误
    @State private var showingError = false

    // MARK: - Computed Properties

    /// 活跃挂单
    private var activeOffers: [TradeOffer] {
        tradeManager.myOffers.filter { $0.status == .active && !$0.isExpired }
    }

    /// 历史挂单（已完成、已取消、已过期）
    private var historyOffers: [TradeOffer] {
        tradeManager.myOffers.filter { $0.status != .active || $0.isExpired }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            if tradeManager.isLoading && tradeManager.myOffers.isEmpty {
                loadingView
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // 发布新挂单按钮
                        createOfferButton

                        // 活跃挂单
                        if !activeOffers.isEmpty {
                            activeOffersSection
                        }

                        // 历史挂单
                        if !historyOffers.isEmpty {
                            historyOffersSection
                        }

                        // 空状态
                        if tradeManager.myOffers.isEmpty {
                            emptyView
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .padding(.bottom, 80)
                }
            }
        }
        .refreshable {
            await tradeManager.loadMyOffers()
        }
        .sheet(isPresented: $showingCreateOffer) {
            CreateTradeOfferView()
                .environmentObject(tradeManager)
                .environmentObject(inventoryManager)
        }
        .alert("确认取消", isPresented: $showingCancelConfirmation) {
            Button("不取消", role: .cancel) { }
            Button("确认取消", role: .destructive) {
                if let offer = offerToCancel {
                    cancelOffer(offer)
                }
            }
        } message: {
            Text("取消挂单后，已锁定的物品将退还到背包。\n确定要取消吗？")
        }
        .alert("操作失败", isPresented: $showingError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "未知错误")
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
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "tag.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            Text("还没有挂单")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("点击上方按钮发布你的第一个挂单")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.vertical, 60)
    }

    // MARK: - 发布新挂单按钮

    private var createOfferButton: some View {
        Button(action: {
            showingCreateOffer = true
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("发布新挂单")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("把你的物品挂到市场上交易")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(16)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 活跃挂单区域

    private var activeOffersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.info)

                Text("等待中")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("(\(activeOffers.count))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()
            }

            ForEach(activeOffers) { offer in
                TradeOfferCard(offer: offer, mode: .myOffer) {
                    offerToCancel = offer
                    showingCancelConfirmation = true
                }
            }
        }
    }

    // MARK: - 历史挂单区域

    private var historyOffersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("历史记录")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("(\(historyOffers.count))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()
            }

            ForEach(historyOffers) { offer in
                TradeOfferCard(offer: offer, mode: .history) { }
            }
        }
    }

    // MARK: - Actions

    private func cancelOffer(_ offer: TradeOffer) {
        isCancelling = true

        Task {
            do {
                try await tradeManager.cancelTradeOffer(offerId: offer.id)
                // 刷新库存
                try? await inventoryManager.loadInventory()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }

            isCancelling = false
        }
    }
}

// MARK: - Preview

#Preview {
    MyTradeOffersView()
        .environmentObject(TradeManager.shared)
        .environmentObject(InventoryManager())
}
