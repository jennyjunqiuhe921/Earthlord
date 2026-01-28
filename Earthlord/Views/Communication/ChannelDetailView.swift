//
//  ChannelDetailView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-28.
//
//  频道详情页 - 订阅/取消订阅/删除
//

import SwiftUI
import Supabase

struct ChannelDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    let channel: CommunicationChannel

    @State private var isProcessing = false
    @State private var showDeleteConfirm = false

    private var isSubscribed: Bool {
        communicationManager.isSubscribed(channelId: channel.id)
    }

    private var isCreator: Bool {
        authManager.currentUser?.id == channel.creatorId
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 频道头像和名称
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(ApocalypseTheme.primary.opacity(0.2))
                                .frame(width: 80, height: 80)

                            Image(systemName: channel.channelType.iconName)
                                .font(.system(size: 36))
                                .foregroundColor(ApocalypseTheme.primary)
                        }

                        Text(channel.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text(channel.channelCode)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(ApocalypseTheme.primary.opacity(0.15))
                            .cornerRadius(6)

                        // 订阅状态标签
                        if isSubscribed {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("已订阅")
                            }
                            .font(.caption)
                            .foregroundColor(.green)
                        }
                    }
                    .padding(.top, 20)

                    // 频道介绍
                    if let description = channel.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("频道介绍")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text(description)
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                    }

                    // 频道信息卡片
                    VStack(spacing: 0) {
                        infoRow(title: "频道类型", value: channel.channelType.displayName)
                        Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
                        infoRow(title: "覆盖范围", value: channel.channelType.rangeText)
                        Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
                        infoRow(title: "成员数量", value: "\(channel.memberCount) 人")
                        Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
                        infoRow(title: "创建时间", value: formatDate(channel.createdAt))
                    }
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)

                    Spacer(minLength: 20)

                    // 操作按钮
                    if isCreator {
                        // 创建者看到删除按钮
                        Button(action: { showDeleteConfirm = true }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("删除频道")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ApocalypseTheme.danger)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    } else {
                        // 非创建者看到订阅/取消订阅按钮
                        Button(action: toggleSubscription) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Image(systemName: isSubscribed ? "bell.slash.fill" : "bell.fill")
                                Text(isSubscribed ? "取消订阅" : "订阅频道")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isSubscribed ? ApocalypseTheme.textSecondary : ApocalypseTheme.primary)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isProcessing)
                    }

                    // 错误提示
                    if let error = communicationManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.danger)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("频道详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteChannel()
                }
            } message: {
                Text("删除后无法恢复，频道内所有消息也将被删除。确定要删除「\(channel.name)」吗？")
            }
        }
    }

    // MARK: - 信息行
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - 订阅/取消订阅
    private func toggleSubscription() {
        guard let userId = authManager.currentUser?.id else { return }

        isProcessing = true

        Task {
            if isSubscribed {
                _ = await communicationManager.unsubscribeFromChannel(userId: userId, channelId: channel.id)
            } else {
                _ = await communicationManager.subscribeToChannel(userId: userId, channelId: channel.id)
            }
            isProcessing = false
        }
    }

    // MARK: - 删除频道
    private func deleteChannel() {
        isProcessing = true

        Task {
            let success = await communicationManager.deleteChannel(channelId: channel.id)
            isProcessing = false

            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    ChannelDetailView(channel: CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .publicChannel,
        channelCode: "PUB-ABC123",
        name: "测试频道",
        description: "这是一个测试频道",
        isActive: true,
        memberCount: 10,
        createdAt: Date(),
        updatedAt: Date()
    ))
    .environmentObject(AuthManager())
}

// MARK: - Preview Helper
extension CommunicationChannel {
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
}
