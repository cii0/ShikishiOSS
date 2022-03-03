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

struct BezierInterpolation {
    var x0 = 0.0, cx = 0.0, x1 = 0.0
}
extension BezierInterpolation {
    static func linear(_ x0: Double, _ x1: Double) -> BezierInterpolation {
        BezierInterpolation(x0: x0, cx: x0.mid(x1), x1: x1)
    }
    func difference(withT t: Double) -> Double {
        2 * (cx - x0) + 2 * (x0 - 2 * cx + x1) * t
    }
    func position(withT t: Double) -> Double {
        let rt = 1 - t
        return rt * rt * x0 + 2 * t * rt * cx + t * t * x1
    }
    func clip(startT t0: Double, endT t1: Double) -> BezierInterpolation {
        let rt0 = 1 - t0, rt1 = 1 - t1
        let t0p0cx = rt0 * x0 + t0 * cx
        let t0cxx1 = rt0 * cx + t0 * x1
        let t1x0cx = rt1 * x0 + t1 * cx
        let t1cxx1 = rt1 * cx + t1 * x1
        let nx0 = rt0 * t0p0cx + t0 * t0cxx1
        let ncx = rt1 * t0p0cx + t1 * t0cxx1
        let nx1 = rt1 * t1x0cx + t1 * t1cxx1
        return BezierInterpolation(x0: nx0, cx: ncx, x1: nx1)
    }
    func midSplit() -> (b0: BezierInterpolation, b1: BezierInterpolation) {
        let x0cx = x0.mid(cx), cxx1 = cx.mid(x1)
        let x = x0cx.mid(cxx1)
        return (BezierInterpolation(x0: x0, cx: x0cx, x1: x),
                BezierInterpolation(x0: x, cx: cxx1, x1: x1))
    }
    func split(withT t: Double) -> (b0: BezierInterpolation,
                                    b1: BezierInterpolation) {
        let x0cx = Double.linear(x0, cx, t: t)
        let cxx1 = Double.linear(cx, x1, t: t)
        let x = Double.linear(x0cx, cxx1, t: t)
        return (BezierInterpolation(x0: x0, cx: x0cx, x1: x),
                BezierInterpolation(x0: x, cx: cxx1, x1: x1))
    }
}

struct BezierIntersection: Hashable, Codable {
    var t: Double, otherT: Double, otherDirection: CrossDirection, point: Point
}
struct Bezier: Hashable, Codable {
    var p0 = Point(), cp = Point(), p1 = Point()
}
extension Bezier: AppliableTransform {
    static func * (lhs: Bezier, rhs: Transform) -> Bezier {
        Bezier(p0: lhs.p0 * rhs, cp: lhs.cp * rhs, p1: lhs.p1 * rhs)
    }
}
extension Bezier: CustomStringConvertible {
    var description: String {
        "((\(p0.x), \(p0.y)), (\(cp.x), \(cp.y)), (\(p1.x), \(p1.y)))"
    }
}
extension Bezier {
    init(_ edge: Edge) {
        self.init(p0: edge.p0, cp: edge.midPoint, p1: edge.p1)
    }
    static func linear(_ p0: Point, _ p1: Point) -> Bezier {
        Bezier(p0: p0, cp: p0.mid(p1), p1: p1)
    }
    static func firstBSpline(_ p0: Point, _ p1: Point, _ p2: Point) -> Bezier {
        Bezier(p0: p0, cp: p1, p1: p1.mid(p2))
    }
    static func bSpline(_ p0: Point, _ p1: Point, _ p2: Point) -> Bezier {
        Bezier(p0: p0.mid(p1), cp: p1, p1: p1.mid(p2))
    }
    static func endBSpline(_ p0: Point, _ p1: Point, _ p2: Point) -> Bezier {
        Bezier(p0: p0.mid(p1), cp: p1, p1: p2)
    }
    
