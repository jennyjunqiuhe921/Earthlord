//
//  TerritoryTabView.swift
//  Earthlord
//
//  Created by Claude Code on 2025/12/24.
//

import SwiftUI

struct TerritoryTabView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @State private var refreshID = UUID()

    var body: some View {
        PlaceholderView(
            icon: "flag.fill",
            title: "领地",
            subtitle: "管理你的领地"
        )
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            print("🌍 TerritoryTabView 收到语言切换通知，刷新界面")
            refreshID = UUID()
        }
    }
}

#Preview {
    TerritoryTabView()
}
