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
    let distanceThisSession: Double        // 行走距离（米）
    let durationThisSession: TimeInterval  // 探索时长（秒）
    let itemsFoundThisSession: [ItemLoot]  // 本次获得的物品

    // 累计统计
    let totalDistance: Double              // 累计行走距离（米）
    let totalDuration: TimeInterval        // 累计探索时长（秒）
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
    let rewardTier: RewardTier    // 奖励等级
}

// MARK: - 奖励等级

/// 探索奖励等级
enum RewardTier: String, Codable, CaseIterable {
    case none = "none"          // 无奖励 (0-200m)
    case bronze = "bronze"      // 铜级 (200-500m)
    case silver = "silver"      // 银级 (500-1000m)
    case gold = "gold"          // 金级 (1000-2000m)
    case diamond = "diamond"    // 钻石级 (2000m+)

    /// 该等级的物品数量
    var itemCount: Int {
        switch self {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 等级显示名称
    var displayName: String {
        switch self {
        case .none: return "无奖励"
        case .bronze: return "铜级"
        case .silver: return "银级"
        case .gold: return "金级"
        case .diamond: return "钻石级"
        }
    }

    /// 等级图标
    var icon: String {
        switch self {
        case .none: return "xmark.circle"
        case .bronze: return "medal.fill"
        case .silver: return "medal.fill"
        case .gold: return "medal.fill"
        case .diamond: return "diamond.fill"
        }
    }

    /// 等级颜色名称
    var colorName: String {
        switch self {
        case .none: return "gray"
        case .bronze: return "brown"
        case .silver: return "gray"
        case .gold: return "yellow"
        case .diamond: return "cyan"
        }
    }

    /// 稀有度概率表 [common, rare, epic]
    var rarityProbabilities: [Double] {
        switch self {
        case .none: return [0, 0, 0]
        case .bronze: return [0.90, 0.10, 0.00]    // 90% common, 10% rare, 0% epic
        case .silver: return [0.70, 0.25, 0.05]    // 70% common, 25% rare, 5% epic
        case .gold: return [0.50, 0.35, 0.15]      // 50% common, 35% rare, 15% epic
        case .diamond: return [0.30, 0.40, 0.30]   // 30% common, 40% rare, 30% epic
        }
    }
}

// MARK: - 数据库兼容结构

/// 物品定义（数据库结构）
struct ItemDefinitionDB: Codable {
    let id: String
    let name: String
    let category: String
    let rarity: String
    let weight: Double?
    let description: String?
    let iconName: String?
    let canStack: Bool?
    let maxStack: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, category, rarity, weight, description
        case iconName = "icon_name"
        case canStack = "can_stack"
        case maxStack = "max_stack"
    }

    /// 转换为 ItemDefinition
    func toItemDefinition() -> ItemDefinition {
        let cat: ItemCategory
        switch category {
        case "water": cat = .water
        case "food": cat = .food
        case "medical": cat = .medical
        case "material": cat = .material
        case "tool": cat = .tool
        default: cat = .material
        }

        let rar: ItemRarity
        switch rarity {
        case "common": rar = .common
        case "rare": rar = .rare
        case "epic": rar = .epic
        default: rar = .common
        }

        return ItemDefinition(
            id: id,
            name: name,
            category: cat,
            weight: weight ?? 0,
            volume: 0,
            rarity: rar,
            description: description ?? "",
            canStack: canStack ?? true,
            maxStack: maxStack ?? 99,
            hasQuality: false
        )
    }
}

/// 背包物品（数据库结构）
struct InventoryItemDB: Codable {
    let id: String
    let userId: String
    let itemDefinitionId: String
    let quantity: Int
    let quality: Int?
    let obtainedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemDefinitionId = "item_definition_id"
        case quantity, quality
        case obtainedAt = "obtained_at"
    }

    /// 转换为 InventoryItem
    func toInventoryItem() -> InventoryItem {
        let qual: ItemQuality? = quality != nil ? ItemQuality(rawValue: quality!) : nil

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = dateFormatter.date(from: obtainedAt) ?? Date()

        return InventoryItem(
            id: id,
            definitionId: itemDefinitionId,
            quantity: quantity,
            quality: qual,
            obtainedAt: date
        )
    }
}

/// 探索记录（数据库结构）- 用于插入
struct ExplorationSessionInsert: Codable {
    let userId: String
    let startTime: String
    let endTime: String
    let distanceMeters: Double
    let durationSeconds: Int
    let rewardTier: String
    let itemsEarned: String  // JSON 字符串

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case distanceMeters = "distance_meters"
        case durationSeconds = "duration_seconds"
        case rewardTier = "reward_tier"
        case itemsEarned = "items_earned"
    }
}

/// 背包物品插入结构
struct InventoryItemInsert: Codable {
    let userId: String
    let itemDefinitionId: String
    let quantity: Int
    let quality: Int?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case itemDefinitionId = "item_definition_id"
        case quantity, quality
    }
}

/// 背包物品更新结构
struct InventoryItemUpdate: Codable {
    let quantity: Int
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case quantity
        case updatedAt = "updated_at"
    }
}

// MARK: - 玩家密度等级

/// 玩家密度等级（根据附近玩家数量动态调整 POI 显示）
enum PlayerDensityLevel: String, CaseIterable {
    case solitary = "独行者"    // 0人
    case low = "低密度"         // 1-5人
    case medium = "中密度"      // 6-20人
    case high = "高密度"        // 20人以上

    /// 根据附近玩家数量确定密度等级
    static func from(nearbyCount: Int) -> PlayerDensityLevel {
        switch nearbyCount {
        case 0:
            return .solitary
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }

    /// 该密度等级对应的 POI 数量上限
    var poiLimit: Int {
        switch self {
        case .solitary: return 1
        case .low: return 3
        case .medium: return 6
        case .high: return 20
        }
    }

    /// 显示图标
    var icon: String {
        switch self {
        case .solitary: return "person"
        case .low: return "person.2"
        case .medium: return "person.3"
        case .high: return "person.3.fill"
        }
    }
}

// MARK: - 玩家位置上报结构

/// 玩家位置上报数据（用于 Supabase upsert）
struct PlayerLocationUpsert: Encodable {
    let userId: String
    let latitude: Double
    let longitude: Double
    let updatedAt: String
    let isOnline: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case latitude
        case longitude
        case updatedAt = "updated_at"
        case isOnline = "is_online"
    }
}

/// 玩家在线状态更新结构（用于 update）
struct PlayerOnlineStatusUpdate: Encodable {
    let isOnline: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isOnline = "is_online"
        case updatedAt = "updated_at"
    }
}
