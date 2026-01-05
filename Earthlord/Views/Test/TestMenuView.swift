//
//  TestMenuView.swift
//  Earthlord
//
//  开发测试入口菜单 - 包含 Supabase 测试和圈地测试
//

import SwiftUI

struct TestMenuView: View {

    // MARK: - Body

    var body: some View {
        List {
            // Supabase 连接测试
            NavigationLink(destination: SupabaseTestView()) {
                HStack(spacing: 15) {
                    Image(systemName: "server.rack")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Supabase 连接测试")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("测试数据库连接和认证功能")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // 圈地功能测试
            NavigationLink(destination: TerritoryTestView()) {
                HStack(spacing: 15) {
                    Image(systemName: "map.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("圈地功能测试")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("查看圈地追踪的实时日志")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("开发测试")
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ApocalypseTheme.background)
    }
}

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
