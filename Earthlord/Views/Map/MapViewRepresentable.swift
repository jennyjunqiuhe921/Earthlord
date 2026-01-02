//
//  MapViewRepresentable.swift
//  Earthlord
//
//  MKMapView 的 SwiftUI 包装器 - 显示苹果地图并应用末世风格
//

import SwiftUI
import MapKit

/// 地图视图的 SwiftUI 包装器
/// 负责显示地图、用户位置、应用末世滤镜效果
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - Bindings

    /// 用户位置（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（防止重复居中）
    @Binding var hasLocatedUser: Bool

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

    /// 更新地图视图（空实现即可）
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 这里可以根据需要更新地图状态
        // 目前无需实现，因为位置更新由 Coordinator 处理
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
    }
}
