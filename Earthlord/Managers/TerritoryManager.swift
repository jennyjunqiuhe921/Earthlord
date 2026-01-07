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

    /// 上传领地到数据库
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
                startedAt: ISO8601DateFormatter().string(from: startTime),
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
            print("❌ 上传失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            errorMessage = "上传失败: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }

    /// 加载所有活跃的领地
    /// - Returns: Territory 对象数组
    /// - Throws: 加载失败时抛出错误
    func loadAllTerritories() async throws -> [Territory] {
        print("📥 开始加载领地...")
        isLoading = true
        errorMessage = nil

        do {
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
            print("❌ 加载失败: \(error.localizedDescription)")
            errorMessage = "加载失败: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }
}
