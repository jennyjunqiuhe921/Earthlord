//
//  ExplorationModels.swift
//  Earthlord
//
//  Created by Claude on 2026-01-10.
//

import Foundation
import CoreLocation

// MARK: - POI（兴趣点）模型

/// POI 状态
enum POIStatus: String, Codable {
    case undiscovered = "未发现"    // 未发现
    case discovered = "已发现"      // 已发现但未搜刮
    case looted = "已搜空"          // 已被搜空
}

/// POI 类型
enum POIType: String, Codable {
    case supermarket = "超市"
    case hospital = "医院"
    case gasStation = "加油站"
    case pharmacy = "药店"
    case factory = "工厂"
    case warehouse = "仓库"
    case restaurant = "餐厅"
    case policeStation = "警察局"
    case school = "学校"
    case residential = "住宅区"
}

/// 兴趣点
struct POI: Identifiable, Codable {
    let id: String
    let name: String                    // 名称（如：废弃超市）
    let type: POIType                   // 类型
    let coordinate: CLLocationCoordinate2D  // 坐标
    var status: POIStatus               // 状态
    var hasLoot: Bool                   // 是否有物资
    let description: String             // 描述
    let dangerLevel: Int                // 危险等级（1-5）
    var discoveredAt: Date?             // 发现时间
    var lootedAt: Date?                 // 搜刮时间

    enum CodingKeys: String, CodingKey {
        case id, name, type, status, hasLoot, description, dangerLevel, discoveredAt, lootedAt
        case latitude, longitude
    }

    init(id: String, name: String, type: POIType, coordinate: CLLocationCoordinate2D,
         status: POIStatus, hasLoot: Bool, description: String, dangerLevel: Int,
         discoveredAt: Date? = nil, lootedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.coordinate = coordinate
        self.status = status
        self.hasLoot = hasLoot
        self.description = description
        self.dangerLevel = dangerLevel
        self.discoveredAt = discoveredAt
        self.lootedAt = lootedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(POIType.self, forKey: .type)
        status = try container.decode(POIStatus.self, forKey: .status)
        hasLoot = try container.decode(Bool.self, forKey: .hasLoot)
        description = try container.decode(String.self, forKey: .description)
        dangerLevel = try container.decode(Int.self, forKey: .dangerLevel)
        discoveredAt = try container.decodeIfPresent(Date.self, forKey: .discoveredAt)
        lootedAt = try container.decodeIfPresent(Date.self, forKey: .lootedAt)

        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(status, forKey: .status)
        try container.encode(hasLoot, forKey: .hasLoot)
        try container.encode(description, forKey: .description)
        try container.encode(dangerLevel, forKey: .dangerLevel)
        try container.encodeIfPresent(discoveredAt, forKey: .discoveredAt)
        try container.encodeIfPresent(lootedAt, forKey: .lootedAt)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }
}

// MARK: - 物品模型

/// 物品类型
enum ItemCategory: String, Codable {
    case water = "水"
    case food = "食物"
    case medical = "医疗"
    case material = "材料"
    case tool = "工具"
    case weapon = "武器"
}

/// 物品稀有度
enum ItemRarity: String, Codable {
    case common = "普通"
    case uncommon = "罕见"
    case rare = "稀有"
    case epic = "史诗"
    case legendary = "传说"

    var color: String {
        switch self {
        case .common: return "gray"
        case .uncommon: return "green"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "orange"
        }
    }
}

/// 物品品质（耐久度）
enum ItemQuality: Int, Codable {
    case broken = 0      // 损坏
    case poor = 1        // 破损
    case normal = 2      // 普通
    case good = 3        // 良好
    case excellent = 4   // 优秀

    var description: String {
        switch self {
        case .broken: return "损坏"
        case .poor: return "破损"
        case .normal: return "普通"
        case .good: return "良好"
        case .excellent: return "优秀"
        }
    }
}

/// 物品定义（静态数据）
struct ItemDefinition: Identifiable, Codable {
    let id: String              // 物品 ID（如：item_water_bottle）
    let name: String            // 中文名（如：矿泉水）
    let category: ItemCategory  // 分类
    let weight: Double          // 重量（克）
    let volume: Double          // 体积（立方厘米）
    let rarity: ItemRarity      // 稀有度
    let description: String     // 描述
    let canStack: Bool          // 是否可堆叠
    let maxStack: Int           // 最大堆叠数量
    let hasQuality: Bool        // 是否有品质（耐久度）
}

/// 背包中的物品实例
struct InventoryItem: Identifiable, Codable {
    let id: String                  // 实例 ID
    let definitionId: String        // 关联的物品定义 ID
    var quantity: Int               // 数量
    var quality: ItemQuality?       // 品质（可选，如食物、材料没有品质）
    let obtainedAt: Date            // 获得时间
}

// MARK: - 探索结果模型

/// 探索统计
struct ExplorationStats: Codable {
    // 本次探索
    let distanceThisSession: Double     // 行走距离（米）
    let areaThisSession: Double         // 探索面积（平方米）
    let durationThisSession: TimeInterval  // 探索时长（秒）
    let itemsFoundThisSession: [ItemLoot]  // 本次获得的物品

    // 累计统计
    let totalDistance: Double           // 累计行走距离（米）
    let totalArea: Double               // 累计探索面积（平方米）
    let totalDuration: TimeInterval     // 累计探索时长（秒）

    // 排名
    let distanceRank: Int               // 距离排名
    let areaRank: Int                   // 面积排名
}

/// 战利品（探索获得的物品）
struct ItemLoot: Identifiable, Codable {
    let id: String
    let definitionId: String    // 物品定义 ID
    let quantity: Int           // 数量
    let quality: ItemQuality?   // 品质
}

/// 探索结果
struct ExplorationResult: Identifiable, Codable {
    let id: String
    let userId: String
    let startTime: Date
    let endTime: Date
    let stats: ExplorationStats
    let poisDiscovered: [String]  // 发现的 POI ID 列表
    let achievements: [String]    // 获得的成就 ID 列表
}
