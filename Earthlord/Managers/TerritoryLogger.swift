//
//  TerritoryLogger.swift
//  Earthlord
//
//  圈地功能日志管理器 - 记录和显示圈地模块的调试信息
//

import Foundation
import SwiftUI
import Combine

/// 日志类型
enum LogType: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"

    /// 对应的颜色
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

/// 日志条目
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType

    /// 格式化显示文本（短时间格式）
    var displayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeStr = formatter.string(from: timestamp)
        return "[\(timeStr)] [\(type.rawValue)] \(message)"
    }

    /// 格式化导出文本（完整时间格式）
    var exportText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timeStr = formatter.string(from: timestamp)
        return "[\(timeStr)] [\(type.rawValue)] \(message)"
    }
}

/// 圈地功能日志管理器
class TerritoryLogger: ObservableObject {

    // MARK: - Singleton

    /// 全局单例
    static let shared = TerritoryLogger()

    // MARK: - Published Properties

    /// 日志数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于显示）
    @Published var logText: String = ""

    // MARK: - Constants

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 200

    // MARK: - Initialization

    private init() {
        // 私有初始化器，确保单例模式
    }

    // MARK: - Public Methods

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型
    func log(_ message: String, type: LogType = .info) {
        // ⭐ 确保在主线程更新（ObservableObject 需要）
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 创建日志条目
            let entry = LogEntry(timestamp: Date(), message: message, type: type)

            // 添加到数组
            self.logs.append(entry)

            // 限制日志条数，超出时移除最旧的
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst(self.logs.count - self.maxLogCount)
            }

            // 更新显示文本
            self.updateLogText()
        }
    }

    /// 清空所有日志
    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
            self?.logText = ""
        }
    }

    /// 导出日志为文本
    /// - Returns: 包含头信息和完整时间戳的日志文本
    func export() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let exportTime = formatter.string(from: Date())

        var text = """
        === 圈地功能测试日志 ===
        导出时间: \(exportTime)
        日志条数: \(logs.count)

        """

        // 添加所有日志
        for entry in logs {
            text += entry.exportText + "\n"
        }

        return text
    }

    // MARK: - Private Methods

    /// 更新显示文本
    private func updateLogText() {
        logText = logs.map { $0.displayText }.joined(separator: "\n")
    }
}
