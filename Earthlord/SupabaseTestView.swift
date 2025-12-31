//
//  SupabaseTestView.swift
//  Earthlord
//
//  Created by Claude Code on 2025/12/26.
//

import SwiftUI
import Supabase

// 初始化 Supabase 客户端
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://acnriuoexalqvckiuvgr.supabase.co")!,
    supabaseKey: "sb_publishable_ddDdaU8v_cxisWA6TiHDuA_BHAdLp-R"
)

struct SupabaseTestView: View {
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var debugLog: String = "准备测试连接..."

    enum ConnectionStatus {
        case idle
        case testing
        case success
        case failed

        var icon: String {
            switch self {
            case .idle, .testing:
                return "circle.dotted"
            case .success:
                return "checkmark.circle.fill"
            case .failed:
                return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .idle:
                return .gray
            case .testing:
                return .blue
            case .success:
                return .green
            case .failed:
                return .red
            }
        }
    }

    var body: some View {
        ZStack {
            // 末日风格背景
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // 标题
                Text("Supabase 连接测试")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 40)

                // 状态图标
                Image(systemName: connectionStatus.icon)
                    .font(.system(size: 80))
                    .foregroundColor(connectionStatus.color)
                    .padding()

                // 调试日志框
                ScrollView {
                    Text(debugLog)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.green)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 250)
                .background(Color.black.opacity(0.5))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)

                // 测试按钮
                VStack(spacing: 15) {
                    Button(action: testConnection) {
                        HStack {
                            if connectionStatus == .testing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(connectionStatus == .testing ? "测试中..." : "测试连接")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(connectionStatus == .testing ? Color.gray : Color.orange)
                        .cornerRadius(10)
                    }
                    .disabled(connectionStatus == .testing)

                    Button(action: verifyTables) {
                        HStack {
                            if connectionStatus == .testing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "checkmark.shield")
                            Text(connectionStatus == .testing ? "验证中..." : "验证数据表")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(connectionStatus == .testing ? Color.gray : Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(connectionStatus == .testing)
                }
                .padding(.horizontal)

                Spacer()
            }
        }
    }

    // 测试连接函数
    func testConnection() {
        connectionStatus = .testing
        debugLog = "🔍 开始测试连接...\n"
        debugLog += "📡 目标: https://acnriuoexalqvckiuvgr.supabase.co\n\n"

        Task {
            do {
                // 故意查询一个不存在的表来测试连接
                debugLog += "⚡ 发送测试请求...\n"
                let _ = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()

                // 如果没有抛出错误，说明表存在（不太可能）
                await MainActor.run {
                    debugLog += "✅ 意外成功：表存在！\n"
                    connectionStatus = .success
                }

            } catch {
                // 分析错误信息
                let errorMessage = error.localizedDescription
                debugLog += "📋 收到响应:\n\(errorMessage)\n\n"

                await MainActor.run {
                    // 判断错误类型
                    if errorMessage.contains("PGRST") ||
                       errorMessage.contains("Could not find the table") ||
                       errorMessage.contains("relation") && errorMessage.contains("does not exist") {
                        // 这些错误说明服务器已经响应，连接成功
                        debugLog += "✅ 连接成功！\n"
                        debugLog += "💡 服务器正常响应（表不存在是预期行为）\n"
                        connectionStatus = .success

                    } else if errorMessage.contains("hostname") ||
                              errorMessage.contains("URL") ||
                              errorMessage.contains("NSURLErrorDomain") {
                        // URL 或网络错误
                        debugLog += "❌ 连接失败\n"
                        debugLog += "💡 URL 错误或无网络连接\n"
                        connectionStatus = .failed

                    } else {
                        // 其他未知错误
                        debugLog += "⚠️ 未知错误:\n\(errorMessage)\n"
                        connectionStatus = .failed
                    }
                }
            }
        }
    }

    // 验证数据表函数
    func verifyTables() {
        connectionStatus = .testing
        debugLog = "🔍 开始验证数据表...\n"
        debugLog += "📊 检查核心表是否已创建\n\n"

        Task {
            var successCount = 0
            let totalTables = 3

            // 检查 profiles 表
            debugLog += "1️⃣ 检查 profiles 表...\n"
            do {
                let _ = try await supabase
                    .from("profiles")
                    .select()
                    .limit(1)
                    .execute()

                await MainActor.run {
                    debugLog += "   ✅ profiles 表存在\n"
                    successCount += 1
                }
            } catch {
                await MainActor.run {
                    let errorMsg = error.localizedDescription
                    if errorMsg.contains("relation") && errorMsg.contains("does not exist") {
                        debugLog += "   ❌ profiles 表不存在\n"
                    } else if errorMsg.contains("Results contain 0 rows") || errorMsg.contains("No rows") {
                        debugLog += "   ✅ profiles 表存在（空表）\n"
                        successCount += 1
                    } else {
                        debugLog += "   ⚠️ 错误: \(errorMsg)\n"
                    }
                }
            }

            // 检查 territories 表
            await MainActor.run {
                debugLog += "\n2️⃣ 检查 territories 表...\n"
            }
            do {
                let _ = try await supabase
                    .from("territories")
                    .select()
                    .limit(1)
                    .execute()

                await MainActor.run {
                    debugLog += "   ✅ territories 表存在\n"
                    successCount += 1
                }
            } catch {
                await MainActor.run {
                    let errorMsg = error.localizedDescription
                    if errorMsg.contains("relation") && errorMsg.contains("does not exist") {
                        debugLog += "   ❌ territories 表不存在\n"
                    } else if errorMsg.contains("Results contain 0 rows") || errorMsg.contains("No rows") {
                        debugLog += "   ✅ territories 表存在（空表）\n"
                        successCount += 1
                    } else {
                        debugLog += "   ⚠️ 错误: \(errorMsg)\n"
                    }
                }
            }

            // 检查 pois 表
            await MainActor.run {
                debugLog += "\n3️⃣ 检查 pois 表...\n"
            }
            do {
                let _ = try await supabase
                    .from("pois")
                    .select()
                    .limit(1)
                    .execute()

                await MainActor.run {
                    debugLog += "   ✅ pois 表存在\n"
                    successCount += 1
                }
            } catch {
                await MainActor.run {
                    let errorMsg = error.localizedDescription
                    if errorMsg.contains("relation") && errorMsg.contains("does not exist") {
                        debugLog += "   ❌ pois 表不存在\n"
                    } else if errorMsg.contains("Results contain 0 rows") || errorMsg.contains("No rows") {
                        debugLog += "   ✅ pois 表存在（空表）\n"
                        successCount += 1
                    } else {
                        debugLog += "   ⚠️ 错误: \(errorMsg)\n"
                    }
                }
            }

            // 总结
            await MainActor.run {
                debugLog += "\n" + String(repeating: "=", count: 30) + "\n"
                debugLog += "📋 验证结果: \(successCount)/\(totalTables) 个表已创建\n"

                if successCount == totalTables {
                    debugLog += "✅ 所有核心表验证成功！\n"
                    debugLog += "💡 数据库已准备就绪\n"
                    connectionStatus = .success
                } else if successCount > 0 {
                    debugLog += "⚠️ 部分表缺失，请检查 migration\n"
                    connectionStatus = .failed
                } else {
                    debugLog += "❌ 所有表都不存在\n"
                    debugLog += "💡 请先执行 migration 脚本\n"
                    connectionStatus = .failed
                }
            }
        }
    }
}

#Preview {
    SupabaseTestView()
}