    static func beziersWith(_ b3: Bezier3) -> (b0: Bezier, b1: Bezier) {
        beziersWith(p0: b3.p0, cp0: b3.cp0, cp1: b3.cp1, p1: b3.p1)
    }
    static func beziersWith(p0: Point,
                            cp0: Point, cp1: Point,
                            p1: Point) -> (b0: Bezier, b1: Bezier) {
        let b3 = Bezier3(p0: p0, cp0: cp0, cp1: cp1, p1: p1)
        let (b30, b31) = b3.midSplit()
        let d0 = b30.p0.distance(b30.cp0)
        var b0cp = b30.p0 == b30.cp0 || b30.cp1 == b30.p1 ?
            b30.p0.mid(b30.p1) :
            (LinearLine(b30.p0, b30.cp0)
                .intersection(LinearLine(b30.cp1, b30.p1)) ?? b30.p0.mid(b30.p1))
        if b30.p0.distance(b0cp) > d0 * 3 {
            b0cp = b30.cp0.mid(b30.cp1)
        }
        let d1 = b31.p0.distance(b31.cp0)
        var b1cp = b31.p0 == b31.cp0 || b31.cp1 == b31.p1 ?
            b31.p0.mid(b31.p1) :
            (LinearLine(b31.p0, b31.cp0)
                .intersection(LinearLine(b31.cp1, b31.p1)) ?? b31.p0.mid(b31.p1))
        if b31.p0.distance(b1cp) > d1 * 3 {
            b1cp = b31.cp0.mid(b31.cp1)
        }
        return (Bezier(p0: b30.p0, cp: b0cp, p1: b30.p1),
                Bezier(p0: b31.p0, cp: b1cp, p1: b31.p1))
    }
    
    var isEmpty: Bool {
        p0 == cp && cp == p1
    }
    var isLineaer: Bool {
        if p0 == cp || cp == p1 {
            return true
        } else {
            return Edge(p0, p1).t(from: cp) != nil
        }
    }
    
