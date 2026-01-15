//
//  PlayerLocationManager.swift
//  Earthlord
//
//  Created by Claude on 2026-01-14.
//
//  管理玩家位置上报和附近玩家密度查询
//

import Foundation
import Combine
import CoreLocation
import Supabase
import UIKit

/// 玩家位置管理器
/// 负责位置上报到 Supabase 和查询附近玩家数量
@MainActor
class PlayerLocationManager: ObservableObject {

    // MARK: - Published Properties

    /// 当前玩家密度等级
    @Published var currentDensityLevel: PlayerDensityLevel = .solitary

    /// 附近玩家数量
    @Published var nearbyPlayerCount: Int = 0

    /// 是否正在上报
    @Published var isUploading: Bool = false

    /// 是否服务运行中
    @Published var isServiceRunning: Bool = false

    /// 错误消息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let supabase: SupabaseClient

    /// 定时上报计时器
    private var uploadTimer: Timer?

    /// 上次上报位置
    private var lastUploadedLocation: CLLocationCoordinate2D?

    /// 上次上报时间
    private var lastUploadTime: Date?

    /// 当前位置（由外部更新）
    private var currentLocation: CLLocationCoordinate2D?

    // MARK: - Constants

    /// 定时上报间隔（秒）
    private let uploadInterval: TimeInterval = 30.0

    /// 触发即时上报的移动距离阈值（米）
    private let movementThreshold: CLLocationDistance = 50.0

    /// 查询半径（米）
    private let queryRadius: Double = 1000.0

    /// 活跃时间窗口（分钟）
    private let activeMinutes: Int = 5

    // MARK: - Initialization

