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
import UIKit

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

    // MARK: - POI 相关属性

    /// 附近 POI 列表
    @Published var nearbyPOIs: [POI] = []

    /// 是否显示接近 POI 弹窗
    @Published var showPOIPopup: Bool = false

    /// 当前接近的 POI
    @Published var currentPOI: POI? = nil

    /// 当前距离 POI 的距离（米）
    @Published var currentPOIDistance: Double = 0

    /// 是否显示搜刮结果
    @Published var showScavengeResult: Bool = false

    /// 搜刮获得的物品（传统方式，保留作为降级方案）
    @Published var scavengeItems: [ItemLoot] = []

    /// AI 生成的物品列表
    @Published var aiGeneratedItems: [AIGeneratedItem] = []

    /// 是否正在生成 AI 物品
    @Published var isGeneratingAIItems: Bool = false

    /// 当前搜刮的 POI（用于结果显示）
    @Published var scavengedPOI: POI? = nil

    /// POI 搜索状态
    @Published var isSearchingPOI: Bool = false

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

    /// 背包管理器引用（使用强引用确保不会被释放）
    private var inventoryManager: InventoryManager?

    /// 玩家位置管理器引用
    private weak var playerLocationManager: PlayerLocationManager?

    /// 当前玩家密度等级
    @Published var playerDensityLevel: PlayerDensityLevel = .solitary

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

    // MARK: - POI 常量

    /// POI 搜索半径（米）
    private let poiSearchRadius: CLLocationDistance = 1000

    /// POI 触发距离（米）
    private let poiTriggerDistance: CLLocationDistance = 50

    /// 已搜刮的 POI ID 集合（防止重复搜刮）
    private var scavengedPOIIds: Set<String> = []

    // MARK: - Initialization

    override init() {
        self.locationManager = CLLocationManager()
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://acnriuoexalqvckiuvgr.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFjbnJpdW9leGFscXZja2l1dmdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5NTQzNDUsImV4cCI6MjA4MTUzMDM0NX0.cOTtYT-dnBDLNKFzFh3pIU6H1W0hksl3sdgdWiqOjIM"
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
        log("✅ InventoryManager 已设置, 实例ID: \(ObjectIdentifier(manager))")
    }

    /// 检查 InventoryManager 是否已设置
    func checkInventoryManager() -> Bool {
        let isSet = inventoryManager != nil
        log("检查 InventoryManager: \(isSet ? "已设置" : "未设置")")
        return isSet
    }

    /// 设置玩家位置管理器引用
    func setPlayerLocationManager(_ manager: PlayerLocationManager) {
        self.playerLocationManager = manager
        log("PlayerLocationManager 已设置")
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

        // 重置 POI 相关状态
        nearbyPOIs = []
        showPOIPopup = false
        currentPOI = nil
        currentPOIDistance = 0
        showScavengeResult = false
        scavengeItems = []
        aiGeneratedItems = []
        isGeneratingAIItems = false
        scavengedPOI = nil
        scavengedPOIIds = []

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

        // 启动玩家位置上报服务
        if let location = locationManager.location?.coordinate {
            playerLocationManager?.startLocationService(at: location)
            log("玩家位置上报服务已启动")
        }

        // 搜索附近 POI
        Task {
            await searchNearbyPOIs()
        }
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

        // 清除地理围栏
        clearGeofences()

        // 停止玩家位置上报服务
        playerLocationManager?.stopLocationService()
        log("玩家位置上报服务已停止")

        // 清除 POI 相关状态
        nearbyPOIs = []
        showPOIPopup = false
        currentPOI = nil

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

        // 清除地理围栏
        clearGeofences()

        // 停止玩家位置上报服务
        playerLocationManager?.stopLocationService()

        // 清除 POI 相关状态
        nearbyPOIs = []
        showPOIPopup = false
        currentPOI = nil

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

            // ⭐ 优先使用系统提供的速度（更可靠）
            var speedKmh: Double
            if location.speed >= 0 {
                // 系统速度有效（非负值表示有效）
                speedKmh = location.speed * 3.6  // m/s -> km/h
                log("使用系统速度: \(String(format: "%.1f", speedKmh))km/h")
            } else {
                // 系统速度无效，自己计算
                let speedMs = distance / timeInterval
                speedKmh = speedMs * 3.6
                log("计算速度: \(String(format: "%.1f", speedKmh))km/h (系统速度无效)")
            }

            // ⭐ GPS 跳点检测（速度超过 50 km/h 判定为跳点，忽略此位置）
            let gpsJumpThreshold: Double = 50.0  // km/h，人类跑步极限约 45 km/h
            if speedKmh > gpsJumpThreshold {
                log("忽略: GPS跳点 (速度=\(String(format: "%.1f", speedKmh))km/h > \(gpsJumpThreshold)km/h)", level: "WARN")
                // 不更新 lastValidLocation，等待下一个正常的位置点
                return
            }

            // 检查是否跳跃过大（可能是GPS漂移）
            if distance > maxJumpDistance {
                log("忽略: 跳跃过大 (\(String(format: "%.0f", distance))m > \(String(format: "%.0f", maxJumpDistance))m)", level: "WARN")
                return
            }

            // 更新当前速度
            currentSpeed = speedKmh

            log("移动: 距离=\(String(format: "%.1f", distance))m, 时间=\(String(format: "%.1f", timeInterval))s, 速度=\(String(format: "%.1f", speedKmh))km/h")

            // 检查速度（真正的超速检测）
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

        // 通知玩家位置管理器（用于上报和密度检测）
        playerLocationManager?.handleLocationUpdate(location.coordinate)

        // ⭐ POI 距离检测（比地理围栏更可靠）
        checkPOIProximity(currentLocation: location)
    }

    /// 检查是否接近任何 POI
    private func checkPOIProximity(currentLocation: CLLocation) {
        // 检查是否正在显示弹窗（使用 scavengedPOI 作为搜刮结果弹窗的真实状态）
        guard !showPOIPopup && scavengedPOI == nil else { return }

        // ⭐ 关键修复：将用户坐标从 WGS-84 转换为 GCJ-02
        // MapKit 返回的 POI 坐标是 GCJ-02，GPS 返回的用户位置是 WGS-84
        // 在中国必须转换后才能正确计算距离
        let userGcj02 = CoordinateConverter.wgs84ToGcj02(currentLocation.coordinate)
        let userGcj02Location = CLLocation(latitude: userGcj02.latitude, longitude: userGcj02.longitude)

        // 遍历所有 POI，检查距离
        for poi in nearbyPOIs {
            // 跳过已搜刮的 POI
            guard !scavengedPOIIds.contains(poi.id) else { continue }

            // POI 坐标已经是 GCJ-02，直接使用
            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let distance = userGcj02Location.distance(from: poiLocation)

            // 如果距离小于触发阈值，触发弹窗
            if distance <= poiTriggerDistance {
                log("距离检测触发: \(poi.name)，距离=\(String(format: "%.1f", distance))m")
                currentPOI = poi
                currentPOIDistance = distance
                showPOIPopup = true

                // 触发震动
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(.warning)

                // 只触发一个 POI
                break
            }
        }
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

    // MARK: - POI 搜索方法

    /// 搜索附近 POI
    private func searchNearbyPOIs() async {
        guard let location = lastValidLocation?.coordinate ?? locationManager.location?.coordinate else {
            log("无法获取当前位置，延迟搜索 POI", level: "WARN")
            // 延迟 2 秒后重试
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if state == .exploring {
                await searchNearbyPOIs()
            }
            return
        }

        isSearchingPOI = true
        log("开始搜索附近 POI，位置: (\(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude)))")

        // 先查询附近玩家密度
        if let manager = playerLocationManager {
            await manager.refreshDensity(at: location)
            playerDensityLevel = manager.currentDensityLevel
            log("玩家密度: \(playerDensityLevel.rawValue)（附近 \(manager.nearbyPlayerCount) 人）")
        }

        // 根据密度等级确定 POI 数量上限
        let maxPOIs = playerDensityLevel.poiLimit
        log("根据密度限制 POI 上限: \(maxPOIs) 个")

        // 搜索 POI（传入数量限制）
        let pois = await POISearchManager.shared.searchNearbyPOIs(
            center: location,
            radius: poiSearchRadius,
            maxResults: maxPOIs
        )

        isSearchingPOI = false
        nearbyPOIs = pois

        log("POI 搜索完成，找到 \(pois.count) 个 POI")

        // 设置地理围栏
        if !pois.isEmpty {
            setupGeofences()
        }
    }

    /// 设置地理围栏
    private func setupGeofences() {
        // 清除旧的围栏
        clearGeofences()

        guard !nearbyPOIs.isEmpty else { return }

        log("设置 \(nearbyPOIs.count) 个地理围栏")

        for poi in nearbyPOIs {
            let region = CLCircularRegion(
                center: poi.coordinate,
                radius: poiTriggerDistance,
                identifier: poi.id
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            locationManager.startMonitoring(for: region)
            log("围栏已设置: \(poi.name) (ID: \(poi.id))")
        }
    }

    /// 清除所有地理围栏
    private func clearGeofences() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        log("已清除 \(locationManager.monitoredRegions.count) 个地理围栏")
    }

    /// 处理进入 POI 范围
    func handlePOIEntry(regionId: String) {
        // 检查是否已搜刮过
        guard !scavengedPOIIds.contains(regionId) else {
            log("POI \(regionId) 已被搜刮，忽略")
            return
        }

        // 查找对应的 POI
        guard let poi = nearbyPOIs.first(where: { $0.id == regionId }) else {
            log("未找到 POI: \(regionId)", level: "WARN")
            return
        }

        // 检查是否正在显示其他弹窗（使用 scavengedPOI 作为搜刮结果弹窗的真实状态）
        guard !showPOIPopup && scavengedPOI == nil else {
            log("正在显示其他弹窗，忽略 POI 进入事件")
            return
        }

        log("进入 POI 范围: \(poi.name)")

        // 计算当前距离（需要坐标转换）
        if let currentLocation = lastValidLocation {
            // 将用户坐标从 WGS-84 转换为 GCJ-02
            let userGcj02 = CoordinateConverter.wgs84ToGcj02(currentLocation.coordinate)
            let userGcj02Location = CLLocation(latitude: userGcj02.latitude, longitude: userGcj02.longitude)
            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            currentPOIDistance = userGcj02Location.distance(from: poiLocation)
        } else {
            currentPOIDistance = poiTriggerDistance
        }

        // 显示弹窗
        currentPOI = poi
        showPOIPopup = true

        // 触发震动
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// 关闭 POI 弹窗
    func dismissPOIPopup() {
        showPOIPopup = false
        currentPOI = nil
        log("关闭 POI 弹窗")
    }

    /// 执行搜刮（使用 AI 生成物品）
    func scavengePOI() async {
        guard let poi = currentPOI else {
            log("无当前 POI，无法搜刮", level: "ERROR")
            return
        }

        log("开始搜刮: \(poi.name) (危险等级: \(poi.dangerLevel))")

        // 标记为已搜刮
        scavengedPOIIds.insert(poi.id)

        // 更新 POI 状态
        if let index = nearbyPOIs.firstIndex(where: { $0.id == poi.id }) {
            nearbyPOIs[index].status = .looted
            nearbyPOIs[index].hasLoot = false
        }

        // 关闭接近弹窗
        showPOIPopup = false

        // 设置生成状态
        isGeneratingAIItems = true

        // 计算物品数量（基于 POI 危险等级）
        let itemCount = AIItemGenerator.shared.calculateItemCount(for: poi)
        log("计划生成 \(itemCount) 个物品")

        // 尝试使用 AI 生成物品
        var generatedItems: [AIGeneratedItem]? = nil

        generatedItems = await AIItemGenerator.shared.generateItems(for: poi, count: itemCount)

        // 如果 AI 生成失败，使用降级方案
        if generatedItems == nil || generatedItems!.isEmpty {
            log("AI 生成失败，使用降级方案", level: "WARN")
            generatedItems = AIItemGenerator.shared.generateFallbackItems(for: poi, count: itemCount)
        }

        // 保存 AI 生成的物品
        aiGeneratedItems = generatedItems ?? []

        // 同时转换为 ItemLoot 添加到背包（保持向后兼容）
        let items = convertAIItemsToItemLoot(generatedItems ?? [])
        scavengeItems = items

        log("转换后的物品: \(items.map { $0.definitionId })")

        // 添加到背包
        if !items.isEmpty {
            if let manager = inventoryManager {
                log("🎒 [ExplorationManager] 使用 InventoryManager 实例ID: \(ObjectIdentifier(manager))")
                do {
                    try await manager.addItems(items)
                    log("✅ 搜刮物品已添加到背包: \(items.count) 件")
                    log("🎒 [ExplorationManager] 添加后 inventoryItems.count: \(manager.inventoryItems.count)")
                } catch {
                    log("❌ 添加搜刮物品到背包失败: \(error.localizedDescription)", level: "ERROR")
                }
            } else {
                log("❌ inventoryManager 为 nil，无法添加物品到背包!", level: "ERROR")
            }
        } else {
            log("⚠️ 转换后物品列表为空", level: "WARN")
        }

        // 完成生成
        isGeneratingAIItems = false

        // 保存搜刮的 POI
        scavengedPOI = poi

        // 显示搜刮结果
        showScavengeResult = true

        log("搜刮完成: \(poi.name)，获得 \(aiGeneratedItems.count) 件 AI 生成物品")
    }

    /// 将 AI 生成的物品转换为 ItemLoot（用于背包系统）
    /// 将 AI 物品映射到数据库中已有的物品定义，同时保留 AI 生成的自定义信息
    private func convertAIItemsToItemLoot(_ aiItems: [AIGeneratedItem]) -> [ItemLoot] {
        return aiItems.compactMap { aiItem in
            // 根据分类和稀有度映射到现有物品定义
            let definitionId = mapAIItemToDefinitionId(category: aiItem.categoryEnum, rarity: aiItem.rarityEnum)

            guard let defId = definitionId else {
                log("无法映射 AI 物品: \(aiItem.name) (分类: \(aiItem.category), 稀有度: \(aiItem.rarity))", level: "WARN")
                return nil
            }

            // 保留 AI 生成的自定义信息
            return ItemLoot(
                id: aiItem.id,
                definitionId: defId,
                quantity: 1,
                quality: nil,
                customName: aiItem.name,           // AI 生成的独特名称
                customStory: aiItem.story,         // AI 生成的背景故事
                customCategory: aiItem.category,   // AI 生成的分类
                customRarity: aiItem.rarity        // AI 生成的稀有度
            )
        }
    }

    /// 将 AI 物品的分类和稀有度映射到现有物品定义 ID
    private func mapAIItemToDefinitionId(category: ItemCategory, rarity: ItemRarity) -> String? {
        // 物品映射表（基于数据库中的 item_definitions）
        // 格式: [分类: [稀有度: 物品ID]]
        let itemMap: [ItemCategory: [ItemRarity: String]] = [
            .medical: [
                .common: "item_bandage",
                .uncommon: "item_bandage",
                .rare: "item_first_aid_kit",
                .epic: "item_antibiotics",
                .legendary: "item_antibiotics"
            ],
            .food: [
                .common: "item_biscuit",
                .uncommon: "item_canned_food",
                .rare: "item_canned_food",
                .epic: "item_canned_food",
                .legendary: "item_canned_food"
            ],
            .water: [
                .common: "item_water",
                .uncommon: "item_water",
                .rare: "item_water",
                .epic: "item_water",
                .legendary: "item_water"
            ],
            .tool: [
                .common: "item_matches",
                .uncommon: "item_matches",
                .rare: "item_flashlight",
                .epic: "item_gas_mask",
                .legendary: "item_gas_mask"
            ],
            .material: [
                .common: "item_matches",
                .uncommon: "item_matches",
                .rare: "item_toolbox",
                .epic: "item_generator_parts",
                .legendary: "item_generator_parts"
            ],
            .weapon: [
                .common: "item_matches",
                .uncommon: "item_toolbox",
                .rare: "item_toolbox",
                .epic: "item_toolbox",
                .legendary: "item_toolbox"
            ]
        ]

        // 查找映射
        if let categoryMap = itemMap[category], let itemId = categoryMap[rarity] {
            return itemId
        }

        // 降级：返回同分类的普通物品
        if let categoryMap = itemMap[category], let itemId = categoryMap[.common] {
            return itemId
        }

        // 最终降级：返回饼干
        return "item_biscuit"
    }

    /// 生成搜刮物品
    private func generateScavengeItems() async -> [ItemLoot] {
        // 获取物品定义
        let definitions: [ItemDefinition]
        if let manager = inventoryManager {
            if manager.itemDefinitions.isEmpty {
                try? await manager.loadItemDefinitions()
            }
            definitions = manager.getAllDefinitions()
        } else {
            return []
        }

        guard !definitions.isEmpty else {
            log("物品定义为空，无法生成搜刮物品", level: "WARN")
            return []
        }

        // 随机生成 1-3 件物品
        let itemCount = Int.random(in: 1...3)
        var items: [ItemLoot] = []

        // 按稀有度分类
        let commonItems = definitions.filter { $0.rarity == .common }
        let rareItems = definitions.filter { $0.rarity == .rare }
        let epicItems = definitions.filter { $0.rarity == .epic }

        for _ in 0..<itemCount {
            let roll = Double.random(in: 0..<1)

            var selectedItem: ItemDefinition?

            // 70% common, 25% rare, 5% epic
            if roll < 0.70 {
                selectedItem = commonItems.randomElement()
            } else if roll < 0.95 {
                selectedItem = rareItems.randomElement() ?? commonItems.randomElement()
            } else {
                selectedItem = epicItems.randomElement() ?? rareItems.randomElement() ?? commonItems.randomElement()
            }

            if let item = selectedItem {
                // 检查是否已有这个物品
                if let existingIndex = items.firstIndex(where: { $0.definitionId == item.id }) {
                    let existing = items[existingIndex]
                    items[existingIndex] = ItemLoot(
                        id: existing.id,
                        definitionId: existing.definitionId,
                        quantity: existing.quantity + 1,
                        quality: existing.quality
                    )
                } else {
                    items.append(ItemLoot(
                        id: UUID().uuidString,
                        definitionId: item.id,
                        quantity: 1,
                        quality: nil
                    ))
                }
            }
        }

        return items
    }

    /// 关闭搜刮结果弹窗
    func dismissScavengeResult() {
        showScavengeResult = false
        scavengeItems = []
        aiGeneratedItems = []
        scavengedPOI = nil
        currentPOI = nil
        log("关闭搜刮结果弹窗")
    }

    // MARK: - 测试方法

    /// 添加测试 POI（在用户附近指定距离处）
    /// - Parameters:
    ///   - distance: 距离用户的米数（默认 10 米）
    ///   - type: POI 类型（默认医院）
    ///   - dangerLevel: 危险等级（1-5，默认 3）
    func addTestPOI(distance: Double = 10, type: POIType = .hospital, dangerLevel: Int = 3) {
        guard let currentLocation = locationManager.location?.coordinate else {
            log("无法获取当前位置，无法添加测试 POI", level: "ERROR")
            return
        }

        // 将用户坐标从 WGS-84 转换为 GCJ-02（与 MapKit POI 保持一致）
        let userGcj02 = CoordinateConverter.wgs84ToGcj02(currentLocation)

        // 计算偏移（向北偏移指定距离）
        // 1度纬度约等于 111,000 米
        let latOffset = distance / 111000.0
        let testCoordinate = CLLocationCoordinate2D(
            latitude: userGcj02.latitude + latOffset,
            longitude: userGcj02.longitude
        )

        // 创建测试 POI
        let testPOI = POI(
            id: "test_poi_\(UUID().uuidString.prefix(8))",
            name: "🧪 测试点 - \(type.rawValue)",
            type: type,
            coordinate: testCoordinate,
            status: .discovered,
            hasLoot: true,
            description: "这是一个用于测试 AI 物品生成的虚拟 POI",
            dangerLevel: dangerLevel
        )

        // 添加到 POI 列表
        nearbyPOIs.append(testPOI)

        // 设置地理围栏
        let region = CLCircularRegion(
            center: testCoordinate,
            radius: poiTriggerDistance,
            identifier: testPOI.id
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        locationManager.startMonitoring(for: region)

        log("✅ 测试 POI 已添加: \(testPOI.name)")
        log("   位置: (\(String(format: "%.6f", testCoordinate.latitude)), \(String(format: "%.6f", testCoordinate.longitude)))")
        log("   距离: \(distance) 米（向北）")
        log("   类型: \(type.rawValue), 危险等级: \(dangerLevel)")
    }

    /// 直接触发测试 POI 的搜刮弹窗（无需走到 POI 位置）
    func triggerTestPOIPopup(type: POIType = .hospital, dangerLevel: Int = 4) {
        guard let currentLocation = locationManager.location?.coordinate else {
            log("无法获取当前位置", level: "ERROR")
            return
        }

        // 将用户坐标从 WGS-84 转换为 GCJ-02
        let userGcj02 = CoordinateConverter.wgs84ToGcj02(currentLocation)

        // 创建测试 POI（就在用户位置）
        let testPOI = POI(
            id: "test_trigger_\(UUID().uuidString.prefix(8))",
            name: "🧪 测试搜刮点 - \(type.rawValue)",
            type: type,
            coordinate: userGcj02,
            status: .discovered,
            hasLoot: true,
            description: "测试 AI 物品生成功能",
            dangerLevel: dangerLevel
        )

        // 设置当前 POI 并显示弹窗
        currentPOI = testPOI
        currentPOIDistance = 0
        showPOIPopup = true

        // 触发震动
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)

        log("✅ 测试 POI 弹窗已触发: \(testPOI.name), 危险等级: \(dangerLevel)")
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

    // MARK: - 地理围栏回调

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            guard state == .exploring || state == .speedWarning else { return }
            log("进入地理围栏: \(region.identifier)")
            handlePOIEntry(regionId: region.identifier)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            log("离开地理围栏: \(region.identifier)")
            // 目前不处理离开事件
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Task { @MainActor in
            log("地理围栏监控失败: \(region?.identifier ?? "unknown") - \(error.localizedDescription)", level: "ERROR")
        }
    }
}
