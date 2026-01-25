//
//  TerritoryToolbarView.swift
//  Earthlord
//
//  领地详情悬浮工具栏组件
//

import SwiftUI

/// 领地悬浮工具栏
struct TerritoryToolbarView: View {

    // MARK: - Properties

    let territoryName: String
    let onClose: () -> Void
    let onBuild: () -> Void
    let onTogglePanel: () -> Void
    let isPanelVisible: Bool

    // MARK: - Body

    var body: some View {
        HStack {
            // 关闭按钮
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }

            Spacer()

            // 领地名称
            Text(territoryName)
                .font(.headline)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)

            Spacer()

            // 工具按钮组
            HStack(spacing: 12) {
                // 建造按钮
                Button(action: onBuild) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(ApocalypseTheme.primary)
                        .clipShape(Circle())
                }

                // 面板切换按钮
                Button(action: onTogglePanel) {
                    Image(systemName: isPanelVisible ? "chevron.down" : "chevron.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.7), Color.clear]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

#Preview {
    ZStack {
        Color.gray
            .ignoresSafeArea()

        VStack {
            TerritoryToolbarView(
                territoryName: "我的领地",
                onClose: {},
                onBuild: {},
                onTogglePanel: {},
                isPanelVisible: true
            )

            Spacer()
        }
    }
}
