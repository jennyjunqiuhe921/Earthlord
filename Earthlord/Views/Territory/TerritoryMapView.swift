//
//  TerritoryMapView.swift
//  Earthlord
//
//  领地地图组件 - 使用 UIKit MKMapView 显示领地边界和建筑
//

import SwiftUI
import MapKit

/// 领地地图视图
struct TerritoryMapView: UIViewRepresentable {

    // MARK: - Properties

    /// 领地数据
    let territory: Territory

    /// 已有建筑列表
    let buildings: [PlayerBuilding]

    /// 建筑模板字典
    let buildingTemplates: [String: BuildingTemplate]

    // MARK: - Computed Properties

    /// 领地坐标（转换为 GCJ-02）
    private var territoryCoordinates: [CLLocationCoordinate2D] {
        let coords = territory.toCoordinates()
        return CoordinateConverter.wgs84ToGcj02(coords)
    }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false

        // 添加领地多边形
        if territoryCoordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: territoryCoordinates, count: territoryCoordinates.count)
            polygon.title = "territory"
            mapView.addOverlay(polygon)

            // 设置地图区域
            let region = calculateRegion(for: territoryCoordinates)
            mapView.setRegion(region, animated: false)
        }

        // 添加建筑标记
        addBuildingAnnotations(to: mapView)

        // 应用末世滤镜
        applyApocalypseFilter(to: mapView)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 更新建筑标记
        updateBuildingAnnotations(on: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Private Methods

    /// 计算领地区域
    private func calculateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 1.5
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    /// 添加建筑标记
    private func addBuildingAnnotations(to mapView: MKMapView) {
        for building in buildings {
            guard let coord = building.coordinate else { continue }
            let template = buildingTemplates[building.templateId]
            let annotation = TerritoryBuildingAnnotation(
                building: building,
                template: template,
                coordinate: coord
            )
            mapView.addAnnotation(annotation)
        }
    }

    /// 更新建筑标记
    private func updateBuildingAnnotations(on mapView: MKMapView) {
        // 移除旧标记
        let existingAnnotations = mapView.annotations.compactMap { $0 as? TerritoryBuildingAnnotation }
        mapView.removeAnnotations(existingAnnotations)

        // 添加新标记
        addBuildingAnnotations(to: mapView)
    }

    /// 应用末世滤镜
    private func applyApocalypseFilter(to mapView: MKMapView) {
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(-0.15, forKey: kCIInputBrightnessKey)
        colorControls?.setValue(0.5, forKey: kCIInputSaturationKey)

        let sepiaFilter = CIFilter(name: "CISepiaTone")
        sepiaFilter?.setValue(0.65, forKey: kCIInputIntensityKey)

        if let colorControls = colorControls, let sepiaFilter = sepiaFilter {
            mapView.layer.filters = [colorControls, sepiaFilter]
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: TerritoryMapView

        init(_ parent: TerritoryMapView) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                if polygon.title == "territory" {
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 3
                }

                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 不处理用户位置
            if annotation is MKUserLocation {
                return nil
            }

            // 建筑标记
            if let buildingAnnotation = annotation as? TerritoryBuildingAnnotation {
                let identifier = "TerritoryBuildingAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = annotation
                }

                view?.image = createBuildingMarkerImage(for: buildingAnnotation)
                view?.centerOffset = CGPoint(x: 0, y: -15)

                return view
            }

            return nil
        }

        // MARK: - Image Creation

        private func createBuildingMarkerImage(for annotation: TerritoryBuildingAnnotation) -> UIImage {
            let size = CGSize(width: 36, height: 36)
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { context in
                let rect = CGRect(origin: .zero, size: size)

                // 根据建筑状态和分类设置颜色
                let color: UIColor
                if annotation.building.status == .constructing {
                    color = .systemYellow
                } else {
                    switch annotation.template?.category {
                    case .survival:
                        color = .systemOrange
                    case .storage:
                        color = .systemBlue
                    case .production:
                        color = .systemGreen
                    case .energy:
                        color = .systemYellow
                    case .none:
                        color = .systemGray
                    }
                }

                // 背景圆
                color.withAlphaComponent(0.9).setFill()
                let circlePath = UIBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
                circlePath.fill()

                // 白色边框
                UIColor.white.setStroke()
                circlePath.lineWidth = 2
                circlePath.stroke()

                // 图标
                let iconName = annotation.template?.iconName ?? "building.fill"
                if let iconImage = UIImage(systemName: iconName)?
                    .withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
                    .withTintColor(.white, renderingMode: .alwaysOriginal) {

                    let iconSize = iconImage.size
                    let iconRect = CGRect(
                        x: (size.width - iconSize.width) / 2,
                        y: (size.height - iconSize.height) / 2,
                        width: iconSize.width,
                        height: iconSize.height
                    )
                    iconImage.draw(in: iconRect)
                }

                // 建造中标记
                if annotation.building.status == .constructing {
                    UIColor.white.setFill()
                    let indicatorRect = CGRect(x: size.width - 10, y: 0, width: 10, height: 10)
                    let indicatorPath = UIBezierPath(ovalIn: indicatorRect)
                    indicatorPath.fill()

                    UIColor.systemYellow.setFill()
                    let innerRect = indicatorRect.insetBy(dx: 2, dy: 2)
                    let innerPath = UIBezierPath(ovalIn: innerRect)
                    innerPath.fill()
                }
            }
        }
    }
}

// MARK: - Territory Building Annotation

/// 领地建筑标记
class TerritoryBuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    let template: BuildingTemplate?
    var coordinate: CLLocationCoordinate2D

    var title: String? {
        building.buildingName
    }

    var subtitle: String? {
        if building.status == .constructing {
            return "建造中"
        }
        return template?.category.displayName
    }

    init(building: PlayerBuilding, template: BuildingTemplate?, coordinate: CLLocationCoordinate2D) {
        self.building = building
        self.template = template
        self.coordinate = coordinate
        super.init()
    }
}
