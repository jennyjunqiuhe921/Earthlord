//
//  TradeHistoryView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-26.
//
//  交易历史视图

import SwiftUI

/// 交易历史视图
struct TradeHistoryView: View {

    // MARK: - Environment

    @EnvironmentObject var tradeManager: TradeManager

    // MARK: - State

    /// 选中的历史记录（用于评价）
    @State private var selectedHistory: TradeHistory?

    /// 是否显示评价弹窗
    @State private var showingRating = false

    /// 当前用户ID
    @State private var currentUserId: String?

    // MARK: - Body

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            if tradeManager.isLoading && tradeManager.tradeHistory.isEmpty {
                loadingView
            } else if tradeManager.tradeHistory.isEmpty {
                emptyView
            } else {
                historyList
            }
        }
        .refreshable {
            await tradeManager.loadTradeHistory()
        }
        .sheet(isPresented: $showingRating) {
            if let history = selectedHistory, let userId = currentUserId {
                TradeRatingView(history: history, currentUserId: userId)
                    .environmentObject(tradeManager)
            }
        }
        .task {
            // 获取当前用户ID
            // 这里简化处理，实际应该从 AuthManager 获取
            if let session = try? await SupabaseClientSingleton.shared.auth.session {
                currentUserId = session.user.id.uuidString
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

                Image(systemName: "clock.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            Text("暂无交易记录")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("完成交易后，记录会显示在这里")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }

    // MARK: - 历史列表

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tradeManager.tradeHistory) { history in
                    TradeHistoryCard(
                        history: history,
                        currentUserId: currentUserId ?? ""
                    ) {
                        selectedHistory = history
                        showingRating = true
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 80)
        }
    }
}

// MARK: - 交易历史卡片

struct TradeHistoryCard: View {

    let history: TradeHistory
    let currentUserId: String
    let onRateTap: () -> Void

    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - Computed Properties

    /// 是否是卖家
    private var isSeller: Bool {
        history.sellerId == currentUserId
    }

    /// 交易对方名称
    private var counterpartyName: String {
        if isSeller {
            return history.buyerUsername ?? "匿名买家"
        } else {
            return history.sellerUsername ?? "匿名卖家"
        }
    }

    /// 是否已评价
    private var hasRated: Bool {
        history.hasRated(userId: currentUserId)
    }

    /// 获得的物品
    private var receivedItems: [TradeItem] {
        if isSeller {
            return history.itemsExchanged.buyerGave
        } else {
            return history.itemsExchanged.sellerGave
        }
    }

    /// 给出的物品
    private var gaveItems: [TradeItem] {
        if isSeller {
            return history.itemsExchanged.sellerGave
        } else {
            return history.itemsExchanged.buyerGave
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部信息
            HStack {
                // 角色标签
                Text(isSeller ? "卖家" : "买家")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isSeller ? ApocalypseTheme.info : ApocalypseTheme.success)
                    .cornerRadius(4)

                Text("与 \(counterpartyName)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 时间
                Text(formatDate(history.completedAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 交换详情
            HStack(spacing: 16) {
                // 给出的
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ApocalypseTheme.danger)

                        Text("给出")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(ApocalypseTheme.danger)
                    }

                    ForEach(gaveItems) { item in
                        itemRow(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 分隔
                Rectangle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(width: 1)

                // 获得的
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ApocalypseTheme.success)

                        Text("获得")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(ApocalypseTheme.success)
                    }

                    ForEach(receivedItems) { item in
                        itemRow(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 评价区域
            if hasRated {
                ratingDisplay
            } else {
                rateButton
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 物品行

    private func itemRow(_ item: TradeItem) -> some View {
        HStack(spacing: 6) {
            let itemName = inventoryManager.getDefinition(for: item.itemId)?.name ?? item.itemId

            Text(itemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(1)

            Text("x\(item.quantity)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 评价显示

    private var ratingDisplay: some View {
        HStack(spacing: 12) {
            // 我的评价
            let myRating = isSeller ? history.sellerRating : history.buyerRating
            if let rating = myRating {
                HStack(spacing: 4) {
                    Text("我的评价:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(star <= rating ? ApocalypseTheme.warning : ApocalypseTheme.textMuted)
                    }
                }
            }

            Spacer()

            // 对方的评价
            let theirRating = isSeller ? history.buyerRating : history.sellerRating
            if let rating = theirRating {
                HStack(spacing: 4) {
                    Text("对方评价:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(star <= rating ? ApocalypseTheme.warning : ApocalypseTheme.textMuted)
                    }
                }
            } else {
                Text("对方未评价")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - 评价按钮

    private var rateButton: some View {
        Button(action: onRateTap) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .bold))

                Text("去评价")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(ApocalypseTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(ApocalypseTheme.primary.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.top, 8)
    }

    // MARK: - Helper

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Supabase 单例（临时）

class SupabaseClientSingleton {
    static let shared = SupabaseClient(
        supabaseURL: URL(string: "https://acnriuoexalqvckiuvgr.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFjbnJpdW9leGFscXZja2l1dmdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5NTQzNDUsImV4cCI6MjA4MTUzMDM0NX0.cOTtYT-dnBDLNKFzFh3pIU6H1W0hksl3sdgdWiqOjIM"
    )
}

import Supabase

// MARK: - Preview

#Preview {
    TradeHistoryView()
        .environmentObject(TradeManager.shared)
        .environmentObject(InventoryManager())
}
