//
//  AIItemGenerator.swift
//  Earthlord
//
//  AI 物品生成器
//  通过 Supabase Edge Function 调用阿里云百炼 API 生成独特的游戏物品
//

import Foundation
import Combine
import Supabase

// MARK: - AI 生成物品模型

/// AI 生成的物品
struct AIGeneratedItem: Identifiable, Codable {
    let id: String
    let name: String           // 独特名称
    let category: String       // 分类（医疗/食物/工具/武器/材料）
    let rarity: String         // 稀有度（common/uncommon/rare/epic/legendary）
    let story: String          // 背景故事

    init(id: String = UUID().uuidString, name: String, category: String, rarity: String, story: String) {
        self.id = id
        self.name = name
        self.category = category
        self.rarity = rarity
        self.story = story
    }

    /// 稀有度枚举转换
    var rarityEnum: ItemRarity {
        switch rarity.lowercased() {
        case "common": return .common
        case "uncommon": return .uncommon
        case "rare": return .rare
        case "epic": return .epic
        case "legendary": return .legendary
        default: return .common
        }
    }

    /// 分类枚举转换
    var categoryEnum: ItemCategory {
        switch category {
        case "医疗": return .medical
        case "食物": return .food
        case "工具": return .tool
        case "武器": return .weapon
        case "材料": return .material
        case "水": return .water
        default: return .material
        }
    }
}

// MARK: - API 请求/响应模型

/// 生成请求中的 POI 信息
struct AIGeneratePOIInfo: Codable {
    let name: String
    let type: String
    let dangerLevel: Int
}

/// 生成请求
struct AIGenerateRequest: Codable {
    let poi: AIGeneratePOIInfo
    let itemCount: Int
}

/// 生成响应
struct AIGenerateResponse: Codable {
    let success: Bool
    let items: [AIGeneratedItemResponse]?
    let error: String?
    let poi: AIGeneratePOIInfo?
}

/// 响应中的物品数据
struct AIGeneratedItemResponse: Codable {
    let name: String
    let category: String
    let rarity: String
    let story: String
}

// MARK: - AI 物品生成器

/// AI 物品生成器
/// 负责调用 Supabase Edge Function 生成 AI 物品
@MainActor
final class AIItemGenerator {

    // MARK: - Singleton

    static let shared = AIItemGenerator()

    // MARK: - Properties

    /// Supabase 客户端
    private let supabase: SupabaseClient

    /// Edge Function 名称
    private let functionName = "generate-ai-item"

    /// 是否正在生成
    @Published var isGenerating = false

    /// 最后一次错误
    @Published var lastError: String?

    // MARK: - Initialization

    private init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://acnriuoexalqvckiuvgr.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFjbnJpdW9leGFscXZja2l1dmdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5NTQzNDUsImV4cCI6MjA4MTUzMDM0NX0.cOTtYT-dnBDLNKFzFh3pIU6H1W0hksl3sdgdWiqOjIM"
        )
        log("AIItemGenerator 初始化完成")
    }

    // MARK: - Public Methods

    /// 为 POI 生成 AI 物品
    /// - Parameters:
    ///   - poi: 搜刮的 POI
    ///   - count: 生成数量（默认 3）
    /// - Returns: AI 生成的物品数组，失败返回 nil
    func generateItems(for poi: POI, count: Int = 3) async -> [AIGeneratedItem]? {
        guard !isGenerating else {
            log("正在生成中，跳过重复请求", level: "WARN")
            return nil
        }

        isGenerating = true
        lastError = nil

        defer {
            isGenerating = false
        }

        log("开始为 POI 生成物品: \(poi.name) (类型: \(poi.type.rawValue), 危险: \(poi.dangerLevel))")

        // 构建请求
        let request = AIGenerateRequest(
            poi: AIGeneratePOIInfo(
                name: poi.name,
                type: mapPOITypeToAPIType(poi.type),
                dangerLevel: poi.dangerLevel
            ),
            itemCount: count
        )

        do {
            // 调用 Edge Function（直接使用泛型返回类型）
            let response: AIGenerateResponse = try await supabase.functions.invoke(
                functionName,
                options: FunctionInvokeOptions(
                    method: .post,
                    body: request
                )
            )

            if response.success, let items = response.items {
                let generatedItems = items.map { item in
                    AIGeneratedItem(
                        name: item.name,
                        category: item.category,
                        rarity: item.rarity,
                        story: item.story
                    )
                }

                log("成功生成 \(generatedItems.count) 个 AI 物品")
                for item in generatedItems {
                    log("  - [\(item.rarity)] \(item.name)")
                }

                return generatedItems
            } else {
                let errorMsg = response.error ?? "未知错误"
                log("AI 生成失败: \(errorMsg)", level: "ERROR")
                lastError = errorMsg
                return nil
            }

        } catch {
            log("调用 Edge Function 失败: \(error.localizedDescription)", level: "ERROR")
            lastError = error.localizedDescription
            return nil
        }
    }

    /// 计算物品数量（基于 POI 危险等级）
    /// - Parameter poi: POI
    /// - Returns: 建议的物品数量
    func calculateItemCount(for poi: POI) -> Int {
        switch poi.dangerLevel {
        case 1:
            return Int.random(in: 1...2)
        case 2:
            return Int.random(in: 1...3)
        case 3:
            return Int.random(in: 2...3)
        case 4:
            return Int.random(in: 2...4)
        case 5:
            return Int.random(in: 3...5)
        default:
            return Int.random(in: 1...3)
        }
    }

    // MARK: - Private Methods

    /// 将 POI 类型映射到 API 类型字符串
    private func mapPOITypeToAPIType(_ type: POIType) -> String {
        switch type {
        case .hospital:
            return "hospital"
        case .pharmacy:
            return "pharmacy"
        case .supermarket:
            return "supermarket"
        case .gasStation:
            return "gas_station"
        case .restaurant:
            return "restaurant"
        case .policeStation:
            return "police_station"
        case .factory:
            return "factory"
        case .warehouse:
            return "warehouse"
        case .school:
            return "school"
        case .residential:
            return "residential"
        }
    }

    /// 日志输出
    private func log(_ message: String, level: String = "INFO") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level)] [AIItemGenerator] \(message)")
    }
}

