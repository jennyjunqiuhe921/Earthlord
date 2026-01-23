//
//  BuildingManager.swift
//  Earthlord
//
//  Created by Claude on 2026-01-23.
//
//  建筑管理器 - 管理建筑模板加载、建造、升级等操作
//

import Foundation
import Combine
import Supabase

/// 建筑管理器（单例）
@MainActor
class BuildingManager: ObservableObject {

    // MARK: - Singleton

    static let shared = BuildingManager()

    // MARK: - Published Properties

    /// 建筑模板缓存（templateId -> BuildingTemplate）
    @Published var templates: [String: BuildingTemplate] = [:]

    /// 玩家建筑列表
    @Published var playerBuildings: [PlayerBuilding] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误消息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let supabase: SupabaseClient
    private var inventoryManager: InventoryManager?

    // MARK: - Initialization

    private init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://acnriuoexalqvckiuvgr.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFjbnJpdW9leGFscXZja2l1dmdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5NTQzNDUsImV4cCI6MjA4MTUzMDM0NX0.cOTtYT-dnBDLNKFzFh3pIU6H1W0hksl3sdgdWiqOjIM"
        )
    }

    // MARK: - Configuration

    /// 设置 InventoryManager 引用（用于资源检查和扣除）
    func setInventoryManager(_ manager: InventoryManager) {
        self.inventoryManager = manager
    }

    // MARK: - Template Loading

    /// 从 JSON 文件加载建筑模板
    func loadTemplates() async {
        print("[BuildingManager] 开始加载建筑模板...")

        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            print("[BuildingManager] ❌ 找不到 building_templates.json 文件")
            errorMessage = "找不到建筑模板配置文件"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let templatesJSON = try decoder.decode(BuildingTemplatesJSON.self, from: data)

            // 转换为字典缓存
            var templateDict: [String: BuildingTemplate] = [:]
            for template in templatesJSON.templates {
                templateDict[template.id] = template
            }
            self.templates = templateDict

            print("[BuildingManager] ✅ 成功加载 \(templates.count) 个建筑模板")
        } catch {
            print("[BuildingManager] ❌ 加载建筑模板失败: \(error.localizedDescription)")
            errorMessage = "加载建筑模板失败: \(error.localizedDescription)"
        }
    }

    /// 获取指定分类的建筑模板
    func getTemplates(for category: BuildingCategory) -> [BuildingTemplate] {
        return templates.values.filter { $0.category == category }
    }

    /// 获取指定等级的建筑模板
    func getTemplates(forTier tier: Int) -> [BuildingTemplate] {
        return templates.values.filter { $0.tier == tier }
    }

    // MARK: - Resource Checking

    /// 检查是否可以建造指定建筑
    /// - Parameters:
    ///   - templateId: 建筑模板 ID
    ///   - territoryId: 领地 ID
    /// - Returns: (canBuild, missingResources) 是否可建造及缺少的资源
    func canBuild(templateId: String, territoryId: String) async throws -> (canBuild: Bool, missingResources: [String: Int]) {
        guard let template = templates[templateId] else {
            throw BuildingError.templateNotFound(templateId: templateId)
        }

        // 检查领地内该类型建筑数量
        let existingCount = playerBuildings.filter {
            $0.territoryId == territoryId && $0.templateId == templateId
        }.count

        if existingCount >= template.maxPerTerritory {
            throw BuildingError.maxBuildingsReached(templateId: templateId, max: template.maxPerTerritory)
        }

        // 检查资源
        let missingResources = await checkResources(for: template)

        return (missingResources.isEmpty, missingResources)
    }

    /// 检查资源是否足够
    /// - Parameter template: 建筑模板
    /// - Returns: 缺少的资源字典（resourceId -> 缺少数量）
    private func checkResources(for template: BuildingTemplate) async -> [String: Int] {
        guard let inventory = inventoryManager else {
            print("[BuildingManager] ⚠️ InventoryManager 未设置，无法检查资源")
            // 返回所有资源都缺少（假设全部缺少）
            var missing: [String: Int] = [:]
            for resource in template.resources {
                missing[resource.resourceId] = resource.amount
            }
            return missing
        }

        var missingResources: [String: Int] = [:]

        for resource in template.resources {
            // 计算背包中该资源的总数量
            let ownedItems = inventory.inventoryItems.filter { $0.definitionId == resource.resourceId }
            let totalOwned = ownedItems.reduce(0) { $0 + $1.quantity }

            if totalOwned < resource.amount {
                missingResources[resource.resourceId] = resource.amount - totalOwned
            }
        }

        return missingResources
    }

    // MARK: - Construction

    /// 开始建造建筑
    /// - Parameters:
    ///   - templateId: 建筑模板 ID
    ///   - territoryId: 领地 ID
    ///   - customName: 自定义名称（可选）
    ///   - location: 建造位置（可选）
    /// - Returns: 创建的建筑实例
    @discardableResult
    func startConstruction(
        templateId: String,
        territoryId: String,
        customName: String? = nil,
        locationLat: Double? = nil,
        locationLon: Double? = nil
    ) async throws -> PlayerBuilding {
        guard let template = templates[templateId] else {
            throw BuildingError.templateNotFound(templateId: templateId)
        }

        // 检查是否可建造
        let (canBuild, missingResources) = try await canBuild(templateId: templateId, territoryId: territoryId)
        if !canBuild {
            throw BuildingError.insufficientResources(missing: missingResources)
        }

        // 获取当前用户
        guard let userId = try? await getCurrentUserId() else {
            throw BuildingError.userNotLoggedIn
        }

        // 扣除资源
        try await deductResources(for: template)

        // 创建建筑记录
        let buildingName = customName ?? template.name
        let now = ISO8601DateFormatter().string(from: Date())

        let insert = PlayerBuildingInsert(
            userId: userId,
            territoryId: territoryId,
            templateId: templateId,
            buildingName: buildingName,
            status: BuildingStatus.constructing.rawValue,
            level: 1,
            locationLat: locationLat,
            locationLon: locationLon,
            buildStartedAt: now
        )

        do {
            try await supabase
                .from("player_buildings")
                .insert(insert)
                .execute()

            print("[BuildingManager] ✅ 开始建造: \(buildingName)")

            // 重新加载建筑列表
            try await loadPlayerBuildings(for: territoryId)

            // 返回新创建的建筑
            if let newBuilding = playerBuildings.first(where: {
                $0.templateId == templateId &&
                $0.territoryId == territoryId &&
                $0.status == .constructing
            }) {
                return newBuilding
            }

            // 如果找不到，创建一个本地实例返回
            return PlayerBuilding(
                id: UUID().uuidString,
                userId: userId,
                territoryId: territoryId,
                templateId: templateId,
                buildingName: buildingName,
                status: .constructing,
                level: 1,
                locationLat: locationLat,
                locationLon: locationLon,
                buildStartedAt: Date(),
                buildCompletedAt: nil,
                createdAt: Date(),
                updatedAt: Date()
            )

        } catch {
            print("[BuildingManager] ❌ 创建建筑失败: \(error.localizedDescription)")
            throw BuildingError.databaseError(underlying: error)
        }
    }

    /// 扣除建造资源
    private func deductResources(for template: BuildingTemplate) async throws {
        guard let inventory = inventoryManager else {
            print("[BuildingManager] ⚠️ InventoryManager 未设置，跳过资源扣除")
            return
        }

        for resource in template.resources {
            var remainingToDeduct = resource.amount

            // 获取该资源的所有物品（按数量排序，优先扣除数量多的）
            let ownedItems = inventory.inventoryItems
                .filter { $0.definitionId == resource.resourceId }
                .sorted { $0.quantity > $1.quantity }

            for item in ownedItems {
                if remainingToDeduct <= 0 { break }

                let deductAmount = min(item.quantity, remainingToDeduct)
                try await inventory.useItem(item, quantity: deductAmount)
                remainingToDeduct -= deductAmount

                print("[BuildingManager] 扣除资源: \(resource.resourceId) x\(deductAmount)")
            }
        }
    }

    // MARK: - Completion

    /// 完成建造（将状态改为 active）
    /// - Parameter buildingId: 建筑实例 ID
    func completeConstruction(buildingId: String) async throws {
        guard let building = playerBuildings.first(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound(buildingId: buildingId)
        }

        guard building.status == .constructing else {
            print("[BuildingManager] 建筑已经完成")
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())

        let update = PlayerBuildingUpdate(
            status: BuildingStatus.active.rawValue,
            level: nil,
            buildCompletedAt: now,
            updatedAt: now
        )

        do {
            try await supabase
                .from("player_buildings")
                .update(update)
                .eq("id", value: buildingId)
                .execute()

            print("[BuildingManager] ✅ 建筑完成: \(building.buildingName)")

            // 更新本地缓存
            if let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) {
                playerBuildings[index].status = .active
                playerBuildings[index].buildCompletedAt = Date()
                playerBuildings[index].updatedAt = Date()
            }

        } catch {
            print("[BuildingManager] ❌ 完成建筑失败: \(error.localizedDescription)")
            throw BuildingError.databaseError(underlying: error)
        }
    }

    /// 检查并自动完成所有到期的建筑
    func checkAndCompleteBuildings() async {
        for building in playerBuildings where building.status == .constructing {
            guard let template = templates[building.templateId] else { continue }

            if building.isBuildComplete(template: template) {
                do {
                    try await completeConstruction(buildingId: building.id)
                } catch {
                    print("[BuildingManager] ❌ 自动完成建筑失败: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Upgrade

    /// 升级建筑
    /// - Parameter buildingId: 建筑实例 ID
    func upgradeBuilding(buildingId: String) async throws {
        guard let building = playerBuildings.first(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound(buildingId: buildingId)
        }

        guard building.status == .active else {
            throw BuildingError.buildingNotComplete
        }

        guard let template = templates[building.templateId] else {
            throw BuildingError.templateNotFound(templateId: building.templateId)
        }

        guard let upgradeTemplateId = template.upgradeToId,
              let upgradeTemplate = templates[upgradeTemplateId] else {
            throw BuildingError.cannotUpgrade(reason: "该建筑无法升级")
        }

        // 检查升级资源
        let missingResources = await checkResources(for: upgradeTemplate)
        if !missingResources.isEmpty {
            throw BuildingError.insufficientResources(missing: missingResources)
        }

        // 扣除资源
        try await deductResources(for: upgradeTemplate)

        // 更新建筑（升级等级，重置为建造中状态）
        let now = ISO8601DateFormatter().string(from: Date())

        let update = PlayerBuildingUpdate(
            status: BuildingStatus.constructing.rawValue,
            level: building.level + 1,
            buildCompletedAt: nil,
            updatedAt: now
        )

        do {
            try await supabase
                .from("player_buildings")
                .update(update)
                .eq("id", value: buildingId)
                .execute()

            print("[BuildingManager] ✅ 开始升级: \(building.buildingName) -> Lv.\(building.level + 1)")

            // 更新本地缓存
            if let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) {
                playerBuildings[index].status = .constructing
                playerBuildings[index].level = building.level + 1
                playerBuildings[index].updatedAt = Date()
            }

        } catch {
            print("[BuildingManager] ❌ 升级建筑失败: \(error.localizedDescription)")
            throw BuildingError.databaseError(underlying: error)
        }
    }

    // MARK: - Data Loading

    /// 加载指定领地的玩家建筑
    func loadPlayerBuildings(for territoryId: String) async throws {
        guard let userId = try? await getCurrentUserId() else {
            throw BuildingError.userNotLoggedIn
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response: [PlayerBuildingDB] = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId)
                .eq("territory_id", value: territoryId)
                .execute()
                .value

            self.playerBuildings = response.map { $0.toPlayerBuilding() }

            print("[BuildingManager] ✅ 加载了 \(playerBuildings.count) 个建筑")

        } catch {
            print("[BuildingManager] ❌ 加载建筑失败: \(error.localizedDescription)")
            throw BuildingError.databaseError(underlying: error)
        }
    }

    /// 加载当前用户所有建筑
    func loadAllPlayerBuildings() async throws {
        guard let userId = try? await getCurrentUserId() else {
            throw BuildingError.userNotLoggedIn
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response: [PlayerBuildingDB] = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            self.playerBuildings = response.map { $0.toPlayerBuilding() }

            print("[BuildingManager] ✅ 加载了 \(playerBuildings.count) 个建筑（全部）")

        } catch {
            print("[BuildingManager] ❌ 加载建筑失败: \(error.localizedDescription)")
            throw BuildingError.databaseError(underlying: error)
        }
    }

    // MARK: - Delete

    /// 删除建筑
    func deleteBuilding(buildingId: String) async throws {
        do {
            try await supabase
                .from("player_buildings")
                .delete()
                .eq("id", value: buildingId)
                .execute()

            print("[BuildingManager] ✅ 删除建筑: \(buildingId)")

            // 从本地缓存移除
            playerBuildings.removeAll { $0.id == buildingId }

        } catch {
            print("[BuildingManager] ❌ 删除建筑失败: \(error.localizedDescription)")
            throw BuildingError.databaseError(underlying: error)
        }
    }

    // MARK: - Helper Methods

    /// 获取当前用户 ID
    private func getCurrentUserId() async throws -> String {
        let session = try await supabase.auth.session
        return session.user.id.uuidString
    }

    /// 获取指定领地的建筑数量统计
    func getBuildingCounts(for territoryId: String) -> [String: Int] {
        var counts: [String: Int] = [:]
        for building in playerBuildings where building.territoryId == territoryId {
            counts[building.templateId, default: 0] += 1
        }
        return counts
    }

    /// 获取指定领地的总效果值
    func getTotalEffects(for territoryId: String) -> [String: Double] {
        var effects: [String: Double] = [:]

        for building in playerBuildings where building.territoryId == territoryId && building.status == .active {
            guard let template = templates[building.templateId],
                  let buildingEffects = template.effects else { continue }

            for effect in buildingEffects {
                effects[effect.effectType, default: 0] += effect.value * Double(building.level)
            }
        }

        return effects
    }
}
