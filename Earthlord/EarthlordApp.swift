//
//  EarthlordApp.swift
//  Earthlord
//
//  Created by gong on 2025/12/23.
//

import SwiftUI
import GoogleSignIn

@main
struct EarthlordApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    print("🔗 收到 URL callback: \(url)")
                    // 处理 Google Sign In 的 URL callback
                    GIDSignIn.sharedInstance.handle(url)
                    print("✅ Google Sign In URL callback 已处理")
                }
        }
    }
}
