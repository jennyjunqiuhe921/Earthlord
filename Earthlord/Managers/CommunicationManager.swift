//
//  CommunicationManager.swift
//  Earthlord
//
//  Created by Claude on 2026-01-27.
//
//  通讯系统管理器 - 管理通讯设备的加载、切换、解锁等操作
//

import Foundation
import Combine
import Supabase

@MainActor
final class CommunicationManager: ObservableObject {
    static let shared = CommunicationManager()

    // MARK: - 设备属性
    @Published private(set) var devices: [CommunicationDevice] = []
    @Published private(set) var currentDevice: CommunicationDevice?

    // MARK: - 频道属性
    @Published private(set) var channels: [CommunicationChannel] = []
    @Published private(set) var subscribedChannels: [SubscribedChannel] = []
    @Published private(set) var mySubscriptions: [ChannelSubscription] = []

    // MARK: - 状态属性
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let supabase: SupabaseClient

    private init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://acnriuoexalqvckiuvgr.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFjbnJpdW9leGFscXZja2l1dmdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5NTQzNDUsImV4cCI6MjA4MTUzMDM0NX0.cOTtYT-dnBDLNKFzFh3pIU6H1W0hksl3sdgdWiqOjIM"
        )
    }

    // MARK: - 加载设备

    func loadDevices(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationDevice] = try await supabase
                .from("communication_devices")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            devices = response
            currentDevice = devices.first(where: { $0.isCurrent })

            if devices.isEmpty {
                await initializeDevices(userId: userId)
            }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 初始化设备

    func initializeDevices(userId: UUID) async {
        do {
            try await supabase.rpc("initialize_user_devices", params: ["p_user_id": userId.uuidString]).execute()
            await loadDevices(userId: userId)
        } catch {
            errorMessage = "初始化失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 切换设备

    func switchDevice(userId: UUID, to deviceType: DeviceType) async {
        guard let device = devices.first(where: { $0.deviceType == deviceType }), device.isUnlocked else {
            errorMessage = "设备未解锁"
            return
        }

        if device.isCurrent { return }

        isLoading = true

        do {
            try await supabase.rpc("switch_current_device", params: [
                "p_user_id": userId.uuidString,
                "p_device_type": deviceType.rawValue
            ]).execute()

            for i in devices.indices {
                devices[i].isCurrent = (devices[i].deviceType == deviceType)
            }
            currentDevice = devices.first(where: { $0.deviceType == deviceType })
        } catch {
            errorMessage = "切换失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 解锁设备（由建造系统调用）

    func unlockDevice(userId: UUID, deviceType: DeviceType) async {
        do {
            let updateData = DeviceUnlockUpdate(
                isUnlocked: true,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase
                .from("communication_devices")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .eq("device_type", value: deviceType.rawValue)
                .execute()

            if let index = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[index].isUnlocked = true
            }
        } catch {
            errorMessage = "解锁失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 便捷方法

    func getCurrentDeviceType() -> DeviceType {
        currentDevice?.deviceType ?? .walkieTalkie
    }

    func canSendMessage() -> Bool {
        currentDevice?.deviceType.canSend ?? false
    }

    func getCurrentRange() -> Double {
        currentDevice?.deviceType.range ?? 3.0
    }

    func isDeviceUnlocked(_ deviceType: DeviceType) -> Bool {
        devices.first(where: { $0.deviceType == deviceType })?.isUnlocked ?? false
    }

    // MARK: - 频道方法

    /// 加载所有公开频道
    func loadPublicChannels() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationChannel] = try await supabase
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            channels = response
        } catch {
            errorMessage = "加载频道失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 加载用户已订阅的频道
    func loadSubscribedChannels(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            // 1. 获取用户的订阅记录
            let subscriptions: [ChannelSubscription] = try await supabase
                .from("channel_subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            mySubscriptions = subscriptions

            if subscriptions.isEmpty {
                subscribedChannels = []
                isLoading = false
                return
            }

            // 2. 获取对应的频道详情
            let channelIds = subscriptions.map { $0.channelId.uuidString }
            let channelList: [CommunicationChannel] = try await supabase
                .from("communication_channels")
                .select()
                .in("id", values: channelIds)
                .execute()
                .value

            // 3. 组合成 SubscribedChannel
            subscribedChannels = subscriptions.compactMap { sub in
                guard let channel = channelList.first(where: { $0.id == sub.channelId }) else {
                    return nil
                }
                return SubscribedChannel(channel: channel, subscription: sub)
            }
        } catch {
            errorMessage = "加载订阅频道失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 创建频道
    func createChannel(
        userId: UUID,
        type: ChannelType,
        name: String,
        description: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async -> UUID? {
        isLoading = true
        errorMessage = nil

        do {
            // 处理 public 类型的特殊映射
            let typeValue = type == .publicChannel ? "public" : type.rawValue

            let params: [String: AnyJSON] = [
                "p_creator_id": .string(userId.uuidString),
                "p_channel_type": .string(typeValue),
                "p_name": .string(name),
                "p_description": description.map { .string($0) } ?? .null,
                "p_latitude": latitude.map { .double($0) } ?? .null,
                "p_longitude": longitude.map { .double($0) } ?? .null
            ]

            let response: UUID = try await supabase
                .rpc("create_channel_with_subscription", params: params)
                .execute()
                .value

            // 刷新数据
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)

            isLoading = false
            return response
        } catch {
            errorMessage = "创建频道失败: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }

    /// 订阅频道
    func subscribeToChannel(userId: UUID, channelId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let params: [String: AnyJSON] = [
                "p_user_id": .string(userId.uuidString),
                "p_channel_id": .string(channelId.uuidString)
            ]

            try await supabase
                .rpc("subscribe_to_channel", params: params)
                .execute()

            // 刷新订阅列表
            await loadSubscribedChannels(userId: userId)
            await loadPublicChannels()

            isLoading = false
            return true
        } catch {
            errorMessage = "订阅失败: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    /// 取消订阅
    func unsubscribeFromChannel(userId: UUID, channelId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let params: [String: AnyJSON] = [
                "p_user_id": .string(userId.uuidString),
                "p_channel_id": .string(channelId.uuidString)
            ]

            try await supabase
                .rpc("unsubscribe_from_channel", params: params)
                .execute()

            // 刷新订阅列表
            await loadSubscribedChannels(userId: userId)
            await loadPublicChannels()

            isLoading = false
            return true
        } catch {
            errorMessage = "取消订阅失败: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    /// 检查是否已订阅
    func isSubscribed(channelId: UUID) -> Bool {
        mySubscriptions.contains { $0.channelId == channelId }
    }

    /// 删除频道（仅创建者可用）
    func deleteChannel(channelId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase
                .from("communication_channels")
                .delete()
                .eq("id", value: channelId.uuidString)
                .execute()

            // 从本地列表移除
            channels.removeAll { $0.id == channelId }
            subscribedChannels.removeAll { $0.channel.id == channelId }
            mySubscriptions.removeAll { $0.channelId == channelId }

            isLoading = false
            return true
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - ========== Day 34: 消息系统 ==========

    // MARK: - 消息属性
    @Published private(set) var channelMessages: [UUID: [ChannelMessage]] = [:]  // channelId -> messages
    @Published private(set) var isSendingMessage = false

    private var realtimeChannel: RealtimeChannelV2?
    private var messageSubscriptionTask: Task<Void, Never>?
    private var subscribedChannelIds: Set<UUID> = []

    // MARK: - 加载频道消息

    /// 加载指定频道的历史消息
    func loadChannelMessages(channelId: UUID, limit: Int = 50) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await supabase
                .from("channel_messages")
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .eq("is_deleted", value: false)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()

            // 使用自定义解码
            let messages = try decodeMessages(from: response.data)

            // 按时间正序排列（旧消息在前）
            let sortedMessages = messages.sorted { $0.createdAt < $1.createdAt }

            channelMessages[channelId] = sortedMessages
        } catch {
            errorMessage = "加载消息失败: \(error.localizedDescription)"
            print("❌ 加载消息失败: \(error)")
        }

        isLoading = false
    }

    /// 解码消息数据
    private func decodeMessages(from data: Data) throws -> [ChannelMessage] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ChannelMessage].self, from: data)
    }

    // MARK: - 发送消息

    /// 发送频道消息
    func sendChannelMessage(
        channelId: UUID,
        content: String,
        messageType: MessageType = .text,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async -> Bool {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "消息内容不能为空"
            return false
        }

        // 检查设备是否可发送
        guard canSendMessage() else {
            errorMessage = "当前设备不支持发送消息"
            return false
        }

        isSendingMessage = true
        errorMessage = nil

        do {
            let params: [String: AnyJSON] = [
                "p_channel_id": .string(channelId.uuidString),
                "p_content": .string(content),
                "p_message_type": .string(messageType.rawValue),
                "p_latitude": latitude.map { .double($0) } ?? .null,
                "p_longitude": longitude.map { .double($0) } ?? .null,
                "p_metadata": .object(["device_type": .string(getCurrentDeviceType().rawValue)])
            ]

            let _: UUID = try await supabase
                .rpc("send_channel_message", params: params)
                .execute()
                .value

            isSendingMessage = false
            return true
        } catch {
            errorMessage = "发送失败: \(error.localizedDescription)"
            print("❌ 发送消息失败: \(error)")
            isSendingMessage = false
            return false
        }
    }

    // MARK: - Realtime 订阅

    /// 开始监听频道消息
    func subscribeToChannelMessages(channelId: UUID) async {
        // 避免重复订阅
        guard !subscribedChannelIds.contains(channelId) else { return }
        subscribedChannelIds.insert(channelId)

        // 取消之前的订阅
        await stopRealtimeSubscription()

        // 创建新的 Realtime Channel
        realtimeChannel = supabase.realtimeV2.channel("channel_messages_\(channelId.uuidString)")

        guard let channel = realtimeChannel else { return }

        // 订阅 postgres_changes
        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "channel_messages",
            filter: "channel_id=eq.\(channelId.uuidString)"
        )

        // 启动监听任务
        messageSubscriptionTask = Task { [weak self] in
            await channel.subscribe()
            print("✅ 已订阅频道消息: \(channelId)")

            for await insertion in insertions {
                await self?.handleNewMessage(insertion: insertion, channelId: channelId)
            }
        }
    }

    /// 停止 Realtime 订阅
    func stopRealtimeSubscription() async {
        messageSubscriptionTask?.cancel()
        messageSubscriptionTask = nil

        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
        }

        subscribedChannelIds.removeAll()
        print("✅ 已停止 Realtime 订阅")
    }

    /// 处理新消息
    private func handleNewMessage(insertion: InsertAction, channelId: UUID) async {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let message = try insertion.decodeRecord(as: ChannelMessage.self, decoder: decoder)

            // 添加到消息列表
            await MainActor.run {
                if channelMessages[channelId] != nil {
                    // 避免重复添加
                    if !channelMessages[channelId]!.contains(where: { $0.id == message.id }) {
                        channelMessages[channelId]?.append(message)
                    }
                } else {
                    channelMessages[channelId] = [message]
                }
            }

            print("📨 收到新消息: \(message.content.prefix(20))...")
        } catch {
            print("❌ 处理新消息失败: \(error)")
        }
    }

    /// 取消订阅特定频道
    func unsubscribeFromChannelMessages(channelId: UUID) async {
        subscribedChannelIds.remove(channelId)

        if subscribedChannelIds.isEmpty {
            await stopRealtimeSubscription()
        }
    }

    // MARK: - 便捷方法

    /// 获取指定频道的消息
    func getMessages(for channelId: UUID) -> [ChannelMessage] {
        channelMessages[channelId] ?? []
    }

    /// 清空频道消息缓存
    func clearMessages(for channelId: UUID) {
        channelMessages.removeValue(forKey: channelId)
    }
}

// MARK: - Update Models

private struct DeviceUnlockUpdate: Encodable {
    let isUnlocked: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isUnlocked = "is_unlocked"
        case updatedAt = "updated_at"
    }
}
