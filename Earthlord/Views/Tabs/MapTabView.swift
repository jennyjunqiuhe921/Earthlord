//
//  MapTabView.swift
//  Earthlord
//
//  Created by Claude Code on 2025/12/24.
//

import SwiftUI

struct MapTabView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @State private var refreshID = UUID()

    var body: some View {
        PlaceholderView(
            icon: "map.fill",
            title: "地图",
            subtitle: "探索和圈占领地"
        )
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            print("🌍 MapTabView 收到语言切换通知，刷新界面")
            refreshID = UUID()
        }
    }
}

#Preview {
    MapTabView()
}
