//
//  LocationManager.swift
//  Earthlord
//
//  GPS定位管理器 - 负责请求定位权限、获取用户位置
//

import Foundation
import CoreLocation
import Combine  // ⚠️ 必须导入：@Published 需要这个框架

/// GPS 定位管理器
/// 负责处理定位权限请求、位置更新和错误处理
class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合
    @Published var isPathClosed: Bool = false

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    // MARK: - Private Properties

    /// CoreLocation 管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 路径更新定时器
    private var pathUpdateTimer: Timer?

    /// 上次位置的时间戳（用于速度计算）
    private var lastLocationTimestamp: Date?

    // MARK: - Constants

    /// 闭环距离阈值（米）
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数
    private let minimumPathPoints: Int = 10

    // MARK: - Computed Properties

    /// 是否已授权定位
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// 是否被拒绝授权
    var isDenied: Bool {
        authorizationStatus == .denied
    }

    /// 是否未决定（首次请求）
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    // MARK: - Initialization

    override init() {
        // 初始化授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置 LocationManager
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 10  // 移动10米才更新一次

        // 如果已授权，开始定位
        if isAuthorized {
            startUpdatingLocation()
        }
    }

    // MARK: - Public Methods

    /// 请求定位权限（使用期间）
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        guard isAuthorized else {
            locationError = "未授权定位权限"
            return
        }

        locationManager.startUpdatingLocation()
        locationError = nil  // 清除之前的错误
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Path Tracking Methods

    /// 开始路径追踪
    func startPathTracking() {
        guard isAuthorized else {
            locationError = "未授权定位权限，无法开始追踪"
            return
        }

        // 清空之前的路径
        pathCoordinates.removeAll()
        pathUpdateVersion = 0
        isPathClosed = false

        // 清除速度警告
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil

        // 标记为追踪中
        isTracking = true

        // 启动定时器，每 2 秒检查一次位置
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }

        print("✅ 开始路径追踪")
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)
    }

    /// 停止路径追踪
    func stopPathTracking() {
        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 标记为未追踪
        isTracking = false

        print("⏹️ 停止路径追踪，共记录 \(pathCoordinates.count) 个点")
        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion = 0
        isPathClosed = false
        print("🗑️ 路径已清除")
    }

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        // 检查是否有当前位置
        guard let location = currentLocation else { return }

        // ⭐ 速度检测：超速时不记录该点
        if !validateMovementSpeed(newLocation: location) {
            print("⚠️ 速度超限，跳过本次记录")
            return
        }

        // 如果路径为空，直接添加第一个点
        if pathCoordinates.isEmpty {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            lastLocationTimestamp = Date()
            print("📍 记录第 1 个路径点")
            TerritoryLogger.shared.log("记录第 1 个点", type: .info)
            return
        }

        // 获取上一个点
        guard let lastCoordinate = pathCoordinates.last else { return }

        // 计算距离上一个点的距离
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = location.distance(from: lastLocation)

        // 距离超过 10 米才记录新点（过滤 GPS 抖动）
        if distance > 10 {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            lastLocationTimestamp = Date()
            print("📍 记录第 \(pathCoordinates.count) 个路径点，距离上个点 \(String(format: "%.1f", distance)) 米")
            TerritoryLogger.shared.log("记录第 \(pathCoordinates.count) 个点，距上点 \(String(format: "%.1f", distance))m", type: .info)

            // ⭐ 记录新点后检测是否闭环
            checkPathClosure()
        }
    }

    // MARK: - Path Closure Detection

    /// 检测路径是否闭环
    private func checkPathClosure() {
        // 已经闭环，不再检测
        guard !isPathClosed else { return }

        // 检查点数是否足够
        guard pathCoordinates.count >= minimumPathPoints else {
            print("⚪️ 闭环检测：点数不足（\(pathCoordinates.count)/\(minimumPathPoints)）")
            return
        }

        // 获取起点和当前位置
        guard let startPoint = pathCoordinates.first,
              let currentPoint = pathCoordinates.last else { return }

        // 计算当前位置到起点的距离
        let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
        let distance = currentLocation.distance(from: startLocation)

        // 判断是否在闭环距离阈值内
        if distance <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1  // 触发 UI 更新
            print("✅ 闭环检测成功！距离起点 \(String(format: "%.1f", distance)) 米")
            TerritoryLogger.shared.log("闭环成功！距起点 \(String(format: "%.1f", distance))m", type: .success)
        } else {
            print("⚪️ 闭环检测：距离起点 \(String(format: "%.1f", distance)) 米（需 ≤ \(closureDistanceThreshold) 米）")
            TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distance))m (需≤30m)", type: .info)
        }
    }

    // MARK: - Speed Validation

    /// 验证移动速度是否正常
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示超速
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 如果路径为空或没有上次时间戳，直接通过
        guard !pathCoordinates.isEmpty,
              let lastTimestamp = lastLocationTimestamp,
              let lastCoordinate = pathCoordinates.last else {
            return true
        }

        // 计算距离
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = newLocation.distance(from: lastLocation)

        // 计算时间差（秒）
        let timeInterval = Date().timeIntervalSince(lastTimestamp)

        // 避免除以零
        guard timeInterval > 0 else { return true }

        // 计算速度（km/h）
        let speedMps = distance / timeInterval  // 米/秒
        let speedKmh = speedMps * 3.6            // 转换为 km/h

        // 速度检测
        if speedKmh > 30 {
            // 严重超速：停止追踪
            speedWarning = "速度过快（\(String(format: "%.1f", speedKmh)) km/h），已暂停追踪"
            isOverSpeed = true
            print("🚫 严重超速（\(String(format: "%.1f", speedKmh)) km/h），已暂停追踪")
            TerritoryLogger.shared.log("超速 \(String(format: "%.1f", speedKmh)) km/h，已停止追踪", type: .error)
            stopPathTracking()
            return false
        } else if speedKmh > 15 {
            // 轻微超速：警告但继续记录
            speedWarning = "移动速度较快（\(String(format: "%.1f", speedKmh)) km/h），请步行圈地"
            isOverSpeed = true
            print("⚠️ 速度警告：\(String(format: "%.1f", speedKmh)) km/h")
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.1f", speedKmh)) km/h", type: .warning)

            // 3 秒后自动清除警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.speedWarning = nil
                self?.isOverSpeed = false
            }

            return true
        } else {
            // 速度正常（不记录日志，避免过多）
            speedWarning = nil
            isOverSpeed = false
            return true
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态改变时调用
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // 更新授权状态
        authorizationStatus = manager.authorizationStatus

        // 如果授权成功，开始定位
        if isAuthorized {
            startUpdatingLocation()
        } else if isDenied {
            locationError = "定位权限被拒绝，请在系统设置中开启"
        }
    }

    /// 位置更新时调用
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 获取最新位置
        guard let location = locations.last else { return }

        // ⭐ 更新当前位置（Timer 需要用这个）
        self.currentLocation = location

        // 更新用户位置
        userLocation = location.coordinate

        // 清除错误信息
        locationError = nil
    }

    /// 定位失败时调用
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 处理定位错误
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = "定位权限被拒绝"
            case .locationUnknown:
                locationError = "暂时无法获取位置信息"
            case .network:
                locationError = "网络错误，无法定位"
            default:
                locationError = "定位失败: \(error.localizedDescription)"
            }
        } else {
            locationError = "定位失败: \(error.localizedDescription)"
        }
    }
}
