//
//  TradeOfferDetailView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-26.
//
//  挂单详情视图

import SwiftUI

/// 挂单详情视图
struct TradeOfferDetailView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tradeManager: TradeManager
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - Properties

    let offer: TradeOffer

    // MARK: - State

    /// 是否显示确认弹窗
    @State private var showingConfirmation = false

    /// 是否正在处理
    @State private var isProcessing = false

    /// 错误消息
    @State private var errorMessage: String?

    /// 是否显示错误提示
    @State private var showingError = false

    /// 成功消息
    @State private var successMessage: String?

    /// 是否显示成功提示
    @State private var showingSuccess = false

    // MARK: - Computed Properties

    /// 检查库存是否满足需求
    private var canAcceptOffer: Bool {
        for item in offer.requestingItems {
            let owned = getOwnedQuantity(itemId: item.itemId)
            if owned < item.quantity {
                return false
            }
        }
        return offer.canBeAccepted
    }

    /// 缺少的物品列表
    private var missingItems: [(itemId: String, required: Int, owned: Int)] {
        var missing: [(String, Int, Int)] = []
        for item in offer.requestingItems {
            let owned = getOwnedQuantity(itemId: item.itemId)
            if owned < item.quantity {
                missing.append((item.itemId, item.quantity, owned))
            }
        }
        return missing
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 发布者信息
                        sellerInfoCard

                        // 提供的物品
                        offeringItemsCard

                        // 交换箭头
                        exchangeArrow

                        // 需要的物品
                        requestingItemsCard

                        // 留言
                        if let message = offer.message, !message.isEmpty {
                            messageCard(message)
                        }

                        // 缺少物品提示
                        if !missingItems.isEmpty {
                            missingItemsWarning
                        }

                        // 接受按钮
                        acceptButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("挂单详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("确认交易", isPresented: $showingConfirmation) {
                Button("取消", role: .cancel) { }
                Button("确认接受", role: .destructive) {
                    acceptOffer()
                }
            } message: {
                Text("确定要接受这个交易吗？\n交易完成后无法撤销。")
            }
            .alert("交易失败", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .alert("交易成功", isPresented: $showingSuccess) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text(successMessage ?? "交易已完成！")
            }
        }
    }

    // MARK: - 发布者信息卡片

    private var sellerInfoCard: some View {
        HStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.info.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.info)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(offer.ownerUsername ?? "匿名玩家")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 8) {
                    // 剩余时间
                    Label(offer.formattedRemainingTime, systemImage: "clock.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(offer.remainingSeconds < 3600 ? ApocalypseTheme.warning : ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            // 状态标签
            statusBadge(offer.status)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 提供的物品卡片

    private var offeringItemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.success)

                Text("对方出")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ApocalypseTheme.success)

                Spacer()

                Text("\(offer.offeringItems.count) 种物品")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            ForEach(offer.offeringItems) { item in
                TradeItemRow(item: item, showDelete: false)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.success.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 交换箭头

    private var exchangeArrow: some View {
        HStack {
            Spacer()
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.cardBackground)
                    .frame(width: 44, height: 44)

                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.primary)
            }
            Spacer()
        }
    }

    // MARK: - 需要的物品卡片

    private var requestingItemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("对方要")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ApocalypseTheme.warning)

                Spacer()

                Text("\(offer.requestingItems.count) 种物品")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            ForEach(offer.requestingItems) { item in
                HStack {
                    TradeItemRow(item: item, showDelete: false)

                    Spacer()

                    // 库存状态
                    let owned = getOwnedQuantity(itemId: item.itemId)
                    let sufficient = owned >= item.quantity

                    HStack(spacing: 4) {
                        Image(systemName: sufficient ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))

                        Text("库存: \(owned)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(sufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.warning.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 留言卡片

    private func messageCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("卖家留言")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 缺少物品警告

    private var missingItemsWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.danger)

                Text("物品不足")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            ForEach(missingItems, id: \.itemId) { item in
                let itemName = inventoryManager.getDefinition(for: item.itemId)?.name ?? item.itemId
                Text("· \(itemName) 还需 \(item.required - item.owned) 个")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ApocalypseTheme.danger.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.danger.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 接受按钮

    private var acceptButton: some View {
        Button(action: {
            showingConfirmation = true
        }) {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                }

                Text(isProcessing ? "处理中..." : "接受交易")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canAcceptOffer && !isProcessing ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            .cornerRadius(12)
        }
        .disabled(!canAcceptOffer || isProcessing)
    }

    // MARK: - 状态徽章

    private func statusBadge(_ status: TradeOfferStatus) -> some View {
        Text(status.displayName)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor(status))
            .cornerRadius(6)
    }

    private func statusColor(_ status: TradeOfferStatus) -> Color {
        switch status {
        case .active: return ApocalypseTheme.info
        case .completed: return ApocalypseTheme.success
        case .cancelled: return ApocalypseTheme.textMuted
        case .expired: return ApocalypseTheme.warning
        }
    }

    // MARK: - Helper Methods

    private func getOwnedQuantity(itemId: String) -> Int {
        inventoryManager.inventoryItems
            .filter { $0.definitionId == itemId }
            .reduce(0) { $0 + $1.quantity }
    }

    private func acceptOffer() {
        isProcessing = true

        Task {
            do {
                _ = try await tradeManager.acceptTradeOffer(offerId: offer.id)

                // 刷新库存
                try? await inventoryManager.loadInventory()

                successMessage = "交易完成！物品已添加到你的背包。"
                showingSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }

            isProcessing = false
        }
    }
}

// MARK: - Preview

#Preview {
    TradeOfferDetailView(
        offer: TradeOffer(
            id: "test",
            ownerId: "owner123",
            ownerUsername: "测试玩家",
            offeringItems: [TradeItem(itemId: "item_wood", quantity: 50)],
            requestingItems: [TradeItem(itemId: "item_stone", quantity: 30)],
            status: .active,
            message: "诚心交易，价格好商量",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600 * 24),
            completedAt: nil,
            completedByUserId: nil,
            completedByUsername: nil
        )
    )
    .environmentObject(TradeManager.shared)
    .environmentObject(InventoryManager())
}