    init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://acnriuoexalqvckiuvgr.supabase.co")!,
            supabaseKey: "sb_publishable_ddDdaU8v_cxisWA6TiHDuA_BHAdLp-R"
        )

        // 监听 App 生命周期
        setupAppLifecycleObservers()

        log("PlayerLocationManager 初始化完成")
    }

    deinit {
        uploadTimer?.invalidate()
        uploadTimer = nil
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - App Lifecycle

    /// 设置 App 生命周期监听
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    /// App 进入前台
    @objc private func appDidBecomeActive() {
        guard isServiceRunning else { return }
        log("App 进入前台，恢复位置上报")
        Task {
            await markOnline(true)
            startPeriodicUpload()
        }
    }

    /// App 进入后台
    @objc private func appDidEnterBackground() {
        guard isServiceRunning else { return }
        log("App 进入后台，标记离线")
        stopPeriodicUpload()
        Task {
            await markOnline(false)
        }
    }

    // MARK: - Public Methods

    /// 启动位置上报服务（探索开始时调用）
    /// - Parameter initialLocation: 初始位置
    func startLocationService(at initialLocation: CLLocationCoordinate2D) {
        guard !isServiceRunning else {
            log("位置服务已在运行中")
            return
        }

        log("启动位置上报服务")
        isServiceRunning = true
        currentLocation = initialLocation

        // 立即上报当前位置
        Task {
            await uploadLocation(initialLocation)
            await queryNearbyPlayers(at: initialLocation)
        }

        // 启动定时上报
        startPeriodicUpload()
    }

    /// 停止位置上报服务（探索结束时调用）
    func stopLocationService() {
        guard isServiceRunning else { return }

        log("停止位置上报服务")
        isServiceRunning = false
        stopPeriodicUpload()

        // 标记离线
        Task {
            await markOnline(false)
        }

        // 重置状态
        lastUploadedLocation = nil
        lastUploadTime = nil
        currentLocation = nil
    }

    /// 处理位置更新（由 ExplorationManager 调用）
    /// - Parameter location: 新位置
    func handleLocationUpdate(_ location: CLLocationCoordinate2D) {
        guard isServiceRunning else { return }

        currentLocation = location

        // 检查是否需要即时上报（移动超过阈值）
        if shouldUploadImmediately(newLocation: location) {
            log("移动超过 \(Int(movementThreshold))m，触发即时上报")
            Task {
                await uploadLocation(location)
            }
        }
    }

    /// 手动刷新附近玩家密度
    /// - Parameter location: 当前位置
    func refreshDensity(at location: CLLocationCoordinate2D) async {
        await queryNearbyPlayers(at: location)
    }

    // MARK: - Private Methods - Upload

    /// 上报位置到数据库
    private func uploadLocation(_ location: CLLocationCoordinate2D) async {
        guard let userId = try? await getCurrentUserId() else {
            log("无法获取用户 ID，跳过上报", level: "WARN")
            return
        }

        isUploading = true
        defer { isUploading = false }

        let dateFormatter = ISO8601DateFormatter()
        let data = PlayerLocationUpsert(
            userId: userId,
            latitude: location.latitude,
            longitude: location.longitude,
            updatedAt: dateFormatter.string(from: Date()),
            isOnline: true
        )

        do {
            // 使用 upsert（基于 user_id 的唯一约束）
            try await supabase
                .from("player_locations")
                .upsert(data, onConflict: "user_id")
                .execute()

            // 更新上次上报记录
            lastUploadedLocation = location
            lastUploadTime = Date()

            log("位置上报成功: (\(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude)))")

        } catch {
            log("位置上报失败: \(error.localizedDescription)", level: "ERROR")
            errorMessage = "位置上报失败"
        }
    }

    /// 标记在线/离线状态
    private func markOnline(_ online: Bool) async {
        guard let userId = try? await getCurrentUserId() else { return }

        let dateFormatter = ISO8601DateFormatter()
        let update = PlayerOnlineStatusUpdate(
            isOnline: online,
            updatedAt: dateFormatter.string(from: Date())
        )

        do {
            try await supabase
                .from("player_locations")
                .update(update)
                .eq("user_id", value: userId)
                .execute()

            log("标记\(online ? "在线" : "离线")成功")

        } catch {
            log("标记在线状态失败: \(error.localizedDescription)", level: "ERROR")
        }
    }

    // MARK: - Private Methods - Query

    /// 查询附近玩家数量
    private func queryNearbyPlayers(at location: CLLocationCoordinate2D) async {
        do {
            // 调用 RPC 函数
            let response: Int = try await supabase
                .rpc("count_nearby_players", params: [
                    "p_lat": location.latitude,
                    "p_lon": location.longitude,
                    "p_radius_meters": queryRadius,
                    "p_since_minutes": Double(activeMinutes)
                ])
                .execute()
                .value

            // 更新状态
            nearbyPlayerCount = response
            currentDensityLevel = PlayerDensityLevel.from(nearbyCount: response)

            log("附近玩家查询: \(response) 人，密度等级: \(currentDensityLevel.rawValue)")

        } catch {
            log("附近玩家查询失败: \(error.localizedDescription)", level: "ERROR")
            // 查询失败时使用默认值（独行者模式）
            nearbyPlayerCount = 0
            currentDensityLevel = .solitary
        }
    }

    // MARK: - Private Methods - Timer

    /// 启动定时上报
    private func startPeriodicUpload() {
        stopPeriodicUpload() // 先停止已有的

        uploadTimer = Timer.scheduledTimer(withTimeInterval: uploadInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isServiceRunning else { return }

                // 使用当前位置上报
                if let location = self.currentLocation {
                    await self.uploadLocation(location)
                }
            }
        }

        log("定时上报已启动，间隔: \(Int(uploadInterval))秒")
    }

    /// 停止定时上报
    private func stopPeriodicUpload() {
        uploadTimer?.invalidate()
        uploadTimer = nil
        log("定时上报已停止")
    }

    /// 判断是否需要即时上报
    private func shouldUploadImmediately(newLocation: CLLocationCoordinate2D) -> Bool {
        guard let lastLocation = lastUploadedLocation else {
            return true // 没有上次位置，需要上报
        }

        let lastCLLocation = CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
        let newCLLocation = CLLocation(latitude: newLocation.latitude, longitude: newLocation.longitude)
        let distance = newCLLocation.distance(from: lastCLLocation)

        return distance >= movementThreshold
    }

    // MARK: - Helper Methods

    /// 获取当前用户 ID
    private func getCurrentUserId() async throws -> String {
        let session = try await supabase.auth.session
        return session.user.id.uuidString
    }

    /// 日志输出
    private func log(_ message: String, level: String = "INFO") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level)] [PlayerLocation] \(message)")
    }
}
