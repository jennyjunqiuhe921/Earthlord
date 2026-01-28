//
//  CreateChannelSheet.swift
//  Earthlord
//
//  Created by Claude on 2026-01-28.
//
//  创建频道表单
//

import SwiftUI
import Supabase

struct CreateChannelSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedType: ChannelType = .publicChannel
    @State private var channelName: String = ""
    @State private var channelDescription: String = ""
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道类型选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text("频道类型")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        ForEach(ChannelType.creatableTypes, id: \.self) { type in
                            channelTypeButton(type)
                        }
                    }

                    // 频道名称
                    VStack(alignment: .leading, spacing: 8) {
                        Text("频道名称")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        TextField("输入频道名称", text: $channelName)
                            .padding(12)
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(8)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        if !nameValidation.isValid && !channelName.isEmpty {
                            Text(nameValidation.message)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.danger)
                        }
                    }

                    // 频道描述
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("频道描述")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text("（可选）")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
                        }

                        TextEditor(text: $channelDescription)
                            .frame(height: 80)
                            .padding(8)
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(8)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .scrollContentBackground(.hidden)
                    }

                    // 设备提示
                    if let requiredDevice = selectedType.requiredDevice {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(ApocalypseTheme.info)

                            Text("此频道类型需要「\(requiredDevice.displayName)」设备")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                        .padding(12)
                        .background(ApocalypseTheme.info.opacity(0.1))
                        .cornerRadius(8)
                    }

                    Spacer(minLength: 20)

                    // 创建按钮
                    Button(action: createChannel) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isCreating ? "创建中..." : "创建频道")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canCreate ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!canCreate || isCreating)

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
            .navigationTitle("创建频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 频道类型按钮
    private func channelTypeButton(_ type: ChannelType) -> some View {
        Button(action: { selectedType = type }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(selectedType == type ? ApocalypseTheme.primary.opacity(0.2) : ApocalypseTheme.textSecondary.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: type.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(selectedType == type ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if selectedType == type {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .padding(12)
            .background(selectedType == type ? ApocalypseTheme.primary.opacity(0.1) : ApocalypseTheme.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedType == type ? ApocalypseTheme.primary : Color.clear, lineWidth: 1)
            )
        }
    }

    // MARK: - 验证逻辑
    private var nameValidation: (isValid: Bool, message: String) {
        let trimmed = channelName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return (false, "请输入频道名称")
        } else if trimmed.count < 2 {
            return (false, "名称至少2个字符")
        } else if trimmed.count > 50 {
            return (false, "名称最多50个字符")
        }
        return (true, "")
    }

    private var canCreate: Bool {
        nameValidation.isValid
    }

    // MARK: - 创建频道
    private func createChannel() {
        guard let userId = authManager.currentUser?.id else { return }

        isCreating = true

        Task {
            let description = channelDescription.trimmingCharacters(in: .whitespaces)
            let result = await communicationManager.createChannel(
                userId: userId,
                type: selectedType,
                name: channelName.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description
            )

            isCreating = false

            if result != nil {
                dismiss()
            }
        }
    }
}

#Preview {
    CreateChannelSheet()
        .environmentObject(AuthManager())
}
