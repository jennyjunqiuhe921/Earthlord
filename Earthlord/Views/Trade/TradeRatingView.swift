//
//  TradeRatingView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-26.
//
//  交易评价视图

import SwiftUI

/// 交易评价视图
struct TradeRatingView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tradeManager: TradeManager

    // MARK: - Properties

    let history: TradeHistory
    let currentUserId: String

    // MARK: - State

    /// 评分（1-5）
    @State private var rating: Int = 5

    /// 评语
    @State private var comment: String = ""

    /// 是否正在提交
    @State private var isSubmitting = false

    /// 错误消息
    @State private var errorMessage: String?

    /// 是否显示错误
    @State private var showingError = false

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

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 头部说明
                        headerSection

                        // 星级评分
                        ratingSection

                        // 评语输入
                        commentSection

                        // 提交按钮
                        submitButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("评价交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("评价失败", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }

    // MARK: - 头部说明

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "star.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            Text("评价 \(counterpartyName)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("你的评价将帮助其他玩家了解这位交易者")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 星级评分

    private var ratingSection: some View {
        VStack(spacing: 16) {
            Text("整体评分")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            rating = star
                        }
                    }) {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(star <= rating ? ApocalypseTheme.warning : ApocalypseTheme.textMuted)
                            .scaleEffect(star <= rating ? 1.1 : 1.0)
                    }
                }
            }

            Text(ratingText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ratingColor)
        }
        .padding(20)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 评分文字
    private var ratingText: String {
        switch rating {
        case 1: return "非常差"
        case 2: return "较差"
        case 3: return "一般"
        case 4: return "满意"
        case 5: return "非常满意"
        default: return ""
        }
    }

    /// 评分颜色
    private var ratingColor: Color {
        switch rating {
        case 1, 2: return ApocalypseTheme.danger
        case 3: return ApocalypseTheme.warning
        case 4, 5: return ApocalypseTheme.success
        default: return ApocalypseTheme.textSecondary
        }
    }

    // MARK: - 评语输入

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("评语（可选）")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(comment.count)/100")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            TextField("说说你的交易体验...", text: $comment, axis: .vertical)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(3...5)
                .onChange(of: comment) { newValue in
                    if newValue.count > 100 {
                        comment = String(newValue.prefix(100))
                    }
                }
                .padding(12)
                .background(ApocalypseTheme.background)
                .cornerRadius(8)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 提交按钮

    private var submitButton: some View {
        Button(action: submitRating) {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                }

                Text(isSubmitting ? "提交中..." : "提交评价")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSubmitting ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
            .cornerRadius(12)
        }
        .disabled(isSubmitting)
    }

    // MARK: - Actions

    private func submitRating() {
        isSubmitting = true

        Task {
            do {
                try await tradeManager.rateTrade(
                    historyId: history.id,
                    rating: rating,
                    comment: comment.isEmpty ? nil : comment
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }

            isSubmitting = false
        }
    }
}

// MARK: - Preview

#Preview {
    TradeRatingView(
        history: TradeHistory(
            id: "test",
            offerId: nil,
            sellerId: "seller123",
            sellerUsername: "卖家小明",
            buyerId: "buyer456",
            buyerUsername: "买家小红",
            itemsExchanged: TradeExchangeDetail(
                sellerGave: [TradeItem(itemId: "item_wood", quantity: 50)],
                buyerGave: [TradeItem(itemId: "item_stone", quantity: 30)]
            ),
            completedAt: Date(),
            sellerRating: nil,
            buyerRating: nil,
            sellerComment: nil,
            buyerComment: nil
        ),
        currentUserId: "buyer456"
    )
    .environmentObject(TradeManager.shared)
}
