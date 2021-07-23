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

enum RectCorner: String {
    case minXMinY, maxXMinY, minXMaxY, maxXMaxY
}
extension RectCorner: Protobuf {
    init(_ pb: PBRectCorner) throws {
        switch pb {
        case .minXminY: self = .minXMinY
        case .minXmaxY: self = .minXMaxY
        case .maxXminY: self = .maxXMinY
        case .maxXmaxY: self = .maxXMaxY
        case .UNRECOGNIZED: self = .minXMinY
        }
    }
    var pb: PBRectCorner {
        switch self {
        case .minXMinY: return .minXminY
        case .minXMaxY: return .minXmaxY
        case .maxXMinY: return .maxXminY
        case .maxXMaxY: return .maxXmaxY
        }
    }
}
extension RectCorner: Codable {}

struct Rect: Hashable {
    var origin = Point(), size = Size()
    
    init(origin: Point = Point(), size: Size = Size()) {
        self.origin = origin
        self.size = size
    }
}
extension Rect: Protobuf {
    init(_ pb: PBRect) throws {
        origin = try Point(pb.origin)
        size = try Size(pb.size)
    }
    var pb: PBRect {
        PBRect.with {
            $0.origin = origin.pb
            $0.size = size.pb
        }
    }
}
extension Rect {
    init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: Point(x, y),
                  size: Size(width: width, height: height))
    }
    init(_ p: Point, distance: Double) {
        self.init(origin: Point(p.x - distance, p.y - distance),
                  size: Size(square: distance * 2))
    }
    init?(points: [Point]) {
        guard !points.isEmpty else { return nil }
        if points.count <= 1 {
            self = Rect(origin: points[0], size: Size())
        } else {
            let minX = points.min { $0.x < $1.x }!.x
            let maxX = points.max { $0.x < $1.x }!.x
            let minY = points.min { $0.y < $1.y }!.y
            let maxY = points.max { $0.y < $1.y }!.y
            self = AABB(minX: minX, maxX: maxX,
                        minY: minY, maxY: maxY).rect
        }
    }
    init(_ edge: Edge) {
        self.init(points: [edge.p0, edge.p1])!
    }
}
extension Rect: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        origin = try container.decode(Point.self)
        size = try container.decode(Size.self)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(origin)
        try container.encode(size)
    }
}
extension Rect: CustomStringConvertible {
    var description: String {
        "((\(origin.x), \(origin.y)), (\(width), \(height)))"
    }
}
extension Rect {
    func insetBy(dx: Double, dy: Double) -> Rect {
        Rect(x: minX + dx, y: minY + dy,
             width: width - dx * 2, height: height - dy * 2)
    }
    func outsetBy(dx: Double, dy: Double) -> Rect {
        Rect(x: minX - dx, y: minY - dy,
             width: width + dx * 2, height: height + dy * 2)
    }
    func inset(by size: Size) -> Rect {
        insetBy(dx: size.width, dy: size.height)
    }
    func outset(by size: Size) -> Rect {
        insetBy(dx: -size.width, dy: -size.height)
    }
    func inset(by width: Double) -> Rect {
        insetBy(dx: width, dy: width)
    }
    func outset(by width: Double) -> Rect {
        insetBy(dx: -width, dy: -width)
    }
    func inset(by d: Double, _ lrtb: LRTB) -> Rect {
        switch lrtb {
        case .bottom:
            return Rect(x: origin.x, y: origin.y + d,
                        width: size.width, height: size.height - d)
        case .left:
            return Rect(x: origin.x + d, y: origin.y,
                        width: size.width - d, height: size.height)
        case .right:
            return Rect(x: origin.x, y: origin.y,
                        width: size.width - d, height: size.height)
        case .top:
            return Rect(x: origin.x, y: origin.y,
                        width: size.width, height: size.height - d)
        }
    }
    func outset(by d: Double, _ lrtb: LRTB) -> Rect {
        switch lrtb {
        case .bottom:
            return Rect(x: origin.x, y: origin.y - d,
                        width: size.width, height: size.height + d)
        case .left:
            return Rect(x: origin.x - d, y: origin.y,
                        width: size.width + d, height: size.height)
        case .right:
            return Rect(x: origin.x, y: origin.y,
                        width: size.width + d, height: size.height)
        case .top:
            return Rect(x: origin.x, y: origin.y,
                        width: size.width, height: size.height + d)
        }
    }
    
