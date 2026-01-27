//
//  TradeModels.swift
//  Earthlord
//
//  Created by Claude on 2026-01-25.
//
//  交易系统数据模型
//

import Foundation

// MARK: - 交易状态枚举

/// 交易挂单状态
enum TradeOfferStatus: String, Codable, CaseIterable {
    case active = "active"           // 等待中，可被接受
    case completed = "completed"     // 已完成，被其他用户接受
    case cancelled = "cancelled"     // 已取消，发布者主动取消
    case expired = "expired"         // 已过期，超时自动失效

    /// 状态显示名称
    var displayName: String {
        switch self {
        case .active: return "等待中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        case .expired: return "已过期"
        }
    }

    /// 状态颜色名称
    var colorName: String {
        switch self {
        case .active: return "orange"
        case .completed: return "green"
        case .cancelled: return "gray"
        case .expired: return "red"
        }
    }
}

// MARK: - 交易物品

/// 交易物品（用于挂单中的物品列表）
struct TradeItem: Codable, Identifiable, Equatable {
    var id: String { itemId }
    let itemId: String          // 物品定义 ID
    let quantity: Int           // 数量

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
    }

    init(itemId: String, quantity: Int) {
        self.itemId = itemId
        self.quantity = quantity
    }
}

// MARK: - 交易挂单

/// 交易挂单（本地模型）
struct TradeOffer: Identifiable, Codable {
    let id: String                          // 唯一标识
    let ownerId: String                     // 发布者 ID
    let ownerUsername: String?              // 发布者用户名
    let offeringItems: [TradeItem]          // 提供的物品
    let requestingItems: [TradeItem]        // 需要的物品
    var status: TradeOfferStatus            // 当前状态
    let message: String?                    // 留言备注
    let createdAt: Date                     // 创建时间
    let expiresAt: Date                     // 过期时间
    var completedAt: Date?                  // 完成时间
    var completedByUserId: String?          // 接受者 ID
    var completedByUsername: String?        // 接受者用户名

    /// 是否已过期
    var isExpired: Bool {
        Date() > expiresAt
    }

    /// 是否可被接受
    var canBeAccepted: Bool {
        status == .active && !isExpired
    }

    /// 剩余时间（秒）
    var remainingSeconds: Int {
        max(0, Int(expiresAt.timeIntervalSinceNow))
    }

    /// 格式化剩余时间
    var formattedRemainingTime: String {
        let seconds = remainingSeconds
        if seconds <= 0 { return "已过期" }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)时\(minutes)分"
        } else if minutes > 0 {
            return "\(minutes)分"
        } else {
            return "\(seconds)秒"
        }
    }
}

// MARK: - 交易历史

/// 交易历史记录（本地模型）
struct TradeHistory: Identifiable, Codable {
    let id: String                          // 唯一标识
    let offerId: String?                    // 关联的挂单 ID
    let sellerId: String                    // 卖家（发布者）ID
    let sellerUsername: String?             // 卖家用户名
    let buyerId: String                     // 买家（接受者）ID
    let buyerUsername: String?              // 买家用户名
    let itemsExchanged: TradeExchangeDetail // 交换的物品详情
    let completedAt: Date                   // 完成时间
    var sellerRating: Int?                  // 卖家给买家的评分（1-5）
    var buyerRating: Int?                   // 买家给卖家的评分（1-5）
    var sellerComment: String?              // 卖家评语
    var buyerComment: String?               // 买家评语

    /// 当前用户是卖家
    func isSeller(userId: String) -> Bool {
        sellerId == userId
    }

    /// 当前用户是买家
    func isBuyer(userId: String) -> Bool {
        buyerId == userId
    }

    /// 当前用户是否已评价
    func hasRated(userId: String) -> Bool {
        if isSeller(userId: userId) {
            return sellerRating != nil
        } else if isBuyer(userId: userId) {
            return buyerRating != nil
        }
        return false
    }
}

/// 交换详情
struct TradeExchangeDetail: Codable {
    let sellerGave: [TradeItem]     // 卖家给出的物品
    let buyerGave: [TradeItem]      // 买家给出的物品

    enum CodingKeys: String, CodingKey {
        case sellerGave = "seller_gave"
        case buyerGave = "buyer_gave"
    }
}

// MARK: - 数据库结构

/// 交易挂单（数据库结构）
struct TradeOfferDB: Codable {
    let id: String
    let ownerId: String
    let ownerUsername: String?
    let offeringItems: [TradeItem]   // JSONB 直接解码为数组
    let requestingItems: [TradeItem] // JSONB 直接解码为数组
    let status: String
    let message: String?
    let createdAt: String
    let expiresAt: String
    let completedAt: String?
    let completedByUserId: String?
    let completedByUsername: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case status
        case message
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case completedAt = "completed_at"
        case completedByUserId = "completed_by_user_id"
        case completedByUsername = "completed_by_username"
    }

    /// 转换为本地模型
    func toTradeOffer() -> TradeOffer? {
        // 尝试多种日期格式
        guard let createdDate = Self.parseDate(createdAt),
              let expiresDate = Self.parseDate(expiresAt) else {
            print("[TradeOfferDB] 日期解析失败: createdAt=\(createdAt), expiresAt=\(expiresAt)")
            return nil
        }

        let completedDate: Date? = completedAt != nil ? Self.parseDate(completedAt!) : nil

        return TradeOffer(
            id: id,
            ownerId: ownerId,
            ownerUsername: ownerUsername,
            offeringItems: offeringItems,
            requestingItems: requestingItems,
            status: TradeOfferStatus(rawValue: status) ?? .active,
            message: message,
            createdAt: createdDate,
            expiresAt: expiresDate,
            completedAt: completedDate,
            completedByUserId: completedByUserId,
            completedByUsername: completedByUsername
        )
    }

    /// 解析日期（支持多种格式）
    private static func parseDate(_ dateString: String) -> Date? {
        // 尝试带小数秒的格式
        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFraction.date(from: dateString) {
            return date
        }

        // 尝试不带小数秒的格式
        let formatterWithoutFraction = ISO8601DateFormatter()
        formatterWithoutFraction.formatOptions = [.withInternetDateTime]
        if let date = formatterWithoutFraction.date(from: dateString) {
            return date
        }

        // 尝试 Supabase 默认格式（带时区偏移）
        let customFormatter = DateFormatter()
        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        customFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = customFormatter.date(from: dateString) {
            return date
        }

        // 尝试不带时区的格式
        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return customFormatter.date(from: dateString)
    }
}

