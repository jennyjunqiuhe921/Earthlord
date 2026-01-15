//
//  RootView.swift
//  Earthlord
//
//  Created by Claude Code on 2025/12/24.
//

import SwiftUI

/// 根视图：控制启动页、认证页与主界面的切换
struct RootView: View {
    /// 认证管理器
    @StateObject private var authManager = AuthManager()

    /// 语言管理器
    @StateObject private var languageManager = LanguageManager.shared

    /// 位置管理器（全局共享）
    @StateObject private var locationManager = LocationManager()

    /// 领地管理器（全局共享）
    @StateObject private var territoryManager = TerritoryManager()

    /// 背包管理器（全局共享）
    @StateObject private var inventoryManager = InventoryManager()

    /// 探索管理器（全局共享）
    @StateObject private var explorationManager = ExplorationManager()

    /// 玩家位置管理器（全局共享）
    @StateObject private var playerLocationManager = PlayerLocationManager()

    /// 启动页是否完成
    @State private var splashFinished = false

    var body: some View {
        ZStack {
            if !splashFinished {
                // 启动页
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            } else if authManager.isAuthenticated {
                // 已认证 - 显示主页面
                MainTabView()
                    .environmentObject(authManager)
                    .environmentObject(locationManager)
                    .environmentObject(territoryManager)
                    .environmentObject(inventoryManager)
                    .environmentObject(explorationManager)
                    .environmentObject(playerLocationManager)
                    .transition(.opacity)
                    .onAppear {
                        // 设置探索管理器的背包管理器引用
                        explorationManager.setInventoryManager(inventoryManager)
                        // 设置探索管理器的玩家位置管理器引用
                        explorationManager.setPlayerLocationManager(playerLocationManager)
                    }
            } else {
                // 未认证 - 显示认证页面
                AuthView()
                    .environmentObject(authManager)
                    .transition(.opacity)
            }
        }
        .environment(\.locale, languageManager.currentLocale)
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .task {
            // 应用启动时检查用户会话
            await authManager.checkSession()
        }
    }
}

#Preview {
    RootView()
}