    var bounds: Rect {
        var minX = min(p0.x, p1.x), maxX = max(p0.x, p1.x)
        var d = p0.x - 2 * cp.x + p1.x
        if d != 0 {
            let t = (p0.x - cp.x) / d
            if t >= 0 && t <= 1 {
                let rt = 1 - t
                let tx = rt * rt * p0.x + 2 * rt * t * cp.x + t * t * p1.x
                if tx < minX {
                    minX = tx
                } else if tx > maxX {
                    maxX = tx
                }
            }
        }
        var minY = min(p0.y, p1.y), maxY = max(p0.y, p1.y)
        d = p0.y - 2 * cp.y + p1.y
        if d != 0 {
            let t = (p0.y - cp.y) / d
            if t >= 0 && t <= 1 {
                let rt = 1 - t
                let ty = rt * rt * p0.y + 2 * rt * t * cp.y + t * t * p1.y
                if ty < minY {
                    minY = ty
                } else if ty > maxY {
                    maxY = ty
                }
            }
        }
        return Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    var controlBounds: Rect {
        AABB(self).rect
    }
    
    // L = ∫ [0,1] sqrt(x'(t)^2 + y'(t)^2) dt
    func length() -> Double {
        let ap = p0 - 2 * cp + p1
        let a = 4 * ap.lengthSquared()
        guard a >= .ulpOfOne else { return p0.distance(p1) }
        let bp = 2 * cp - 2 * p0
        let b = 4 * ap.dot(bp)
        let c = bp.lengthSquared()
        
        let sa = a.squareRoot()
        let asa2 = 2 * a * sa
        let bsa = b / sa
        let sc2 = 2 * c.squareRoot()
        let m = bsa + sc2
        guard abs(m) >= .ulpOfOne else { return p0.distance(p1) }
        let sabc2 = 2 * (a + b + c).squareRoot()
        let d = 4 * c * a - b * b
        let dlog = d * .log((2 * sa + bsa + sabc2) / m)
        return (asa2 * sabc2 + sa * b * (sabc2 - sc2) + dlog) / (4 * asa2)
    }
    func length(withFlatness flatness: Int) -> Double {
        var d = 0.0, oldP = p0
        let nd = 1 / Double(flatness)
        for i in 1...flatness {
            let newP = position(withT: Double(i) * nd)
            d += oldP.distance(newP)
            oldP = newP
        }
        return d
    }
    func t(withLength length: Double, flatness: Int = 128) -> Double {
        var d = 0.0, oldP = p0
        let nd = 1 / Double(flatness)
        for i in 1...flatness {
            let t = Double(i) * nd
            let newP = position(withT: t)
            d += oldP.distance(newP)
            if d > length {
                return t
            }
            oldP = newP
        }
        return 1
    }
    func position(withLength length: Double) -> Point? {
        guard p0 != cp && cp != p1 else {
            let d = p0.distance(p1)
            if d > 0 && length <= d {
                let t = length / d
                return Point.linear(p0, p1, t: t)
            }
            return nil
        }
        
        let maxLength = self.length()
        guard length < maxLength else { return length == maxLength ? p1 : nil }
        
        func bisection(minT: Double, maxT: Double) -> Double {
            let midT = (minT + maxT) / 2
            if maxT - minT <= 0.0000001 {
                return midT
            }
            if clip(t1: midT).length() < length {
                return bisection(minT: midT, maxT: maxT)
            } else {
                return bisection(minT: minT, maxT: midT)
            }
        }
        return position(withT: bisection(minT: 0, maxT: 1))
    }
    func difference(withT t: Double) -> Point {
        Point(2 * (cp.x - p0.x) + 2 * (p0.x - 2 * cp.x + p1.x) * t,
              2 * (cp.y - p0.y) + 2 * (p0.y - 2 * cp.y + p1.y) * t)
    }
    func tangential(withT t: Double) -> Double {
        difference(withT: t).angle()
    }
    func position(withT t: Double) -> Point {
        let rt = 1 - t
        let tSquared = t * t, rtSquared = rt * rt
        return Point(rtSquared * p0.x + 2 * t * rt * cp.x + tSquared * p1.x,
                     rtSquared * p0.y + 2 * t * rt * cp.y + tSquared * p1.y)
    }
    func midSplit() -> (b0: Bezier, b1: Bezier) {
        let p0cp = p0.mid(cp), cpp1 = cp.mid(p1)
        let p = p0cp.mid(cpp1)
        return (Bezier(p0: p0, cp: p0cp, p1: p), Bezier(p0: p, cp: cpp1, p1: p1))
    }
    func split(withT t: Double) -> (b0: Bezier, b1: Bezier) {
        let p0cp = Point.linear(p0, cp, t: t)
        let cpp1 = Point.linear(cp, p1, t: t)
        let p = Point.linear(p0cp, cpp1, t: t)
        return (Bezier(p0: p0, cp: p0cp, p1: p),
                Bezier(p0: p, cp: cpp1, p1: p1))
    }
    func clip(t1: Double) -> Bezier {
        let rt1 = 1 - t1
        let t1p0cp = rt1 * p0 + t1 * cp
        let t1cpp1 = rt1 * cp + t1 * p1
        let ncp = rt1 * p0 + t1 * cp
        let np1 = rt1 * t1p0cp + t1 * t1cpp1
        return Bezier(p0: p0, cp: ncp, p1: np1)
    }
    func clip(startT t0: Double, endT t1: Double) -> Bezier {
        let rt0 = 1 - t0, rt1 = 1 - t1
        let t0p0cp = rt0 * p0 + t0 * cp
        let t0cpp1 = rt0 * cp + t0 * p1
        let t1p0cp = rt1 * p0 + t1 * cp
        let t1cpp1 = rt1 * cp + t1 * p1
        let np0 = rt0 * t0p0cp + t0 * t0cpp1
        let ncp = rt1 * t0p0cp + t1 * t0cpp1
        let np1 = rt1 * t1p0cp + t1 * t1cpp1
        return Bezier(p0: np0, cp: ncp, p1: np1)
    }
    
    var firstAngle: Double {
        p0 == cp ? p0.angle(p1) : p0.angle(cp)
    }
    var lastAngle: Double {
        cp == p1 ? p0.angle(p1) : cp.angle(p1)
    }
    
    func enumeratedEdges(quality: Double = 1, maxCount: Int = 20,
                         _ handler: (_ t: Double, _ oldT: Double,
                                     _ edge: Edge, _ stop: inout Bool) -> ()) {
        var stop = false
        guard !isLineaer else {
            handler(1, 0, Edge(p0, p1), &stop)
            return
        }
        let l = length(withFlatness: 4)
        let count = Int(l * quality).clipped(min: 2, max: maxCount)
        let rCount = 1 / Double(count)
        var oldP = p0, oldT = 0.0
        for i in 1...count {
            let t = Double(i) * rCount
            let p = position(withT: t)
            handler(t, oldT, Edge(oldP, p), &stop)
            if stop {
                return
            }
            oldP = p
            oldT = t
        }
    }
    func reversedEnumeratedEdges(quality: Double = 1, maxCount: Int = 20,
                                 _ handler: (_ t: Double, _ oldT: Double,
                                             _ edge: Edge) -> ()) {
        guard !isLineaer else {
            handler(0, 1, Edge(p1, p0))
            return
        }
        let l = length(withFlatness: 4)
        let count = Int(l * quality).clipped(min: 2, max: maxCount)
        let rCount = 1 / Double(count)
        var oldP = p1, oldT = 1.0
        for i in (0..<count).reversed() {
            let t = Double(i) * rCount
            let p = position(withT: t)
            handler(t, oldT, Edge(oldP, p))
            oldP = p
            oldT = t
        }
    }
    
    func intersects(_ otherRect: Rect) -> Bool {
        guard controlBounds.intersects(otherRect) else {
            return false
        }
        if otherRect.contains(p0) || otherRect.contains(p1) {
            return true
        } else {
            let x0y0 = otherRect.origin
            let x1y0 = Point(otherRect.maxX, otherRect.minY)
            let x0y1 = Point(otherRect.minX, otherRect.maxY)
            let x1y1 = Point(otherRect.maxX, otherRect.maxY)
            return intersects(Edge(x0y0, x1y0))
                || intersects(Edge(x1y0, x1y1))
                || intersects(Edge(x1y1, x0y1))
                || intersects(Edge(x0y1, x0y0))
        }
    }
    func intersects(_ other: Bezier) -> Bool {
        guard self != other else {
            return false
        }
        return _intersects(other)
    }
    private static let intersectsMinRange = 0.00000001
    private static let intersectsMinDistanceSquared = 0.0001 * 0.0001
    private func _intersects(_ other: Bezier) -> Bool {
        let aabb0 = AABB(self), aabb1 = AABB(other)
        guard aabb0.intersects(aabb1) else {
            return false
        }
        if aabb1.width < Bezier.intersectsMinRange &&
            aabb1.height < Bezier.intersectsMinRange {
            
            return true
        } else {
            let nb = other.midSplit()
            return nb.b0.intersects(self) ? true : nb.b1.intersects(self)
        }
    }
    
    func intersects(_ otherEdge: Edge) -> Bool {
        !intersections(Bezier(otherEdge)).isEmpty
    }
    func intersects(_ otherArc: Arc) -> Bool {
        var aIntersects = false
        otherArc.edges { (edge, flag) in
            if intersects(edge) {
                aIntersects = true
                flag = true
            }
        }
        return aIntersects
    }
    
    func intersections(_ edge: Edge) -> [BezierIntersection] {
        let q0 = edge.p0, q1 = edge.p1
        guard q0 != q1 else { return [] }
        guard !isLineaer else {
            let e0 = Edge(p0, p1), e1 = edge
            guard let p = e0.intersection(e1) else { return [] }
            let t0 = e0.nearestT(from: p), t1 = e1.nearestT(from: p)
            let d = CrossDirection(e0.vector.cross(e1.vector))
            return [BezierIntersection(t: t0, otherT: t1,
                                       otherDirection: d, point: p)]
        }
        let a = q1.y - q0.y
        let b = q0.x - q1.x
        let c = -a * q1.x - q1.y * b
        let da = a * p0.x + a * p1.x
            + b * p0.y + b * p1.y
            - 2 * a * cp.x - 2 * b * cp.y
        let db = -2 * a * p0.x - 2 * b * p0.y
            + 2 * a * cp.x + 2 * b * cp.y
        let dc = a * p0.x + b * p0.y + c
        let d = db * db - 4 * da * dc
        func intersection(with t: Double) -> BezierIntersection {
            let p = position(withT: t)
            let et = edge.nearestT(from: p)
            let direction = CrossDirection(difference(withT: t).cross(edge.vector))
            return BezierIntersection(t: t, otherT: et,
                                      otherDirection: direction, point: p)
        }
        if d > 0 {
            let sd = d.squareRoot(), rda = 1 / da
            let t0 = 0.5 * (sd - db) * rda, t1 = 0.5 * (-sd - db) * rda
            if t0 >= 0 && t0 <= 1 {
                let bi0 = intersection(with: t0)
                if t1 >= 0 && t1 <= 1 {
                    let bi1 = intersection(with: t1)
                    return [bi0, bi1]
                } else {
                    return [bi0]
                }
            } else if t1 >= 0 && t1 <= 1 {
                let bi = intersection(with: t1)
                return [bi]
            }
        } else if d == 0 {
            let t = -0.5 * db / da
            if t >= 0 && t <= 1 {
                let bi = intersection(with: t)
                return [bi]
            }
        }
        return []
    }
    func intersections(_ linearLine: LinearLine) -> [Point] {
        let q0 = linearLine.p0, q1 = linearLine.p1
        guard q0 != q1 else {
            return []
        }
        if isLineaer {
            if let p = linearLine.intersection(Edge(p0, p1)) {
                return [p]
            } else {
                return []
            }
        }
        let a = q1.y - q0.y, b = q0.x - q1.x
        let c = -a * q1.x - q1.y * b
        let da = a * p0.x + a * p1.x
            + b * p0.y + b * p1.y
            - 2 * a * cp.x - 2 * b * cp.y
        let db = -2 * a * p0.x - 2 * b * p0.y
            + 2 * a * cp.x + 2 * b * cp.y
        let dc = a * p0.x + b * p0.y + c
        let d = db * db - 4 * da * dc
        if d > 0 {
            let sd = d.squareRoot(), rda = 1 / da
            let t0 = 0.5 * (sd - db) * rda, t1 = 0.5 * (-sd - db) * rda
            if t0 >= 0 && t0 <= 1 {
                return t1 >= 0 && t1 <= 1 ?
                    [position(withT: t0), position(withT: t1)] :
                    [position(withT: t0)]
            } else if t1 >= 0 && t1 <= 1 {
                return [position(withT: t1)]
            }
        } else if d == 0 {
            let t = -0.5 * db / da
            if t >= 0 && t <= 1 {
                return [position(withT: t)]
            }
        }
        return []
    }
    func intersections(_ other: Bezier) -> [BezierIntersection] {
        guard self != other else { return [] }
        guard !isLineaer else {
            if other.isLineaer {
                let e0 = Edge(p0, p1), e1 = Edge(other.p0, other.p1)
                guard let p = e0.intersection(e1) else { return [] }
                let t0 = e0.nearestT(from: p), t1 = e1.nearestT(from: p)
                let d = CrossDirection(e0.vector.cross(e1.vector))
                return [BezierIntersection(t: t0, otherT: t1,
                                           otherDirection: d, point: p)]
            } else {
                var results = [BezierIntersection]()
                intersections(other, &results, 0, 1, 0, 1, isFlipped: false)
                return results
            }
        }
        var results = [BezierIntersection]()
        intersections(other, &results, 0, 1, 0, 1, isFlipped: false)
        return results
    }
    private func intersections(_ other: Bezier,
                               _ results: inout [BezierIntersection],
                               _ min0: Double, _ max0: Double,
                               _ min1: Double, _ max1: Double,
                               isFlipped: Bool) {
        let aabb0 = AABB(self), aabb1 = AABB(other)
        guard aabb0.intersects(aabb1) else { return }
        let imr = Bezier.intersectsMinRange
        if aabb1.width < imr && aabb1.height < imr {
            let newP = Point(aabb1.midX, aabb1.midY)
            if !results.isEmpty {
                let oldP = results[results.count - 1].point
                if newP.distanceSquared(oldP)
                    < Bezier.intersectsMinDistanceSquared { return }
            }
            let range1 = max1 - min1
            let b0t: Double, b1t: Double, b0: Bezier, b1:Bezier
            if !isFlipped {
                b0t = (min0 + max0) / 2
                b1t = min1 + range1 / 2
                b0 = self
                b1 = other
            } else {
                b1t = (min0 + max0) / 2
                b0t = min1 + range1 / 2
                b0 = other
                b1 = self
            }
            
            let b0dp = b0.difference(withT: b0t), b1dp = b1.difference(withT: b1t)
            let b0b1Cross = b0dp.cross(b1dp)
            if b0b1Cross != 0 {
                results.append(BezierIntersection(t: b0t, otherT: b1t,
                                                  otherDirection: .init(b0b1Cross),
                                                  point: newP))
            }
        } else {
            let range1 = max1 - min1
            let nb = other.midSplit()
            nb.b0.intersections(self, &results,
                                min1, min1 + range1 / 2,
                                min0, max0,
                                isFlipped: !isFlipped)
            if results.count < 4 {
                nb.b1.intersections(self, &results,
                                    min1 + range1 / 2, min1 + range1,
                                    min0, max0,
                                    isFlipped: !isFlipped)
            }
        }
    }
    
    func rayCasting(_ p: Point) -> Int {
        guard !isLineaer else {
            return Edge(p0, p1).rayCasting(p)
        }
        
        var isUp0: Bool, isUp1: Bool
        if p0.y == cp.y {
            isUp0 = cp.y < p1.y
            isUp1 = isUp0
        } else if cp.y == p1.y {
            isUp0 = p0.y < cp.y
            isUp1 = isUp0
        } else {
            isUp0 = p0.y < cp.y
            isUp1 = cp.y < p1.y
        }
        func isContainsT(_ t: Double) -> Bool {
            let isFT = isUp0 ? t >= 0 : t > 0
            let isLT = isUp1 ? t < 1 : t <= 1
            return isFT && isLT
        }
        
        let a = p1.y + p0.y - 2 * cp.y
        let b = -2 * p0.y + 2 * cp.y
        let c = p0.y - p.y
        if abs(a) < .ulpOfOne {
            if abs(b) < .ulpOfOne {
                return 0
            } else {
                let t = -c / b
                if isContainsT(t) {
                    return position(withT: t).x < p.x ? 1 : 0
                } else {
                    return 0
                }
            }
        } else {
            let d = b * b - 4 * a * c
            if abs(d) < .ulpOfOne {
                let t = -b / (2 * a)
                if isContainsT(t) {
                    return position(withT: t).x < p.x ? 1 : 0
                } else {
                    return 0
                }
            } else if d < 0 {
                return 0
            } else {
                let sd = d.squareRoot()
                let nd = -b - sd
                let t0 = abs(nd) < .ulpOfOne ?
                    (-b + sd) / (2 * a) : 2 * c / nd
                let t1 = nd / (2 * a)
                var count = 0
                if isContainsT(t0) {
                    count += position(withT: t0).x < p.x ? 1 : 0
                }
                if isContainsT(t1) {
                    count += position(withT: t1).x < p.x ? 1 : 0
                }
                return count
            }
        }
    }
    func rayCastingPointTuples(_ p: Point) -> [(t: Double,
                                                d: CrossDirection, p: Point)] {
        guard !isLineaer else {
            return Edge(p0, p1).rayCastingPointTuples(p)
        }
        var isUp0: Bool, isUp1: Bool
        if p0.y == cp.y {
            isUp0 = cp.y < p1.y
            isUp1 = isUp0
        } else if cp.y == p1.y {
            isUp0 = p0.y < cp.y
            isUp1 = isUp0
        } else {
            isUp0 = p0.y < cp.y
            isUp1 = cp.y < p1.y
        }
        func isContainsT(_ t: Double) -> Bool {
            return isUp0 ?
                (isUp1 ? t >= 0 && t < 1 : t >= 0 && t <= 1) :
                (isUp1 ? t > 0 && t < 1 : t > 0 && t <= 1)
        }
        let a = p1.y + p0.y - 2 * cp.y
        let b = -2 * p0.y + 2 * cp.y
        let c = p0.y - p.y
        let d = b * b - 4 * a * c
        guard d > 0 else {
            return []
        }
        let sd = d.squareRoot(), ra = 1 / a
        let t0 = 0.5 * (sd - b) * ra, t1 = 0.5 * (-sd - b) * ra
        var pointTuples = [(Double, CrossDirection, Point)]()
        if isContainsT(t0) {
            let npx = position(withT: t0).x
            if npx < p.x {
                pointTuples.append((t0, CrossDirection(-difference(withT: t0).y),
                                    Point(npx, p.y)))
            }
        }
        if isContainsT(t1) {
            let npx = position(withT: t1).x
            if npx < p.x {
                pointTuples.append((t1, CrossDirection(-difference(withT: t1).y),
                                    Point(npx, p.y)))
            }
        }
        return pointTuples
    }
    
    // pを原点とし
    // f(t) = sqrt(x(t)^2 + y(t)^2) の微分値が0になるt
    // またはt=0またはt=1のうち最小の距離となる解
    func nearest(at p: Point) -> (t: Double, distanceSquared: Double) {
        guard !isLineaer else {
            let edge = Edge(p0, p1)
            let dSquared = edge.distanceSquared(from: p)
            return (edge.nearestT(from: p), dSquared)
        }
        
        let a = p0 - 2 * cp + p1, b = 2 * (cp - p0), c = p0 - p
        let aa = 4 * a.lengthSquared()
        let bb = 6 * a.dot(b)
        let cc = 2 * b.lengthSquared() + 4 * a.dot(c)
        let dd = 2 * b.dot(c)
        let ts = Double.solveEquationReals(aa, bb, cc, dd)
        let d0Squared = p0.distanceSquared(p), d1Squared = p1.distanceSquared(p)
        var minT = 0.0, minDSquared = d0Squared
        if d1Squared < minDSquared {
            minDSquared = d1Squared
            minT = 1
        }
        for t in ts {
            if t >= 0 && t <= 1 {
                let dSquared = position(withT: t).distanceSquared(p)
                if dSquared < minDSquared {
                    minDSquared = dSquared
                    minT = t
                }
            }
        }
        return (minT, minDSquared)
    }
    func minDistanceSquared(from p: Point) -> Double {
        nearest(at: p).distanceSquared
    }
    private static let distanceMinRange = 0.0000001
    func maxDistanceSquared(from p: Point) -> Double {
        let d = max(p0.distanceSquared(p), p1.distanceSquared(p))
        let dcp = cp.distanceSquared(p)
        if d >= dcp {
            return d
        } else if dcp - d < Bezier.distanceMinRange {
            return (dcp + d) / 2
        } else {
            let b = midSplit()
            return max(b.b0.maxDistanceSquared(from: p), b.b1.maxDistanceSquared(from: p))
        }
    }
}

struct Bezier3: Codable, Hashable {
    var p0 = Point(), cp0 = Point(), cp1 = Point(), p1 = Point()
}
extension Bezier3 {
    static func linear(_ p0: Point, _ p1: Point) -> Bezier3 {
        Bezier3(p0: p0, cp0: p0, cp1: p1, p1: p1)
    }
    func split(withT t: Double) -> (b0: Bezier3, b1: Bezier3) {
        let b0cp0 = Point.linear(p0, cp0, t: t)
        let cp0cp1 = Point.linear(cp0, cp1, t: t)
        let b1cp1 = Point.linear(cp1, p1, t: t)
        let b0cp1 = Point.linear(b0cp0, cp0cp1, t: t)
        let b1cp0 = Point.linear(cp0cp1, b1cp1, t: t)
        let p = Point.linear(b0cp1, b1cp0, t: t)
        return (Bezier3(p0: p0, cp0: b0cp0, cp1: b0cp1, p1: p),
                Bezier3(p0: p, cp0: b1cp0, cp1: b1cp1, p1: p1))
    }
    func y(withX x: Double) -> Double {
        var y = 0.0
        let sb = split(withT: 0.5)
        if !sb.b0.y(withX: x, y: &y) {
            _ = sb.b1.y(withX: x, y: &y)
        }
        return y
    }
    private func y(withX x: Double, y: inout Double,
                   yMinRange: Double = 0.000001) -> Bool {
        let aabb = AABB(self)
        guard aabb.minX < x && aabb.maxX >= x else {
            return false
        }
        if aabb.maxY - aabb.minY < yMinRange {
            y = (aabb.minY + aabb.maxY) / 2
            return true
        } else {
            let sb = split(withT: 0.5)
            if sb.b0.y(withX: x, y: &y) {
                return true
            } else {
                return sb.b1.y(withX: x, y: &y)
            }
        }
    }
    func midSplit() -> (b0: Bezier3, b1: Bezier3) {
        let b0cp0 = p0.mid(cp0), cp0cp1 = cp0.mid(cp1), b1cp1 = cp1.mid(p1)
        let b0cp1 = b0cp0.mid(cp0cp1), b1cp0 = cp0cp1.mid(b1cp1)
        let p = b0cp1.mid(b1cp0)
        return (Bezier3(p0: p0, cp0: b0cp0, cp1: b0cp1, p1: p),
                Bezier3(p0: p, cp0: b1cp0, cp1: b1cp1, p1: p1))
    }
    func position(withT t: Double) -> Point {
        let rt = 1 - t
        let tCubed = t * t * t, tSquared = t * t
        let rtCubed = rt * rt * rt, rtSquared = rt * rt
        let x = rtCubed * p0.x
            + 3 * rtSquared * t * cp0.x
            + 3 * rt * tSquared * cp1.x
            + tCubed * p1.x
        let y = rtCubed * p0.y
            + 3 * rtSquared * t * cp0.y
            + 3 * rt * tSquared * cp1.y
            + tCubed * p1.y
        return Point(x, y)
    }
    func difference(withT t: Double) -> Point {
        let rt = 1 - t
        let tSquared = t * t, rtSquared = rt * rt
        let dx = 3 * (rtSquared * (cp0.x - p0.x)
                        + 2 * rt * t * (cp1.x - cp0.x) + tSquared * (p1.x - cp1.x))
        let dy = 3 * (rtSquared * (cp0.y - p0.y)
                        + 2 * rt * t * (cp1.y - cp0.y) + tSquared * (p1.y - cp1.y))
        return Point(dx, dy)
    }
    func tangential(withT t: Double) -> Double {
        difference(withT: t).angle()
    }
}
