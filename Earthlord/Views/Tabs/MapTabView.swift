//
//  MapTabView.swift
//  Earthlord
//
//  地图页面 - 显示真实地图、用户位置、领地边界
//

import SwiftUI
import CoreLocation
import Supabase

struct MapTabView: View {

    // MARK: - State Management

    /// GPS 定位管理器（从上层注入）
    @EnvironmentObject var locationManager: LocationManager

    /// 领地管理器（从上层注入）
    @EnvironmentObject var territoryManager: TerritoryManager

    /// 认证管理器（从上层注入）
    @EnvironmentObject var authManager: AuthManager

    /// 已加载的领地列表
    @State private var territories: [Territory] = []

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

    /// 上传成功/失败提示
    @State private var uploadMessage: String?
    @State private var uploadSuccess: Bool = false
    @State private var showUploadMessage: Bool = false

    /// 追踪开始时间
    @State private var trackingStartTime: Date?

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
                    isTracking: locationManager.isTracking,
                    isPathClosed: locationManager.isPathClosed,
                    territories: territories,
                    currentUserId: authManager.currentUser?.id.uuidString
                )
                .ignoresSafeArea()
                .onAppear {
                    Task {
                        await loadTerritories()
                    }
                }
            } else {
                // 未授权：显示权限请求界面
                permissionView
            }

            // 顶部工具栏
            VStack {
                topToolbar

                // 速度警告横幅
                if let warning = locationManager.speedWarning {
                    speedWarningBanner(message: warning)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 验证结果横幅
                if showValidationBanner {
                    validationResultBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 上传消息横幅
                if showUploadMessage, let message = uploadMessage {
                    uploadMessageBanner(message: message, success: uploadSuccess)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

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

                        // 确认登记按钮（仅在验证通过时显示）
                        if locationManager.territoryValidationPassed {
                            confirmRegistrationButton
                        }
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
        // 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showValidationBanner = false
                        }
                    }
                }
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
                trackingStartTime = nil
            } else {
                // 开始追踪，记录开始时间
                trackingStartTime = Date()
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

    /// 速度警告横幅
    private func speedWarningBanner(message: String) -> some View {
        HStack {
            Image(systemName: "gauge.high")
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer()
        }
        .padding()
        .background(
            // 根据是否还在追踪使用不同颜色
            (locationManager.isTracking ? Color.orange : Color.red)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        )
    }

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)
            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    /// 确认登记按钮
    private var confirmRegistrationButton: some View {
        Button {
            Task {
                await uploadCurrentTerritory()
            }
        } label: {
            HStack(spacing: 8) {
                if territoryManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                }

                Text(territoryManager.isLoading ? "上传中..." : "确认登记领地")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(territoryManager.isLoading ? Color.gray : Color.green)
                    .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
            )
        }
        .disabled(territoryManager.isLoading) // ⚠️ 上传中禁用按钮
    }

    /// 上传消息横幅
    private func uploadMessageBanner(message: String, success: Bool) -> some View {
        HStack {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .background(
            (success ? Color.green : Color.red)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        )
    }

    // MARK: - Methods

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        // ⚠️ 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            showUploadError("领地验证未通过，无法上传")
            return
        }

        // 检查是否有追踪开始时间
        guard let startTime = trackingStartTime else {
            showUploadError("缺少追踪开始时间")
            return
        }

        do {
            // 上传领地
            try await territoryManager.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startTime: startTime
            )

            // 上传成功
            showUploadSuccess("领地登记成功！")

            // ⚠️ 关键：上传成功后必须停止追踪！
            locationManager.stopPathTracking()
            trackingStartTime = nil

            // 刷新领地显示
            await loadTerritories()

        } catch {
            // 上传失败 - 不清除数据，允许用户稍后重试
            let errorDesc = error.localizedDescription

            // 判断是否为网络错误
            if errorDesc.contains("网络") || errorDesc.contains("connection") ||
               errorDesc.contains("network") || errorDesc.contains("Internet") {
                showUploadError("网络连接失败，请检查网络后点击\"上传领地\"重试")
            } else {
                showUploadError("上传失败: \(errorDesc)")
            }

            // ⚠️ 注意：不调用 stopPathTracking()，保留数据供重试使用
            TerritoryLogger.shared.log("领地数据已保留，可稍后重试", type: .info)
        }
    }

    /// 加载所有领地（静默失败，不阻塞用户操作）
    private func loadTerritories() async {
        do {
            territories = try await territoryManager.loadAllTerritories()
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
        } catch {
            // ⚠️ 静默失败：加载领地失败不影响用户继续圈地和上传
            let errorDesc = error.localizedDescription
            TerritoryLogger.shared.log("加载领地失败: \(errorDesc)", type: .error)

            // 如果是网络错误，保持现有的领地列表不变
            if errorDesc.contains("网络") || errorDesc.contains("connection") ||
               errorDesc.contains("network") || errorDesc.contains("Internet") {
                TerritoryLogger.shared.log("网络不可用，将在下次恢复时自动加载", type: .info)
            }

            // 不抛出错误，允许用户继续使用应用
        }
    }

    /// 显示上传成功消息
    private func showUploadSuccess(_ message: String) {
        uploadMessage = message
        uploadSuccess = true
        withAnimation {
            showUploadMessage = true
        }

        // 3 秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showUploadMessage = false
            }
        }
    }

    /// 显示上传失败消息
    private func showUploadError(_ message: String) {
        uploadMessage = message
        uploadSuccess = false
        withAnimation {
            showUploadMessage = true
        }

        // 5 秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
                showUploadMessage = false
            }
        }
    }
}

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
        .environmentObject(TerritoryManager())
        .environmentObject(AuthManager())
}
