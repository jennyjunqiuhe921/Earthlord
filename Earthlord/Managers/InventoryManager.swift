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
            supabaseKey: "sb_publishable_ddDdaU8v_cxisWA6TiHDuA_BHAdLp-R"
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

    // MARK: - Private Methods

    /// 获取当前用户ID
    private func getCurrentUserId() async throws -> String {
        let session = try await supabase.auth.session
        return session.user.id.uuidString
    }

    /// 添加单个物品（处理堆叠逻辑）
    private func addSingleItem(_ item: ItemLoot, userId: String) async throws {
        // 查找是否已有该物品
        let existing: [InventoryItemDB] = try await supabase
            .from("inventory_items")
            .select()
            .eq("user_id", value: userId)
            .eq("item_definition_id", value: item.definitionId)
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
                    try await insertNewItem(item.definitionId, quantity: overflow, userId: userId)
                }
            }
        } else {
            // 插入新物品
            try await insertNewItem(item.definitionId, quantity: item.quantity, userId: userId)
        }
    }

    /// 插入新物品记录
    private func insertNewItem(_ definitionId: String, quantity: Int, userId: String) async throws {
        let insert = InventoryItemInsert(
            userId: userId,
            itemDefinitionId: definitionId,
            quantity: quantity,
            quality: nil
        )

        try await supabase
            .from("inventory_items")
            .insert(insert)
            .execute()

        print("📦 插入新物品: \(definitionId) x\(quantity)")
    }
}
