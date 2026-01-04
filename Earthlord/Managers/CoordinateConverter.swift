//
//  CoordinateConverter.swift
//  Earthlord
//
//  坐标转换工具 - 解决中国 GPS 偏移问题
//  WGS-84（GPS原始坐标） → GCJ-02（中国地图坐标）
//

import Foundation
import CoreLocation

/// 坐标转换工具类
/// 用于解决中国地图的坐标偏移问题（俗称"火星坐标系"）
struct CoordinateConverter {

    // MARK: - Constants

    /// 椭球参数
    private static let a: Double = 6378245.0           // 长半轴
    private static let ee: Double = 0.00669342162296594323  // 偏心率平方

    // MARK: - Public Methods

    /// 将 WGS-84 坐标转换为 GCJ-02 坐标
    /// - Parameter coordinate: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（中国地图坐标）
    static func wgs84ToGcj02(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果不在中国境内，不进行转换
        if !isInChina(coordinate) {
            return coordinate
        }

        // 计算偏移量
        var (dLat, dLon) = delta(coordinate.latitude, coordinate.longitude)

        // 应用偏移
        let gcjLat = coordinate.latitude + dLat
        let gcjLon = coordinate.longitude + dLon

        return CLLocationCoordinate2D(latitude: gcjLat, longitude: gcjLon)
    }

    /// 批量转换坐标数组
    /// - Parameter coordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func wgs84ToGcj02(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return coordinates.map { wgs84ToGcj02($0) }
    }

    // MARK: - Private Methods

    /// 判断坐标是否在中国境内
    /// - Parameter coordinate: 待判断的坐标
    /// - Returns: 是否在中国境内
    private static func isInChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // 粗略判断：经度 72.004 - 137.8347，纬度 0.8293 - 55.8271
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        if lon < 72.004 || lon > 137.8347 { return false }
        if lat < 0.8293 || lat > 55.8271 { return false }

        return true
    }

    /// 计算偏移量
    /// - Parameters:
    ///   - lat: 纬度
    ///   - lon: 经度
    /// - Returns: (纬度偏移, 经度偏移)
    private static func delta(_ lat: Double, _ lon: Double) -> (Double, Double) {
        let dLat = transformLat(lon - 105.0, lat - 35.0)
        let dLon = transformLon(lon - 105.0, lat - 35.0)

        let radLat = lat / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        let deltaLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Double.pi)
        let deltaLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * Double.pi)

        return (deltaLat, deltaLon)
    }

    /// 纬度转换函数
    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y
        ret += 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * Double.pi) + 320.0 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度转换函数
    private static func transformLon(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y
        ret += 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
        return ret
    }
}
