// Copyright 2021 Cii
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

struct Edge: Hashable {
    var p0, p1: Point
    
    init() {
        p0 = Point()
        p1 = Point()
    }
    init(_ p0: Point, _ p1: Point) {
        self.p0 = p0
        self.p1 = p1
    }
}
extension Edge: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        p0 = try container.decode(Point.self)
        p1 = try container.decode(Point.self)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(p0)
        try container.encode(p1)
    }
}
extension Edge: AppliableTransform {
    static func * (lhs: Edge, rhs: Transform) -> Edge {
        Edge(lhs.p0 * rhs, lhs.p1 * rhs)
    }
}
extension Edge {
    var midPoint: Point {
        p0.mid(p1)
    }
    var vector: Double2 {
        p1 - p0
    }
    var isEmpty: Bool {
        p0 == p1
    }
    func reversed() -> Edge {
        Edge(p1, p0)
    }
    func extendedFirst(withDistance d: Double) -> Edge {
        Edge(p0.movedWith(distance: d, angle: reversed().angle()), p1)
    }
    func extendedLast(withDistance d: Double) -> Edge {
        Edge(p0, p1.movedWith(distance: d, angle: angle()))
    }
    
    var length: Double {
        p0.distance(p1)
    }
    var lengthSquared: Double {
        p0.distanceSquared(p1)
    }
    func distance(from p: Point) -> Double {
        if p0 == p1 {
            return p0.distance(p)
        }
        let p1p0v = p1 - p0, pp0v = p - p0
        let r = p1p0v.dot(pp0v) / p1p0v.dot(p1p0v)
        if r <= 0 {
            return p0.distance(p)
        } else if r > 1 {
            return p1.distance(p)
        } else {
            return abs(p1p0v.cross(pp0v)) / p0.distance(p1)
        }
    }
    func distanceSquared(from p: Point) -> Double {
        if p0 == p1 {
            return p0.distanceSquared(p)
        }
        let p1p0v = p1 - p0, pp0v = p - p0
        let r = p1p0v.dot(pp0v) / p1p0v.dot(p1p0v)
        if r <= 0 {
            return p0.distanceSquared(p)
        } else if r > 1 {
            return p1.distanceSquared(p)
        } else {
            let cv = p1p0v.cross(pp0v)
            return cv * cv / p0.distanceSquared(p1)
        }
    }
    func angle() -> Double {
        vector.angle()
    }
    func angle(_ other: Edge) -> Double {
        Point.differenceAngle(vector, other.vector)
    }
    func nearestT(from p: Point) -> Double {
        if p0 == p1 {
            return 0.5
        } else {
            let p1p0v = p1 - p0, pp0v = p - p0
            let r = p1p0v.dot(pp0v) / p1p0v.dot(p1p0v)
            return r.clipped(min: 0, max: 1)
        }
    }
    var bounds: Rect {
        AABB(minX: min(p0.x, p1.x), maxX: max(p0.x, p1.x),
             minY: min(p0.y, p1.y), maxY: max(p0.y, p1.y)).rect
    }
    func position(atT t: Double) -> Point {
        Point.linear(p0, p1, t: t)
    }
    func t(from p: Point) -> Double? {
        if p0 == p1 {
            return p == p0 ? 0.5 : nil
        } else {
            let p1p0v = p1 - p0, pp0v = p - p0
            let r = p1p0v.dot(pp0v) / p1p0v.dot(p1p0v)
            guard r >= 0 && r <= 1 else { return nil }
            return (p0 + r * p1p0v)
                .isApproximatelyEqual(p, tolerance: 1e-10) ? r : nil
        }
    }
    func nearestPoint(from p: Point) -> Point {
        if p0 == p1 {
            return p0
        } else {
            let p1p0v = p1 - p0, pp0v = p - p0
            let r = p1p0v.dot(pp0v) / p1p0v.dot(p1p0v)
            if r <= 0 {
                return p0
            } else if r >= 1 {
                return p1
            } else {
                return p0 + r * p1p0v
            }
        }
    }
    
    func intersects(_ other: Edge) -> Bool {
        let v0 = vector, v1 = other.vector
        return v0.cross(other.p0 - p0) * v0.cross(other.p1 - p0) <= 0
            && v1.cross(p0 - other.p0) * v1.cross(p1 - other.p0) <= 0
    }
    func intersectsNone0(_ other: Edge) -> Bool {
        let v0 = vector, v1 = other.vector
        return v0.cross(other.p0 - p0) * v0.cross(other.p1 - p0) < 0
            && v1.cross(p0 - other.p0) * v1.cross(p1 - other.p0) < 0
    }
    func intersection(_ other: Edge) -> Point? {
        let v0 = vector, v1 = other.vector
        let a = v1.cross(p0 - other.p0)
        let b = v1.cross(p1 - other.p0)
        let c = v0.cross(other.p0 - p0)
        let d = v0.cross(other.p1 - p0)
        guard a * b < 0 && c * d < 0 else { return nil }
        let absA = abs(a)
        let t = absA / (absA + abs(b))
        return p0 + vector * t
    }
    func intersectionPointAndT(_ other: Edge) -> (p: Point,
                                                  t0: Double, t1: Double)? {
        let v0 = vector, v1 = other.vector
        let a = v1.cross(p0 - other.p0)
        let b = v1.cross(p1 - other.p0)
        let c = v0.cross(other.p0 - p0)
        let d = v0.cross(other.p1 - p0)
        guard a * b < 0 && c * d < 0 else { return nil }
        let absA = abs(a)
        let t0 = absA / (absA + abs(b))
        let absC = abs(c)
        let t1 = absC / (absC + abs(d))
        return (p0 + vector * t0, t0, t1)
    }
    
