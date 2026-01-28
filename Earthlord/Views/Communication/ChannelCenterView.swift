//
//  ChannelCenterView.swift
//  Earthlord
//
//  Created by Claude on 2026-01-28.
//
//  频道中心 - 我的频道 + 发现频道
//

import SwiftUI
import Supabase

struct ChannelCenterView: View {
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var selectedChannel: CommunicationChannel?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作栏
            HStack {
                Text("频道中心")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Button(action: { showCreateSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("创建")
                    }
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ApocalypseTheme.primary.opacity(0.15))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Tab 切换栏
            HStack(spacing: 0) {
                tabButton(title: "我的频道", index: 0)
                tabButton(title: "发现频道", index: 1)
            }
            .padding(.horizontal, 16)

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 搜索栏（仅发现页面显示）
            if selectedTab == 1 {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    TextField("搜索频道...", text: $searchText)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .padding(10)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // 内容区域
            if communicationManager.isLoading {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if selectedTab == 0 {
                            myChannelsView
                        } else {
                            discoverChannelsView
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(ApocalypseTheme.background)
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateChannelSheet()
                .environmentObject(authManager)
        }
        .sheet(item: $selectedChannel) { channel in
            ChannelDetailView(channel: channel)
                .environmentObject(authManager)
        }
    }

    // MARK: - Tab 按钮
    private func tabButton(title: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(selectedTab == index ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                Rectangle()
                    .fill(selectedTab == index ? ApocalypseTheme.primary : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 我的频道
    @ViewBuilder
    private var myChannelsView: some View {
        if communicationManager.subscribedChannels.isEmpty {
            emptyStateView(
                icon: "antenna.radiowaves.left.and.right",
                title: "暂无订阅的频道",
                subtitle: "去「发现频道」找找感兴趣的吧"
            )
        } else {
            ForEach(communicationManager.subscribedChannels) { subscribedChannel in
                ChannelRowView(
                    channel: subscribedChannel.channel,
                    isSubscribed: true
                ) {
                    selectedChannel = subscribedChannel.channel
                }
            }
        }
    }

    // MARK: - 发现频道
    @ViewBuilder
    private var discoverChannelsView: some View {
        let filteredChannels = filterChannels(communicationManager.channels)

        if filteredChannels.isEmpty {
            if searchText.isEmpty {
                emptyStateView(
                    icon: "globe",
                    title: "暂无公开频道",
                    subtitle: "成为第一个创建频道的人吧"
                )
            } else {
                emptyStateView(
                    icon: "magnifyingglass",
                    title: "未找到频道",
                    subtitle: "换个关键词试试"
                )
            }
        } else {
            ForEach(filteredChannels) { channel in
                ChannelRowView(
                    channel: channel,
                    isSubscribed: communicationManager.isSubscribed(channelId: channel.id)
                ) {
                    selectedChannel = channel
                }
            }
        }
    }

    // MARK: - 空状态视图
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(title)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 辅助方法
    private func loadData() {
        guard let userId = authManager.currentUser?.id else { return }
        Task {
            await communicationManager.loadPublicChannels()
            await communicationManager.loadSubscribedChannels(userId: userId)
        }
    }

    private func filterChannels(_ channels: [CommunicationChannel]) -> [CommunicationChannel] {
        guard !searchText.isEmpty else { return channels }
        let lowercased = searchText.lowercased()
        return channels.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.channelCode.lowercased().contains(lowercased)
        }
    }
}

// MARK: - 频道行视图
struct ChannelRowView: View {
    let channel: CommunicationChannel
    let isSubscribed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: channel.channelType.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(channel.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .lineLimit(1)

                        if isSubscribed {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(channel.channelCode)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.primary)

                        Text("·")
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text("\(channel.memberCount) 人")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
        }
    }
}

#Preview {
    ChannelCenterView()
        .environmentObject(AuthManager())
}
