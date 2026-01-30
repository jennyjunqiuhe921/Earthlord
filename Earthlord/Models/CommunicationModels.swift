//
//  CommunicationModels.swift
//  Earthlord
//
//  Created by Claude on 2026-01-27.
//
//  通讯系统数据模型
//

import Foundation

// MARK: - 设备类型
enum DeviceType: String, Codable, CaseIterable {
    case radio = "radio"
    case walkieTalkie = "walkie_talkie"
    case campRadio = "camp_radio"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .radio: return "收音机"
        case .walkieTalkie: return "对讲机"
        case .campRadio: return "营地电台"
        case .satellite: return "卫星通讯"
        }
    }

    var iconName: String {
        switch self {
        case .radio: return "radio"
        case .walkieTalkie: return "walkie.talkie.radio"
        case .campRadio: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .radio: return "只能接收信号，无法发送消息"
        case .walkieTalkie: return "可在3公里范围内通讯"
        case .campRadio: return "可在30公里范围内广播"
        case .satellite: return "可在100公里+范围内联络"
        }
    }

    var range: Double {
        switch self {
        case .radio: return Double.infinity
        case .walkieTalkie: return 3.0
        case .campRadio: return 30.0
        case .satellite: return 100.0
        }
    }

    var rangeText: String {
        switch self {
        case .radio: return "无限制（仅接收）"
        case .walkieTalkie: return "3 公里"
        case .campRadio: return "30 公里"
        case .satellite: return "100+ 公里"
        }
    }

    var canSend: Bool {
        self != .radio
    }

    var unlockRequirement: String {
        switch self {
        case .radio, .walkieTalkie: return "默认拥有"
        case .campRadio: return "需建造「营地电台」建筑"
        case .satellite: return "需建造「通讯塔」建筑"
        }
    }
}

// MARK: - 设备模型
struct CommunicationDevice: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let deviceType: DeviceType
    var deviceLevel: Int
    var isUnlocked: Bool
    var isCurrent: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceType = "device_type"
        case deviceLevel = "device_level"
        case isUnlocked = "is_unlocked"
        case isCurrent = "is_current"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 导航枚举
enum CommunicationSection: String, CaseIterable {
    case messages = "消息"
    case channels = "频道"
    case call = "呼叫"
    case devices = "设备"

    var iconName: String {
        switch self {
        case .messages: return "bell.fill"
        case .channels: return "dot.radiowaves.left.and.right"
        case .call: return "phone.fill"
        case .devices: return "gearshape.fill"
        }
    }
}

// MARK: - 频道类型
enum ChannelType: String, Codable, CaseIterable {
    case official = "official"
    case publicChannel = "public"
    case walkie = "walkie"
    case camp = "camp"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .official: return "官方频道"
        case .publicChannel: return "公开频道"
        case .walkie: return "对讲机频道"
        case .camp: return "营地频道"
        case .satellite: return "卫星频道"
        }
    }

    var iconName: String {
        switch self {
        case .official: return "megaphone.fill"
        case .publicChannel: return "globe"
        case .walkie: return "walkie.talkie.radio"
        case .camp: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .official: return "系统官方发布的公告频道"
        case .publicChannel: return "任何人都可以加入的公开频道"
        case .walkie: return "需要对讲机设备，3公里范围"
        case .camp: return "需要营地电台，30公里范围"
        case .satellite: return "需要卫星通讯，100+公里范围"
        }
    }

    var rangeText: String {
        switch self {
        case .official, .publicChannel: return "无限制"
        case .walkie: return "3 公里"
        case .camp: return "30 公里"
        case .satellite: return "100+ 公里"
        }
    }

    var requiredDevice: DeviceType? {
        switch self {
        case .official, .publicChannel: return nil
        case .walkie: return .walkieTalkie
        case .camp: return .campRadio
        case .satellite: return .satellite
        }
    }

    /// 用于创建频道的可选类型（排除官方频道）
    static var creatableTypes: [ChannelType] {
        [.publicChannel, .walkie, .camp, .satellite]
    }
}

// MARK: - 频道模型
struct CommunicationChannel: Codable, Identifiable {
    let id: UUID
    let creatorId: UUID
    let channelType: ChannelType
    let channelCode: String
    let name: String
    let description: String?
    let isActive: Bool
    let memberCount: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case name
        case description
        case isActive = "is_active"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // 普通初始化器（用于 Preview 和测试）
    init(
        id: UUID,
        creatorId: UUID,
        channelType: ChannelType,
        channelCode: String,
        name: String,
        description: String?,
        isActive: Bool,
        memberCount: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.creatorId = creatorId
        self.channelType = channelType
        self.channelCode = channelCode
        self.name = name
        self.description = description
        self.isActive = isActive
        self.memberCount = memberCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        creatorId = try container.decode(UUID.self, forKey: .creatorId)

        // 处理 channel_type 的特殊映射
        let typeString = try container.decode(String.self, forKey: .channelType)
        if typeString == "public" {
            channelType = .publicChannel
        } else {
            channelType = ChannelType(rawValue: typeString) ?? .publicChannel
        }

        channelCode = try container.decode(String.self, forKey: .channelCode)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        memberCount = try container.decode(Int.self, forKey: .memberCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

// MARK: - 频道订阅模型
struct ChannelSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let channelId: UUID
    var isMuted: Bool
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case channelId = "channel_id"
        case isMuted = "is_muted"
        case joinedAt = "joined_at"
    }
}

// MARK: - 已订阅频道（组合模型）
struct SubscribedChannel: Identifiable {
    let channel: CommunicationChannel
    let subscription: ChannelSubscription

