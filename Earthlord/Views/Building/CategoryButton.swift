//
//  CategoryButton.swift
//  Earthlord
//
//  建筑分类筛选按钮组件
//

import SwiftUI

/// 建筑分类筛选按钮
struct CategoryButton: View {

    // MARK: - Properties

    let category: BuildingCategory?
    let isSelected: Bool
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 14))
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Properties

    private var iconName: String {
        if let category = category {
            return category.icon
        }
        return "square.grid.2x2.fill"
    }

    private var displayName: String {
        if let category = category {
            return category.displayName
        }
        return "全部"
    }
}

#Preview {
    HStack(spacing: 10) {
        CategoryButton(category: nil, isSelected: true, action: {})
        CategoryButton(category: .survival, isSelected: false, action: {})
        CategoryButton(category: .storage, isSelected: false, action: {})
    }
    .padding()
    .background(ApocalypseTheme.background)
}
