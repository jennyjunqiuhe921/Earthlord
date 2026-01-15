//
//  POISearchManager.swift
//  Earthlord
//
//  Created by Claude on 2026-01-13.
//
//  封装 MapKit MKLocalSearch，搜索附近真实 POI
//

import Foundation
import MapKit
import CoreLocation

// POI 和 POIType 定义在 ExplorationModels.swift 中

/// POI 搜索管理器
/// 负责使用 MapKit 搜索附近的真实地点并转换为游戏 POI 模型
class POISearchManager {

    // MARK: - Singleton

    static let shared = POISearchManager()

    private init() {}

    // MARK: - Constants

    /// 默认搜索半径（米）
    private let defaultRadius: CLLocationDistance = 1000

    /// 每种类型最多返回的结果数
    private let maxResultsPerCategory = 5

    /// 搜索的 POI 类型（使用关键词搜索，兼容中国大陆）
    private let searchKeywords: [(keyword: String, gameType: POIType)] = [
        ("超市", .supermarket),
        ("便利店", .supermarket),
        ("医院", .hospital),
        ("药店", .pharmacy),
        ("药房", .pharmacy),
        ("加油站", .gasStation),
        ("餐厅", .restaurant),
        ("餐馆", .restaurant),
        ("咖啡", .restaurant)
    ]

    // MARK: - Public Methods

    /// 搜索附近 POI
    /// - Parameters:
    ///   - center: 搜索中心点坐标
    ///   - radius: 搜索半径（米），默认 1000 米
    ///   - maxResults: 最大返回数量，默认 20（iOS 围栏限制）
    /// - Returns: 搜索到的 POI 列表
    func searchNearbyPOIs(center: CLLocationCoordinate2D, radius: CLLocationDistance? = nil, maxResults: Int? = nil) async -> [POI] {
        let searchRadius = radius ?? defaultRadius
        let resultLimit = maxResults ?? 20

        log("开始搜索 POI，中心: (\(String(format: "%.4f", center.latitude)), \(String(format: "%.4f", center.longitude)))，半径: \(searchRadius)m，上限: \(resultLimit)")

        var allPOIs: [POI] = []
        var seenPlacemarks: Set<String> = [] // 用于去重

        // 并发搜索所有关键词
        await withTaskGroup(of: [POI].self) { group in
            for (keyword, gameType) in searchKeywords {
                group.addTask {
                    await self.searchByKeyword(keyword: keyword, gameType: gameType, center: center, radius: searchRadius)
                }
            }

            for await pois in group {
                for poi in pois {
                    // 去重：使用坐标作为唯一标识
                    let key = "\(String(format: "%.5f", poi.coordinate.latitude)),\(String(format: "%.5f", poi.coordinate.longitude))"
                    if !seenPlacemarks.contains(key) {
                        seenPlacemarks.insert(key)
                        allPOIs.append(poi)
                    }
                }
            }
        }

        // 按距离排序（优先显示最近的 POI）
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let sortedPOIs = allPOIs.sorted { poi1, poi2 in
            let loc1 = CLLocation(latitude: poi1.coordinate.latitude, longitude: poi1.coordinate.longitude)
            let loc2 = CLLocation(latitude: poi2.coordinate.latitude, longitude: poi2.coordinate.longitude)
            return centerLocation.distance(from: loc1) < centerLocation.distance(from: loc2)
        }

        // 根据密度限制结果数量
        let limitedPOIs = Array(sortedPOIs.prefix(resultLimit))

        log("搜索完成，共找到 \(allPOIs.count) 个 POI，按密度限制后 \(limitedPOIs.count) 个")

        return limitedPOIs
    }

    // MARK: - Private Methods

    /// 使用关键词搜索 POI（兼容中国大陆）
    private func searchByKeyword(keyword: String, gameType: POIType, center: CLLocationCoordinate2D, radius: CLLocationDistance) async -> [POI] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword

        // 设置搜索区域
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        request.region = region

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()

