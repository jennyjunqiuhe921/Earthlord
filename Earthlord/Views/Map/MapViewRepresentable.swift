//
//  MapViewRepresentable.swift
//  Earthlord
//
//  MKMapView 的 SwiftUI 包装器 - 显示苹果地图并应用末世风格
//

import SwiftUI
import MapKit

/// 地图视图的 SwiftUI 包装器
/// 负责显示地图、用户位置、应用末世滤镜效果、绘制追踪轨迹
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - Bindings

    /// 用户位置（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（防止重复居中）
    @Binding var hasLocatedUser: Bool

    /// 追踪路径坐标数组（双向绑定）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    // MARK: - Properties

    /// 路径更新版本号（触发重绘）
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    /// 路径是否闭合
    var isPathClosed: Bool

    /// 已加载的领地列表
    var territories: [Territory]

    /// 当前用户 ID
    var currentUserId: String?

    // MARK: - UIViewRepresentable Methods

    /// 创建地图视图
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 基础配置
        mapView.mapType = .hybrid                       // 卫星图+道路标签（末世废土风格）
        mapView.pointOfInterestFilter = .excludingAll   // ⭐ 隐藏所有POI（商店、餐厅等）
        mapView.showsBuildings = false                  // 隐藏3D建筑
        mapView.showsUserLocation = true                // ⭐ 显示用户位置蓝点（必须设置！）

        // 交互配置
        mapView.isZoomEnabled = true                    // 允许双指缩放
        mapView.isScrollEnabled = true                  // 允许单指拖动
        mapView.isRotateEnabled = true                  // 允许双指旋转
        mapView.isPitchEnabled = false                  // 禁用倾斜（保持2D视角）

        // ⭐ 设置代理（关键！否则 didUpdate userLocation 不会被调用）
        mapView.delegate = context.coordinator

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        return mapView
    }

    /// 更新地图视图
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 更新追踪路径
        context.coordinator.updateTrackingPath(on: uiView, path: trackingPath)

        // 更新领地显示
        context.coordinator.drawTerritories(on: uiView, territories: territories, currentUserId: currentUserId)
    }

    /// 创建协调器（负责处理地图回调）
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Private Methods

    /// 应用末世滤镜效果（废土泛黄风格）
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(-0.15, forKey: kCIInputBrightnessKey)  // 稍微变暗
        colorControls?.setValue(0.5, forKey: kCIInputSaturationKey)    // 降低饱和度

        // 棕褐色调：废土的泛黄效果
        let sepiaFilter = CIFilter(name: "CISepiaTone")
        sepiaFilter?.setValue(0.65, forKey: kCIInputIntensityKey)      // 黄色强度

        // 应用滤镜到地图图层
        if let colorControls = colorControls, let sepiaFilter = sepiaFilter {
            mapView.layer.filters = [colorControls, sepiaFilter]
        }
    }

    // MARK: - Coordinator Class

    /// 协调器 - 处理地图代理回调
    class Coordinator: NSObject, MKMapViewDelegate {

        // MARK: - Properties

        var parent: MapViewRepresentable

        /// 是否已完成首次居中（防止重复居中）
        private var hasInitialCentered = false

        // MARK: - Initialization

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate Methods

        /// ⭐⭐⭐ 关键方法：用户位置更新时调用
        /// 这是实现地图自动居中的核心方法
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置
            guard let location = userLocation.location else { return }

            // 更新绑定的位置（同步到外部）
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            // 如果已经居中过，不再重复居中（允许用户手动拖动地图）
            guard !hasInitialCentered else { return }

            // 创建居中区域（约1公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,   // 南北跨度 1 公里
                longitudinalMeters: 1000   // 东西跨度 1 公里
            )

            // ⭐ 平滑居中地图（animated: true 实现平滑过渡）
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }

            print("✅ 地图已居中到用户位置: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        }

        /// 地图区域改变完成时调用
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可用于检测用户手动拖动地图
            // 目前无需实现
        }

        /// 地图加载完成时调用
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            print("✅ 地图加载完成")
        }

        // MARK: - Territory Drawing Methods

        /// 绘制所有领地
        func drawTerritories(on mapView: MKMapView, territories: [Territory], currentUserId: String?) {
            // 移除旧的领地多边形（保留路径轨迹）
            let territoryOverlays = mapView.overlays.filter { overlay in
                if let polygon = overlay as? MKPolygon {
                    return polygon.title == "mine" || polygon.title == "others"
                }
                return false
            }
            mapView.removeOverlays(territoryOverlays)

            // 绘制每个领地
            for territory in territories {
                var coords = territory.toCoordinates()

                // ⚠️ 中国大陆需要坐标转换 WGS-84 → GCJ-02
                coords = CoordinateConverter.wgs84ToGcj02(coords)

                guard coords.count >= 3 else { continue }

                let polygon = MKPolygon(coordinates: coords, count: coords.count)

                // ⚠️ 关键：比较 userId 时必须统一大小写！
                // 数据库存的是小写 UUID，但 iOS 的 uuidString 返回大写
                // 如果不转换，会导致自己的领地显示为橙色
                let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
                polygon.title = isMine ? "mine" : "others"

                mapView.addOverlay(polygon, level: .aboveRoads)
            }
        }

        // MARK: - Path Tracking Methods

        /// 更新追踪路径
        func updateTrackingPath(on mapView: MKMapView, path: [CLLocationCoordinate2D]) {
            // 移除旧的覆盖层（轨迹线和多边形）
            mapView.removeOverlays(mapView.overlays)

            // 如果路径为空或只有一个点，不绘制
            guard path.count >= 2 else { return }

            // ⭐ 坐标转换：WGS-84 → GCJ-02（解决中国地图偏移问题）
            let convertedPath = CoordinateConverter.wgs84ToGcj02(path)

            // 创建并添加轨迹线
            let polyline = MKPolyline(coordinates: convertedPath, count: convertedPath.count)
            mapView.addOverlay(polyline)

            // ⭐ 如果路径已闭合且点数 ≥ 3，添加多边形填充
            if parent.isPathClosed && convertedPath.count >= 3 {
                let polygon = MKPolygon(coordinates: convertedPath, count: convertedPath.count)
                mapView.addOverlay(polygon)
                print("🎨 更新轨迹：\(path.count) 个点（已闭合，添加多边形填充）")
            } else {
                print("🎨 更新轨迹：\(path.count) 个点")
            }
        }

        /// ⭐⭐⭐ 关键方法：提供覆盖层渲染器（必须实现，否则轨迹不显示！）
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 处理轨迹线
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // ⭐ 根据是否闭环设置颜色
                if parent.isPathClosed {
                    renderer.strokeColor = UIColor.systemGreen  // 闭环：绿色
                } else {
                    renderer.strokeColor = UIColor.systemCyan   // 未闭环：青色
                }

                renderer.lineWidth = 5                       // 线宽 5pt
                renderer.lineCap = .round                    // 圆头线条
                renderer.lineJoin = .round                   // 圆角转折
                return renderer
            }

            // ⭐ 处理多边形填充
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 根据 title 区分领地类型
                if polygon.title == "mine" {
                    // 我的领地：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                } else if polygon.title == "others" {
                    // 他人领地：橙色
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                } else {
                    // 追踪中的多边形（无 title）：默认绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                }

                renderer.lineWidth = 2.0
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