/// 交易历史（数据库结构）
struct TradeHistoryDB: Codable {
    let id: String
    let offerId: String?
    let sellerId: String
    let sellerUsername: String?
    let buyerId: String
    let buyerUsername: String?
    let itemsExchanged: TradeExchangeDetail  // JSONB 直接解码为对象
    let completedAt: String
    let sellerRating: Int?
    let buyerRating: Int?
    let sellerComment: String?
    let buyerComment: String?

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case sellerUsername = "seller_username"
        case buyerId = "buyer_id"
        case buyerUsername = "buyer_username"
        case itemsExchanged = "items_exchanged"
        case completedAt = "completed_at"
        case sellerRating = "seller_rating"
        case buyerRating = "buyer_rating"
        case sellerComment = "seller_comment"
        case buyerComment = "buyer_comment"
    }

    /// 转换为本地模型
    func toTradeHistory() -> TradeHistory? {
        guard let completedDate = Self.parseDate(completedAt) else {
            print("[TradeHistoryDB] 日期解析失败: completedAt=\(completedAt)")
            return nil
        }

        return TradeHistory(
            id: id,
            offerId: offerId,
            sellerId: sellerId,
            sellerUsername: sellerUsername,
            buyerId: buyerId,
            buyerUsername: buyerUsername,
            itemsExchanged: itemsExchanged,
            completedAt: completedDate,
            sellerRating: sellerRating,
            buyerRating: buyerRating,
            sellerComment: sellerComment,
            buyerComment: buyerComment
        )
    }

    /// 解析日期（支持多种格式）
    private static func parseDate(_ dateString: String) -> Date? {
        // 尝试带小数秒的格式
        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFraction.date(from: dateString) {
            return date
        }

        // 尝试不带小数秒的格式
        let formatterWithoutFraction = ISO8601DateFormatter()
        formatterWithoutFraction.formatOptions = [.withInternetDateTime]
        if let date = formatterWithoutFraction.date(from: dateString) {
            return date
        }

        // 尝试 Supabase 默认格式
        let customFormatter = DateFormatter()
        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        customFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = customFormatter.date(from: dateString) {
            return date
        }

        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return customFormatter.date(from: dateString)
    }
}

// MARK: - 插入结构

/// 交易挂单插入结构
struct TradeOfferInsert: Codable {
    let ownerId: String
    let ownerUsername: String?
    let offeringItems: [TradeItem]  // JSONB 原生数组
    let requestingItems: [TradeItem] // JSONB 原生数组
    let status: String
    let message: String?
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case status
        case message
        case expiresAt = "expires_at"
    }
}

/// 交易挂单更新结构
struct TradeOfferUpdate: Codable {
    let status: String?
    let completedAt: String?
    let completedByUserId: String?
    let completedByUsername: String?

    enum CodingKeys: String, CodingKey {
        case status
        case completedAt = "completed_at"
        case completedByUserId = "completed_by_user_id"
        case completedByUsername = "completed_by_username"
    }
}

/// 交易历史插入结构
struct TradeHistoryInsert: Codable {
    let offerId: String?
    let sellerId: String
    let sellerUsername: String?
    let buyerId: String
    let buyerUsername: String?
    let itemsExchanged: TradeExchangeDetail  // JSONB 原生对象
    let completedAt: String

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case sellerUsername = "seller_username"
        case buyerId = "buyer_id"
        case buyerUsername = "buyer_username"
        case itemsExchanged = "items_exchanged"
        case completedAt = "completed_at"
    }
}

/// 交易评价更新结构
struct TradeRatingUpdate: Codable {
    let sellerRating: Int?
    let buyerRating: Int?
    let sellerComment: String?
    let buyerComment: String?

    enum CodingKeys: String, CodingKey {
        case sellerRating = "seller_rating"
        case buyerRating = "buyer_rating"
        case sellerComment = "seller_comment"
        case buyerComment = "buyer_comment"
    }
}

// MARK: - 错误类型

/// 交易错误
enum TradeError: LocalizedError {
    case userNotLoggedIn
    case offerNotFound
    case offerAlreadyCompleted
    case offerExpired
    case cannotAcceptOwnOffer
    case insufficientItems(itemId: String, required: Int, owned: Int)
    case databaseError(underlying: Error)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .userNotLoggedIn:
            return "请先登录"
        case .offerNotFound:
            return "挂单不存在"
        case .offerAlreadyCompleted:
            return "挂单已失效"
        case .offerExpired:
            return "挂单已过期"
        case .cannotAcceptOwnOffer:
            return "不能接受自己的挂单"
        case .insufficientItems(let itemId, let required, let owned):
            return "物品不足：\(itemId) 还需 \(required - owned) 个"
        case .databaseError(let error):
            return "数据库错误：\(error.localizedDescription)"
        case .invalidData:
            return "数据格式无效"
        }
    }
}
