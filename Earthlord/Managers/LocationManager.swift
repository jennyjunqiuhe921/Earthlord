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

    // MARK: - Validation State Properties

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算得到的领地面积
    @Published var calculatedArea: Double = 0

    // MARK: - Private Properties

    /// CoreLocation 管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 路径更新定时器
    private var pathUpdateTimer: Timer?

    /// 上次位置的时间戳（用于速度计算）
    private var lastLocationTimestamp: Date?

    // MARK: - Validation Constants

    /// 闭环距离阈值（米）
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数
    private let minimumPathPoints: Int = 10

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 50.0

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
        locationManager.distanceFilter = 5  // 移动5米才更新一次

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

        // ⚠️ 重置所有验证和追踪状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
        isPathClosed = false
        pathCoordinates.removeAll()
        pathUpdateVersion = 0

        print("⏹️ 停止路径追踪，所有状态已重置")
        TerritoryLogger.shared.log("停止追踪，所有状态已重置", type: .info)
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

        // 距离超过 5 米才记录新点（过滤 GPS 抖动）
        if distance > 5 {
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

            // ⭐ 闭环成功后，立即进行领地验证
            let validationResult = validateTerritory()

            // 更新验证状态属性
            territoryValidationPassed = validationResult.isValid
            territoryValidationError = validationResult.errorMessage

            // 如果验证通过，保存计算的面积
            if validationResult.isValid {
                calculatedArea = calculatePolygonArea()
            } else {
                calculatedArea = 0
            }
        } else {
            print("⚪️ 闭环检测：距离起点 \(String(format: "%.1f", distance)) 米（需 ≤ \(closureDistanceThreshold) 米）")
            TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distance))m (需≤30m)", type: .info)
        }
    }

    // MARK: - Distance and Area Calculation (距离与面积计算)

    /// 计算路径总距离
    /// - Returns: 总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        // 遍历相邻点，累加距离
        for i in 0..<pathCoordinates.count - 1 {
            let location1 = CLLocation(latitude: pathCoordinates[i].latitude,
                                      longitude: pathCoordinates[i].longitude)
            let location2 = CLLocation(latitude: pathCoordinates[i + 1].latitude,
                                      longitude: pathCoordinates[i + 1].longitude)
            totalDistance += location1.distance(from: location2)
        }

        return totalDistance
    }

    /// 计算多边形面积（投影平面鞋带公式）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        // 对于小区域（几公里范围内），使用投影到平面的鞋带公式足够准确
        // 将经纬度转换为米制坐标（使用第一个点作为原点）
        guard let origin = pathCoordinates.first else { return 0 }

        // 计算平均纬度，用于经度到米的转换
        let avgLat = pathCoordinates.map { $0.latitude }.reduce(0, +) / Double(pathCoordinates.count)
        let metersPerDegreeLon = cos(avgLat * .pi / 180) * 111320.0  // 经度1度对应的米数
        let metersPerDegreeLat = 111320.0  // 纬度1度对应的米数（常数）

        // 计算每个点相对于原点的米制坐标
        var projectedPoints: [(x: Double, y: Double)] = []

        for coord in pathCoordinates {
            // 经度差转 x（米）
            let dx = (coord.longitude - origin.longitude) * metersPerDegreeLon

            // 纬度差转 y（米）
            let dy = (coord.latitude - origin.latitude) * metersPerDegreeLat

            projectedPoints.append((x: dx, y: dy))
        }

        // 应用标准鞋带公式：Area = |∑(x_i × y_{i+1} - x_{i+1} × y_i)| / 2
        var area: Double = 0
        for i in 0..<projectedPoints.count {
            let current = projectedPoints[i]
            let next = projectedPoints[(i + 1) % projectedPoints.count]

            area += current.x * next.y - next.x * current.y
        }

        return abs(area / 2.0)
    }

    // MARK: - Self-Intersection Detection (自相交检测)

    /// CCW 算法辅助函数：判断三点是否逆时针排列
    /// - Parameters:
    ///   - A: 第一个点
    ///   - B: 第二个点
    ///   - C: 第三个点
    /// - Returns: 叉积 > 0 为 true（逆时针）
    private func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
        // ⚠️ 坐标映射：longitude = X轴，latitude = Y轴
        // 叉积公式：(Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
        let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                          (B.latitude - A.latitude) * (C.longitude - A.longitude)
        return crossProduct > 0
    }

    /// 判断两条线段是否相交
    /// - Parameters:
    ///   - p1: 线段1的起点
    ///   - p2: 线段1的终点
    ///   - p3: 线段2的起点
    ///   - p4: 线段2的终点
    /// - Returns: true = 相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                   p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        // 使用 CCW 算法判断两线段是否相交
        // 相交条件：ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且 ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        let ccw1 = ccw(p1, p3, p4)
        let ccw2 = ccw(p2, p3, p4)
        let ccw3 = ccw(p1, p2, p3)
        let ccw4 = ccw(p1, p2, p4)

        return (ccw1 != ccw2) && (ccw3 != ccw4)
    }

    /// 检测路径是否有自相交（画"8"字形）
    /// - Returns: true = 有自交（验证失败）
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量（防止正常圈地被误判为自交）
        let skipHeadCount = 2
        let skipTailCount = 2

        // 遍历每条线段
        for i in 0..<segmentCount {
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            // 对比每条非相邻线段
            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较（防止闭环时误判）
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount

                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                // 检测线段是否相交
                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - Territory Validation (综合验证)

    /// 综合验证领地是否符合规则
    /// - Returns: (isValid: 验证是否通过, errorMessage: 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let error = "点数不足: \(pointCount)个点 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log("点数检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("点数检查: \(pointCount)个点 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let error = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(String(format: "%.0f", minimumTotalDistance))m)"
            TerritoryLogger.shared.log("距离检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let error = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, error)
        }
        // hasPathSelfIntersection 内部已经记录了日志

        // 4. 面积检查
        let area = calculatePolygonArea()
        if area < minimumEnclosedArea {
            let error = "面积不足: \(String(format: "%.0f", area))m² (需≥\(String(format: "%.0f", minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("面积检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✓", type: .info)

        // 验证通过
        TerritoryLogger.shared.log("领地验证通过！面积: \(String(format: "%.0f", area))m²", type: .success)
        return (true, nil)
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
