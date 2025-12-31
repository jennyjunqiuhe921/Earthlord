//
//  MoreTabView.swift
//  Earthlord
//
//  Created by Claude Code on 2025/12/24.
//

import SwiftUI

struct MoreTabView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var languageManager = LanguageManager.shared
    @State private var refreshID = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                // 末日风格背景
                Color.black.opacity(0.9)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // 标题
                    VStack(spacing: 8) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)

                        Text("更多".localized)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("更多功能模块".localized)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)

                    // 功能列表
                    VStack(spacing: 15) {
                        // Supabase 测试
                        NavigationLink(destination: SupabaseTestView()) {
                            HStack {
                                Image(systemName: "network")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Supabase 连接测试".localized)
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Text("测试数据库连接状态".localized)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }

                        // 登出按钮
                        Button(action: {
                            Task {
                                await authManager.signOut()
                            }
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.title2)
                                    .foregroundColor(.red)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("退出登录".localized)
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Text("退出当前账号".localized)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 30)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .id(refreshID)
            .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
                print("🌍 MoreTabView 收到语言切换通知，刷新界面")
                refreshID = UUID()
            }
        }
    }
}

#Preview {
    MoreTabView()
        .environmentObject(AuthManager())
}
