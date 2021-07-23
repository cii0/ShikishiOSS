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

struct Arc {
    var centerPosition: Point {
        didSet {
            startPosition = Arc.positionWith(centerPosition,
                                             r: radius, angle: startAngle)
            endPosition = Arc.positionWith(centerPosition,
                                           r: radius, angle: endAngle)
        }
    }
    var radius: Double {
        didSet {
            startPosition = Arc.positionWith(centerPosition,
                                             r: radius, angle: startAngle)
            endPosition = Arc.positionWith(centerPosition,
                                           r: radius, angle: endAngle)
        }
    }
    var startAngle: Double {
        didSet {
            startPosition = Arc.positionWith(centerPosition,
                                             r: radius, angle: startAngle)
        }
    }
    var endAngle: Double {
        didSet {
            endPosition = Arc.positionWith(centerPosition,
                                           r: radius, angle: endAngle)
        }
    }
    private(set) var startPosition: Point, endPosition: Point
    
    init(centerPosition: Point = Point(), radius: Double = 0,
         startAngle: Double = 0, endAngle: Double = 2 * .pi) {
        
        self.centerPosition = centerPosition
        self.radius = radius
        self.startAngle = startAngle
        self.endAngle = endAngle
        startPosition = Arc.positionWith(centerPosition,
                                         r: radius, angle: startAngle)
        endPosition = Arc.positionWith(centerPosition,
                                       r: radius, angle: endAngle)
    }
    private static func positionWith(_ cp: Point,
                                     r: Double, angle: Double) -> Point {
        cp.movedWith(distance: r, angle: angle)
    }
}
extension Arc {
    func toVertical() -> Arc {
        Arc(centerPosition: centerPosition.inverted(),
            radius: radius, startAngle: startAngle, endAngle: endAngle)
    }
    var arcLength: Double {
        radius * abs(endAngle - startAngle)
    }
    var orientation: CircularOrientation {
        startAngle > endAngle ? .clockwise : .counterClockwise
    }
    var bounds: Rect {
        Rect(x: centerPosition.x - radius, y: centerPosition.y - radius,
             width: radius * 2, height: radius * 2)
    }
    func contains(angle: Double,
                  isEqual0: Bool = true, isEqual1: Bool = true) -> Bool {
        let sa = min(startAngle, endAngle), ea = max(startAngle, endAngle)
        let da = angle.differenceRotation(sa), wa = ea - sa
        return isEqual0 ?
            (da >= 0 && (isEqual1 ? da <= wa : da < wa)) :
            (da > 0 && (isEqual1 ? da <= wa : da < wa))
    }
    func distanceSquared(from p: Point) -> Double {
        let angle = centerPosition.angle(p)
        if !contains(angle: angle) {
            return min(startPosition.distanceSquared(p),
                       endPosition.distanceSquared(p))
        } else {
            return (centerPosition.distance(p) - radius) ** 2
        }
    }
    func intersects(_ rect: Rect) -> Bool {
        guard bounds.intersects(rect) else { return false }
        return intersects(rect.leftEdge)
            || intersects(rect.bottomEdge)
            || intersects(rect.rightEdge)
            || intersects(rect.topEdge)
    }
    func intersects(_ edge: Edge) -> Bool {
        func angleTest(_ p: Point) -> Bool {
            let angle = centerPosition.angle(p)
            return contains(angle: angle)
        }
        if edge.p0 == edge.p1 {
            let d = centerPosition.distanceSquared(edge.p0)
            return d == radius * radius ? angleTest(edge.p0) : false
        }
        let p = LinearLine(edge).nearestPoint(from: centerPosition)
        let dSquared = centerPosition.distanceSquared(p)
        let rSquared = radius * radius
        if dSquared <= rSquared {
            let ev = edge.p1 - edge.p0
            let pd = (rSquared - dSquared).squareRoot(), theta = ev.angle()
            let dp = PolarPoint(pd, theta).rectangular
            let q0 = p + dp, q1 = p - dp
            let rv = 1 / (ev.x * ev.x + ev.y * ev.y)
            func intersectionTest(_ q: Point) -> Bool {
                let qp0v = q - edge.p0
                let t = (ev.x * qp0v.x + ev.y * qp0v.y) * rv
                return t >= 0 && t <= 1
            }
            if intersectionTest(q0) && angleTest(q0) {
                return true
            } else if intersectionTest(q1) && angleTest(q1) {
                return true
            }
        }
        return false
    }
    func rayCasting(_ p: Point) -> Int {
        let isUp0: Bool, isUp1: Bool
        if startPosition.x == centerPosition.x {
            isUp0 = startPosition.x < centerPosition.x
            isUp1 = isUp0
        } else if endPosition.x == centerPosition.x {
            isUp0 = endPosition.x < centerPosition.x
            isUp1 = isUp0
        } else {
            isUp0 = startPosition.x < centerPosition.x
            isUp1 = endPosition.x < centerPosition.x
        }
        func angleTest(_ p: Point) -> Bool {
            let angle = centerPosition.angle(p)
            return contains(angle: angle, isEqual0: isUp0, isEqual1: !isUp1)
        }
        let b = -2 * centerPosition.x
        let dpy = p.y - centerPosition.y
        let c = centerPosition.x * centerPosition.x
            - (radius + dpy) * (radius - dpy)
        let d = b * b - 4 * c
        guard d > 0 else { return 0 }
        let s = d.squareRoot()
        let q0x = (-b - s) / 2, q1x = (-b + s) / 2
        var count = 0
        if q0x < p.x && angleTest(Point(q0x, p.y)) {
            count += 1
        }
        if q1x < p.x && angleTest(Point(q1x, p.y)) {
            count += 1
        }
        return count
    }
    func intersects(_ arc: Arc) -> Bool {
        var aIntersects = false
        arc.edges { (edge, flag) in
            if intersects(edge) {
                aIntersects = true
                flag = true
            }
        }
        return aIntersects
    }
    func edges(count: Int = 10, _ handler: (Edge, inout Bool) -> ()) {
        var oldP = startPosition, flag = false
        for i in 0..<count {
            let t = Double(i) / Double(count - 1)
            let a = Double.linear(startAngle, endAngle, t: t)
            let p = centerPosition.movedWith(distance: radius, angle: a)
            handler(Edge(oldP, p), &flag)
            if flag {
                return
            }
            oldP = p
        }
    }
}
extension Arc: AppliableTransform {
    static func * (lhs: Arc, rhs: Transform) -> Arc {
        let angle = rhs.angle
        return Arc(centerPosition: lhs.centerPosition * rhs,
                   radius: lhs.radius * rhs.absXScale,
                   startAngle: lhs.startAngle + angle,
                   endAngle: lhs.endAngle + angle)
    }
}
