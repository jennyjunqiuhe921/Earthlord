//
//  MapTabView.swift
//  Earthlord
//
//  地图页面 - 显示真实地图、用户位置、领地边界
//

import SwiftUI
import CoreLocation

struct MapTabView: View {

    // MARK: - State Management

    /// GPS 定位管理器
    @StateObject private var locationManager = LocationManager()

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            // 地图层
            if locationManager.isAuthorized {
                // 已授权：显示地图
                MapViewRepresentable(
                    userLocation: $locationManager.userLocation,
                    hasLocatedUser: $hasLocatedUser,
                    trackingPath: $locationManager.pathCoordinates,
                    pathUpdateVersion: locationManager.pathUpdateVersion,
                    isTracking: locationManager.isTracking
                )
                .ignoresSafeArea()
            } else {
                // 未授权：显示权限请求界面
                permissionView
            }

            // 顶部工具栏
            VStack {
                topToolbar
                Spacer()
            }

            // 右下角按钮组
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // 定位按钮
                        locationButton

                        // 圈地按钮
                        claimButton
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }

            // 错误提示（如果有）
            if let error = locationManager.locationError {
                VStack {
                    Spacer()
                    errorBanner(message: error)
                        .padding(.bottom, 80)
                }
            }
        }
        .onAppear {
            // 页面出现时检查权限
            if locationManager.isNotDetermined {
                // 首次使用，请求权限
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                // 已授权，开始定位
                locationManager.startUpdatingLocation()
            }
        }
    }

    // MARK: - Subviews

    /// 顶部工具栏
    private var topToolbar: some View {
        HStack {
            // 标题
            VStack(alignment: .leading, spacing: 4) {
                Text("地图")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let location = locationManager.userLocation {
                    // 显示当前坐标
                    Text("坐标: \(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude))")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else {
                    Text("定位中...")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()
        }
        .padding()
        .background(
            ApocalypseTheme.cardBackground.opacity(0.95)
                .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        )
    }

    /// 右下角定位按钮
    private var locationButton: some View {
        Button {
            // 居中到用户位置
            if locationManager.isAuthorized {
                // 重新触发居中
                hasLocatedUser = false
                locationManager.startUpdatingLocation()
            } else {
                // 请求权限
                locationManager.requestPermission()
            }
        } label: {
            Image(systemName: locationManager.userLocation != nil ? "location.fill" : "location")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(ApocalypseTheme.primary)
                        .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
                )
        }
    }

    /// 圈地按钮（开始/停止追踪）
    private var claimButton: some View {
        Button {
            if locationManager.isTracking {
                // 停止追踪
                locationManager.stopPathTracking()
            } else {
                // 开始追踪
                locationManager.startPathTracking()
            }
        } label: {
            HStack(spacing: 8) {
                // 图标
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 16))

                // 文字
                Text(locationManager.isTracking ? "停止圈地" : "开始圈地")
                    .font(.system(size: 15, weight: .semibold))

                // 追踪中显示点数
                if locationManager.isTracking {
                    Text("(\(locationManager.pathCoordinates.count))")
                        .font(.system(size: 13))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(locationManager.isTracking ? Color.red : ApocalypseTheme.primary)
                    .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
            )
        }
    }

    /// 权限请求界面
    private var permissionView: some View {
        VStack(spacing: 30) {
            Spacer()

            // 图标
            Image(systemName: "location.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(ApocalypseTheme.primary)

            // 标题
            Text("需要定位权限")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 说明
            Text("《地球新主》需要获取您的位置\n来显示您在末日世界中的坐标\n帮助您探索和圈定领地")
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)

            // 按钮组
            VStack(spacing: 15) {
                if locationManager.isNotDetermined {
                    // 首次请求：显示"允许定位"按钮
                    Button {
                        locationManager.requestPermission()
                    } label: {
                        Text("允许定位")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(12)
                    }
                } else if locationManager.isDenied {
                    // 已拒绝：显示"前往设置"按钮
                    Button {
                        // 打开系统设置
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("前往设置")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    /// 错误横幅
    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(ApocalypseTheme.warning)

            Text(message)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 如果是权限错误，显示"设置"按钮
            if locationManager.isDenied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("设置")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .padding()
        .background(
            ApocalypseTheme.cardBackground
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
        )
        .padding(.horizontal)
    }
}

#Preview {
    MapTabView()
}
