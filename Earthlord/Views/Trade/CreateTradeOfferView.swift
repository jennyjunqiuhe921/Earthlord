//
//  CreateTradeOfferView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-26.
//
//  发布交易挂单视图

import SwiftUI

/// 有效期选项
enum ExpirationOption: Int, CaseIterable, Identifiable {
    case hour1 = 1
    case hour6 = 6
    case hour12 = 12
    case hour24 = 24
    case hour48 = 48
    case hour72 = 72

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .hour1: return "1小时"
        case .hour6: return "6小时"
        case .hour12: return "12小时"
        case .hour24: return "24小时"
        case .hour48: return "48小时"
        case .hour72: return "72小时"
        }
    }
}

/// 发布交易挂单视图
struct CreateTradeOfferView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tradeManager: TradeManager
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: - State

    /// 提供的物品列表
    @State private var offeringItems: [TradeItem] = []

    /// 需要的物品列表
    @State private var requestingItems: [TradeItem] = []

    /// 留言
    @State private var message: String = ""

    /// 有效期
    @State private var selectedExpiration: ExpirationOption = .hour24

    /// 是否显示物品选择器（提供的物品）
    @State private var showingOfferingPicker = false

    /// 是否显示物品选择器（需要的物品）
    @State private var showingRequestingPicker = false

    /// 是否正在发布
    @State private var isPublishing = false

    /// 错误消息
    @State private var errorMessage: String?

    /// 是否显示错误
    @State private var showingError = false

    /// 是否显示成功
    @State private var showingSuccess = false

    // MARK: - Computed Properties

    /// 是否可以发布
    private var canPublish: Bool {
        !offeringItems.isEmpty && !requestingItems.isEmpty && !isPublishing
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 提供的物品区域
                        offeringSection

                        // 交换箭头
                        exchangeArrow

                        // 需要的物品区域
                        requestingSection

                        // 有效期选择
                        expirationSection

                        // 留言输入
                        messageSection

                        // 发布按钮
                        publishButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("发布挂单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .sheet(isPresented: $showingOfferingPicker) {
                ItemPickerView(mode: .inventory) { itemId, quantity in
                    addItem(itemId: itemId, quantity: quantity, to: &offeringItems)
                }
                .environmentObject(inventoryManager)
            }
            .sheet(isPresented: $showingRequestingPicker) {
                ItemPickerView(mode: .allItems) { itemId, quantity in
                    addItem(itemId: itemId, quantity: quantity, to: &requestingItems)
                }
                .environmentObject(inventoryManager)
            }
            .alert("发布失败", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .alert("发布成功", isPresented: $showingSuccess) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("你的挂单已发布到交易市场！")
            }
        }
    }

    // MARK: - 提供的物品区域

    private var offeringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.success)

                Text("我要出")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ApocalypseTheme.success)

                Spacer()

                Text("从背包选择")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 物品列表
            if offeringItems.isEmpty {
                emptyItemsPlaceholder(text: "点击下方按钮添加你要出的物品")
            } else {
                ForEach(offeringItems) { item in
                    TradeItemRow(item: item, showDelete: true) {
                        removeItem(item, from: &offeringItems)
                    }
                }
            }

            // 添加按钮
            addItemButton {
                showingOfferingPicker = true
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

    // MARK: - 需要的物品区域

    private var requestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("我想要")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ApocalypseTheme.warning)

                Spacer()

                Text("从所有物品选择")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 物品列表
            if requestingItems.isEmpty {
                emptyItemsPlaceholder(text: "点击下方按钮添加你想要的物品")
            } else {
                ForEach(requestingItems) { item in
                    TradeItemRow(item: item, showDelete: true) {
                        removeItem(item, from: &requestingItems)
                    }
                }
            }

            // 添加按钮
            addItemButton {
                showingRequestingPicker = true
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

    // MARK: - 有效期选择

    private var expirationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.info)

                Text("有效期")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ExpirationOption.allCases) { option in
                        Button(action: {
                            selectedExpiration = option
                        }) {
                            Text(option.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(selectedExpiration == option ? .white : ApocalypseTheme.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedExpiration == option ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedExpiration == option ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 留言输入

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("留言（可选）")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            TextField("给买家留言...", text: $message, axis: .vertical)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(3...5)
                .padding(12)
                .background(ApocalypseTheme.background)
                .cornerRadius(8)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 发布按钮

    private var publishButton: some View {
        Button(action: publishOffer) {
            HStack(spacing: 8) {
                if isPublishing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .bold))
                }

                Text(isPublishing ? "发布中..." : "发布挂单")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canPublish ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            .cornerRadius(12)
        }
        .disabled(!canPublish)
    }

    // MARK: - 空物品占位符

    private func emptyItemsPlaceholder(text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(ApocalypseTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(ApocalypseTheme.background.opacity(0.5))
            .cornerRadius(8)
    }

    // MARK: - 添加物品按钮

    private func addItemButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))

                Text("添加物品")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(ApocalypseTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(ApocalypseTheme.primary.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Helper Methods

    private func addItem(itemId: String, quantity: Int, to items: inout [TradeItem]) {
        // 检查是否已存在相同物品
        if let index = items.firstIndex(where: { $0.itemId == itemId }) {
            // 合并数量
            let existing = items[index]
            items[index] = TradeItem(itemId: itemId, quantity: existing.quantity + quantity)
        } else {
            items.append(TradeItem(itemId: itemId, quantity: quantity))
        }
    }

    private func removeItem(_ item: TradeItem, from items: inout [TradeItem]) {
        items.removeAll { $0.itemId == item.itemId }
    }

    private func publishOffer() {
        isPublishing = true

        Task {
            do {
                _ = try await tradeManager.createTradeOffer(
                    offeringItems: offeringItems,
                    requestingItems: requestingItems,
                    message: message.isEmpty ? nil : message,
                    expirationHours: selectedExpiration.rawValue
                )

                // 刷新库存
                try? await inventoryManager.loadInventory()

                showingSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }

            isPublishing = false
        }
    }
}

// MARK: - Preview

#Preview {
    CreateTradeOfferView()
        .environmentObject(TradeManager.shared)
        .environmentObject(InventoryManager())
}
