//
//  MainTabView.swift
//  Earthlord
//
//  Created by Claude Code on 2025/12/24.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var languageManager = LanguageManager.shared
    @State private var refreshID = UUID()

    init() {
        // 自定义 TabBar 外观
        let appearance = UITabBarAppearance()

        // 设置背景为深色
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)

        // 设置未选中状态的图标和文字颜色（灰色）
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.gray
        ]

        // 设置选中状态的图标和文字颜色（橙色）
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 1.0, green: 0.45, blue: 0.15, alpha: 1.0)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 1.0, green: 0.45, blue: 0.15, alpha: 1.0)
        ]

        // 应用外观配置
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MapTabView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("地图".localized)
                }
                .tag(0)

            TerritoryTabView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text("领地".localized)
                }
                .tag(1)

            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("个人".localized)
                }
                .tag(2)

            MoreTabView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("更多".localized)
                }
                .tag(3)
        }
        .accentColor(ApocalypseTheme.primary)
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            print("🌍 MainTabView 收到语言切换通知，刷新界面")
            refreshID = UUID()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}
