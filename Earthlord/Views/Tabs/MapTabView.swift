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

    /// 探索管理器（从上层注入）
    @EnvironmentObject var explorationManager: ExplorationManager

    /// 背包管理器（从上层注入）
    @EnvironmentObject var inventoryManager: InventoryManager

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

    // MARK: - Day 19: 碰撞检测状态
    @State private var collisionCheckTimer: Timer?
    @State private var collisionWarning: String?
    @State private var showCollisionWarning = false
    @State private var collisionWarningLevel: WarningLevel = .safe

    // MARK: - 探索功能状态（已移至 ExplorationManager）
    // 旧代码已删除，使用 explorationManager.state 代替

    // MARK: - Computed Properties

    /// 当前用户 ID
    private var currentUserId: String? {
        authManager.currentUser?.id.uuidString
    }

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
                    currentUserId: authManager.currentUser?.id.uuidString,
                    nearbyPOIs: explorationManager.nearbyPOIs
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

                // 速度警告横幅（圈地功能）
                if let warning = locationManager.speedWarning {
                    speedWarningBanner(message: warning)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 探索超速警告横幅
                if explorationManager.isOverSpeed {
                    explorationSpeedWarningBanner
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 探索失败横幅
                if explorationManager.state == .failed, let reason = explorationManager.failureReason {
                    explorationFailedBanner(reason: reason)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 探索错误消息横幅
                if let errorMsg = explorationManager.errorMessage {
                    explorationErrorBanner(message: errorMsg)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            // 5秒后自动清除错误消息
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                explorationManager.errorMessage = nil
                            }
                        }
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

                // Day 19: 碰撞警告横幅（分级颜色）
                if showCollisionWarning, let warning = collisionWarning {
                    collisionWarningBanner(message: warning, level: collisionWarningLevel)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }

            // 右下角按钮组
            VStack {
                Spacer()

                // 底部按钮组 - 水平排列
                HStack(spacing: 12) {
                    // 左侧：圈地按钮
                    claimButton

                    // 中间：定位按钮
                    locationButton

                    // 右侧：探索按钮
                    exploreButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                // 确认登记按钮（仅在验证通过时显示）
                if locationManager.territoryValidationPassed {
                    confirmRegistrationButton
                        .padding(.horizontal, 20)
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
        // 探索结果弹窗
        .sheet(isPresented: $explorationManager.showResult) {
            if let result = explorationManager.explorationResult {
                ExplorationResultView(result: result)
                    .environmentObject(inventoryManager)
                    .onDisappear {
                        // 关闭弹窗后重置状态
                        explorationManager.resetState()
                    }
            }
        }
        // POI 接近弹窗（从底部滑出）
        .overlay(alignment: .bottom) {
            Group {
                if explorationManager.showPOIPopup, let poi = explorationManager.currentPOI {
                    POIProximityPopup(
                        poi: poi,
                        distance: explorationManager.currentPOIDistance,
                        onScavenge: {
                            Task {
                                await explorationManager.scavengePOI()
                            }
                        },
                        onDismiss: {
                            explorationManager.dismissPOIPopup()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: explorationManager.showPOIPopup)
        }
        // 搜刮结果弹窗（全屏）- 使用 item 绑定确保有效数据时才显示
        .fullScreenCover(item: $explorationManager.scavengedPOI) { poi in
            ScavengeResultView(
                poi: poi,
                items: explorationManager.scavengeItems,
                onDismiss: {
                    explorationManager.dismissScavengeResult()
                }
            )
            .environmentObject(explorationManager)
            .environmentObject(inventoryManager)
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

            // 测试按钮（仅在探索状态下显示）
            if explorationManager.state == .exploring || explorationManager.state == .speedWarning {
                Button {
                    // 直接触发测试 POI 弹窗
                    explorationManager.triggerTestPOIPopup(type: .hospital, dangerLevel: 4)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "flask.fill")
                            .font(.system(size: 14))
                        Text("测试")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.purple)
                    )
                }
            }
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

    /// 探索按钮
    private var exploreButton: some View {
        Button {
            handleExplore()
        } label: {
            HStack(spacing: 8) {
                switch explorationManager.state {
                case .idle:
                    // 空闲状态：显示探索按钮
                    Image(systemName: "binoculars.fill")
                        .font(.system(size: 16))
                    Text("探索")
                        .font(.system(size: 15, weight: .semibold))

                case .exploring:
                    // 探索中：显示实时数据
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 12))
                            Text(formatDistance(explorationManager.currentDistance))
                                .font(.system(size: 13, weight: .medium))
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 11))
                            Text(String(format: "%.1f km/h", explorationManager.currentSpeed))
                                .font(.system(size: 12))
                        }
                    }
                    Text("结束")
                        .font(.system(size: 14, weight: .bold))

                case .speedWarning:
                    // 超速警告状态：显示倒计时
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text("超速!")
                                .font(.system(size: 13, weight: .bold))
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.system(size: 11))
                            Text("\(explorationManager.speedWarningCountdown)秒")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    Text("结束")
                        .font(.system(size: 14, weight: .bold))

                case .processing:
                    // 处理中：显示加载
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("计算中...")
                        .font(.system(size: 14, weight: .semibold))

                case .completed:
                    // 完成状态
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                    Text("完成")
                        .font(.system(size: 15, weight: .semibold))

                case .failed:
                    // 失败状态
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                    Text("重新探索")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(exploreButtonColor)
                    .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
            )
        }
        .disabled(explorationManager.state == .processing)
    }

    /// 探索按钮颜色
    private var exploreButtonColor: Color {
        switch explorationManager.state {
        case .idle:
            return ApocalypseTheme.primary
        case .exploring:
            return Color.green
        case .speedWarning:
            return Color.red
        case .processing:
            return Color.gray
        case .completed:
            return Color.green
        case .failed:
            return Color.orange
        }
    }

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0fm", meters)
        } else {
            return String(format: "%.2fkm", meters / 1000)
        }
    }

    /// 格式化时长
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// 圈地按钮（开始/停止追踪）
    private var claimButton: some View {
        Button {
            if locationManager.isTracking {
                // 停止追踪
                stopCollisionMonitoring()
                locationManager.stopPathTracking()
                trackingStartTime = nil
            } else {
                // Day 19: 开始圈地前检测起始点
                startClaimingWithCollisionCheck()
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

    /// Day 19: 碰撞警告横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return HStack {
            Image(systemName: iconName)
                .font(.system(size: 18))

            Text(message)
                .font(.system(size: 14, weight: .medium))

            Spacer()
        }
        .foregroundColor(textColor)
        .padding()
        .background(
            backgroundColor.opacity(0.95)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        )
    }

    // MARK: - Methods

    /// 处理探索按钮点击
    private func handleExplore() {
        switch explorationManager.state {
        case .idle, .failed:
            // 开始探索（从空闲或失败状态）
            explorationManager.startExploration()
        case .exploring, .speedWarning:
            // 结束探索（正常结束或超速警告时主动结束）
            Task {
                await explorationManager.stopExploration()
            }
        case .completed:
            // 重置状态（关闭结果后再次点击）
            explorationManager.resetState()
        case .processing:
            // 处理中，不做任何操作
            break
        }
    }

    /// 探索超速警告横幅
    private var explorationSpeedWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text("速度过快!")
                    .font(.system(size: 15, weight: .bold))
                Text("当前速度 \(String(format: "%.1f", explorationManager.currentSpeed)) km/h，超过 30 km/h 限制")
                    .font(.system(size: 13))
                if explorationManager.speedWarningCountdown > 0 {
                    Text("请在 \(explorationManager.speedWarningCountdown) 秒内减速，否则探索将失败")
                        .font(.system(size: 12, weight: .medium))
                }
            }

            Spacer()
        }
        .foregroundColor(.white)
        .padding()
        .background(
            Color.red
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        )
    }

    /// 探索错误消息横幅
    private func explorationErrorBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20))

            Text(message)
                .font(.system(size: 14, weight: .medium))

            Spacer()

            Button {
                explorationManager.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .foregroundColor(.white)
        .padding()
        .background(
            Color.red.opacity(0.9)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        )
    }

    /// 探索失败横幅
    private func explorationFailedBanner(reason: ExplorationFailureReason) -> some View {
        let message: String
        let icon: String

        switch reason {
        case .speedExceeded:
            message = "探索失败：移动速度超过限制"
            icon = "speedometer"
        case .gpsError:
            message = "探索失败：GPS信号丢失"
            icon = "location.slash.fill"
        case .userCancelled:
            message = "探索已取消"
            icon = "xmark.circle.fill"
        }

        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.system(size: 15, weight: .bold))
                Text("已行走 \(formatDistance(explorationManager.currentDistance))，点击按钮重新开始")
                    .font(.system(size: 13))
            }

            Spacer()

            Button {
                explorationManager.resetState()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .foregroundColor(.white)
        .padding()
        .background(
            Color.orange
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        )
    }

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
            stopCollisionMonitoring()  // Day 19: 停止碰撞监控
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

    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let userId = currentUserId else {
            return
        }

        // 检测起始点是否在他人领地内
        let result = territoryManager.checkPointCollision(
            location: location,
            currentUserId: userId
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

            return
        }

        // 起点安全，开始圈地
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        trackingStartTime = Date()
        locationManager.startPathTracking()
        startCollisionMonitoring()
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
            performCollisionCheck()
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
        TerritoryLogger.shared.log("碰撞检测定时器已停止", type: .info)
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = currentUserId else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = territoryManager.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 【关键修复】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 2. 触发震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()
            trackingStartTime = nil

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        // 添加调试日志
        print("🔔 触发震动 - 级别: \(level)")
        TerritoryLogger.shared.log("触发震动反馈 - 级别: \(level.rawValue)", type: .info)

        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.triggerHapticFeedback(level: level)
            }
            return
        }

        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次 - 使用通知反馈
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            // 延迟一小段时间以确保 prepare 完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                generator.notificationOccurred(.warning)
                print("✅ 执行了 caution 震动")
            }

        case .warning:
            // 警告：中震 2 次 - 使用撞击反馈
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()

            // 使用 withExtendedLifetime 确保 generator 不会被释放
            withExtendedLifetime(generator) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    generator.impactOccurred()
                    print("✅ 执行了 warning 震动 1/2")

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        generator.impactOccurred()
                        print("✅ 执行了 warning 震动 2/2")
                    }
                }
            }

        case .danger:
            // 危险：强震 3 次 - 使用重度撞击反馈
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()

            // 使用 withExtendedLifetime 确保 generator 不会被释放
            withExtendedLifetime(generator) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    generator.impactOccurred()
                    print("✅ 执行了 danger 震动 1/3")

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        generator.impactOccurred()
                        print("✅ 执行了 danger 震动 2/3")
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        generator.impactOccurred()
                        print("✅ 执行了 danger 震动 3/3")
                    }
                }
            }

        case .violation:
            // 违规：错误震动 - 使用通知反馈
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                generator.notificationOccurred(.error)
                print("✅ 执行了 violation 震动")
            }
        }
    }
}

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
        .environmentObject(TerritoryManager())
        .environmentObject(AuthManager())
        .environmentObject(ExplorationManager())
        .environmentObject(InventoryManager())
}
