//
//  ExplorationManager.swift
//  Earthlord
//
//  Created by Claude on 2026-01-12.
//
//  管理探索会话：GPS追踪、距离计算、速度检测、奖励生成
//

import Foundation
import Combine
import CoreLocation
import Supabase

/// 探索状态
enum ExplorationState: String {
    case idle           // 空闲状态
    case exploring      // 探索中
    case speedWarning   // 超速警告中
    case processing     // 处理中（计算奖励）
    case completed      // 完成
    case failed         // 探索失败（超速）
}

/// 探索失败原因
enum ExplorationFailureReason {
    case speedExceeded  // 超速
    case gpsError       // GPS错误
    case userCancelled  // 用户取消
}

/// 探索管理器
/// 负责管理整个探索流程：GPS追踪、距离计算、速度检测、奖励生成、数据保存
@MainActor
class ExplorationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 当前探索状态
    @Published var state: ExplorationState = .idle

    /// 当前累计距离（米）
    @Published var currentDistance: Double = 0

    /// 当前探索时长（秒）
    @Published var currentDuration: TimeInterval = 0

    /// 当前速度（km/h）
    @Published var currentSpeed: Double = 0

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    /// 超速倒计时（秒）
    @Published var speedWarningCountdown: Int = 0

    /// 探索结果（完成后可用）
    @Published var explorationResult: ExplorationResult?

    /// 是否显示结果弹窗
    @Published var showResult: Bool = false

    /// 错误消息
    @Published var errorMessage: String?

    /// 奖励等级（实时计算）
    @Published var currentRewardTier: RewardTier = .none

    /// 探索失败原因
    @Published var failureReason: ExplorationFailureReason?

    // MARK: - Private Properties

    /// 位置管理器
    private var locationManager: CLLocationManager

    /// 探索路径上的位置点
    private var explorationPath: [CLLocation] = []

    /// 探索开始时间
    private var startTime: Date?

    /// 计时器
    private var durationTimer: Timer?

    /// 超速计时器
    private var speedWarningTimer: Timer?

    /// 上一个有效位置
    private var lastValidLocation: CLLocation?

    /// Supabase 客户端
    private let supabase: SupabaseClient

    /// 背包管理器引用
    private weak var inventoryManager: InventoryManager?

    // MARK: - 速度限制常量

    /// 最大允许速度（km/h）
    private let maxSpeedKmh: Double = 30.0

    /// 最大允许速度（m/s）
    private var maxSpeedMs: Double { maxSpeedKmh / 3.6 }

    /// 超速警告倒计时（秒）
    private let speedWarningDuration: Int = 10

    /// 最小探索时间（秒）- 防止误触立即结束
    private let minExplorationDuration: TimeInterval = 3.0

    /// 上次状态变更时间 - 防止重复触发
    private var lastStateChangeTime: Date = Date.distantPast

    // MARK: - GPS 过滤常量

    /// 最大允许精度（米）
    private let maxAccuracy: CLLocationAccuracy = 50.0

    /// 最大跳跃距离（米）- 基于最大速度计算，10秒内最大移动距离
    private var maxJumpDistance: Double { maxSpeedMs * 10 }

    /// 最小时间间隔（秒）
    private let minTimeInterval: TimeInterval = 1.0

    /// 最小移动距离（米）- 过滤GPS噪声
    private let minMovementDistance: Double = 2.0

    // MARK: - Initialization

    override init() {
        self.locationManager = CLLocationManager()
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://acnriuoexalqvckiuvgr.supabase.co")!,
            supabaseKey: "sb_publishable_ddDdaU8v_cxisWA6TiHDuA_BHAdLp-R"
        )

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 3  // 每移动3米更新一次
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.activityType = .fitness  // 优化步行/跑步追踪

        log("ExplorationManager 初始化完成")
        log("速度限制: \(maxSpeedKmh) km/h (\(String(format: "%.2f", maxSpeedMs)) m/s)")
        log("GPS精度要求: ≤\(maxAccuracy)m")
    }

    // MARK: - Logging

    /// 日志输出
    private func log(_ message: String, level: String = "INFO") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let stateStr = state.rawValue
        print("[\(timestamp)] [\(level)] [Exploration:\(stateStr)] \(message)")
    }

    // MARK: - Public Methods

    /// 设置背包管理器引用
    func setInventoryManager(_ manager: InventoryManager) {
        self.inventoryManager = manager
        log("InventoryManager 已设置")
    }

    /// 开始探索
    func startExploration() {
        // 防止重复触发（500ms 内忽略）
        let now = Date()
        guard now.timeIntervalSince(lastStateChangeTime) > 0.5 else {
            log("忽略重复触发：距离上次状态变更不足 500ms", level: "WARN")
            return
        }

        guard state == .idle || state == .failed else {
            log("无法开始探索：当前状态为 \(state.rawValue)", level: "WARN")
            return
        }

        log("========== 开始探索 ==========", level: "INFO")
        log("当前位置权限状态: \(locationManager.authorizationStatus.rawValue)")

        // 检查位置权限
        let authStatus = locationManager.authorizationStatus
        if authStatus == .denied || authStatus == .restricted {
            log("位置权限被拒绝，无法开始探索", level: "ERROR")
            errorMessage = "需要位置权限才能探索，请在设置中开启"
            return
        }

        if authStatus == .notDetermined {
            log("位置权限未确定，请求权限", level: "INFO")
            locationManager.requestWhenInUseAuthorization()
            // 不要立即开始，等待权限回调
            return
        }

        // 重置状态
        explorationPath = []
        currentDistance = 0
        currentDuration = 0
        currentSpeed = 0
        isOverSpeed = false
        speedWarningCountdown = 0
        currentRewardTier = .none
        lastValidLocation = nil
        explorationResult = nil
        errorMessage = nil
        failureReason = nil
        showResult = false

        // 记录开始时间
        startTime = Date()
        lastStateChangeTime = now

        // 更新状态
        state = .exploring

        // 开始GPS追踪
        locationManager.startUpdatingLocation()
        log("GPS追踪已启动")

        // 开始计时器
        startDurationTimer()
        log("计时器已启动")
    }

    /// 结束探索（正常结束）
    func stopExploration() async {
        // 防止重复触发（500ms 内忽略）
        let now = Date()
        guard now.timeIntervalSince(lastStateChangeTime) > 0.5 else {
            log("忽略重复触发：距离上次状态变更不足 500ms", level: "WARN")
            return
        }

        guard state == .exploring || state == .speedWarning else {
            log("无法结束探索：当前状态为 \(state.rawValue)", level: "WARN")
            return
        }

        // 检查最小探索时间
        if let start = startTime {
            let elapsed = now.timeIntervalSince(start)
            if elapsed < minExplorationDuration {
                log("探索时间不足 \(minExplorationDuration) 秒，当前 \(String(format: "%.1f", elapsed)) 秒", level: "WARN")
                errorMessage = "探索时间太短，请至少探索 \(Int(minExplorationDuration)) 秒"
                return
            }
        }

        lastStateChangeTime = now
        log("========== 结束探索 ==========", level: "INFO")
        log("探索时长: \(String(format: "%.1f", currentDuration)) 秒, 距离: \(String(format: "%.0f", currentDistance)) 米")

        // 停止所有计时器
        stopAllTimers()

        // 停止GPS追踪
        locationManager.stopUpdatingLocation()
        log("GPS追踪已停止")

        // 更新状态
        state = .processing
        log("开始处理探索结果...")

        // 处理探索结果
        await processExplorationResult()
    }

    /// 因超速停止探索
    func stopExplorationDueToSpeed() {
        log("========== 探索失败：超速 ==========", level: "ERROR")

        // 停止所有计时器
        stopAllTimers()

        // 停止GPS追踪
        locationManager.stopUpdatingLocation()

        // 更新状态
        state = .failed
        failureReason = .speedExceeded
        errorMessage = "探索失败：移动速度超过 \(Int(maxSpeedKmh)) km/h 限制"

        log("探索失败，行走距离: \(String(format: "%.0f", currentDistance))m")
    }

    /// 重置状态（用于关闭结果弹窗后）
    func resetState() {
        log("重置探索状态")
        state = .idle
        showResult = false
        explorationResult = nil
        errorMessage = nil
        failureReason = nil
        currentSpeed = 0
        isOverSpeed = false
        speedWarningCountdown = 0
    }

    // MARK: - Private Methods

    /// 停止所有计时器
    private func stopAllTimers() {
        durationTimer?.invalidate()
        durationTimer = nil
        speedWarningTimer?.invalidate()
        speedWarningTimer = nil
        log("所有计时器已停止")
    }

    /// 开始计时器
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                guard self.state == .exploring || self.state == .speedWarning else { return }

                if let start = self.startTime {
                    self.currentDuration = Date().timeIntervalSince(start)
                }

                // 实时更新奖励等级
                self.currentRewardTier = RewardGenerator.shared.determineRewardTier(distance: self.currentDistance)

                // 每10秒输出一次状态日志
                if Int(self.currentDuration) % 10 == 0 && self.currentDuration > 0 {
                    self.log("状态: 距离=\(String(format: "%.0f", self.currentDistance))m, 时长=\(Int(self.currentDuration))s, 速度=\(String(format: "%.1f", self.currentSpeed))km/h, 等级=\(self.currentRewardTier.displayName)")
                }
            }
        }
    }

    /// 开始超速倒计时
    private func startSpeedWarningCountdown() {
        guard speedWarningTimer == nil else { return }

        speedWarningCountdown = speedWarningDuration
        state = .speedWarning
        log("开始超速倒计时: \(speedWarningDuration)秒", level: "WARN")

        speedWarningTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }

                self.speedWarningCountdown -= 1
                self.log("超速倒计时: \(self.speedWarningCountdown)秒", level: "WARN")

                if self.speedWarningCountdown <= 0 {
                    // 倒计时结束，速度仍然超标，停止探索
                    if self.isOverSpeed {
                        self.stopExplorationDueToSpeed()
                    }
                }
            }
        }
    }

    /// 停止超速倒计时
    private func cancelSpeedWarningCountdown() {
        speedWarningTimer?.invalidate()
        speedWarningTimer = nil
        speedWarningCountdown = 0

        if state == .speedWarning {
            state = .exploring
            log("速度恢复正常，继续探索")
        }
    }

    /// 处理探索结果
    private func processExplorationResult() async {
        guard let startTime = self.startTime else {
            log("探索数据异常：无开始时间", level: "ERROR")
            errorMessage = "探索数据异常"
            state = .idle
            return
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        log("处理探索结果: 距离=\(String(format: "%.0f", currentDistance))m, 时长=\(Int(duration))s, 路径点数=\(explorationPath.count)")

        // 计算奖励
        let rewardGenerator = RewardGenerator.shared

        // 获取物品定义
        let definitions: [ItemDefinition]
        if let manager = inventoryManager {
            if manager.itemDefinitions.isEmpty {
                log("加载物品定义...")
                try? await manager.loadItemDefinitions()
            }
            definitions = manager.getAllDefinitions()
            log("物品定义数量: \(definitions.count)")
        } else {
            definitions = []
            log("警告: InventoryManager 未设置", level: "WARN")
        }

        // 生成奖励
        let (tier, items) = rewardGenerator.generateRewardsForDistance(
            distance: currentDistance,
            definitions: definitions
        )

        log("奖励结果: 等级=\(tier.displayName), 物品数量=\(items.count)")
        for item in items {
            log("  - \(item.definitionId) x\(item.quantity)")
        }

        // 创建探索结果
        let result = ExplorationResult(
            id: UUID().uuidString,
            userId: (try? await getCurrentUserId()) ?? "unknown",
            startTime: startTime,
            endTime: endTime,
            stats: ExplorationStats(
                distanceThisSession: currentDistance,
                durationThisSession: duration,
                itemsFoundThisSession: items,
                totalDistance: currentDistance,
                totalDuration: duration
            ),
            rewardTier: tier
        )

        // 保存探索记录到数据库
        await saveExplorationSession(result: result, tier: tier, items: items)

        // 添加物品到背包
        if !items.isEmpty {
            do {
                try await inventoryManager?.addItems(items)
                log("物品已添加到背包")
            } catch {
                log("添加物品到背包失败: \(error.localizedDescription)", level: "ERROR")
            }
        }

        // 更新状态
        self.explorationResult = result
        self.state = .completed
        self.showResult = true

        log("========== 探索完成 ==========")
    }

    /// 保存探索记录到数据库
    private func saveExplorationSession(result: ExplorationResult, tier: RewardTier, items: [ItemLoot]) async {
        guard let userId = try? await getCurrentUserId() else {
            log("无法获取用户ID，跳过保存探索记录", level: "WARN")
            return
        }

        log("保存探索记录到数据库...")

        // 将物品列表转为JSON
        let itemsJson: String
        do {
            let itemsArray: [[String: Any]] = items.map { ["item_definition_id": $0.definitionId, "quantity": $0.quantity] }
            let data = try JSONSerialization.data(withJSONObject: itemsArray, options: [])
            itemsJson = String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            itemsJson = "[]"
            log("物品序列化失败: \(error.localizedDescription)", level: "WARN")
        }

        let dateFormatter = ISO8601DateFormatter()

        let session = ExplorationSessionInsert(
            userId: userId,
            startTime: dateFormatter.string(from: result.startTime),
            endTime: dateFormatter.string(from: result.endTime),
            distanceMeters: result.stats.distanceThisSession,
            durationSeconds: Int(result.stats.durationThisSession),
            rewardTier: tier.rawValue,
            itemsEarned: itemsJson
        )

        do {
            try await supabase
                .from("exploration_sessions")
                .insert(session)
                .execute()

            log("探索记录已保存到数据库")
        } catch {
            log("保存探索记录失败: \(error.localizedDescription)", level: "ERROR")
        }
    }

    /// 获取当前用户ID
    private func getCurrentUserId() async throws -> String {
        let session = try await supabase.auth.session
        return session.user.id.uuidString
    }

    /// 处理新的位置更新
    private func handleLocationUpdate(_ location: CLLocation) {
        let timestamp = location.timestamp
        let accuracy = location.horizontalAccuracy
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        log("GPS更新: (\(String(format: "%.6f", lat)), \(String(format: "%.6f", lon))), 精度=\(String(format: "%.1f", accuracy))m")

        // 验证位置有效性
        guard isValidLocation(location) else {
            log("忽略无效位置: 精度=\(String(format: "%.1f", accuracy))m (要求≤\(maxAccuracy)m)", level: "WARN")
            return
        }

        // 计算与上一个点的距离和速度
        if let lastLocation = lastValidLocation {
            let distance = location.distance(from: lastLocation)
            let timeInterval = timestamp.timeIntervalSince(lastLocation.timestamp)

            // 检查时间间隔
            guard timeInterval >= minTimeInterval else {
                log("忽略: 时间间隔过短 (\(String(format: "%.2f", timeInterval))s < \(minTimeInterval)s)")
                return
            }

            // 计算速度 (m/s -> km/h)
            let speedMs = distance / timeInterval
            let speedKmh = speedMs * 3.6
            currentSpeed = speedKmh

            log("移动: 距离=\(String(format: "%.1f", distance))m, 时间=\(String(format: "%.1f", timeInterval))s, 速度=\(String(format: "%.1f", speedKmh))km/h")

            // 检查速度
            if speedKmh > maxSpeedKmh {
                log("超速检测: \(String(format: "%.1f", speedKmh))km/h > \(maxSpeedKmh)km/h", level: "WARN")
                isOverSpeed = true

                // 如果还没开始倒计时，开始倒计时
                if speedWarningTimer == nil {
                    startSpeedWarningCountdown()
                }

                // 超速时不计入距离
                return
            } else {
                // 速度正常
                if isOverSpeed {
                    isOverSpeed = false
                    cancelSpeedWarningCountdown()
                }
            }

            // 检查是否跳跃过大（可能是GPS漂移）
            if distance > maxJumpDistance {
                log("忽略: 跳跃过大 (\(String(format: "%.0f", distance))m > \(String(format: "%.0f", maxJumpDistance))m)", level: "WARN")
                return
            }

            // 过滤GPS噪声（太小的移动）
            if distance < minMovementDistance {
                log("忽略: 移动太小 (\(String(format: "%.2f", distance))m < \(minMovementDistance)m)")
                return
            }

            // 累加距离
            currentDistance += distance
            log("距离累加: +\(String(format: "%.1f", distance))m, 总计=\(String(format: "%.0f", currentDistance))m")
        } else {
            log("记录起始位置")
        }

        // 记录位置
        explorationPath.append(location)
        lastValidLocation = location
    }

    /// 验证位置是否有效
    private func isValidLocation(_ location: CLLocation) -> Bool {
        // 检查精度是否有效
        if location.horizontalAccuracy < 0 {
            return false
        }

        // 检查精度是否在允许范围内
        if location.horizontalAccuracy > maxAccuracy {
            return false
        }

        return true
    }
}

// MARK: - CLLocationManagerDelegate

extension ExplorationManager: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard state == .exploring || state == .speedWarning else { return }

            for location in locations {
                handleLocationUpdate(location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            log("GPS错误: \(error.localizedDescription)", level: "ERROR")

            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    errorMessage = "位置权限被拒绝，请在设置中开启"
                case .locationUnknown:
                    errorMessage = "无法获取位置，请检查GPS信号"
                default:
                    errorMessage = "位置更新失败: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "位置更新失败: \(error.localizedDescription)"
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            log("位置权限状态变更: \(status.rawValue)")

            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                log("位置权限已授权")
            case .denied, .restricted:
                log("位置权限被拒绝", level: "ERROR")
                errorMessage = "需要位置权限才能使用探索功能，请在设置中开启"
            case .notDetermined:
                log("请求位置权限...")
                manager.requestWhenInUseAuthorization()
            @unknown default:
                break
            }
        }
    }
}
