//
//  BuildingLocationPickerView.swift
//  Earthlord
//
//  地图位置选择器 - 使用 UIKit MKMapView + MKPolygon
//

import SwiftUI
import MapKit

/// 建筑位置选择器
struct BuildingLocationPickerView: UIViewRepresentable {

    // MARK: - Properties

    /// 领地边界坐标（已转换为 GCJ-02）
    let territoryCoordinates: [CLLocationCoordinate2D]

    /// 已有建筑列表
    let existingBuildings: [PlayerBuilding]

    /// 建筑模板字典
    let buildingTemplates: [String: BuildingTemplate]

    /// 选中的坐标
    @Binding var selectedCoordinate: CLLocationCoordinate2D?

    /// 选择位置回调
    var onSelectLocation: ((CLLocationCoordinate2D) -> Void)?

    /// 取消回调
    var onCancel: (() -> Void)?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true

        // 添加领地多边形
        if territoryCoordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: territoryCoordinates, count: territoryCoordinates.count)
            polygon.title = "territory"
            mapView.addOverlay(polygon)

            // 设置地图区域为领地范围
            let region = calculateRegion(for: territoryCoordinates)
            mapView.setRegion(region, animated: false)
        }

        // 添加已有建筑标记
        addExistingBuildingAnnotations(to: mapView)

        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        // 应用末世滤镜
        applyApocalypseFilter(to: mapView)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 更新选中位置标记
        context.coordinator.updateSelectedAnnotation(on: uiView, coordinate: selectedCoordinate)
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

    /// 添加已有建筑标记
    private func addExistingBuildingAnnotations(to mapView: MKMapView) {
        for building in existingBuildings {
            guard let coord = building.coordinate else { continue }
            let template = buildingTemplates[building.templateId]
            let annotation = BuildingAnnotation(
                building: building,
                template: template,
                coordinate: coord
            )
            mapView.addAnnotation(annotation)
        }
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

        var parent: BuildingLocationPickerView
        private var selectedAnnotation: MKPointAnnotation?

        init(_ parent: BuildingLocationPickerView) {
            self.parent = parent
        }

        // MARK: - Gesture Handling

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // 检查点是否在领地范围内
            if isPointInPolygon(coordinate, polygon: parent.territoryCoordinates) {
                parent.selectedCoordinate = coordinate
                parent.onSelectLocation?(coordinate)
            }
        }

        /// 射线法判断点是否在多边形内
        private func isPointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
            guard polygon.count >= 3 else { return false }

            var inside = false
            let x = point.longitude
            let y = point.latitude

            var j = polygon.count - 1
            for i in 0..<polygon.count {
                let xi = polygon[i].longitude
                let yi = polygon[i].latitude
                let xj = polygon[j].longitude
                let yj = polygon[j].latitude

                let intersect = ((yi > y) != (yj > y)) &&
                               (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

                if intersect {
                    inside.toggle()
                }
                j = i
            }

            return inside
        }

        // MARK: - Annotation Management

        func updateSelectedAnnotation(on mapView: MKMapView, coordinate: CLLocationCoordinate2D?) {
            // 移除旧的选中标记
            if let oldAnnotation = selectedAnnotation {
                mapView.removeAnnotation(oldAnnotation)
            }

            // 添加新的选中标记
            if let coord = coordinate {
                let annotation = MKPointAnnotation()
                annotation.coordinate = coord
                annotation.title = "建造位置"
                mapView.addAnnotation(annotation)
                selectedAnnotation = annotation
            }
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                if polygon.title == "territory" {
                    // 领地边界
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.15)
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

            // 选中位置标记
            if annotation is MKPointAnnotation {
                let identifier = "SelectedLocation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = annotation
                }

                // 使用自定义图标
                view?.image = createSelectedLocationImage()
                view?.centerOffset = CGPoint(x: 0, y: -20)

                return view
            }

            // 建筑标记
            if let buildingAnnotation = annotation as? BuildingAnnotation {
                let identifier = "BuildingAnnotation"
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

        private func createSelectedLocationImage() -> UIImage {
            let size = CGSize(width: 40, height: 40)
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { context in
                // 绘制十字准心
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius: CGFloat = 15

                // 外圈
                UIColor.systemOrange.setStroke()
                let circlePath = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                circlePath.lineWidth = 3
                circlePath.stroke()

                // 中心点
                UIColor.systemOrange.setFill()
                let dotPath = UIBezierPath(arcCenter: center, radius: 4, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                dotPath.fill()

                // 十字线
                UIColor.systemOrange.setStroke()
                let crossPath = UIBezierPath()
                crossPath.move(to: CGPoint(x: center.x - radius - 5, y: center.y))
                crossPath.addLine(to: CGPoint(x: center.x - 6, y: center.y))
                crossPath.move(to: CGPoint(x: center.x + 6, y: center.y))
                crossPath.addLine(to: CGPoint(x: center.x + radius + 5, y: center.y))
                crossPath.move(to: CGPoint(x: center.x, y: center.y - radius - 5))
                crossPath.addLine(to: CGPoint(x: center.x, y: center.y - 6))
                crossPath.move(to: CGPoint(x: center.x, y: center.y + 6))
                crossPath.addLine(to: CGPoint(x: center.x, y: center.y + radius + 5))
                crossPath.lineWidth = 2
                crossPath.stroke()
            }
        }

        private func createBuildingMarkerImage(for annotation: BuildingAnnotation) -> UIImage {
            let size = CGSize(width: 32, height: 32)
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { context in
                let rect = CGRect(origin: .zero, size: size)

                // 背景圆
                UIColor.systemBlue.withAlphaComponent(0.8).setFill()
                let circlePath = UIBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
                circlePath.fill()

                // 白色边框
                UIColor.white.setStroke()
                circlePath.lineWidth = 2
                circlePath.stroke()

                // 图标
                let iconName = annotation.template?.iconName ?? "building.fill"
                if let iconImage = UIImage(systemName: iconName)?
                    .withConfiguration(UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
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
            }
        }
    }
}

// MARK: - Building Annotation

/// 建筑标记
class BuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    let template: BuildingTemplate?
    var coordinate: CLLocationCoordinate2D

    var title: String? {
        building.buildingName
    }

    var subtitle: String? {
        template?.category.displayName
    }

    init(building: PlayerBuilding, template: BuildingTemplate?, coordinate: CLLocationCoordinate2D) {
        self.building = building
        self.template = template
        self.coordinate = coordinate
        super.init()
    }
}