    func rayCasting(_ p: Point) -> Int {
        guard (p0.y <= p.y && p1.y > p.y)
                || (p0.y > p.y && p1.y <= p.y) else { return 0 }
        if p1.x.isApproximatelyEqual(p0.x) {
            return p0.x < p.x ? 1 : 0
        } else if p1.y < p0.y {
            return p.y * p1.x + p0.x * p1.y + p.x * p0.y
                > p.x * p1.y + p0.y * p1.x + p.y * p0.x ?
                1 : 0
        } else {
            return p.y * p1.x + p0.x * p1.y + p.x * p0.y
                < p.x * p1.y + p0.y * p1.x + p.y * p0.x ?
                1 : 0
        }
    }
    func rayCastingPointTuples(_ p: Point) -> [(t: Double,
                                                d: CrossDirection,
                                                p: Point)] {
        guard (p0.y <= p.y && p1.y > p.y)
                || (p0.y > p.y && p1.y <= p.y) else { return [] }
        let t = (p.y - p0.y) / (p1.y - p0.y)
        let npx = p0.x + (p1.x - p0.x) * t
        return npx < p.x ?
            [(t, CrossDirection(-vector.y), Point(npx, p.y))] :
            []
    }
    
    func nearest(_ e1: Edge) -> Edge {
        if let p = intersection(e1) {
            return Edge(p, p)
        }
        let dSquared00 = distanceSquared(from: e1.p0)
        let dSquared01 = distanceSquared(from: e1.p1)
        let dSquared10 = e1.distanceSquared(from: p0)
        let dSquared11 = e1.distanceSquared(from: p1)
        let nd = min(dSquared00, dSquared01, dSquared10, dSquared11)
        if nd == dSquared00 {
            return Edge(nearestPoint(from: e1.p0), e1.p0)
        } else if nd == dSquared01 {
            return Edge(nearestPoint(from: e1.p1), e1.p1)
        } else if nd == dSquared10 {
            return Edge(p0, e1.nearestPoint(from: p0))
        } else {
            return Edge(p1, e1.nearestPoint(from: p1))
        }
    }
}

struct LinearLine {
    var p0, p1: Point
}
extension LinearLine {
    init(_ p0: Point, _ p1: Point) {
        self.p0 = p0
        self.p1 = p1
    }
    init(_ edge: Edge) {
        p0 = edge.p0
        p1 = edge.p1
    }
}
extension LinearLine {
    func distance(from p: Point) -> Double {
        p0 == p1 ?
            p0.distance(p) :
            abs((p1 - p0).cross(p - p0)) / p0.distance(p1)
    }
    func distanceSquared(from p: Point) -> Double {
        if p0 == p1 {
            return p0.distanceSquared(p)
        } else {
            let cv = (p1 - p0).cross(p - p0)
            return cv * cv / p0.distanceSquared(p1)
        }
    }
    func t(from p: Point) -> Double {
        if p0 == p1 {
            return 0.5
        } else {
            let p1p0v = p1 - p0, pp0v = p - p0
            return p1p0v.dot(pp0v) / p1p0v.dot(p1p0v)
        }
    }
    func nearestPoint(from p: Point) -> Point {
        if p0 == p1 {
            return p0
        } else {
            let p1p0v = p1 - p0, pp0v = p - p0
            let r = p1p0v.dot(pp0v) / p1p0v.dot(p1p0v)
            return p0 + r * p1p0v
        }
    }
    func contains(_ p: Point, isUpper: Bool) -> Bool {
        let vy = p1.y - p0.y
        if isUpper {
            if vy == 0 {
                return p1.x > p0.x ? p.x <= p0.x : p.x >= p0.x
            } else {
                let n = -(p1.x - p0.x) / vy
                let ny = n * (p.x - p0.x) + p0.y
                return p1.y > p0.y ? p.y <= ny : p.y >= ny
            }
        } else {
            if vy == 0 {
                return p1.x > p0.x ? p.x > p0.x : p.x < p0.x
            } else {
                let n = -(p1.x - p0.x) / vy
                let ny = n * (p.x - p0.x) + p0.y
                return p1.y > p0.y ? p.y > ny : p.y < ny
            }
        }
    }
    
    func intersects(_ other: LinearLine) -> Bool {
        abs((p1 - p0).cross(other.p1 - other.p0)) >= .ulpOfOne
    }
    func intersection(_ other: LinearLine) -> Point? {
        let v0 = p1 - p0, v1 = other.p1 - other.p0
        let d = v1.cross(v0)
        return abs(d) < .ulpOfOne ?
            nil :
            p0 + v0 * v1.cross(other.p0 - p0) / d
    }
    func intersection(_ other: Edge) -> Point? {
        let v0 = p1 - p0, v1 = other.vector
        let c = v0.cross(other.p0 - p0)
        let d = v0.cross(other.p1 - p0)
        guard c * d < 0 else { return nil }
        let absC = abs(c)
        let t = absC / (absC + abs(d))
        return other.p0 + v1 * t
    }
}
