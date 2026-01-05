//
//  TerritoryTestView.swift
//  Earthlord
//
//  圈地功能测试界面 - 显示实时日志和状态
//

import SwiftUI

struct TerritoryTestView: View {

    // MARK: - Environment & Observed Objects

    /// 位置管理器（监听追踪状态）
    @EnvironmentObject var locationManager: LocationManager

    /// 日志管理器（监听日志更新）
    @ObservedObject var logger = TerritoryLogger.shared

    // MARK: - State

    /// 用于自动滚动的锚点 ID
    @State private var scrollToBottom = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 状态指示器
            statusIndicator
                .padding()
                .background(ApocalypseTheme.cardBackground)

            Divider()

            // 日志滚动区域
            logScrollView

            Divider()

            // 底部按钮栏
            bottomToolbar
                .padding()
                .background(ApocalypseTheme.cardBackground)
        }
        .navigationTitle("圈地测试")
        .navigationBarTitleDisplayMode(.inline)
        .background(ApocalypseTheme.background)
    }

    // MARK: - Subviews

    /// 状态指示器
    private var statusIndicator: some View {
        HStack(spacing: 12) {
            // 状态点
            Circle()
                .fill(locationManager.isTracking ? Color.green : Color.gray)
                .frame(width: 12, height: 12)

            // 状态文字
            Text(locationManager.isTracking ? "追踪中" : "未追踪")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 日志条数
            Text("\(logger.logs.count) 条日志")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    /// 日志滚动区域
    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if logger.logs.isEmpty {
                        // 空状态提示
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 50))
                                .foregroundColor(ApocalypseTheme.textMuted)

                            Text("暂无日志")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textMuted)

                            Text("开始圈地追踪后，日志会实时显示在这里")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        // 日志列表
                        ForEach(logger.logs) { entry in
                            logEntryView(entry)
                        }

                        // 底部锚点（用于自动滚动）
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .onChange(of: logger.logText) { _ in
                // ⭐ 日志更新时自动滚动到底部
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    /// 单条日志视图
    private func logEntryView(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // 类型标记点
            Circle()
                .fill(entry.type.color)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            // 日志文本
            Text(entry.displayText)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }

    /// 底部工具栏
    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            // 清空按钮
            Button {
                logger.clear()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("清空日志")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(8)
            }
            .disabled(logger.logs.isEmpty)

            // 导出按钮
            ShareLink(item: logger.export()) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出日志")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary.opacity(0.2))
                .foregroundColor(ApocalypseTheme.primary)
                .cornerRadius(8)
            }
            .disabled(logger.logs.isEmpty)
        }
    }
}

#Preview {
    NavigationStack {
        TerritoryTestView()
            .environmentObject(LocationManager())
    }
}
