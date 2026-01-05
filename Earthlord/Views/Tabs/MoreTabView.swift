//
//  MoreTabView.swift
//  Earthlord
//
//  Created by Claude Code on 2025/12/24.
//

import SwiftUI

struct MoreTabView: View {
    @EnvironmentObject private var authManager: AuthManager

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

                        Text("更多")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("更多功能模块")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)

                    // 功能列表
                    VStack(spacing: 15) {
                        // 开发测试
                        NavigationLink(destination: TestMenuView()) {
                            HStack {
                                Image(systemName: "hammer.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("开发测试")
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Text("功能测试和调试工具")
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
                                    Text("退出登录")
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Text("退出当前账号")
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
        }
    }
}

#Preview {
    MoreTabView()
        .environmentObject(AuthManager())
}
