//
//  ProfileTabView.swift
//  Earthlord
//
//  Created by Claude Code on 2025/12/24.
//

import SwiftUI
import Supabase

/// 个人页面 - 显示用户信息和账户设置
struct ProfileTabView: View {
    @EnvironmentObject private var authManager: AuthManager

    /// 是否显示退出确认对话框
    @State private var showLogoutConfirm = false

    /// 是否显示删除账户对话框
    @State private var showDeleteAccountDialog = false

    /// 删除账户确认输入
    @State private var deleteConfirmText = ""

    /// 是否显示删除成功提示
    @State private var showDeleteSuccessAlert = false

    var body: some View {
        ZStack {
            // 背景
            Color.black
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部标题
                    Text("幸存者档案")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        .padding(.bottom, 30)

                    // 用户头像和信息
                    VStack(spacing: 16) {
                        // 头像
                        ZStack {
                            Circle()
                                .fill(ApocalypseTheme.primary)
                                .frame(width: 80, height: 80)

                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }

                        // 用户ID（使用邮箱前缀或用户名）
                        Text(userDisplayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        // 邮箱
                        if let email = authManager.currentUser?.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        // 用户ID
                        if let userId = authManager.currentUser?.id.uuidString {
                            Text("ID: \(String(userId.prefix(8)))...")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }
                    .padding(.bottom, 30)

                    // 统计数据卡片
                    HStack(spacing: 0) {
                        StatCard(icon: "flag.fill", title: "领地", value: "0", color: ApocalypseTheme.primary)

                        Divider()
                            .frame(height: 60)
                            .background(Color.white.opacity(0.1))

                        StatCard(icon: "mappin.circle.fill", title: "资源点", value: "0", color: ApocalypseTheme.primary)

                        Divider()
                            .frame(height: 60)
                            .background(Color.white.opacity(0.1))

                        StatCard(icon: "figure.walk", title: "探索距离", value: "0", color: ApocalypseTheme.primary)
                    }
                    .frame(height: 100)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)

                    // 菜单项
                    VStack(spacing: 0) {
                        MenuItemRow(
                            icon: "gearshape.fill",
                            iconColor: .gray,
                            title: "设置",
                            action: {
                                // TODO: 打开设置页面
                            }
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 60)

                        MenuItemRow(
                            icon: "bell.fill",
                            iconColor: ApocalypseTheme.primary,
                            title: "通知",
                            action: {
                                // TODO: 打开通知页面
                            }
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 60)

                        MenuItemRow(
                            icon: "questionmark.circle.fill",
                            iconColor: .blue,
                            title: "帮助",
                            action: {
                                // TODO: 打开帮助页面
                            }
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 60)

                        MenuItemRow(
                            icon: "info.circle.fill",
                            iconColor: .green,
                            title: "关于",
                            action: {
                                // TODO: 打开关于页面
                            }
                        )
                    }
                    .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)

                    // 退出登录按钮
                    Button(action: {
                        showLogoutConfirm = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.headline)

                            Text("退出登录")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.3, blue: 0.3),
                                    Color(red: 1.0, green: 0.2, blue: 0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                    // 删除账户按钮
                    Button(action: {
                        deleteConfirmText = ""
                        showDeleteAccountDialog = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.headline)

                            Text("删除账户")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.6, green: 0.1, blue: 0.1),
                                    Color(red: 0.5, green: 0.05, blue: 0.05)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color(red: 0.8, green: 0.1, blue: 0.1), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }

            // 加载指示器
            if authManager.isLoading {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()

                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                }
            }
        }
        .confirmationDialog(
            "确认退出登录",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("退出登录", role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后需要重新登录才能访问您的账户")
        }
        .sheet(isPresented: $showDeleteAccountDialog) {
            DeleteAccountConfirmView(
                deleteConfirmText: $deleteConfirmText,
                isPresented: $showDeleteAccountDialog,
                onConfirm: {
                    Task {
                        print("🔴 用户确认删除账户")
                        let success = await authManager.deleteAccount()
                        if success {
                            showDeleteSuccessAlert = true
                        }
                    }
                }
            )
            .environmentObject(authManager)
        }
        .alert("账户已删除", isPresented: $showDeleteSuccessAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("您的账户已被永久删除")
        }
    }

    // MARK: - 辅助方法

    /// 获取用户显示名称
    private var userDisplayName: String {
        if let email = authManager.currentUser?.email {
            return email.components(separatedBy: "@").first ?? "幸存者"
        }
        return "幸存者"
    }
}

// MARK: - 统计卡片组件

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 菜单项组件

struct MenuItemRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 30)

                Text(title)
                    .font(.body)
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 删除账户确认对话框

struct DeleteAccountConfirmView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Binding var deleteConfirmText: String
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                // 深色背景
                Color(red: 0.1, green: 0.1, blue: 0.1)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 警告图标
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.red)
                            .padding(.top, 40)

                        Text("永久删除账户")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 12) {
                            WarningText("此操作不可撤销")
                            WarningText("您的所有数据将被永久删除")
                            WarningText("删除后无法恢复账户")
                        }
                        .padding(.horizontal, 30)
                    }
                    .padding(.bottom, 40)

                    // 确认输入框
                    VStack(alignment: .leading, spacing: 12) {
                        Text("请输入 \"删除\" 以确认")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 30)

                        TextField("", text: $deleteConfirmText)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(deleteConfirmText == "删除" ? Color.red : Color.gray.opacity(0.3), lineWidth: 2)
                            )
                            .padding(.horizontal, 30)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.bottom, 30)

                    // 错误提示
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 30)
                            .padding(.bottom, 20)
                    }

                    Spacer()

                    // 按钮组
                    VStack(spacing: 12) {
                        // 确认删除按钮
                        Button(action: {
                            print("🔴 点击确认删除按钮")
                            isPresented = false
                            onConfirm()
                        }) {
                            Text("确认删除账户")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.8, green: 0.1, blue: 0.1),
                                            Color(red: 0.6, green: 0.05, blue: 0.05)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(25)
                                .opacity(deleteConfirmText == "删除" ? 1.0 : 0.5)
                        }
                        .disabled(deleteConfirmText != "删除")

                        // 取消按钮
                        Button(action: {
                            print("🔴 用户取消删除账户")
                            isPresented = false
                        }) {
                            Text("取消")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(25)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("删除账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// 警告文本组件
struct WarningText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)

            Text(text)
                .font(.body)
                .foregroundColor(.white)
        }
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(AuthManager())
}
