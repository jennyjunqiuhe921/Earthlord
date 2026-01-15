//
//  POIProximityPopup.swift
//  Earthlord
//
//  Created by Claude on 2026-01-13.
//
//  接近 POI 时的弹窗提示
//

import SwiftUI
import CoreLocation

/// 接近 POI 弹窗
/// 当玩家进入 POI 50 米范围内时显示
struct POIProximityPopup: View {

    // MARK: - Properties

    /// 当前接近的 POI
    let poi: POI

    /// 当前距离（米）
    let distance: Double

    /// 搜刮回调
    let onScavenge: () -> Void

    /// 关闭回调
    let onDismiss: () -> Void

    // MARK: - State

    @State private var isAnimating = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖动指示器
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)

            // POI 信息卡片
            VStack(spacing: 16) {
                // 图标和标题
                HStack(spacing: 16) {
                    // 类型图标
                    ZStack {
                        Circle()
                            .fill(poiColor.opacity(0.2))
                            .frame(width: 64, height: 64)

                        Image(systemName: poi.iconName)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(poiColor)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                    }

                    // 名称和距离
                    VStack(alignment: .leading, spacing: 6) {
                        Text("发现废墟")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(poi.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                            Text("距离 \(Int(distance)) 米")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(ApocalypseTheme.info)
                    }

                    Spacer()
                }

                // 描述
                Text(poi.description)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                // 危险等级
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(dangerColor)

                    Text("危险等级: \(dangerText)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(dangerColor)

                    Spacer()

                    // 物资标签
                    if poi.hasLoot {
                        HStack(spacing: 4) {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 12))
                            Text("有物资")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ApocalypseTheme.warning.opacity(0.2))
                        .foregroundColor(ApocalypseTheme.warning)
                        .cornerRadius(8)
                    }
                }

                // 分隔线
                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 按钮组
                HStack(spacing: 12) {
                    // 稍后再说按钮
                    Button(action: onDismiss) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 16))
                            Text("稍后再说")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1.5)
                        )
                    }

                    // 立即搜刮按钮
                    Button(action: onScavenge) {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.point.up.fill")
                                .font(.system(size: 16))
                            Text("立即搜刮")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [poiColor, poiColor.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: poiColor.opacity(0.3), radius: 8, y: 4)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.2), radius: 20, y: -5)
        .onAppear {
            isAnimating = true
            // 触发震动反馈
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
        }
    }

    // MARK: - Computed Properties

    /// POI 类型颜色
    private var poiColor: Color {
        switch poi.type {
        case .supermarket:
            return ApocalypseTheme.success
        case .hospital:
            return ApocalypseTheme.danger
        case .pharmacy:
            return Color.purple
        case .gasStation:
            return Color.orange
        case .restaurant:
            return Color.yellow
        default:
            return ApocalypseTheme.info
        }
    }

    /// 危险等级颜色
    private var dangerColor: Color {
        switch poi.dangerLevel {
        case 1:
            return Color.green
        case 2:
            return Color.yellow
        case 3:
            return Color.orange
        case 4:
            return Color.red
        case 5:
            return Color.purple
        default:
            return Color.gray
        }
    }

    /// 危险等级文字
    private var dangerText: String {
        switch poi.dangerLevel {
        case 1:
            return "安全"
        case 2:
            return "低危"
        case 3:
            return "中危"
        case 4:
            return "高危"
        case 5:
            return "极危"
        default:
            return "未知"
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.5)
            .ignoresSafeArea()

        VStack {
            Spacer()

            POIProximityPopup(
                poi: POI(
                    id: "test",
                    name: "废弃的沃尔玛超市",
                    type: .supermarket,
                    coordinate: CLLocationCoordinate2D(latitude: 22.54, longitude: 114.06),
                    status: .discovered,
                    hasLoot: true,
                    description: "这里曾经是繁忙的购物场所，现在货架上或许还残留着一些物资。",
                    dangerLevel: 2
                ),
                distance: 35,
                onScavenge: { print("搜刮") },
                onDismiss: { print("关闭") }
            )
        }
    }
}
