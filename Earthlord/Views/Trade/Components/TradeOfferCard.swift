//
//  TradeOfferCard.swift
//  Earthlord
//
//  Created by Claude on 2026-01-26.
//
//  交易挂单卡片组件

import SwiftUI

/// 卡片显示模式
enum TradeOfferCardMode {
    case market     // 市场列表（显示接受按钮）
    case myOffer    // 我的挂单（显示取消按钮）
    case history    // 历史记录（不显示操作按钮）
}

/// 交易挂单卡片
struct TradeOfferCard: View {

    // MARK: - Environment

    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - Properties

    let offer: TradeOffer
    let mode: TradeOfferCardMode
    let onAction: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：发布者信息 + 状态
            headerRow

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 物品预览
            itemsPreview

            // 留言（如果有）
            if let message = offer.message, !message.isEmpty {
                messagePreview(message)
            }

            // 底部：剩余时间 + 操作按钮
            if mode != .history || offer.status != .active {
                footerRow
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 头部行

    private var headerRow: some View {
        HStack(spacing: 12) {
            // 头像
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.info.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: "person.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.info)
            }

            // 用户名和时间
            VStack(alignment: .leading, spacing: 2) {
                Text(offer.ownerUsername ?? "匿名玩家")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(formatDate(offer.createdAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()

            // 状态标签
            statusBadge
        }
    }

    // MARK: - 物品预览

    private var itemsPreview: some View {
        HStack(spacing: 12) {
            // 提供的物品
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ApocalypseTheme.success)

                    Text("出")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ApocalypseTheme.success)
                }

                ForEach(offer.offeringItems.prefix(2)) { item in
                    itemPreviewRow(item)
                }

                if offer.offeringItems.count > 2 {
                    Text("+\(offer.offeringItems.count - 2) 种")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 交换箭头
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)

            // 需要的物品
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ApocalypseTheme.warning)

                    Text("要")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ApocalypseTheme.warning)
                }

                ForEach(offer.requestingItems.prefix(2)) { item in
                    itemPreviewRow(item)
                }

                if offer.requestingItems.count > 2 {
                    Text("+\(offer.requestingItems.count - 2) 种")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 物品预览行

    private func itemPreviewRow(_ item: TradeItem) -> some View {
        let itemName = inventoryManager.getDefinition(for: item.itemId)?.name ?? item.itemId

        return HStack(spacing: 4) {
            Text(itemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(1)

            Text("x\(item.quantity)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 留言预览

    private func messagePreview(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.top, 4)
    }

    // MARK: - 底部行

    private var footerRow: some View {
        HStack {
            // 剩余时间
            if offer.status == .active {
                Label(offer.formattedRemainingTime, systemImage: "clock.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(offer.remainingSeconds < 3600 ? ApocalypseTheme.warning : ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 操作按钮
            if mode == .market {
                actionButton(title: "查看详情", color: ApocalypseTheme.primary)
            } else if mode == .myOffer && offer.status == .active {
                actionButton(title: "取消挂单", color: ApocalypseTheme.danger)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 状态徽章

    private var statusBadge: some View {
        Text(offer.isExpired && offer.status == .active ? "已过期" : offer.status.displayName)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(4)
    }

    // MARK: - 操作按钮

    private func actionButton(title: String, color: Color) -> some View {
        Button(action: onAction) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(color.opacity(0.1))
                .cornerRadius(6)
        }
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        if offer.isExpired && offer.status == .active {
            return ApocalypseTheme.warning
        }

        switch offer.status {
        case .active: return ApocalypseTheme.info
        case .completed: return ApocalypseTheme.success
        case .cancelled: return ApocalypseTheme.textMuted
        case .expired: return ApocalypseTheme.warning
        }
    }

    private var borderColor: Color {
        switch mode {
        case .market: return ApocalypseTheme.info
        case .myOffer: return offer.status == .active ? ApocalypseTheme.primary : ApocalypseTheme.textMuted
        case .history: return ApocalypseTheme.textMuted
        }
    }

    // MARK: - Helper

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        TradeOfferCard(
            offer: TradeOffer(
                id: "test1",
                ownerId: "owner123",
                ownerUsername: "测试玩家",
                offeringItems: [
                    TradeItem(itemId: "item_wood", quantity: 50),
                    TradeItem(itemId: "item_stone", quantity: 30)
                ],
                requestingItems: [
                    TradeItem(itemId: "item_water", quantity: 10)
                ],
                status: .active,
                message: "诚心交易",
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(3600 * 6),
                completedAt: nil,
                completedByUserId: nil,
                completedByUsername: nil
            ),
            mode: .market,
            onAction: {}
        )

        TradeOfferCard(
            offer: TradeOffer(
                id: "test2",
                ownerId: "owner123",
                ownerUsername: "我的账号",
                offeringItems: [TradeItem(itemId: "item_food", quantity: 20)],
                requestingItems: [TradeItem(itemId: "item_medical", quantity: 5)],
                status: .completed,
                message: nil,
                createdAt: Date().addingTimeInterval(-3600 * 24),
                expiresAt: Date(),
                completedAt: Date(),
                completedByUserId: "buyer456",
                completedByUsername: "买家小红"
            ),
            mode: .history,
            onAction: {}
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
    .environmentObject(InventoryManager())
}
