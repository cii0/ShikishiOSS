// Copyright 2022 Cii
//
// This file is part of Shikishi.
//
// Shikishi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shikishi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shikishi.  If not, see <http://www.gnu.org/licenses/>.

struct IntPoint {
    var x, y: Int
    
    init() {
        x = 0
        y = 0
    }
    init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }
}
extension IntPoint: Hashable {}
extension IntPoint: Protobuf {
    init(_ pb: PBIntPoint) throws {
        x = Int(pb.x)
        y = Int(pb.y)
    }
    var pb: PBIntPoint {
        PBIntPoint.with {
            $0.x = Int64(x)
            $0.y = Int64(y)
        }
    }
}
extension Array where Element == IntPoint {
    init(_ pb: PBIntPointArray) throws {
        self = try pb.value.map { try IntPoint($0) }
    }
    var pb: PBIntPointArray {
        PBIntPointArray.with { $0.value = map { $0.pb } }
    }
}
extension IntPoint: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        x = try container.decode(Int.self)
        y = try container.decode(Int.self)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
}
extension IntPoint {
    func double() -> Point {
        Point(x, y)
    }
    func cross(_ other: IntPoint) -> Int {
        x * other.y - y * other.x
    }
    static func + (lhs: IntPoint, rhs: IntPoint) -> IntPoint {
        IntPoint(lhs.x + rhs.x, lhs.y + rhs.y)
    }
    static func - (lhs: IntPoint, rhs: IntPoint) -> IntPoint {
        IntPoint(lhs.x - rhs.x, lhs.y - rhs.y)
    }
    func distanceSquared(_ other: IntPoint) -> Int {
        let x = self.x - other.x, y = self.y - other.y
        return x * x + y * y
    }
}

struct PolarPoint {
    var r = 0.0, theta = 0.0
}
extension PolarPoint: Hashable {}
extension PolarPoint: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        r = try container.decode(Double.self)
        theta = try container.decode(Double.self)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(r)
        try container.encode(theta)
    }
}
extension PolarPoint {
    init(_ r: Double, _ theta: Double) {
        self.r = r
        self.theta = theta
    }
    var rectangular: Point {
        r * Point(.cos(theta), .sin(theta))
    }
}

typealias Float4 = SIMD4<Float>
typealias Double4 = SIMD4<Double>
typealias Double3 = SIMD3<Double>
typealias Double2 = SIMD2<Double>
typealias Point = SIMD2<Double>

extension SIMD2: Serializable where Scalar == Double {}

extension Point: Protobuf {
    init(_ pb: PBPoint) throws {
        self.init(try pb.x.notNaN(), try pb.y.notNaN())
    }
    var pb: PBPoint {
        PBPoint.with {
            $0.x = x
            $0.y = y
        }
    }
}
extension Point: AppliableTransform {
    static func * (lhs: Point, rhs: Transform) -> Point {
        Point(lhs.normalizedDouble3 * rhs)
    }
}
extension Point: Interpolatable {
    static func linear(_ f0: Point, _ f1: Point, t: Double) -> Point {
        Point(Double.linear(f0.x, f1.x, t: t),
              Double.linear(f0.y, f1.y, t: t))
    }
    static func firstSpline(_ f1: Point,
                            _ f2: Point, _ f3: Point, t: Double) -> Point {
        Point(Double.firstSpline(f1.x, f2.x, f3.x, t: t),
              Double.firstSpline(f1.y, f2.y, f3.y, t: t))
    }
    static func spline(_ f0: Point, _ f1: Point,
                       _ f2: Point, _ f3: Point, t: Double) -> Point {
        Point(Double.spline(f0.x, f1.x, f2.x, f3.x, t: t),
              Double.spline(f0.y, f1.y, f2.y, f3.y, t: t))
    }
    static func lastSpline(_ f0: Point, _ f1: Point,
                           _ f2: Point, t: Double) -> Point {
        Point(Double.lastSpline(f0.x, f1.x, f2.x, t: t),
              Double.lastSpline(f0.y, f1.y, f2.y, t: t))
    }
}
extension Point {
    init(_ x: Int, _ y: Int) {
        self.init(Double(x), Double(y))
    }
    init(_ double3: Double3) {
        self.init(double3.x, double3.y)
    }
    init(distance r: Double, angle: Double) {
        self.init(r * .cos(angle), r * .sin(angle))
    }
    init(unitWithAngle angle: Double) {
        self.init(.cos(angle), .sin(angle))
    }
    
    var normalizedDouble3: Double3 { Double3(x, y, 1) }
    var normalizedDouble4: Double4 { Double4(x, y, 0, 1) }
    var normalizedFloat4: Float4 { Float4(Float(x), Float(y), 0, 1) }
    
