//
//  ChannelChatView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-30.
//
//  频道聊天界面 - Day 34 消息系统
//

import SwiftUI
import Supabase

struct ChannelChatView: View {
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    let channel: CommunicationChannel

    @State private var messageText = ""
    @State private var scrollToBottom = false
    @FocusState private var isInputFocused: Bool

    private var messages: [ChannelMessage] {
        communicationManager.getMessages(for: channel.id)
    }

    private var canSend: Bool {
        communicationManager.canSendMessage()
    }

    private var currentUserId: UUID? {
        authManager.currentUser?.id
    }

    var body: some View {
        VStack(spacing: 0) {
            // 导航栏
            navigationBar

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 消息列表
            messageListView

            // 收音机模式提示 或 输入栏
            if canSend {
                inputBar
            } else {
                radioModeNotice
            }
        }
        .background(ApocalypseTheme.background)
        .navigationBarHidden(true)
        .onAppear {
            loadMessages()
            startSubscription()
        }
        .onDisappear {
            stopSubscription()
        }
    }

    // MARK: - 导航栏
    private var navigationBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 频道图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: safeIconName(channel.channelType.iconName))
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 频道信息
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                Text("\(channel.memberCount) 名成员")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 频道码标签
            Text(channel.channelCode)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    /// 处理可能不存在的 SF Symbol
    private func safeIconName(_ icon: String) -> String {
        // walkie.talkie.radio 在某些系统版本可能不存在
        if icon == "walkie.talkie.radio" {
            return "antenna.radiowaves.left.and.right"
        }
        return icon
    }

    // MARK: - 消息列表
    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty && !communicationManager.isLoading {
                        emptyStateView
                    } else {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isOwnMessage: message.senderId == currentUserId
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _ in
                // 自动滚动到最新消息
                withAnimation(.easeOut(duration: 0.3)) {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                // 初始滚动到底部
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.4))

            Text("暂无消息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("发送第一条消息开始聊天吧")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - 输入栏
    private var inputBar: some View {
        HStack(spacing: 12) {
            // 文本输入框
            TextField("输入消息...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(20)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .focused($isInputFocused)
                .lineLimit(1...5)

            // 发送按钮
            Button(action: sendMessage) {
                ZStack {
                    Circle()
                        .fill(canSendNow ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3))
                        .frame(width: 40, height: 40)

                    if communicationManager.isSendingMessage {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(!canSendNow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.background)
    }

    private var canSendNow: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !communicationManager.isSendingMessage
    }

    // MARK: - 收音机模式提示
    private var radioModeNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "radio")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.warning)

            Text("收音机模式 - 只能收听，无法发送消息")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground.opacity(0.8))
    }

    // MARK: - 方法

    private func loadMessages() {
        Task {
            await communicationManager.loadChannelMessages(channelId: channel.id)
        }
    }

    private func startSubscription() {
        Task {
            await communicationManager.subscribeToChannelMessages(channelId: channel.id)
        }
    }

    private func stopSubscription() {
        Task {
            await communicationManager.unsubscribeFromChannelMessages(channelId: channel.id)
        }
    }

    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        let textToSend = content
        messageText = ""  // 立即清空输入框

        Task {
            let success = await communicationManager.sendChannelMessage(
                channelId: channel.id,
                content: textToSend
            )

            if !success {
                // 发送失败，恢复消息
                messageText = textToSend
            }
        }
    }
}

// MARK: - 消息气泡视图
struct MessageBubbleView: View {
    let message: ChannelMessage
    let isOwnMessage: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOwnMessage {
                Spacer(minLength: 60)
            } else {
                // 他人头像
                avatarView
            }

            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
                // 显示呼号（他人消息）
                if !isOwnMessage {
                    HStack(spacing: 4) {
                        // 设备图标
                        if let deviceType = message.metadata?.deviceType {
                            Image(systemName: deviceIconFor(deviceType))
                                .font(.system(size: 10))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }

                        Text(message.senderUsername ?? "未知用户")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                // 消息内容
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isOwnMessage ? .white : ApocalypseTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isOwnMessage
                            ? ApocalypseTheme.primary
                            : ApocalypseTheme.cardBackground
                    )
                    .cornerRadius(18)

                // 时间戳
                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            if !isOwnMessage {
                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - 头像视图
    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(ApocalypseTheme.primary.opacity(0.2))
                .frame(width: 32, height: 32)

            if let avatarUrl = message.senderAvatarUrl, !avatarUrl.isEmpty {
                // 实际项目中使用 AsyncImage 加载头像
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)
            } else {
                Text(String((message.senderUsername ?? "?").prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
    }

    // MARK: - 辅助方法

    private func deviceIconFor(_ deviceType: String) -> String {
        switch deviceType {
        case "radio":
            return "radio"
        case "walkie_talkie":
            return "antenna.radiowaves.left.and.right"
        case "camp_radio":
            return "antenna.radiowaves.left.and.right"
        case "satellite":
            return "antenna.radiowaves.left.and.right.circle"
        default:
            return "message"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'昨天' HH:mm"
        } else {
            formatter.dateFormat = "MM/dd HH:mm"
        }

        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    // 创建预览用的临时频道
    let previewChannel = CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .publicChannel,
        channelCode: "PUB-ABC123",
        name: "测试频道",
        description: "测试描述",
        isActive: true,
        memberCount: 5,
        createdAt: Date(),
        updatedAt: Date()
    )

    return NavigationView {
        ChannelChatView(channel: previewChannel)
            .environmentObject(AuthManager())
    }
}