    var id: UUID { channel.id }
}

// MARK: - ========== Day 34: 消息系统模型 ==========

// MARK: - 位置点结构体
struct LocationPoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    /// 从 PostGIS WKT 格式解析位置
    /// 例如: "POINT(-122.4194 37.7749)"
    static func fromPostGIS(_ value: String?) -> LocationPoint? {
        guard let value = value, !value.isEmpty else { return nil }

        // 尝试解析 WKT 格式: POINT(longitude latitude)
        let uppercased = value.uppercased()
        if uppercased.hasPrefix("POINT") {
            let cleaned = value
                .replacingOccurrences(of: "POINT(", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: ")", with: "")
                .trimmingCharacters(in: .whitespaces)

            let parts = cleaned.split(separator: " ")
            if parts.count == 2,
               let lon = Double(parts[0]),
               let lat = Double(parts[1]) {
                return LocationPoint(latitude: lat, longitude: lon)
            }
        }

        return nil
    }
}

// MARK: - 消息元数据
struct MessageMetadata: Codable {
    var deviceType: String?
    var replyToId: UUID?
    var attachmentUrl: String?
    var isEdited: Bool?

    enum CodingKeys: String, CodingKey {
        case deviceType = "device_type"
        case replyToId = "reply_to_id"
        case attachmentUrl = "attachment_url"
        case isEdited = "is_edited"
    }

    init(deviceType: String? = nil, replyToId: UUID? = nil, attachmentUrl: String? = nil, isEdited: Bool? = nil) {
        self.deviceType = deviceType
        self.replyToId = replyToId
        self.attachmentUrl = attachmentUrl
        self.isEdited = isEdited
    }
}

// MARK: - 消息类型枚举
enum MessageType: String, Codable {
    case text = "text"
    case system = "system"
    case location = "location"
    case alert = "alert"

    var displayName: String {
        switch self {
        case .text: return "文本"
        case .system: return "系统"
        case .location: return "位置"
        case .alert: return "警报"
        }
    }
}

// MARK: - 频道消息模型
struct ChannelMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let channelId: UUID
    let senderId: UUID
    let content: String
    let messageType: MessageType
    let senderLocation: LocationPoint?
    let metadata: MessageMetadata?
    let isDeleted: Bool
    let createdAt: Date
    let updatedAt: Date

    // 关联数据（JOIN 查询获取）
    var senderUsername: String?
    var senderAvatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case channelId = "channel_id"
        case senderId = "sender_id"
        case content
        case messageType = "message_type"
        case senderLocation = "sender_location"
        case metadata
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case senderUsername = "sender_username"
        case senderAvatarUrl = "sender_avatar_url"
    }

    // 普通初始化器（用于 Preview 和测试）
    init(
        id: UUID = UUID(),
        channelId: UUID,
        senderId: UUID,
        content: String,
        messageType: MessageType = .text,
        senderLocation: LocationPoint? = nil,
        metadata: MessageMetadata? = nil,
        isDeleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        senderUsername: String? = nil,
        senderAvatarUrl: String? = nil
    ) {
        self.id = id
        self.channelId = channelId
        self.senderId = senderId
        self.content = content
        self.messageType = messageType
        self.senderLocation = senderLocation
        self.metadata = metadata
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.senderUsername = senderUsername
        self.senderAvatarUrl = senderAvatarUrl
    }

    // 自定义解码器处理 PostGIS 和日期格式
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        channelId = try container.decode(UUID.self, forKey: .channelId)
        senderId = try container.decode(UUID.self, forKey: .senderId)
        content = try container.decode(String.self, forKey: .content)

        // 消息类型
        let typeString = try container.decode(String.self, forKey: .messageType)
        messageType = MessageType(rawValue: typeString) ?? .text

        // PostGIS POINT 解析
        if let locationString = try container.decodeIfPresent(String.self, forKey: .senderLocation) {
            senderLocation = LocationPoint.fromPostGIS(locationString)
        } else {
            senderLocation = nil
        }

        // 元数据
        metadata = try container.decodeIfPresent(MessageMetadata.self, forKey: .metadata)

        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false

        // 日期解析 - 支持多种格式
        createdAt = try Self.decodeDate(from: container, forKey: .createdAt) ?? Date()
        updatedAt = try Self.decodeDate(from: container, forKey: .updatedAt) ?? Date()

        // 关联数据
        senderUsername = try container.decodeIfPresent(String.self, forKey: .senderUsername)
        senderAvatarUrl = try container.decodeIfPresent(String.self, forKey: .senderAvatarUrl)
    }

    // 日期解码辅助方法
    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Date? {
        // 首先尝试标准 Date 解码
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }

        // 尝试字符串格式
        if let dateString = try? container.decode(String.self, forKey: key) {
            // ISO8601 格式（带毫秒）
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // ISO8601 格式（不带毫秒）
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // PostgreSQL 默认格式
            let pgFormatter = DateFormatter()
            pgFormatter.locale = Locale(identifier: "en_US_POSIX")
            pgFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
            if let date = pgFormatter.date(from: dateString) {
                return date
            }

            // 简化格式
            pgFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let date = pgFormatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    // Equatable
    static func == (lhs: ChannelMessage, rhs: ChannelMessage) -> Bool {
        lhs.id == rhs.id
    }

    // 显示用计算属性
    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: createdAt)
        }
    }
}