    var polar: PolarPoint {
        PolarPoint(length(), angle())
    }
    var isEmpty: Bool {
        x == 0 && y == 0
    }
    func mid(_ other: Point) -> Point {
        (self + other) / 2
    }
    func isApproximatelyEqual(_ other: Point,
                              tolerance: Double = .ulpOfOne) -> Bool {
        x.isApproximatelyEqual(other.x, tolerance: tolerance)
            && y.isApproximatelyEqual(other.y, tolerance: tolerance)
    }
    func distance(_ other: Point) -> Double {
        (other - self).length()
    }
    func distanceSquared(_ other: Point) -> Double {
        (other - self).lengthSquared()
    }
    func angle() -> Double {
        .atan2(y: y, x: x)
    }
    func angle(_ other: Point) -> Double {
        (other - self).angle()
    }
    func length() -> Double {
        .sqrt((self * self).sum())
    }
    func lengthSquared() -> Double {
        (self * self).sum()
    }
    func dot(_ other: Point) -> Double {
        (self * other).sum()
    }
    func cross(_ other: Point) -> Double {
        x * other.y - y * other.x
    }
    func perpendicularDeltaPoint(withDistance distance: Double) -> Point {
        if self == Point() {
            return Point(distance, 0)
        } else {
            let r = distance / length()
            return r * Point(-y, x)
        }
    }
    func movedWith(distance: Double, angle: Double) -> Point {
        self + distance * Point(.cos(angle), .sin(angle))
    }
    func movedRoundedWith(distance: Double, angle: Double) -> Point {
        if angle.isApproximatelyEqual(.pi)
            || angle.isApproximatelyEqual(-.pi) {
            
            return Point(x - distance, y)
        } else if angle.isApproximatelyEqual(.pi / 2)
                    || angle.isApproximatelyEqual(-.pi * 3 / 2) {
            return Point(x, y + distance)
        } else if angle.isApproximatelyEqual(-.pi / 2)
                    || angle.isApproximatelyEqual(.pi * 3 / 2) {
            return Point(x, y - distance)
        } else if angle.isApproximatelyEqual(0)
                    || angle.isApproximatelyEqual(.pi * 2)
                    || angle.isApproximatelyEqual(-.pi * 2) {
            return Point(x + distance, y)
        } else {
            return self + distance * Point(.cos(angle), .sin(angle))
        }
    }
    static func ccw(_ p0: Point, _ p1: Point, _ p2: Point) -> Double {
        (p1 - p0).cross(p2 - p1)
    }
    static func differenceAngle(_ p0: Point, _ p1: Point,
                                _ p2: Point) -> Double {
        differenceAngle(p1 - p0, p2 - p1)
    }
    static func differenceAngle(_ a: Point, _ b: Point) -> Double {
        .atan2(y: a.cross(b), x: a.dot(b))
    }
    static func isConvex(_ p0: Point, _ p1: Point, _ p2: Point) -> Bool {
        (p2.y - p0.y) * (p1.x - p0.x) - (p2.x - p0.x) * (p1.y - p0.y) > 0
    }
    func isBelow(_ other: Point) -> Bool {
        y < other.y || (y == other.y && x < other.x)
    }
    func inverted() -> Point {
        Point(y, x)
    }
    
    mutating func round(_ rule: FloatingPointRoundingRule
                            = .toNearestOrAwayFromZero) {
        self = rounded(rule)
    }
    func rounded(_ rule: FloatingPointRoundingRule
                    = .toNearestOrAwayFromZero) -> Point {
        Point(x.rounded(rule), y.rounded(rule))
    }
    mutating func round(decimalPlaces: Int) {
        self = Point(x.rounded(decimalPlaces: decimalPlaces),
                     y.rounded(decimalPlaces: decimalPlaces))
    }
    func rounded(decimalPlaces: Int) -> Point {
        Point(x.rounded(decimalPlaces: decimalPlaces),
              y.rounded(decimalPlaces: decimalPlaces))
    }
    func interval(scale: Double) -> Point {
        Point(x.interval(scale: scale),
              y.interval(scale: scale))
    }
    
    var isInteger: Bool {
        length().isInteger
    }
    static func isUpLeft(_ p0: Point, _ p1: Point) -> Bool {
        p0.y == p1.y ? p0.x < p1.x : p0.y > p1.y
    }
    
    static func ** (lhs: Point, rhs: Double) -> Point {
        Point(lhs.x ** rhs, lhs.y ** rhs)
    }
    
    func notInfinite() throws -> Point {
        if x.isInfinite || y.isInfinite {
            throw ProtobufError()
        } else {
            return self
        }
    }
}
extension Array where Element == Point {
    static func circle(centerPosition cp: Point = Point(),
                       radius r: Double = 50,
                       firstAngle: Double = .pi / 2,
                       count: Int) -> [Point] {
        var angle = firstAngle, theta = (2 * .pi) / Double(count)
        return (0..<count).map { _ in
            let p = cp.movedWith(distance: r, angle: angle)
            angle += theta
            return p
        }
    }
    var bounds: Rect? {
        guard let fp = first else { return nil }
        var aabb = AABB(fp)
        for p in self {
            aabb += p
        }
        return aabb.rect
    }
}

enum CrossDirection: Int8 {
    case left, straight, right
    init(_ v: Double) {
        if v > 0 {
            self = .left
        } else if v < 0 {
            self = .right
        } else {
            self = .straight
        }
    }
}
extension CrossDirection: Hashable, Codable {}