// MARK: - 降级方案

extension AIItemGenerator {

    /// 生成备用物品（当 AI 服务不可用时）
    /// - Parameters:
    ///   - poi: 搜刮的 POI
    ///   - count: 生成数量
    /// - Returns: 预设的物品数组
    func generateFallbackItems(for poi: POI, count: Int = 3) -> [AIGeneratedItem] {
        log("使用降级方案生成物品", level: "WARN")

        // 预设物品库（按 POI 类型）
        let presetItems = getPresetItems(for: poi.type, dangerLevel: poi.dangerLevel)

        // 随机选择
        return Array(presetItems.shuffled().prefix(count))
    }

    /// 获取预设物品
    private func getPresetItems(for type: POIType, dangerLevel: Int) -> [AIGeneratedItem] {
        switch type {
        case .hospital, .pharmacy:
            return [
                AIGeneratedItem(name: "过期的绷带", category: "医疗", rarity: "common", story: "虽然过期了，但在末日里这已经是奢侈品。"),
                AIGeneratedItem(name: "急救药箱", category: "医疗", rarity: "uncommon", story: "一个落满灰尘的急救箱，里面还有些可用的物资。"),
                AIGeneratedItem(name: "止痛药瓶", category: "医疗", rarity: "common", story: "瓶子已经快空了，但还有几片。"),
                AIGeneratedItem(name: "医用酒精", category: "医疗", rarity: "uncommon", story: "消毒用的酒精，在末日里价值连城。"),
            ]
        case .supermarket, .restaurant:
            return [
                AIGeneratedItem(name: "压缩饼干", category: "食物", rarity: "common", story: "军用口粮，虽然难吃但能救命。"),
                AIGeneratedItem(name: "罐头食品", category: "食物", rarity: "common", story: "一罐不知道什么口味的罐头。"),
                AIGeneratedItem(name: "矿泉水", category: "水", rarity: "common", story: "干净的水比黄金还珍贵。"),
                AIGeneratedItem(name: "能量棒", category: "食物", rarity: "uncommon", story: "高热量的能量补充剂。"),
            ]
        case .gasStation:
            return [
                AIGeneratedItem(name: "打火机", category: "工具", rarity: "common", story: "一个还能用的打火机。"),
                AIGeneratedItem(name: "手电筒", category: "工具", rarity: "uncommon", story: "电池还有电的手电筒。"),
                AIGeneratedItem(name: "扳手", category: "工具", rarity: "common", story: "一把生锈的扳手。"),
            ]
        case .policeStation:
            return [
                AIGeneratedItem(name: "警棍", category: "武器", rarity: "uncommon", story: "标准配发的警用棍。"),
                AIGeneratedItem(name: "防刺背心", category: "材料", rarity: "rare", story: "一件有些破损的防护背心。"),
                AIGeneratedItem(name: "手铐", category: "工具", rarity: "uncommon", story: "也许能派上用场。"),
            ]
        default:
            return [
                AIGeneratedItem(name: "废旧零件", category: "材料", rarity: "common", story: "一些可能有用的零件。"),
                AIGeneratedItem(name: "破布条", category: "材料", rarity: "common", story: "可以用来包扎或生火。"),
                AIGeneratedItem(name: "生锈铁钉", category: "材料", rarity: "common", story: "小心不要被刺伤。"),
            ]
        }
    }
}
