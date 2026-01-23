//
//  BuildingModels.swift
//  Earthlord
//
//  Created by Claude on 2026-01-23.
//
//  建造系统数据模型定义
//

import Foundation

// MARK: - 建筑分类

/// 建筑分类
enum BuildingCategory: String, Codable, CaseIterable {
    case survival = "survival"      // 生存类（篝火、庇护所）
    case storage = "storage"        // 储存类（仓库、箱子）
    case production = "production"  // 生产类（农田、工作台）
    case energy = "energy"          // 能源类（太阳能板、风力发电）

    var displayName: String {
        switch self {
        case .survival: return "生存"
        case .storage: return "储存"
        case .production: return "生产"
        case .energy: return "能源"
        }
    }

    var icon: String {
        switch self {
        case .survival: return "flame.fill"
        case .storage: return "archivebox.fill"
        case .production: return "hammer.fill"
        case .energy: return "bolt.fill"
        }
    }
}

// MARK: - 建筑状态

/// 建筑状态
enum BuildingStatus: String, Codable {
    case constructing = "constructing"  // 建造中
    case active = "active"              // 已完成/激活

    var displayName: String {
        switch self {
        case .constructing: return "建造中"
        case .active: return "已完成"
        }
    }
}

// MARK: - 资源需求

/// 建造所需资源
struct ResourceRequirement: Codable, Identifiable {
    let resourceId: String      // 资源 ID（对应 item_definitions 中的 id）
    let amount: Int             // 需要数量

    var id: String { resourceId }

    enum CodingKeys: String, CodingKey {
        case resourceId = "resource_id"
        case amount
    }
}

// MARK: - 建筑效果

/// 建筑效果
struct BuildingEffect: Codable {
    let effectType: String      // 效果类型（如：storage_capacity, production_rate）
    let value: Double           // 效果数值

    enum CodingKeys: String, CodingKey {
        case effectType = "effect_type"
        case value
    }
}

// MARK: - 建筑模板

/// 建筑模板定义（从 JSON 加载）
struct BuildingTemplate: Identifiable, Codable {
    let id: String                          // 模板 ID（如：building_campfire）
    let name: String                        // 建筑名称
    let description: String                 // 描述
    let category: BuildingCategory          // 分类
    let tier: Int                           // 等级/科技层级（1-5）
    let buildTime: Int                      // 建造时间（秒）
    let maxPerTerritory: Int                // 每个领地最大数量
    let resources: [ResourceRequirement]    // 建造所需资源
    let effects: [BuildingEffect]?          // 建筑效果（可选）
    let iconName: String                    // 图标名称
    let upgradeToId: String?                // 升级后的建筑模板 ID（可选）

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, tier
        case buildTime = "build_time"
        case maxPerTerritory = "max_per_territory"
        case resources, effects
        case iconName = "icon_name"
        case upgradeToId = "upgrade_to_id"
    }
}

// MARK: - 玩家建筑实例

/// 玩家建筑实例
struct PlayerBuilding: Identifiable, Codable {
    let id: String                      // 实例 ID
    let userId: String                  // 用户 ID
    let territoryId: String             // 所属领地 ID
    let templateId: String              // 建筑模板 ID
    let buildingName: String            // 建筑名称（可自定义）
    var status: BuildingStatus          // 当前状态
    var level: Int                      // 当前等级
    let locationLat: Double?            // 位置纬度（可选）
    let locationLon: Double?            // 位置经度（可选）
    let buildStartedAt: Date            // 开始建造时间
    var buildCompletedAt: Date?         // 完成建造时间
    let createdAt: Date                 // 创建时间
    var updatedAt: Date                 // 更新时间

    /// 计算建造剩余时间（秒）
    func remainingBuildTime(template: BuildingTemplate) -> Int {
        guard status == .constructing else { return 0 }
        let elapsed = Date().timeIntervalSince(buildStartedAt)
        let remaining = Double(template.buildTime) - elapsed
        return max(0, Int(remaining))
    }

    /// 建造是否已完成（基于时间）
    func isBuildComplete(template: BuildingTemplate) -> Bool {
        let elapsed = Date().timeIntervalSince(buildStartedAt)
        return elapsed >= Double(template.buildTime)
    }
}

// MARK: - 建筑错误类型

/// 建筑系统错误
enum BuildingError: Error, LocalizedError {
    case insufficientResources(missing: [String: Int])  // 资源不足
    case maxBuildingsReached(templateId: String, max: Int)  // 达到数量上限
    case templateNotFound(templateId: String)           // 模板不存在
    case buildingNotFound(buildingId: String)           // 建筑不存在
    case buildingNotComplete                            // 建筑未完成
    case cannotUpgrade(reason: String)                  // 无法升级
    case userNotLoggedIn                                // 用户未登录
    case databaseError(underlying: Error)               // 数据库错误

    var errorDescription: String? {
        switch self {
        case .insufficientResources(let missing):
            let items = missing.map { "\($0.key): 缺少\($0.value)" }.joined(separator: ", ")
            return "资源不足: \(items)"
        case .maxBuildingsReached(_, let max):
            return "已达到该建筑的最大数量限制 (\(max))"
        case .templateNotFound(let templateId):
            return "建筑模板不存在: \(templateId)"
        case .buildingNotFound(let buildingId):
            return "建筑不存在: \(buildingId)"
        case .buildingNotComplete:
            return "建筑尚未完成建造"
        case .cannotUpgrade(let reason):
            return "无法升级: \(reason)"
        case .userNotLoggedIn:
            return "用户未登录"
        case .databaseError(let underlying):
            return "数据库错误: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - 数据库交互结构

/// 玩家建筑（数据库结构）
struct PlayerBuildingDB: Codable {
    let id: String
    let userId: String
    let territoryId: String
    let templateId: String
    let buildingName: String
    let status: String
    let level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: String
    let buildCompletedAt: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status, level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 转换为 PlayerBuilding
    func toPlayerBuilding() -> PlayerBuilding {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let buildStatus = BuildingStatus(rawValue: status) ?? .constructing
        let startDate = dateFormatter.date(from: buildStartedAt) ?? Date()
        let completeDate = buildCompletedAt != nil ? dateFormatter.date(from: buildCompletedAt!) : nil
        let createDate = dateFormatter.date(from: createdAt) ?? Date()
        let updateDate = dateFormatter.date(from: updatedAt) ?? Date()

        return PlayerBuilding(
            id: id,
            userId: userId,
            territoryId: territoryId,
            templateId: templateId,
            buildingName: buildingName,
            status: buildStatus,
            level: level,
            locationLat: locationLat,
            locationLon: locationLon,
            buildStartedAt: startDate,
            buildCompletedAt: completeDate,
            createdAt: createDate,
            updatedAt: updateDate
        )
    }
}

/// 玩家建筑插入结构
struct PlayerBuildingInsert: Codable {
    let userId: String
    let territoryId: String
    let templateId: String
    let buildingName: String
    let status: String
    let level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status, level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
    }
}

/// 玩家建筑更新结构
struct PlayerBuildingUpdate: Codable {
    let status: String?
    let level: Int?
    let buildCompletedAt: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case status, level
        case buildCompletedAt = "build_completed_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 建筑模板 JSON 包装

/// 建筑模板 JSON 文件结构
struct BuildingTemplatesJSON: Codable {
    let templates: [BuildingTemplate]
}
