//
//  MockExplorationData.swift
//  Earthlord
//
//  Created by Claude on 2026-01-10.
//
//  探索模块测试假数据

import Foundation
import CoreLocation

/// 探索模块假数据
struct MockExplorationData {

    // MARK: - POI 列表（5个不同状态的兴趣点）

    /// 假数据：兴趣点列表
    /// 包含5个不同状态的POI，用于测试各种显示状态
    static let mockPOIs: [POI] = [
        // 1. 废弃超市 - 已发现，有物资
        POI(
            id: "poi_001",
            name: "废弃超市",
            type: .supermarket,
            coordinate: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074), // 天安门附近
            status: .discovered,
            hasLoot: true,
            description: "一座被遗弃的大型超市，货架上还残留着一些罐头食品和瓶装水。小心，可能有其他幸存者已经来过。",
            dangerLevel: 2,
            discoveredAt: Date().addingTimeInterval(-86400 * 2) // 2天前发现
        ),

        // 2. 医院废墟 - 已发现，已被搜空
        POI(
            id: "poi_002",
            name: "医院废墟",
            type: .hospital,
            coordinate: CLLocationCoordinate2D(latitude: 39.9100, longitude: 116.4100),
            status: .looted,
            hasLoot: false,
            description: "曾经的三甲医院，现在只剩下残垣断壁。医药储藏室已被搜刮一空，只留下空药瓶和破碎的医疗设备。",
            dangerLevel: 4,
            discoveredAt: Date().addingTimeInterval(-86400 * 5), // 5天前发现
            lootedAt: Date().addingTimeInterval(-86400 * 3)      // 3天前搜刮
        ),

        // 3. 加油站 - 未发现
        POI(
            id: "poi_003",
            name: "郊外加油站",
            type: .gasStation,
            coordinate: CLLocationCoordinate2D(latitude: 39.8900, longitude: 116.4200),
            status: .undiscovered,
            hasLoot: true,
            description: "位于郊外的小型加油站，可能还有汽油和便利店的物资。但地处偏僻，需要小心行动。",
            dangerLevel: 3
        ),

        // 4. 药店废墟 - 已发现，有物资
        POI(
            id: "poi_004",
            name: "药店废墟",
            type: .pharmacy,
            coordinate: CLLocationCoordinate2D(latitude: 39.9150, longitude: 116.4050),
            status: .discovered,
            hasLoot: true,
            description: "街角的小药店，虽然店面受损严重，但后仓库可能还有一些药品和医疗用品。",
            dangerLevel: 2,
            discoveredAt: Date().addingTimeInterval(-86400 * 1) // 1天前发现
        ),

