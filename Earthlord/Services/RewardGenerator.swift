//
//  RewardGenerator.swift
//  Earthlord
//
//  Created by Claude on 2026-01-12.
//
//  根据行走距离生成探索奖励
//

import Foundation

/// 奖励生成器
/// 负责根据探索距离计算奖励等级并生成随机物品
class RewardGenerator {

    // MARK: - Singleton

    static let shared = RewardGenerator()

    private init() {}

    // MARK: - Public Methods

    /// 根据距离确定奖励等级
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励等级
    func determineRewardTier(distance: Double) -> RewardTier {
        switch distance {
        case 0..<200:
            return .none
        case 200..<500:
            return .bronze
        case 500..<1000:
            return .silver
        case 1000..<2000:
            return .gold
        default:
            return .diamond
        }
    }

    /// 生成奖励物品
    /// - Parameters:
    ///   - tier: 奖励等级
    ///   - definitions: 可用的物品定义列表
    /// - Returns: 生成的物品列表
    func generateRewards(tier: RewardTier, definitions: [ItemDefinition]) -> [ItemLoot] {
        guard tier != .none else { return [] }

        let itemCount = tier.itemCount
        let probabilities = tier.rarityProbabilities

        // 按稀有度分类物品
        let commonItems = definitions.filter { $0.rarity == .common }
        let rareItems = definitions.filter { $0.rarity == .rare }
        let epicItems = definitions.filter { $0.rarity == .epic }

        var rewards: [ItemLoot] = []

        for _ in 0..<itemCount {
            // 掷骰子决定稀有度
            let roll = Double.random(in: 0..<1)

            var selectedItem: ItemDefinition?

            if roll < probabilities[0] {
                // Common
                selectedItem = commonItems.randomElement()
            } else if roll < probabilities[0] + probabilities[1] {
                // Rare
                selectedItem = rareItems.randomElement() ?? commonItems.randomElement()
            } else {
                // Epic
                selectedItem = epicItems.randomElement() ?? rareItems.randomElement() ?? commonItems.randomElement()
            }

            if let item = selectedItem {
                // 检查是否已经有这个物品，如果有则增加数量
                if let existingIndex = rewards.firstIndex(where: { $0.definitionId == item.id }) {
                    let existing = rewards[existingIndex]
                    rewards[existingIndex] = ItemLoot(
                        id: existing.id,
                        definitionId: existing.definitionId,
                        quantity: existing.quantity + 1,
                        quality: existing.quality
                    )
                } else {
                    // 新物品
                    rewards.append(ItemLoot(
                        id: UUID().uuidString,
                        definitionId: item.id,
                        quantity: 1,
                        quality: nil
                    ))
                }
            }
        }

        return rewards
    }

    /// 快捷方法：根据距离生成奖励
    /// - Parameters:
    ///   - distance: 行走距离（米）
    ///   - definitions: 可用的物品定义列表
    /// - Returns: (奖励等级, 物品列表)
    func generateRewardsForDistance(distance: Double, definitions: [ItemDefinition]) -> (tier: RewardTier, items: [ItemLoot]) {
        let tier = determineRewardTier(distance: distance)
        let items = generateRewards(tier: tier, definitions: definitions)
        return (tier, items)
    }
}