    var minX: Double {
        origin.x
    }
    var minY: Double {
        origin.y
    }
    var midX: Double {
        origin.x + size.width / 2
    }
    var midY: Double {
        origin.y + size.height / 2
    }
    var maxX: Double {
        origin.x + size.width
    }
    var maxY: Double {
        origin.y + size.height
    }
    var width: Double {
        size.width
    }
    var height: Double {
        size.height
    }
    var xRange: DoubleRange {
        DoubleRange(lowerBound: minX, upperBound: maxX)
    }
    var yRange: DoubleRange {
        DoubleRange(lowerBound: minY, upperBound: maxY)
    }
    var isEmpty: Bool {
        origin.isEmpty && size.isEmpty
    }
    var area: Double {
        width * height
    }
    func union(_ other: Rect) -> Rect {
        let minX = min(self.minX, other.minX)
        let maxX = max(self.maxX, other.maxX)
        let minY = min(self.minY, other.minY)
        let maxY = max(self.maxY, other.maxY)
        return Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    func clipped(_ p: Point) -> Point {
        AABB(self).clippedPoint(with: p)
    }
    func clipped(_ other: Rect) -> Rect {
        var n = other
        if n.minX < minX {
            n.origin.x += minX - n.minX
        }
        if n.maxX > maxX {
            n.origin.x += maxX - n.maxX
        }
        if n.minY < minY {
            n.origin.y += minY - n.minY
        }
        if n.maxY > maxY {
            n.origin.y += maxY - n.maxY
        }
        return n
    }
    func moveOut(_ other: Rect) -> Rect {
        if let r = intersection(other) {
            if r == other || r == self {
                let dp = other.centerPoint - centerPoint
                var n = other
                if abs(dp.x) > abs(dp.y) {
                    if dp.x > 0 {
                        if n.minX < maxX {
                            n.origin.x += maxX - n.minX
                        }
                    } else {
                        if n.maxX > minX {
                            n.origin.x -= n.maxX - minX
                        }
                    }
                } else {
                    if dp.y > 0 {
                        if n.minY < maxY {
                            n.origin.y += maxY - n.minY
                        }
                    } else {
                        if n.maxY > minY {
                            n.origin.y -= n.maxY - minY
                        }
                    }
                }
                return n
            } else {
                var n = other
                if r.width > r.height {
                    let n0 = n.maxY - minY, n1 = maxY - n.minY
                    if n0 < n1 {
                        n.origin.y -= n0
                    } else {
                        n.origin.y += n1
                    }
                } else {
                    let n0 = n.maxX - minX, n1 = maxX - n.minX
                    if n0 < n1 {
                        n.origin.x -= n0
                    } else {
                        n.origin.x += n1
                    }
                }
                return n
            }
        } else {
            return other
        }
    }
    func moveOut(_ other: Rect, _ orientation: Orientation) -> Rect {
        guard let ib = intersection(other) else { return other }
        var n = other
        switch orientation {
        case .horizontal:
            if other.minY > minY && other.minY < maxY {
                if other.maxY > minY && other.maxY < maxY {
                    let minD = other.maxY - minY, maxD = maxY - other.minY
                    if minD < maxD {
                        n.origin.y -= minD
                    } else {
                        n.origin.y += maxD
                    }
                } else {
                    n.origin.y += ib.height
                }
            } else if other.maxY > minY && other.maxY < maxY {
                n.origin.y -= ib.height
            } else {
                let minD = minY - other.minY, maxD = other.maxY - maxY
                if minD < maxD {
                    n.origin.y += ib.height + minD
                } else {
                    n.origin.y -= ib.height + maxD
                }
            }
        case .vertical:
            if other.minX > minX && other.minX < maxX {
                if other.maxX > minX && other.maxX < maxX {
                    let minD = other.maxX - minX, maxD = maxX - other.minX
                    if minD < maxD {
                        n.origin.x -= minD
                    } else {
                        n.origin.x += maxD
                    }
                } else {
                    n.origin.x += ib.width
                }
            } else if other.maxX > minX && other.maxX < maxX {
                n.origin.x -= ib.width
            } else {
                let minD = minX - other.minX, maxD = other.maxX - maxX
                if minD < maxD {
                    n.origin.x += ib.width + minD
                } else {
                    n.origin.x -= ib.width + maxD
                }
            }
        }
        return n
    }
    var circleBounds: Rect {
        let r = size.diagonal / 2
        return Rect(x: midX - r, y: midY - r, width: r * 2, height: r * 2)
    }
    var integral: Rect {
        AABB(minX: minX.rounded(.down), maxX: maxX.rounded(.up),
             minY: minY.rounded(.down), maxY: maxY.rounded(.up)).rect
    }
    func moved(by p: Point) -> Rect {
        Rect(origin: origin + p, size: size)
    }
    func distanceSquared(_ point: Point) -> Double {
        AABB(self).nearestDistanceSquared(point)
    }
    func distanceSquared(_ other: Rect) -> Double {
        AABB(self).nearestDistanceSquared(AABB(other))
    }
    mutating func formUnion(_ other: Rect) {
        self = union(other)
    }
    
    func contains(_ p: Point) -> Bool {
        p.x >= origin.x && p.x < origin.x + size.width
            && p.y >= origin.y && p.y < origin.y + size.height
    }
    func contains(_ r: Rect) -> Bool {
        r.origin.x >= origin.x && r.origin.y >= origin.y
            && r.maxX <= maxX && r.maxY <= maxY
    }
    func intersects(_ other: Rect) -> Bool {
        abs(midX - other.midX) < (width + other.width) / 2
            && abs(midY - other.midY) < (height + other.height) / 2
    }
    func intersects(_ edge: Edge) -> Bool {
        if !(!contains(edge.p0) && !contains(edge.p1)) {
            return true
        }
        return rightEdge.intersects(edge)
            || topEdge.intersects(edge)
            || leftEdge.intersects(edge)
            || bottomEdge.intersects(edge)
    }
    func intersection(_ linearLine: LinearLine) -> Edge? {
        let p0 = linearLine.intersection(leftEdge)
        let p1 = linearLine.intersection(rightEdge)
        let p2 = linearLine.intersection(bottomEdge)
        let p3 = linearLine.intersection(topEdge)
        if let p0 = p0 {
            if let p1 = p1, p0 != p1 {
                return Edge(p0, p1)
            } else if let p2 = p2, p0 != p2 {
                return Edge(p0, p2)
            } else if let p3 = p3, p0 != p3 {
                return Edge(p0, p3)
            }
        } else if let p1 = p1 {
            if let p2 = p2, p1 != p2 {
                return Edge(p1, p2)
            } else if let p3 = p3, p1 != p3 {
                return Edge(p1, p3)
            }
        } else if let p2 = p2, let p3 = p3, p2 != p3 {
            return Edge(p2, p3)
        }
        return nil
    }
    func intersection(_ other: Rect) -> Rect? {
        let minX = max(origin.x, other.origin.x)
        let minY = max(origin.y, other.origin.y)
        let maxX = min(origin.x + size.width, other.origin.x + other.size.width)
        let maxY = min(origin.y + size.height, other.origin.y + other.size.height)
        let w = maxX - minX, h = maxY - minY
        return w > 0 && h > 0 ? Rect(x: minX, y: minY, width: w, height: h) : nil
    }
    func intersection(_ edge: Edge) -> [Point] {
        var points = [Point]()
        func append(_ otherEdge: Edge) {
            if points.count < 2, let p = edge.intersection(otherEdge) {
                points.append(p)
            }
        }
        append(rightEdge)
        append(topEdge)
        append(leftEdge)
        append(bottomEdge)
        return points
    }
    
    func extend(width w: Double?, height h: Double?) -> Rect {
        if let w = w {
            if let h = h {
                if width < w || height < h {
                    if width < w && height >= h {
                        return Rect(x: centerPoint.x - w / 2, y: origin.y,
                                    width: w, height: size.height)
                    } else if width >= w && height < h {
                        return Rect(x: origin.x, y: centerPoint.y - h / 2,
                                    width: size.width, height: h)
                    } else {
                        return Rect(x: centerPoint.x - w / 2,
                                    y: centerPoint.y - h / 2,
                                    width: w, height: h)
                    }
                }
            } else {
                if width < w {
                    return Rect(x: centerPoint.x - w / 2, y: origin.y,
                                width: w, height: size.height)
                }
            }
        } else {
            if let h = h {
                if height < h {
                    return Rect(x: origin.x, y: centerPoint.y - h / 2,
                                width: size.width, height: h)
                }
            }
        }
        return self
    }
    func resize(width w: Double?, height h: Double?) -> Rect {
        if let w = w {
            if let h = h {
                return Rect(x: centerPoint.x - w / 2,
                            y: centerPoint.y - h / 2,
                            width: w, height: h)
            } else {
                return Rect(x: centerPoint.x - w / 2, y: origin.y,
                            width: w, height: size.height)
            }
        } else {
            if let h = h {
                return Rect(x: origin.x, y: centerPoint.y - h / 2,
                            width: size.width, height: h)
            } else {
                return self
            }
        }
    }
    
    static func + (lhs: Rect, rhs: Rect) -> Rect {
        lhs.union(rhs)
    }
    static func + (lhs: Rect, rhs: Point) -> Rect {
        Rect(origin: lhs.origin + rhs, size: lhs.size)
    }
    static func - (lhs: Rect, rhs: Point) -> Rect {
        Rect(origin: lhs.origin - rhs, size: lhs.size)
    }
    static func += (lhs: inout Rect, rhs: Rect) {
        lhs = lhs.union(rhs)
    }
    
    var minXMinYPoint: Point {
        Point(minX, minY)
    }
    var midXMinYPoint: Point {
        Point(midX, minY)
    }
    var maxXMinYPoint: Point {
        Point(maxX, minY)
    }
    var minXMidYPoint: Point {
        Point(minX, midY)
    }
    var centerPoint: Point {
        Point(midX, midY)
    }
    var maxXMidYPoint: Point {
        Point(maxX, midY)
    }
    var minXMaxYPoint: Point {
        Point(minX, maxY)
    }
    var midXMaxYPoint: Point {
        Point(midX, maxY)
    }
    var maxXMaxYPoint: Point {
        Point(maxX, maxY)
    }
    var leftEdge: Edge {
        Edge(minXMaxYPoint, minXMinYPoint)
    }
    var rightEdge: Edge {
        Edge(maxXMinYPoint, maxXMaxYPoint)
    }
    var topEdge: Edge {
        Edge(maxXMaxYPoint, minXMaxYPoint)
    }
    var bottomEdge: Edge {
        Edge(minXMinYPoint, maxXMinYPoint)
    }
    
    func lrtb(at p: Point) -> LRTB? {
        guard width != 0 && height != 0 else { return nil }
        let a = (p.x - minX) * (maxY - minY) / (maxX - minX) + minY < p.y
        let b = (p.x - minX) * (minY - maxY) / (maxX - minX) + maxY < p.y
        if a {
            return b ? .top : .left
        } else {
            return b ? .right : .bottom
        }
    }
    
    func rounded() -> Rect {
        let minX = self.minX.rounded(), maxX = self.maxX.rounded()
        let minY = self.minY.rounded(), maxY = self.maxY.rounded()
        return AABB(minX: minX, maxX: maxX, minY: minY, maxY: maxY).rect
    }
    
    func minLine(_ other: Rect) -> Pathline? {
        if intersects(other) { return nil }
        return Pathline([centerPoint, other.centerPoint])
    }
}
extension Rect: AppliableTransform {
    static func * (lhs: Rect, rhs: Transform) -> Rect {
        let minXMinYP = lhs.minXMinYPoint * rhs
        let minXMaxYP = lhs.minXMaxYPoint * rhs
        let maxXMinYP = lhs.maxXMinYPoint * rhs
        let maxXMaxYP = lhs.maxXMaxYPoint * rhs
        return AABB(minX: min(minXMinYP.x, minXMaxYP.x, maxXMinYP.x, maxXMaxYP.x),
                    maxX: max(minXMinYP.x, minXMaxYP.x, maxXMinYP.x, maxXMaxYP.x),
                    minY: min(minXMinYP.y, minXMaxYP.y, maxXMinYP.y, maxXMaxYP.y),
                    maxY: max(minXMinYP.y, minXMaxYP.y, maxXMinYP.y, maxXMaxYP.y))
            .rect
    }
}
extension Optional where Wrapped == Rect {
    static func += (lhs: inout Rect?, rhs: Rect) {
        lhs = lhs?.union(rhs) ?? rhs
    }
    static func += (lhs: inout Rect?, rhs: Rect?) {
        if let rhs = rhs {
            lhs = lhs?.union(rhs) ?? rhs
        }
    }
    static func + (lhs: Rect?, rhs: Rect?) -> Rect? {
        if let rhs = rhs {
            return lhs?.union(rhs) ?? rhs
        } else {
            return lhs
        }
    }
    func contains(_ other: Rect?) -> Bool {
        if let other = other {
            return self?.contains(other) ?? false
        } else {
            return false
        }
    }
    func intersects(_ other: Rect?) -> Bool {
        if let other = other {
            return self?.intersects(other) ?? false
        } else {
            return false
        }
    }
    func intersection(_ other: Rect?) -> Rect? {
        if let other = other {
            return self?.intersection(other)
        } else {
            return nil
        }
    }
}
extension Array where Element == Rect {
    static func checkerboard(with size: Size, in frame: Rect) -> [Rect] {
        let xCount = Int(frame.width / size.width)
        let yCount = Int(frame.height / (size.height * 2))
        var rects = [Rect]()
        
        for xi in 0..<xCount {
            let x = frame.minX + Double(xi) * size.width
            let fy = xi % 2 == 0 ? size.height : 0
            for yi in 0..<yCount {
                let y = frame.minY + Double(yi) * size.height * 2 + fy
                rects.append(Rect(x: x, y: y, width: size.width, height: size.height))
            }
        }
        return rects
    }
    func union() -> Rect? {
        reduce(into: Rect?.none) { $0 += $1 }
    }
}

struct AABB: Codable, Hashable {
    var xRange = DoubleRange(), yRange = DoubleRange()
    init() {
        xRange = DoubleRange()
        yRange = DoubleRange()
    }
    init(xRange: DoubleRange, yRange: DoubleRange) {
        self.xRange = xRange
        self.yRange = yRange
    }
    init(minX: Double, maxX: Double, minY: Double, maxY: Double) {
        xRange = DoubleRange(lowerBound: minX, upperBound: maxX)
        yRange = DoubleRange(lowerBound: minY, upperBound: maxY)
    }
    init(maxValue: Double) {
        self.init(minX: -maxValue, maxX: maxValue,
                  minY: -maxValue, maxY: maxValue)
    }
    init(maxValueX: Double, maxValueY: Double) {
        self.init(minX: -maxValueX, maxX: maxValueX,
                  minY: -maxValueY, maxY: maxValueY)
    }
    init(_ p: Point) {
        xRange = DoubleRange(p.x)
        yRange = DoubleRange(p.y)
    }
    init(_ p0: Point, _ p1: Point) {
        xRange = DoubleRange(p0.x, p1.x)
        yRange = DoubleRange(p0.y, p1.y)
    }
    init(_ rect: Rect) {
        xRange = rect.xRange
        yRange = rect.yRange
    }
    init(_ b: Bezier) {
        let cp0 = b.p0.mid(b.cp), cp1 = b.cp.mid(b.p1)
        xRange = DoubleRange(lowerBound: min(b.p0.x, cp0.x, cp1.x, b.p1.x),
                             upperBound: max(b.p0.x, cp0.x, cp1.x, b.p1.x))
        yRange = DoubleRange(lowerBound: min(b.p0.y, cp0.y, cp1.y, b.p1.y),
                             upperBound: max(b.p0.y, cp0.y, cp1.y, b.p1.y))
    }
    init(_ b: Bezier3) {
        xRange = DoubleRange(lowerBound: min(b.p0.x, b.cp0.x, b.cp1.x, b.p1.x),
                             upperBound: max(b.p0.x, b.cp0.x, b.cp1.x, b.p1.x))
        yRange = DoubleRange(lowerBound: min(b.p0.y, b.cp0.y, b.cp1.y, b.p1.y),
                             upperBound: max(b.p0.y, b.cp0.y, b.cp1.y, b.p1.y))
    }
}
extension AABB {
    var width: Double {
        xRange.width
    }
    var height: Double {
        yRange.width
    }
    var minX: Double {
        xRange.lowerBound
    }
    var minY: Double {
        yRange.lowerBound
    }
    var midX: Double {
        xRange.mid
    }
    var midY: Double {
        yRange.mid
    }
    var maxX: Double {
        xRange.upperBound
    }
    var maxY: Double {
        yRange.upperBound
    }
    var rect: Rect {
        Rect(x: minX, y: minY, width: width, height: height)
    }
    func contains(_ point: Point) -> Bool {
        xRange.contains(point.x) && yRange.contains(point.y)
    }
    func intersects(_ other: AABB) -> Bool {
        xRange.intersects(other.xRange)
            && yRange.intersects(other.yRange)
    }
    func clippedPoint(with point: Point) -> Point {
        Point(xRange.clipped(point.x),
              yRange.clipped(point.y))
    }
    func nearestDistanceSquared(_ p: Point) -> Double {
        if p.x < minX {
            if p.y < minY {
                return .hypotSquared(minX - p.x, minY - p.y)
            } else if p.y <= maxY {
                return (minX - p.x).squared
            } else {
                return .hypotSquared(minX - p.x, p.y - maxY)
            }
        } else if p.x <= maxX {
            if p.y < minY {
                return (minY - p.y).squared
            } else if p.y <= maxY {
                return 0
            } else {
                return (p.y - maxY).squared
            }
        } else {
            if p.y < minY {
                return .hypotSquared(maxX - p.x, minY - p.y)
            } else if p.y <= maxY {
                return (maxX - p.x).squared
            } else {
                return .hypotSquared(p.x - maxX, p.y - maxY)
            }
        }
    }
    func nearestDistanceSquared(_ other: AABB) -> Double {
        guard !intersects(other) else { return 0 }
        if other.maxX < minX {
            if other.maxY < minY {
                return .hypotSquared(minX - other.maxX, minY - other.maxY)
            } else if other.minY <= maxY {
                return (minX - other.maxX).squared
            } else {
                return .hypotSquared(minX - other.maxX, other.minY - maxY)
            }
        } else if other.minX <= maxX {
            if other.maxY < minY {
                return (minY - other.maxY).squared
            } else {
                return (other.minY - maxY).squared
            }
        } else {
            if other.maxY < minY {
                return .hypotSquared(maxX - other.minX, minY - other.maxY)
            } else if other.minY <= maxY {
                return (other.minX - maxX).squared
            } else {
                return .hypotSquared(other.minX - maxX, other.minY - maxY)
            }
        }
    }
    
    static func + (lhs: AABB, rhs: Point) -> AABB {
        AABB(xRange: lhs.xRange + rhs.x,
             yRange: lhs.yRange + rhs.y)
    }
    static func + (lhs: AABB, rhs: AABB) -> AABB {
        AABB(xRange: lhs.xRange + rhs.xRange,
             yRange: lhs.yRange + rhs.yRange)
    }
    static func += (lhs: inout AABB, rhs: Point) {
        lhs = lhs + rhs
    }
    static func += (lhs: inout AABB, rhs: AABB) {
        lhs = lhs + rhs
    }
}