        // 5. 工厂废墟 - 未发现
        POI(
            id: "poi_005",
            name: "工厂废墟",
            type: .factory,
            coordinate: CLLocationCoordinate2D(latitude: 39.8850, longitude: 116.3950),
            status: .undiscovered,
            hasLoot: true,
            description: "大型工业工厂的遗址，可能有大量金属材料和工具，但结构不稳定，危险等级高。",
            dangerLevel: 5
        )
    ]

    // MARK: - 物品定义表

    /// 假数据：物品定义表
    /// 记录每种物品的中文名、分类、重量、体积、稀有度
    static let mockItemDefinitions: [ItemDefinition] = [
        // 水类
        ItemDefinition(
            id: "item_water_bottle",
            name: "矿泉水",
            category: .water,
            weight: 550,        // 550克（含瓶重）
            volume: 600,        // 600立方厘米
            rarity: .common,
            description: "500ml瓶装矿泉水，末日中最珍贵的资源之一。",
            canStack: true,
            maxStack: 20,
            hasQuality: false   // 水没有品质
        ),

        // 食物类
        ItemDefinition(
            id: "item_canned_food",
            name: "罐头食品",
            category: .food,
            weight: 400,
            volume: 350,
            rarity: .common,
            description: "肉类罐头，保质期长，是生存的重要食物来源。",
            canStack: true,
            maxStack: 15,
            hasQuality: false   // 食物没有品质
        ),

        // 医疗类 - 绷带
        ItemDefinition(
            id: "item_bandage",
            name: "绷带",
            category: .medical,
            weight: 50,
            volume: 100,
            rarity: .common,
            description: "医用绷带，可用于包扎伤口，减少感染风险。",
            canStack: true,
            maxStack: 30,
            hasQuality: true    // 绷带有品质
        ),

        // 医疗类 - 药品
        ItemDefinition(
            id: "item_medicine",
            name: "抗生素药品",
            category: .medical,
            weight: 100,
            volume: 80,
            rarity: .uncommon,
            description: "广谱抗生素，可治疗感染和疾病。非常珍贵。",
            canStack: true,
            maxStack: 10,
            hasQuality: true    // 药品有品质
        ),

        // 材料类 - 木材
        ItemDefinition(
            id: "item_wood",
            name: "木材",
            category: .material,
            weight: 2000,       // 2公斤
            volume: 5000,       // 5000立方厘米
            rarity: .common,
            description: "可用于建造和修复的木材，末日中的基础建材。",
            canStack: true,
            maxStack: 50,
            hasQuality: false   // 材料没有品质
        ),

        // 材料类 - 废金属
        ItemDefinition(
            id: "item_scrap_metal",
            name: "废金属",
            category: .material,
            weight: 1500,
            volume: 800,
            rarity: .common,
            description: "废弃的金属材料，可用于制作工具或加固建筑。",
            canStack: true,
            maxStack: 40,
            hasQuality: false
        ),

        // 工具类 - 手电筒
        ItemDefinition(
            id: "item_flashlight",
            name: "手电筒",
            category: .tool,
            weight: 300,
            volume: 400,
            rarity: .uncommon,
            description: "LED手电筒，夜间探索的必备工具。需要电池。",
            canStack: false,    // 工具不可堆叠
            maxStack: 1,
            hasQuality: true    // 工具有品质
        ),

        // 工具类 - 绳子
        ItemDefinition(
            id: "item_rope",
            name: "尼龙绳",
            category: .tool,
            weight: 500,
            volume: 600,
            rarity: .common,
            description: "10米长的尼龙绳，用途广泛，可用于攀爬、捆绑等。",
            canStack: true,
            maxStack: 5,
            hasQuality: true    // 绳子有品质
        )
    ]

    // MARK: - 背包物品（6-8种不同类型）

    /// 假数据：背包中的物品
    /// 包含不同类型和品质的物品，用于测试背包界面
    static let mockInventoryItems: [InventoryItem] = [
        // 水类：矿泉水 x3
        InventoryItem(
            id: "inv_001",
            definitionId: "item_water_bottle",
            quantity: 3,
            quality: nil,   // 水没有品质
            obtainedAt: Date().addingTimeInterval(-3600 * 24) // 1天前获得
        ),

        // 食物：罐头食品 x5
        InventoryItem(
            id: "inv_002",
            definitionId: "item_canned_food",
            quantity: 5,
            quality: nil,   // 食物没有品质
            obtainedAt: Date().addingTimeInterval(-3600 * 48)
        ),

        // 医疗：绷带 x8（良好品质）
        InventoryItem(
            id: "inv_003",
            definitionId: "item_bandage",
            quantity: 8,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-3600 * 12)
        ),

        // 医疗：药品 x2（普通品质）
        InventoryItem(
            id: "inv_004",
            definitionId: "item_medicine",
            quantity: 2,
            quality: .normal,
            obtainedAt: Date().addingTimeInterval(-3600 * 6)
        ),

        // 材料：木材 x12
        InventoryItem(
            id: "inv_005",
            definitionId: "item_wood",
            quantity: 12,
            quality: nil,   // 材料没有品质
            obtainedAt: Date().addingTimeInterval(-3600 * 36)
        ),

        // 材料：废金属 x7
        InventoryItem(
            id: "inv_006",
            definitionId: "item_scrap_metal",
            quantity: 7,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-3600 * 20)
        ),

        // 工具：手电筒 x1（优秀品质）
        InventoryItem(
            id: "inv_007",
            definitionId: "item_flashlight",
            quantity: 1,
            quality: .excellent,
            obtainedAt: Date().addingTimeInterval(-3600 * 72)
        ),

        // 工具：绳子 x2（良好品质）
        InventoryItem(
            id: "inv_008",
            definitionId: "item_rope",
            quantity: 2,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-3600 * 15)
        )
    ]

    // MARK: - 探索结果示例

    /// 假数据：探索结果
    /// 包含本次探索和累计统计，用于测试探索结算界面
    static let mockExplorationResult: ExplorationResult = {
        // 本次获得的物品
        let itemsFound = [
            ItemLoot(id: "loot_001", definitionId: "item_wood", quantity: 5, quality: nil),
            ItemLoot(id: "loot_002", definitionId: "item_water_bottle", quantity: 3, quality: nil),
            ItemLoot(id: "loot_003", definitionId: "item_canned_food", quantity: 2, quality: nil)
        ]

        // 探索统计
        let stats = ExplorationStats(
            // 本次探索
            distanceThisSession: 2500,      // 行走 2500 米
            areaThisSession: 50000,         // 探索 5 万平方米
            durationThisSession: 1800,      // 30 分钟（1800秒）
            itemsFoundThisSession: itemsFound,
            // 累计统计
            totalDistance: 15000,           // 累计 15000 米
            totalArea: 250000,              // 累计 25 万平方米
            totalDuration: 10800,           // 累计 3 小时
            // 排名
            distanceRank: 42,               // 距离排名第 42
            areaRank: 38                    // 面积排名第 38
        )

        return ExplorationResult(
            id: "exp_result_001",
            userId: "user_test_001",
            startTime: Date().addingTimeInterval(-1800), // 30分钟前开始
            endTime: Date(),
            stats: stats,
            poisDiscovered: ["poi_001", "poi_004"], // 发现了超市和药店
            achievements: []    // 暂无成就
        )
    }()

    // MARK: - 辅助方法

    /// 根据物品定义 ID 查找物品定义
    static func getItemDefinition(by id: String) -> ItemDefinition? {
        return mockItemDefinitions.first { $0.id == id }
    }

    /// 获取背包总重量（克）
    static func getTotalInventoryWeight() -> Double {
        var totalWeight: Double = 0
        for item in mockInventoryItems {
            if let definition = getItemDefinition(by: item.definitionId) {
                totalWeight += definition.weight * Double(item.quantity)
            }
        }
        return totalWeight
    }

    /// 获取背包总体积（立方厘米）
    static func getTotalInventoryVolume() -> Double {
        var totalVolume: Double = 0
        for item in mockInventoryItems {
            if let definition = getItemDefinition(by: item.definitionId) {
                totalVolume += definition.volume * Double(item.quantity)
            }
        }
        return totalVolume
    }

    /// 格式化重量显示（自动转换为 kg 或 g）
    static func formatWeight(_ grams: Double) -> String {
        if grams >= 1000 {
            return String(format: "%.1f kg", grams / 1000)
        } else {
            return String(format: "%.0f g", grams)
        }
    }

    /// 格式化体积显示（自动转换为 L 或 cm³）
    static func formatVolume(_ cubicCentimeters: Double) -> String {
        if cubicCentimeters >= 1000 {
            return String(format: "%.1f L", cubicCentimeters / 1000)
        } else {
            return String(format: "%.0f cm³", cubicCentimeters)
        }
    }

    /// 格式化距离显示（自动转换为 km 或 m）
    static func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// 格式化面积显示（自动转换为 km² 或 m²）
    static func formatArea(_ squareMeters: Double) -> String {
        if squareMeters >= 1000000 {
            return String(format: "%.2f km²", squareMeters / 1000000)
        } else if squareMeters >= 1000 {
            return String(format: "%.1f 千m²", squareMeters / 1000)
        } else {
            return String(format: "%.0f m²", squareMeters)
        }
    }

    /// 格式化时长显示
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d小时%d分钟", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d分%d秒", minutes, secs)
        } else {
            return String(format: "%d秒", secs)
        }
    }
}
