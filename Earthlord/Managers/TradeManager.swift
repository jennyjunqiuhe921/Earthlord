//
//  TradeManager.swift
//  Earthlord
//
//  Created by Claude on 2026-01-25.
//
//  交易管理器 - 管理交易挂单、接受、取消等操作
//

import Foundation
import Combine
import Supabase

/// 交易管理器（单例）
@MainActor
class TradeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = TradeManager()

    // MARK: - Published Properties

    /// 我发布的挂单列表
    @Published var myOffers: [TradeOffer] = []

    /// 可接受的挂单列表（其他人的活跃挂单）
    @Published var availableOffers: [TradeOffer] = []

    /// 交易历史列表
    @Published var tradeHistory: [TradeHistory] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误消息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let supabase: SupabaseClient
    private var inventoryManager: InventoryManager?

    /// 默认挂单有效期（小时）
    private let defaultExpirationHours: Int = 24

    // MARK: - Initialization

    private init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://acnriuoexalqvckiuvgr.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFjbnJpdW9leGFscXZja2l1dmdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5NTQzNDUsImV4cCI6MjA4MTUzMDM0NX0.cOTtYT-dnBDLNKFzFh3pIU6H1W0hksl3sdgdWiqOjIM"
        )
    }

    // MARK: - Configuration

    /// 设置 InventoryManager 引用
    func setInventoryManager(_ manager: InventoryManager) {
        self.inventoryManager = manager
    }

    // MARK: - 创建挂单

    /// 创建交易挂单
    /// - Parameters:
    ///   - offeringItems: 提供的物品列表
    ///   - requestingItems: 需要的物品列表
    ///   - message: 留言（可选）
    ///   - expirationHours: 有效期小时数（默认24）
    /// - Returns: 创建的挂单
    @discardableResult
    func createTradeOffer(
        offeringItems: [TradeItem],
        requestingItems: [TradeItem],
        message: String? = nil,
        expirationHours: Int? = nil
    ) async throws -> TradeOffer {
        print("[TradeManager] 开始创建交易挂单...")

        // 1. 获取当前用户信息
        guard let userId = try? await getCurrentUserId() else {
            throw TradeError.userNotLoggedIn
        }
        let username = try? await getCurrentUsername()

        // 2. 验证提供的物品是否足够
        guard let inventory = inventoryManager else {
            throw TradeError.databaseError(underlying: NSError(domain: "TradeManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "InventoryManager 未设置"]))
        }

        for item in offeringItems {
            let owned = getOwnedQuantity(itemId: item.itemId, inventory: inventory)
            if owned < item.quantity {
                throw TradeError.insufficientItems(itemId: item.itemId, required: item.quantity, owned: owned)
            }
        }

        // 3. 锁定物品（从库存扣除）
        for item in offeringItems {
            try await deductItems(itemId: item.itemId, quantity: item.quantity, userId: userId)
        }

        // 4. 计算过期时间
        let hours = expirationHours ?? defaultExpirationHours
        let expiresAt = Date().addingTimeInterval(TimeInterval(hours * 3600))
        let expiresAtString = ISO8601DateFormatter().string(from: expiresAt)

        // 5. 创建挂单记录（直接传递物品数组，Supabase 会自动处理 JSONB）
        let insert = TradeOfferInsert(
            ownerId: userId,
            ownerUsername: username,
            offeringItems: offeringItems,
            requestingItems: requestingItems,
            status: TradeOfferStatus.active.rawValue,
            message: message,
            expiresAt: expiresAtString
        )

        do {
            print("[TradeManager] 准备插入挂单...")
            print("[TradeManager] offeringItems: \(offeringItems)")
            print("[TradeManager] requestingItems: \(requestingItems)")

            let response: [TradeOfferDB] = try await supabase
                .from("trade_offers")
                .insert(insert)
                .select()
                .execute()
                .value

            print("[TradeManager] 数据库响应: \(response.count) 条记录")

            guard let offerDB = response.first else {
                print("[TradeManager] ❌ 数据库返回空响应")
                throw TradeError.invalidData
            }

            print("[TradeManager] offerDB.createdAt: \(offerDB.createdAt)")
            print("[TradeManager] offerDB.expiresAt: \(offerDB.expiresAt)")

            guard let offer = offerDB.toTradeOffer() else {
                print("[TradeManager] ❌ toTradeOffer() 转换失败")
                throw TradeError.invalidData
            }

            print("[TradeManager] ✅ 挂单创建成功: \(offer.id)")

            // 刷新我的挂单列表
            await loadMyOffers()

            return offer

        } catch let error as TradeError {
            // 创建失败，退还物品
            for item in offeringItems {
                try? await addItems(itemId: item.itemId, quantity: item.quantity, userId: userId)
            }
            throw error
        } catch {
            // 创建失败，退还物品
            for item in offeringItems {
                try? await addItems(itemId: item.itemId, quantity: item.quantity, userId: userId)
            }
            throw TradeError.databaseError(underlying: error)
        }
    }

    // MARK: - 接受交易

    /// 接受交易挂单（使用数据库函数绕过 RLS）
    /// - Parameter offerId: 挂单 ID
    /// - Returns: 交易历史记录
    @discardableResult
    func acceptTradeOffer(offerId: String) async throws -> TradeHistory {
        print("[TradeManager] 开始接受交易: \(offerId)")

        // 1. 获取当前用户信息
        guard let buyerId = try? await getCurrentUserId() else {
            throw TradeError.userNotLoggedIn
        }
        let buyerUsername = (try? await getCurrentUsername()) ?? "unknown"

        guard let inventory = inventoryManager else {
            throw TradeError.databaseError(underlying: NSError(domain: "TradeManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "InventoryManager 未设置"]))
        }

        // 2. 先在客户端验证库存（优化用户体验，避免不必要的服务器调用）
        let offerResponse: [TradeOfferDB] = try await supabase
            .from("trade_offers")
            .select()
            .eq("id", value: offerId)
            .execute()
            .value

        guard let offerDB = offerResponse.first,
              let offer = offerDB.toTradeOffer() else {
            throw TradeError.offerNotFound
        }

        // 客户端预验证
        guard offer.status == .active else {
            throw TradeError.offerAlreadyCompleted
        }

        guard !offer.isExpired else {
            throw TradeError.offerExpired
        }

        guard offer.ownerId != buyerId else {
            throw TradeError.cannotAcceptOwnOffer
        }

        for item in offer.requestingItems {
            let owned = getOwnedQuantity(itemId: item.itemId, inventory: inventory)
            if owned < item.quantity {
                throw TradeError.insufficientItems(itemId: item.itemId, required: item.quantity, owned: owned)
            }
        }

        // 3. 调用数据库函数执行交易（带 SECURITY DEFINER，可以绕过 RLS）
        let result: ExecuteTradeResult = try await supabase
            .rpc("execute_trade", params: [
                "p_offer_id": offerId,
                "p_buyer_id": buyerId,
                "p_buyer_username": buyerUsername
            ])
            .execute()
            .value

        // 4. 检查执行结果
        guard result.success else {
            let errorMsg = result.error ?? "未知错误"
            print("[TradeManager] ❌ 交易失败: \(errorMsg)")

            // 根据错误信息抛出对应的错误
            if errorMsg.contains("不存在") {
                throw TradeError.offerNotFound
            } else if errorMsg.contains("已失效") || errorMsg.contains("已完成") {
                throw TradeError.offerAlreadyCompleted
            } else if errorMsg.contains("已过期") {
                throw TradeError.offerExpired
            } else if errorMsg.contains("自己的") {
                throw TradeError.cannotAcceptOwnOffer
            } else if errorMsg.contains("物品不足") {
                throw TradeError.databaseError(underlying: NSError(domain: "TradeManager", code: 4, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
            } else {
                throw TradeError.databaseError(underlying: NSError(domain: "TradeManager", code: 5, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
            }
        }

        print("[TradeManager] ✅ 交易完成")

        // 5. 刷新数据
        await loadAvailableOffers()
        await loadMyOffers()
        try? await inventory.loadInventory()

        // 6. 获取最新的交易历史记录
        let historyResponse: [TradeHistoryDB] = try await supabase
            .from("trade_history")
            .select()
            .eq("offer_id", value: offerId)
            .order("completed_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let historyDB = historyResponse.first,
              let history = historyDB.toTradeHistory() else {
            // 交易已成功，但获取历史记录失败，创建一个临时的返回值
            print("[TradeManager] ⚠️ 交易成功但获取历史记录失败")
            throw TradeError.invalidData
        }

        // 发送通知
        NotificationCenter.default.post(name: .tradeCompleted, object: history)

        return history
    }

    /// 数据库函数返回结果结构
    private struct ExecuteTradeResult: Codable {
        let success: Bool
        let message: String?
        let error: String?
    }

    // MARK: - 取消挂单

    /// 取消交易挂单（只能取消自己的活跃挂单）
    /// - Parameter offerId: 挂单 ID
    func cancelTradeOffer(offerId: String) async throws {
        print("[TradeManager] 取消挂单: \(offerId)")

        // 1. 获取当前用户
        guard let userId = try? await getCurrentUserId() else {
            throw TradeError.userNotLoggedIn
        }

        // 2. 查询挂单
        let offerResponse: [TradeOfferDB] = try await supabase
            .from("trade_offers")
            .select()
            .eq("id", value: offerId)
            .execute()
            .value

        guard let offerDB = offerResponse.first,
              let offer = offerDB.toTradeOffer() else {
            throw TradeError.offerNotFound
        }

        // 3. 验证权限
        guard offer.ownerId == userId else {
            throw TradeError.databaseError(underlying: NSError(domain: "TradeManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "只能取消自己的挂单"]))
        }

        guard offer.status == .active else {
            throw TradeError.offerAlreadyCompleted
        }

        // 4. 退还物品
        for item in offer.offeringItems {
            try await addItems(itemId: item.itemId, quantity: item.quantity, userId: userId)
        }

        // 5. 更新状态
        let update = TradeOfferUpdate(
            status: TradeOfferStatus.cancelled.rawValue,
            completedAt: nil,
            completedByUserId: nil,
            completedByUsername: nil
        )

        try await supabase
            .from("trade_offers")
            .update(update)
            .eq("id", value: offerId)
            .execute()

        print("[TradeManager] ✅ 挂单已取消")

        // 刷新数据
        await loadMyOffers()
        try? await inventoryManager?.loadInventory()
    }

    // MARK: - 查询方法

    /// 加载我发布的挂单
    func loadMyOffers() async {
        guard let userId = try? await getCurrentUserId() else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response: [TradeOfferDB] = try await supabase
                .from("trade_offers")
                .select()
                .eq("owner_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            self.myOffers = response.compactMap { $0.toTradeOffer() }

            // 检查并处理过期挂单
            await checkAndExpireOffers()

            print("[TradeManager] ✅ 加载了 \(myOffers.count) 个我的挂单")

        } catch {
            print("[TradeManager] ❌ 加载我的挂单失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// 加载可接受的挂单（其他人的活跃挂单）
    func loadAvailableOffers() async {
        guard let userId = try? await getCurrentUserId() else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let now = ISO8601DateFormatter().string(from: Date())

            let response: [TradeOfferDB] = try await supabase
                .from("trade_offers")
                .select()
                .eq("status", value: TradeOfferStatus.active.rawValue)
                .neq("owner_id", value: userId)
                .gt("expires_at", value: now)
                .order("created_at", ascending: false)
                .execute()
                .value

            self.availableOffers = response.compactMap { $0.toTradeOffer() }

            print("[TradeManager] ✅ 加载了 \(availableOffers.count) 个可接受的挂单")

        } catch {
            print("[TradeManager] ❌ 加载可接受挂单失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// 加载交易历史
    func loadTradeHistory() async {
        guard let userId = try? await getCurrentUserId() else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // 查询作为卖家或买家的交易记录
            let response: [TradeHistoryDB] = try await supabase
                .from("trade_history")
                .select()
                .or("seller_id.eq.\(userId),buyer_id.eq.\(userId)")
                .order("completed_at", ascending: false)
                .execute()
                .value

            self.tradeHistory = response.compactMap { $0.toTradeHistory() }

            print("[TradeManager] ✅ 加载了 \(tradeHistory.count) 条交易历史")

        } catch {
            print("[TradeManager] ❌ 加载交易历史失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 评价交易

    /// 评价交易
    /// - Parameters:
    ///   - historyId: 交易历史 ID
    ///   - rating: 评分（1-5）
    ///   - comment: 评语（可选）
    func rateTrade(historyId: String, rating: Int, comment: String? = nil) async throws {
        guard let userId = try? await getCurrentUserId() else {
            throw TradeError.userNotLoggedIn
        }

        // 查询交易历史
        let response: [TradeHistoryDB] = try await supabase
            .from("trade_history")
            .select()
            .eq("id", value: historyId)
            .execute()
            .value

        guard let historyDB = response.first,
              let history = historyDB.toTradeHistory() else {
            throw TradeError.offerNotFound
        }

        // 确定当前用户角色并更新
        var update: TradeRatingUpdate

        if history.sellerId == userId {
            // 当前用户是卖家，给买家评分
            update = TradeRatingUpdate(
                sellerRating: rating,
                buyerRating: nil,
                sellerComment: comment,
                buyerComment: nil
            )
        } else if history.buyerId == userId {
            // 当前用户是买家，给卖家评分
            update = TradeRatingUpdate(
                sellerRating: nil,
                buyerRating: rating,
                sellerComment: nil,
                buyerComment: comment
            )
        } else {
            throw TradeError.databaseError(underlying: NSError(domain: "TradeManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "只能评价自己参与的交易"]))
        }

        try await supabase
            .from("trade_history")
            .update(update)
            .eq("id", value: historyId)
            .execute()

        print("[TradeManager] ✅ 评价成功")

        // 刷新历史
        await loadTradeHistory()
    }

    // MARK: - 过期处理

    /// 检查并处理过期挂单
    private func checkAndExpireOffers() async {
        for offer in myOffers where offer.status == .active && offer.isExpired {
            do {
                try await expireOffer(offer)
            } catch {
                print("[TradeManager] ❌ 处理过期挂单失败: \(error.localizedDescription)")
            }
        }
    }

    /// 将挂单标记为过期并退还物品
    private func expireOffer(_ offer: TradeOffer) async throws {
        // 退还物品
        for item in offer.offeringItems {
            try await addItems(itemId: item.itemId, quantity: item.quantity, userId: offer.ownerId)
        }

        // 更新状态
        let update = TradeOfferUpdate(
            status: TradeOfferStatus.expired.rawValue,
            completedAt: nil,
            completedByUserId: nil,
            completedByUsername: nil
        )

        try await supabase
            .from("trade_offers")
            .update(update)
            .eq("id", value: offer.id)
            .execute()

        print("[TradeManager] ⏰ 挂单已过期: \(offer.id)")
    }

    // MARK: - Helper Methods

    /// 获取当前用户 ID
    private func getCurrentUserId() async throws -> String {
        let session = try await supabase.auth.session
        return session.user.id.uuidString
    }

    /// 获取当前用户名
    private func getCurrentUsername() async throws -> String? {
        let session = try await supabase.auth.session
        return session.user.email?.components(separatedBy: "@").first
    }

    /// 获取拥有的物品数量
    private func getOwnedQuantity(itemId: String, inventory: InventoryManager) -> Int {
        inventory.inventoryItems
            .filter { $0.definitionId == itemId }
            .reduce(0) { $0 + $1.quantity }
    }

    /// 从用户库存扣除物品
    private func deductItems(itemId: String, quantity: Int, userId: String) async throws {
        guard let inventory = inventoryManager else { return }

        var remaining = quantity
        let items = inventory.inventoryItems.filter { $0.definitionId == itemId }

        for item in items {
            if remaining <= 0 { break }

            let deductAmount = min(item.quantity, remaining)
            try await inventory.useItem(item, quantity: deductAmount)
            remaining -= deductAmount
        }
    }

    /// 向用户库存添加物品
    private func addItems(itemId: String, quantity: Int, userId: String) async throws {
        // 直接使用 Supabase 插入，因为可能是给其他用户添加物品
        let insert = InventoryItemInsert(
            userId: userId,
            itemDefinitionId: itemId,
            quantity: quantity,
            quality: nil,
            customName: nil,
            customStory: nil,
            customCategory: nil,
            customRarity: nil
        )

        // 检查是否已有该物品
        let existing: [InventoryItemDB] = try await supabase
            .from("inventory_items")
            .select()
            .eq("user_id", value: userId)
            .eq("item_definition_id", value: itemId)
            .execute()
            .value

        if let existingItem = existing.first {
            // 更新数量
            let newQuantity = existingItem.quantity + quantity
            let now = ISO8601DateFormatter().string(from: Date())
            let update = InventoryItemUpdate(quantity: newQuantity, updatedAt: now)

            try await supabase
                .from("inventory_items")
                .update(update)
                .eq("id", value: existingItem.id)
                .execute()
        } else {
            // 插入新记录
            try await supabase
                .from("inventory_items")
                .insert(insert)
                .execute()
        }
    }

    /// 从指定用户库存扣除物品（用于回滚）
    private func deductItemsForUser(itemId: String, quantity: Int, userId: String) async throws {
        // 查询用户的物品
        let items: [InventoryItemDB] = try await supabase
            .from("inventory_items")
            .select()
            .eq("user_id", value: userId)
            .eq("item_definition_id", value: itemId)
            .execute()
            .value

        var remaining = quantity

        for item in items {
            if remaining <= 0 { break }

            let deductAmount = min(item.quantity, remaining)
            let newQuantity = item.quantity - deductAmount

            if newQuantity <= 0 {
                // 删除记录
                try await supabase
                    .from("inventory_items")
                    .delete()
                    .eq("id", value: item.id)
                    .execute()
            } else {
                // 更新数量
                let now = ISO8601DateFormatter().string(from: Date())
                let update = InventoryItemUpdate(quantity: newQuantity, updatedAt: now)
                try await supabase
                    .from("inventory_items")
                    .update(update)
                    .eq("id", value: item.id)
                    .execute()
            }

            remaining -= deductAmount
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let tradeCompleted = Notification.Name("tradeCompleted")
    static let tradeOfferCreated = Notification.Name("tradeOfferCreated")
    static let tradeOfferCancelled = Notification.Name("tradeOfferCancelled")
}
