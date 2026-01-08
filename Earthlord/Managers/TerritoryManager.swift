import Foundation
import CoreLocation
import Combine
import Supabase

class TerritoryManager: ObservableObject {

    // MARK: - Properties

    private let supabase: SupabaseClient
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Data Structures

    /// 领地上传数据结构
    private struct TerritoryUpload: Encodable {
        let userId: String
        let path: [[String: Double]]
        let polygon: String
        let bboxMinLat: Double
        let bboxMaxLat: Double
        let bboxMinLon: Double
        let bboxMaxLon: Double
        let area: Double
        let pointCount: Int
        let startedAt: String
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case path
            case polygon
            case bboxMinLat = "bbox_min_lat"
            case bboxMaxLat = "bbox_max_lat"
            case bboxMinLon = "bbox_min_lon"
            case bboxMaxLon = "bbox_max_lon"
            case area
            case pointCount = "point_count"
            case startedAt = "started_at"
            case isActive = "is_active"
        }
    }

    // MARK: - Initialization

    init(supabaseClient: SupabaseClient? = nil) {
        if let client = supabaseClient {
            self.supabase = client
        } else {
            self.supabase = SupabaseClient(
                supabaseURL: URL(string: "https://acnriuoexalqvckiuvgr.supabase.co")!,
                supabaseKey: "sb_publishable_ddDdaU8v_cxisWA6TiHDuA_BHAdLp-R"
            )
        }
    }

    // MARK: - Helper Methods

    /// 将坐标数组转换为 path JSON 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: [{"lat": x, "lon": y}, ...] 格式的数组
    private func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coordinate in
            [
                "lat": coordinate.latitude,
                "lon": coordinate.longitude
            ]
        }
    }

    /// 将坐标数组转换为 WKT 格式的多边形
    /// - Parameter coordinates: 坐标数组
    /// - Returns: WKT 格式字符串，例如 SRID=4326;POLYGON((lon lat, lon lat, ...))
    ///
    /// 注意：
    /// - WKT 格式是「经度在前，纬度在后」
    /// - 多边形必须闭合（首尾坐标相同）
    private func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        // 确保多边形闭合
        var coords = coordinates
        if let first = coords.first, let last = coords.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                coords.append(first) // 添加首点到末尾，形成闭合
            }
        }

        // 构建 WKT 坐标对（经度在前，纬度在后）
        let wktCoords = coords.map { "\($0.longitude) \($0.latitude)" }.joined(separator: ", ")

        return "SRID=4326;POLYGON((\(wktCoords)))"
    }

    /// 计算坐标数组的边界框
    /// - Parameter coordinates: 坐标数组
    /// - Returns: (minLat, maxLat, minLon, maxLon)
    private func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - Public Methods

    /// 上传领地到数据库（带幂等性检查）
    /// - Parameters:
    ///   - coordinates: 领地边界坐标数组
    ///   - area: 领地面积（平方米）
    ///   - startTime: 圈地开始时间
    /// - Throws: 上传失败时抛出错误
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        print("📤 开始上传领地...")
        isLoading = true
        errorMessage = nil

        do {
            // 获取当前用户
            let session = try await supabase.auth.session
            let userId = session.user.id
            print("✅ 获取用户 ID: \(userId)")

            // ⚠️ 幂等性检查：检查是否已存在相同开始时间的领地
            let startTimeString = ISO8601DateFormatter().string(from: startTime)
            print("🔍 检查重复领地 (started_at: \(startTimeString))...")

            let existingTerritories: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("started_at", value: startTimeString)
                .execute()
                .value

            if !existingTerritories.isEmpty {
                print("⚠️ 检测到重复领地，已存在 \(existingTerritories.count) 个相同的领地")
                TerritoryLogger.shared.log("领地已存在，跳过上传", type: .info)
                isLoading = false
                return // 已存在，直接返回成功
            }

            // 转换数据格式
            let pathJSON = coordinatesToPathJSON(coordinates)
            let wktPolygon = coordinatesToWKT(coordinates)
            let bbox = calculateBoundingBox(coordinates)

            print("📊 领地数据:")
            print("  - 坐标点数: \(coordinates.count)")
            print("  - 面积: \(area) m²")
            print("  - 边界框: lat[\(bbox.minLat), \(bbox.maxLat)], lon[\(bbox.minLon), \(bbox.maxLon)]")

            // 构建上传数据
            let territoryData = TerritoryUpload(
                userId: userId.uuidString,
                path: pathJSON,
                polygon: wktPolygon,
                bboxMinLat: bbox.minLat,
                bboxMaxLat: bbox.maxLat,
                bboxMinLon: bbox.minLon,
                bboxMaxLon: bbox.maxLon,
                area: area,
                pointCount: coordinates.count,
                startedAt: startTimeString,
                isActive: true
            )

            // 上传到 Supabase
            print("🚀 正在上传到数据库...")
            try await supabase
                .from("territories")
                .insert(territoryData)
                .execute()

            print("✅ 领地上传成功！")
            TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)
            isLoading = false

        } catch {
            let errorDesc = error.localizedDescription
            print("❌ 上传失败: \(errorDesc)")
            TerritoryLogger.shared.log("领地上传失败: \(errorDesc)", type: .error)
            errorMessage = "上传失败: \(errorDesc)"
            isLoading = false
            throw error
        }
    }

    /// 加载所有活跃的领地（带重试机制）
    /// - Parameters:
    ///   - maxRetries: 最大重试次数（默认2次）
    /// - Returns: Territory 对象数组
    /// - Throws: 加载失败时抛出错误
    func loadAllTerritories(maxRetries: Int = 2) async throws -> [Territory] {
        print("📥 开始加载领地...")
        isLoading = true
        errorMessage = nil

        var lastError: Error?

        // 重试循环
        for attempt in 1...maxRetries {
            do {
                if attempt > 1 {
                    print("🔄 第 \(attempt) 次尝试加载...")
                    // 等待一段时间再重试（0.5秒、1秒）
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
                }

                // 查询 is_active = true 的领地
                let response: [Territory] = try await supabase
                    .from("territories")
                    .select()
                    .eq("is_active", value: true)
                    .execute()
                    .value

                print("✅ 加载成功，共 \(response.count) 个领地")
                isLoading = false
                return response

            } catch {
                lastError = error
                print("❌ 第 \(attempt) 次加载失败: \(error.localizedDescription)")

                // 如果是最后一次尝试，不再重试
                if attempt == maxRetries {
                    errorMessage = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                    throw error
                }
            }
        }

        // 如果到这里说明所有重试都失败了
        isLoading = false
        if let error = lastError {
            throw error
        }

        return [] // 默认返回空数组
    }

    /// 加载我的领地（带重试机制）
    /// - Parameters:
    ///   - maxRetries: 最大重试次数（默认2次）
    /// - Returns: 当前用户的领地数组
    /// - Throws: 加载失败时抛出错误
    func loadMyTerritories(maxRetries: Int = 2) async throws -> [Territory] {
        print("📥 开始加载我的领地...")
        isLoading = true
        errorMessage = nil

        var lastError: Error?

        // 重试循环
        for attempt in 1...maxRetries {
            do {
                if attempt > 1 {
                    print("🔄 第 \(attempt) 次尝试加载...")
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
                }

                // 获取当前用户
                guard let userId = try? await supabase.auth.session.user.id else {
                    throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])
                }

                // 查询当前用户的活跃领地，按创建时间倒序
                let response: [Territory] = try await supabase
                    .from("territories")
                    .select()
                    .eq("user_id", value: userId.uuidString)
                    .eq("is_active", value: true)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                print("✅ 加载我的领地成功，共 \(response.count) 个")
                isLoading = false
                return response

            } catch {
                lastError = error
                print("❌ 第 \(attempt) 次加载失败: \(error.localizedDescription)")

                if attempt == maxRetries {
                    errorMessage = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                    throw error
                }
            }
        }

        isLoading = false
        if let error = lastError {
            throw error
        }

        return []
    }

    /// 删除领地
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 删除是否成功
    func deleteTerritory(territoryId: String) async -> Bool {
        print("🗑️ 开始删除领地: \(territoryId)")
        isLoading = true
        errorMessage = nil

        do {
            try await supabase
                .from("territories")
                .delete()
                .eq("id", value: territoryId)
                .execute()

            print("✅ 领地删除成功")
            TerritoryLogger.shared.log("领地删除成功：ID \(territoryId)", type: .info)
            isLoading = false
            return true

        } catch {
            print("❌ 领地删除失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log("领地删除失败: \(error.localizedDescription)", type: .error)
            errorMessage = "删除失败: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
}
