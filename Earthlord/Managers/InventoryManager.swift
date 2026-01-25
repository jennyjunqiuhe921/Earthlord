//
//  InventoryManager.swift
//  Earthlord
//
//  Created by Claude on 2026-01-12.
//
//  管理用户背包数据，与 Supabase 同步
//

import Foundation
import Combine
import Supabase

/// 背包管理器
/// 负责用户背包的加载、添加、更新操作
@MainActor
class InventoryManager: ObservableObject {

    // MARK: - Published Properties

    /// 用户背包物品列表
    @Published var inventoryItems: [InventoryItem] = []

    /// 物品定义缓存
    @Published var itemDefinitions: [String: ItemDefinition] = [:]

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误消息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let supabase: SupabaseClient

    // MARK: - Initialization

    init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://acnriuoexalqvckiuvgr.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFjbnJpdW9leGFscXZja2l1dmdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5NTQzNDUsImV4cCI6MjA4MTUzMDM0NX0.cOTtYT-dnBDLNKFzFh3pIU6H1W0hksl3sdgdWiqOjIM"
        )
    }

    // MARK: - Public Methods

    /// 加载物品定义
    func loadItemDefinitions() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [ItemDefinitionDB] = try await supabase
                .from("item_definitions")
                .select()
                .execute()
                .value

            // 转换并缓存
            var definitions: [String: ItemDefinition] = [:]
            for dbItem in response {
                let definition = dbItem.toItemDefinition()
                definitions[definition.id] = definition
            }
            self.itemDefinitions = definitions

            print("✅ 加载了 \(definitions.count) 个物品定义")
        } catch {
            print("❌ 加载物品定义失败: \(error.localizedDescription)")
            throw error
        }
    }

    /// 加载用户背包
    func loadInventory() async throws {
        guard let userId = try? await getCurrentUserId() else {
            print("❌ 无法获取用户ID")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // 确保物品定义已加载
            if itemDefinitions.isEmpty {
                try await loadItemDefinitions()
            }

            let response: [InventoryItemDB] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            // 转换
            self.inventoryItems = response.map { $0.toInventoryItem() }

            print("✅ 加载了 \(inventoryItems.count) 个背包物品")
        } catch {
            print("❌ 加载背包失败: \(error.localizedDescription)")
            errorMessage = "加载背包失败: \(error.localizedDescription)"
            throw error
        }
    }

    /// 添加物品到背包（支持堆叠）
    /// - Parameter items: 要添加的物品列表
    func addItems(_ items: [ItemLoot]) async throws {
        guard let userId = try? await getCurrentUserId() else {
            throw NSError(domain: "InventoryManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取用户ID"])
        }

        for item in items {
            try await addSingleItem(item, userId: userId)
        }

        // 重新加载背包
        try await loadInventory()
    }

    /// 获取物品定义
    /// - Parameter itemId: 物品ID
    /// - Returns: 物品定义（如果存在）
    func getDefinition(for itemId: String) -> ItemDefinition? {
        return itemDefinitions[itemId]
    }

    /// 获取所有物品定义列表
    func getAllDefinitions() -> [ItemDefinition] {
        return Array(itemDefinitions.values)
    }

    /// 使用物品（减少数量，数量为0时删除）
    /// - Parameters:
    ///   - item: 要使用的物品
    ///   - quantity: 使用数量（默认1）
    /// - Returns: 是否使用成功
    @discardableResult
    func useItem(_ item: InventoryItem, quantity: Int = 1) async throws -> Bool {
        guard quantity > 0 && quantity <= item.quantity else {
            print("❌ 使用数量无效: 请求 \(quantity), 可用 \(item.quantity)")
            return false
        }

        let newQuantity = item.quantity - quantity

        if newQuantity > 0 {
            // 更新数量
            let update = InventoryItemUpdate(
                quantity: newQuantity,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase
                .from("inventory_items")
                .update(update)
                .eq("id", value: item.id)
                .execute()

            print("✅ 使用物品成功: \(item.definitionId), 剩余 \(newQuantity)")
        } else {
            // 删除物品
            try await supabase
                .from("inventory_items")
                .delete()
                .eq("id", value: item.id)
                .execute()

            print("✅ 物品已用尽并删除: \(item.definitionId)")
        }

        // 刷新本地数据
        try await loadInventory()

        return true
    }

    /// 删除物品
    /// - Parameter item: 要删除的物品
    func deleteItem(_ item: InventoryItem) async throws {
        try await supabase
            .from("inventory_items")
            .delete()
            .eq("id", value: item.id)
            .execute()

        print("🗑️ 删除物品: \(item.definitionId)")

        // 刷新本地数据
        try await loadInventory()
    }

    // MARK: - Private Methods

    /// 获取当前用户ID
    private func getCurrentUserId() async throws -> String {
        let session = try await supabase.auth.session
        return session.user.id.uuidString
    }

    /// 添加单个物品（处理堆叠逻辑）
    private func addSingleItem(_ item: ItemLoot, userId: String) async throws {
        // AI 生成的物品（有自定义名称）不堆叠，每个都是独立的
        if item.customName != nil {
            try await insertNewItem(item, userId: userId)
            return
        }

        // 普通物品：查找是否已有该物品
        let existing: [InventoryItemDB] = try await supabase
            .from("inventory_items")
            .select()
            .eq("user_id", value: userId)
            .eq("item_definition_id", value: item.definitionId)
            .is("custom_name", value: nil)  // 只查找没有自定义名称的物品
            .execute()
            .value

        if let existingItem = existing.first {
            // 更新数量
            let newQuantity = existingItem.quantity + item.quantity
            let maxStack = itemDefinitions[item.definitionId]?.maxStack ?? 99

            if newQuantity <= maxStack {
                // 直接更新
                let update = InventoryItemUpdate(
                    quantity: newQuantity,
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )

                try await supabase
                    .from("inventory_items")
                    .update(update)
                    .eq("id", value: existingItem.id)
                    .execute()

                print("📦 更新物品数量: \(item.definitionId) -> \(newQuantity)")
            } else {
                // 超过最大堆叠，先更新到最大值
                let update = InventoryItemUpdate(
                    quantity: maxStack,
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )

                try await supabase
                    .from("inventory_items")
                    .update(update)
                    .eq("id", value: existingItem.id)
                    .execute()

                // 溢出部分作为新物品
                let overflow = newQuantity - maxStack
                if overflow > 0 {
                    let overflowItem = ItemLoot(
                        id: UUID().uuidString,
                        definitionId: item.definitionId,
                        quantity: overflow,
                        quality: item.quality
                    )
                    try await insertNewItem(overflowItem, userId: userId)
                }
            }
        } else {
            // 插入新物品
            try await insertNewItem(item, userId: userId)
        }
    }

    /// 插入新物品记录（支持 AI 自定义字段）
    private func insertNewItem(_ item: ItemLoot, userId: String) async throws {
        let insert = InventoryItemInsert(
            userId: userId,
            itemDefinitionId: item.definitionId,
            quantity: item.quantity,
            quality: item.quality?.rawValue,
            customName: item.customName,
            customStory: item.customStory,
            customCategory: item.customCategory,
            customRarity: item.customRarity
        )

        try await supabase
            .from("inventory_items")
            .insert(insert)
            .execute()

        if let customName = item.customName {
            print("📦 插入AI物品: \(customName) (定义: \(item.definitionId)) x\(item.quantity)")
        } else {
            print("📦 插入新物品: \(item.definitionId) x\(item.quantity)")
        }
    }

    // MARK: - Debug Methods

    /// 添加测试建造资源（100 木头 + 100 石头）
    /// 仅用于测试建造系统
    func addTestBuildingResources() async throws {
        guard let userId = try? await getCurrentUserId() else {
            throw NSError(domain: "InventoryManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取用户ID"])
        }

        print("🧪 开始添加测试建造资源...")

        // 确保物品定义已加载
        if itemDefinitions.isEmpty {
            try await loadItemDefinitions()
        }

        var addedItems: [String] = []

        // 尝试添加木头
        if itemDefinitions["item_wood"] != nil {
            let woodItem = ItemLoot(id: UUID().uuidString, definitionId: "item_wood", quantity: 100, quality: nil)
            try await addSingleItem(woodItem, userId: userId)
            addedItems.append("100 木头")
            print("📦 已添加 100 木头")
        } else {
            print("⚠️ 木头物品定义不存在，跳过")
        }

        // 尝试添加石头
        if itemDefinitions["item_stone"] != nil {
            let stoneItem = ItemLoot(id: UUID().uuidString, definitionId: "item_stone", quantity: 100, quality: nil)
            try await addSingleItem(stoneItem, userId: userId)
            addedItems.append("100 石头")
            print("📦 已添加 100 石头")
        } else {
            print("⚠️ 石头物品定义不存在，跳过")
        }

        if addedItems.isEmpty {
            throw NSError(domain: "InventoryManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "木头和石头的物品定义都不存在，请先在数据库中添加"])
        }

        // 重新加载背包
        try await loadInventory()

        print("✅ 测试建造资源已添加: \(addedItems.joined(separator: " + "))")
    }
}

