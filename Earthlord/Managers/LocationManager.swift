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

    // MARK: - Private Properties

    /// CoreLocation 管理器
    private let locationManager = CLLocationManager()

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