            // 过滤距离范围内的结果，并转换为游戏 POI 模型
            let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let pois = response.mapItems
                .filter { mapItem in
                    let poiLocation = CLLocation(
                        latitude: mapItem.placemark.coordinate.latitude,
                        longitude: mapItem.placemark.coordinate.longitude
                    )
                    return centerLocation.distance(from: poiLocation) <= radius
                }
                .prefix(maxResultsPerCategory)
                .map { mapItem -> POI in
                    convertToPOI(mapItem: mapItem, gameType: gameType)
                }

            log("关键词「\(keyword)」搜索到 \(pois.count) 个结果")
            return Array(pois)

        } catch {
            log("搜索关键词「\(keyword)」失败: \(error.localizedDescription)", level: "ERROR")
            return []
        }
    }

    /// 将 MKMapItem 转换为游戏 POI 模型
    private func convertToPOI(mapItem: MKMapItem, gameType: POIType) -> POI {
        let placemark = mapItem.placemark

        // 生成废墟风格的名称
        let originalName = mapItem.name ?? "未知地点"
        let apocalypseName = generateApocalypseName(originalName: originalName, type: gameType)

        // 生成描述
        let description = generateDescription(type: gameType)

        // 随机危险等级（1-3，Day22 简化版不使用高危险等级）
        let dangerLevel = Int.random(in: 1...3)

        return POI(
            id: UUID().uuidString,
            name: apocalypseName,
            type: gameType,
            coordinate: placemark.coordinate,
            status: .discovered,  // 搜索到的 POI 默认为已发现
            hasLoot: true,        // 默认有物资
            description: description,
            dangerLevel: dangerLevel,
            discoveredAt: Date()
        )
    }

    /// 生成末世风格的地点名称
    private func generateApocalypseName(originalName: String, type: POIType) -> String {
        let prefixes = ["废弃的", "荒废的", "破损的", "残存的", "遗弃的"]
        let prefix = prefixes.randomElement() ?? "废弃的"

        // 如果原名太长，截取前面部分（增加到20个字符以显示更完整的名称）
        let shortName = originalName.count > 20 ? String(originalName.prefix(20)) : originalName

        return "\(prefix)\(shortName)"
    }

    /// 生成地点描述
    private func generateDescription(type: POIType) -> String {
        switch type {
        case .supermarket:
            return "这里曾经是繁忙的购物场所，现在货架上或许还残留着一些物资。"
        case .hospital:
            return "医疗设施的废墟，可能还有急救用品和药物。"
        case .pharmacy:
            return "药店的残骸，药品柜台可能还有存货。"
        case .gasStation:
            return "加油站遗址，除了燃料，可能还有工具和补给品。"
        case .restaurant:
            return "餐厅废墟，厨房里可能还有食物和水。"
        default:
            return "一处废墟，可能藏有有用的物资。"
        }
    }

    /// 日志输出
    private func log(_ message: String, level: String = "INFO") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level)] [POISearch] \(message)")
    }
}

// MARK: - POI Helper Extension

extension POI {
    /// 获取 POI 类型对应的 SF Symbol 图标
    var iconName: String {
        switch type {
        case .supermarket:
            return "cart.fill"
        case .hospital:
            return "cross.case.fill"
        case .pharmacy:
            return "pills.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .restaurant:
            return "fork.knife"
        case .factory:
            return "building.2.fill"
        case .warehouse:
            return "shippingbox.fill"
        case .policeStation:
            return "shield.fill"
        case .school:
            return "book.fill"
        case .residential:
            return "house.fill"
        }
    }

    /// 获取 POI 类型对应的颜色名称
    var colorName: String {
        switch type {
        case .supermarket:
            return "green"
        case .hospital:
            return "red"
        case .pharmacy:
            return "purple"
        case .gasStation:
            return "orange"
        case .restaurant:
            return "yellow"
        case .factory:
            return "gray"
        case .warehouse:
            return "brown"
        case .policeStation:
            return "blue"
        case .school:
            return "cyan"
        case .residential:
            return "indigo"
        }
    }
}
