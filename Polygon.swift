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

// PolyPartition
// https://github.com/ivanfratric/polypartition
//
// Copyright (C) 2011 by Ivan Fratric
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

struct Triangle: Hashable, Codable {
    var p0, p1, p2: Point
    init() {
        p0 = Point()
        p1 = Point()
        p2 = Point()
    }
    init(_ p0: Point, _ p1: Point, _ p2: Point) {
        self.p0 = p0
        self.p1 = p1
        self.p2 = p2
    }
}
extension Triangle {
    var area: Double {
        abs((p0 - p2).cross(p1 - p2)) / 2
    }
    var bounds: Rect {
        let minX = min(p0.x, p1.x, p2.x)
        let maxX = max(p0.x, p1.x, p2.x)
        let minY = min(p0.y, p1.y, p2.y)
        let maxY = max(p0.y, p1.y, p2.y)
        return AABB(minX: minX, maxX: maxX,
                    minY: minY, maxY: maxY).rect
    }
    func contaions(_ p: Point) -> Bool {
        let p0p1 = p1 - p0
        let p1p = p - p1
        let p1p2 = p2 - p1
        let p2p = p - p2
        let p2p0 = p0 - p2
        let p0p = p - p0
        let x0 = p0p1.cross(p1p)
        let x1 = p1p2.cross(p2p)
        let x2 = p2p0.cross(p0p)
        return (x0 > 0 && x1 > 0 && x2 > 0) || (x0 < 0 && x1 < 0 && x2 < 0)
    }
}

struct Polygon: Hashable, Codable {
    var points = [Point]()
}
extension Polygon: Protobuf {
    init(_ pb: PBPolygon) throws {
        points = try pb.points.map { try Point($0).notInfinite() }
    }
    var pb: PBPolygon {
        PBPolygon.with {
            $0.points = points.map { $0.pb }
        }
    }
}
extension Polygon: AppliableTransform {
    static func * (lhs: Polygon, rhs: Transform) -> Polygon {
        Polygon(points: lhs.points.map { $0 * rhs })
    }
}
extension Polygon {
    init(_ rect: Rect) {
        self.init(points: [rect.minXMaxYPoint, rect.minXMinYPoint,
                           rect.maxXMinYPoint, rect.maxXMaxYPoint])
    }
    static func == (lhs: Polygon, rhs: Rect) -> Bool {
        if lhs.points.count == 4 {
            let ps = [rhs.minXMinYPoint, rhs.maxXMinYPoint,
                      rhs.maxXMaxYPoint, rhs.minXMaxYPoint]
            let rps = Array(ps.reversed())
            let lps0 = [lhs.points[0], lhs.points[1],
                        lhs.points[2], lhs.points[3]]
            if lps0 == ps || lps0 == rps {
                return true
            }
            let lps1 = [lhs.points[1], lhs.points[2],
                        lhs.points[3], lhs.points[0]]
            if lps1 == ps || lps1 == rps {
                return true
            }
            let lps2 = [lhs.points[2], lhs.points[3],
                        lhs.points[0], lhs.points[1]]
            if lps2 == ps || lps2 == rps {
                return true
            }
            let lps3 = [lhs.points[3], lhs.points[0],
                        lhs.points[1], lhs.points[2]]
            if lps3 == ps || lps3 == rps {
                return true
            }
        }
        return false
    }
    static func == (lhs: Rect, rhs: Polygon) -> Bool {
        rhs == lhs
    }
    static func != (lhs: Polygon, rhs: Rect) -> Bool {
        !(lhs == rhs)
    }
    static func != (lhs: Rect, rhs: Polygon) -> Bool {
        !(lhs == rhs)
    }
    var orientation: CircularOrientation? {
        guard var p0 = points.last else {
            return nil
        }
        var area = 0.0
        for p1 in points {
            area += p0.cross(p1)
            p0 = p1
        }
        if area > 0 {
            return .counterClockwise
        } else if area < 0 {
            return .clockwise
        } else {
            return nil
        }
    }
    func inverted() -> Polygon {
        Polygon(points: points.reversed())
    }
    var isEmpty: Bool {
        points.isEmpty
    }
    var centroid: Point? {
        guard !points.isEmpty else { return nil }
        return points.reduce(Point()) { $0 + $1 } / Double(points.count)
    }
    var bounds: Rect? {
        guard let minX = points.min(by: { $0.x < $1.x })?.x,
              let maxX = points.max(by: { $0.x < $1.x })?.x,
              let minY = points.min(by: { $0.y < $1.y })?.y,
              let maxY = points.max(by: { $0.y < $1.y })?.y else { return nil }
        return AABB(minX: minX, maxX: maxX, minY: minY, maxY: maxY).rect
    }
    func rayCasting(_ p: Point) -> Int {
        guard !isEmpty else { return 0 }
        var count = 0
        var p0 = points.last!
        for p1 in points {
            count += Edge(p0, p1).rayCasting(p)
            p0 = p1
        }
        return count
    }
    func contains(_ p: Point) -> Bool {
        rayCasting(p) % 2 != 0
    }
    var isConvex: Bool {
        let ccw0 = Point.ccw(points[0], points[1], points[2])
        guard ccw0 != 0 else { return false }
        for i in 1..<points.count {
            let p0 = points[i]
            let p1 = points[(i + 1) % points.count]
            let p2 = points[(i + 2) % points.count]
            let nccw = Point.ccw(p0, p1, p2)
            if ccw0 * nccw <= 0 {
                return false
            }
        }
        return true
    }
    var convexHull: Polygon {
        guard points.count > 3 else {
            return self
        }
        var nps = [Point]()
        nps.reserveCapacity(points.count)
        let ps = points.sorted { $0.x < $1.x || ($0.x == $1.x && $0.y < $1.y)  }
        for i in 0..<ps.count {
            while nps.count > 1 && Point.ccw(nps[nps.count - 2],
                                             nps[nps.count - 1], ps[i]) <= 0 {
                nps.removeLast()
            }
            nps.append(ps[i])
        }
        let t = nps.count
        for i in (0...(ps.count - 2)).reversed() {
            while nps.count > t && Point.ccw(nps[nps.count - 2],
                                             nps[nps.count - 1], ps[i]) <= 0 {
                nps.removeLast()
            }
            nps.append(ps[i])
        }
        nps.removeLast()
        return Polygon(points: nps)
    }
    var strip: Polygon {
        var nps = [Point]()
        nps.reserveCapacity(points.count)
        nps.append(points[0])
        (1..<points.count).forEach { i in
            let i = i % 2 != 0 ? i / 2 + 1 : points.count - i / 2
            nps.append(points[i])
        }
        return Polygon(points: nps)
    }
    var isIntersectsEdges: Bool {
        guard points.count >= 2 else { return false }
        var p0 = points.last!
        for i in 0..<(points.count - 1) {
            let p1 = points[i]
            let edge0 = Edge(p0, p1)
            var p2 = p1
            for j in (i + 1)..<points.count {
                let p3 = points[j]
                let edge1 = Edge(p2, p3)
                if edge0.intersectsNone0(edge1) {
                    return true
                }
                p2 = p3
            }
            p0 = p1
        }
        return false
    }
    var area: Double {
        guard let polys = try? monotonePolygons() else { return 0 }
        return polys.reduce(0.0) { $0 + $1.trianglesArea }
    }
    var monotoneTriangles: [Triangle] {
        guard let polys = try? monotonePolygons() else { return [] }
        return polys.reduce(into: [Triangle]()) { $0 += $1.triangles }
    }
    private var trianglesArea: Double {
        triangles.reduce(0.0) { $0 + $1.area }
    }
    func noIntersectedPolygons() -> [Polygon] {
        guard let lp = points.last else { return [] }
        
        struct PEdge: Hashable {
            var psIndex = 0, isReversed = false
            
            func reversed() -> PEdge {
                PEdge(psIndex: psIndex, isReversed: !isReversed)
            }
        }
        struct PValue: Hashable {
            var index: Int, t: Double, p: Point
        }
        
        var op = points.last!, ops = [Point]()
        ops.reserveCapacity(points.count)
        (0..<points.count).forEach {
            let p = points[$0]
            if p != op {
                ops.append(p)
                op = p
            }
        }
        
        var p0 = lp, pvs = [PValue]()
        for i in 0..<(ops.count - 1) {
            let p1 = ops[i]
            let edge0 = Edge(p0, p1)
            var p2 = p1
            for j in (i + 1)..<ops.count {
                let p3 = ops[j]
                let edge1 = Edge(p2, p3)
                if let p = edge0.intersection(edge1) {
                    if edge0.p0 != p && edge0.p1 != p {
                        pvs.append(PValue(index: i,
                                          t: edge0.nearestT(from: p),
                                          p: p))
                    }
                    if edge1.p0 != p && edge1.p1 != p {
                        pvs.append(PValue(index: j,
                                          t: edge1.nearestT(from: p),
                                          p: p))
                    }
                }
                p2 = p3
            }
            p0 = p1
        }
        func sortPValue(_ pv0: PValue, _ pv1: PValue) -> Bool {
            if pv0.index == pv1.index {
                return pv0.t > pv1.t
            } else {
                return pv0.index > pv1.index
            }
        }
        var nps = ops
        Set(pvs).sorted(by: sortPValue).forEach { nps.insert($0.p, at: $0.index) }
        
        let edges = (0..<nps.count).reduce(into: [PEdge]()) {
            $0.append(PEdge(psIndex: $1, isReversed: false))
            $0.append(PEdge(psIndex: $1, isReversed: true))
        }
        
        var minI = 0, minP = nps[0]
        for (i, p) in nps.enumerated() {
            if p.x == minP.x ? p.y < minP.y : p.x < minP.x {
                minP = p
                minI = i
            }
        }
        
        func point(with pe: PEdge) -> Point {
            let i = pe.isReversed ?
                (pe.psIndex == nps.count - 1 ? 0 : pe.psIndex + 1) :
                pe.psIndex
            return nps[i]
        }
        func nextPoint(with pe: PEdge) -> Point {
            let i = pe.isReversed ?
                pe.psIndex :
                (pe.psIndex == nps.count - 1 ? 0 : pe.psIndex + 1)
            return nps[i]
        }
        func vector(with pe: PEdge) -> Point {
            nextPoint(with: pe) - point(with: pe)
        }
        
        var pDic = [Point: [PEdge]]()
        for pe in edges {
            let p = point(with: pe)
            if pDic[p] != nil {
                pDic[p]?.append(pe)
            } else {
                pDic[p] = [pe]
            }
        }
        
        func nextEdge(from pe: PEdge) -> PEdge? {
            let p = nextPoint(with: pe)
            let vector0 = vector(with: pe)
            guard var pes = pDic[p] else { return nil }
            pes.remove(at: pes.firstIndex(of: pe.reversed())!)
            let pas: [(pe: PEdge, angle: Double)] = pes.map {
                let vector1 = vector(with: $0)
                return ($0, Double2.differenceAngle(vector0, vector1))
            }
            return pas.max { $0.angle < $1.angle }!.pe
        }
        
        var polygons = [Polygon]()
        var filledEdges = Set<PEdge>()
        for fpe in edges {
            guard !filledEdges.contains(fpe) else { continue }
            var pe = fpe, nps = [Point](), isAppend = true
            while true {
                filledEdges.insert(pe)
                nps.append(point(with: pe))
                guard let npe = nextEdge(from: pe) else { break }
                pe = npe
                if pe == fpe { break }
                if filledEdges.contains(pe) {
                    isAppend = false
                    break
                }
            }
            if isAppend && fpe.psIndex != minI {
                polygons.append(Polygon(points: nps))
            }
        }
        return polygons
    }
    
    var isMonotone: Bool {
        guard points.count >= 3 else {
            return false
        }
        var topIndex = 0, bottomIndex = 0
        for i in 1..<points.count {
            if points[i].isBelow(points[bottomIndex]) {
                bottomIndex = i
            }
            if points[topIndex].isBelow(points[i]) {
                topIndex = i
            }
        }
        var index = topIndex
        while index != bottomIndex {
            let j = index + 1 < points.count ? index + 1 : 0
            guard points[j].isBelow(points[index]) else {
                return false
            }
            index = j
        }
        index = bottomIndex
        while index != topIndex {
            let j = index + 1 < points.count ? index + 1 : 0
            guard points[index].isBelow(points[j]) else {
                return false
            }
            index = j
        }
        return true
    }
    struct PolygonError: Error {}
    func monotonePolygons() throws -> [Polygon] {
        guard points.count >= 3 else { return [] }
        let ps: [Point] = points.enumerated().compactMap { i, p1 in
            let p0 = points[i - 1 >= 0 ? i - 1 : points.count - 1]
            let p2 = points[i + 1 < points.count ? i + 1 : 0]
            let d = (p1.x - p0.x) * (p1.y - p2.y) - (p1.y - p0.y) * (p1.x - p2.x)
            return abs(d) <= .ulpOfOne ? nil : p1
        }
        guard ps.count >= 3 else { return [] }
        
        let verticesCount = ps.count
        var vs = [MVertex]()
        vs.reserveCapacity(verticesCount)
        var es = [MEdge]()
        es.reserveCapacity(verticesCount)
        for (i, p) in ps.enumerated() {
            let previousIndex = i == 0 ? ps.count - 1 : i - 1
            let nextIndex = i == ps.count - 1 ? 0 : i + 1
            let prevP = ps[previousIndex]
            let nextP = ps[nextIndex]
            let type: MVertex.VertexType
            if prevP.isBelow(p) && nextP.isBelow(p) {
                type = Point.isConvex(nextP, prevP, p) ? .start : .split
            } else if p.isBelow(prevP) && p.isBelow(nextP) {
                type = Point.isConvex(nextP, prevP, p) ? .end : .merge
            } else {
                type = .regular
            }
            vs.append(MVertex(p: p, type: type,
                              previousIndex: previousIndex,
                              nextIndex: nextIndex))
            es.append(MEdge(index: i, p0: p, p1: nextP))
        }
        
        var eTree = BinarySearchTree<MEdge>()
        var helpers = [Int: Int]()
        
        struct Diagonal: Hashable {
            var i0, i1: Int
        }
        var diagonals = [Diagonal]()
        func addDiagonal(i0: Int, i1: Int) {
            if i0 < i1 {
                diagonals.append(Diagonal(i0: i0, i1: i1))
            } else {
                diagonals.append(Diagonal(i0: i1, i1: i0))
            }
        }
        
        let priorityQueue = (0..<vs.count).sorted {
            let p0 = vs[$0].p, p1 = vs[$1].p
            return p0.y > p1.y || (p0.y == p1.y && p0.x > p1.x)
        }
        for pi in 0..<priorityQueue.count {
            let i = priorityQueue[pi]
            let v = vs[i]
            switch v.type {
            case .start:
                eTree.insert(es[i])
                helpers[i] = i
            case .end:
                let preI = v.previousIndex
                guard let hi = helpers[preI] else { throw PolygonError() }
                if vs[hi].type == .merge {
                    addDiagonal(i0: i, i1: hi)
                }
                eTree.remove(es[preI])
            case .split:
                let ve = MEdge(index: 0, p0: v.p, p1: v.p)
                guard let j = eTree.previous(at: ve)?.index,
                      let hj = helpers[j] else { throw PolygonError() }
                addDiagonal(i0: i, i1: hj)
                helpers[j] = i
                eTree.insert(es[i])
                helpers[i] = i
            case .merge:
                let preI = v.previousIndex
                guard let hi = helpers[preI] else { throw PolygonError() }
                if vs[hi].type == .merge {
                    addDiagonal(i0: i, i1: hi)
                }
                eTree.remove(es[preI])
                
                let ve = MEdge(index: 0, p0: vs[i].p, p1: vs[i].p)
                guard let j = eTree.previous(at: ve)?.index,
                      let hj = helpers[j] else { throw PolygonError() }
                if vs[hj].type == .merge {
                    addDiagonal(i0: i, i1: hj)
                }
                helpers[j] = i
            case .regular:
                let preI = v.previousIndex
                if v.p.isBelow(vs[preI].p) {
                    guard let hi = helpers[preI] else { throw PolygonError() }
                    if vs[hi].type == .merge {
                        addDiagonal(i0: i, i1: hi)
                    }
                    eTree.remove(es[preI])
                    eTree.insert(es[i])
                    helpers[i] = i
                } else {
                    let ve = MEdge(index: 0, p0: v.p, p1: v.p)
                    guard let j = eTree.previous(at: ve)?.index,
                          let hj = helpers[j] else { throw PolygonError() }
                    if vs[hj].type == .merge {
                        addDiagonal(i0: i, i1: hj)
                    }
                    helpers[j] = i
                }
            }
        }
        
        guard !diagonals.isEmpty else {
            return [Polygon(points: vs.map { $0.p })]
        }
        
        struct NPolygon {
            var pis: [Int]
        }
        var nPolys = [NPolygon(pis: Array(0..<vs.count))]
        var polyIndexes = [Set<Int>]()
        polyIndexes = (0..<vs.count).map { _ in Set([0]) }
        for diagonal in diagonals {
            let polyI0s = polyIndexes[diagonal.i0]
            var polyI = polyI0s.first!
            if polyI0s.count > 1 {
                let polyI1s = polyIndexes[diagonal.i1]
                for pi in polyI1s {
                    if polyI0s.contains(pi) {
                        polyI = pi
                        break
                    }
                }
            }
            
            var pis0 = [Int](), pis1 = [Int]()
            let poly1I = nPolys.count
            for pi in nPolys[polyI].pis {
                if pi == diagonal.i0 || pi == diagonal.i1 {
                    pis0.append(pi)
                    pis1.append(pi)
                    polyIndexes[pi].insert(poly1I)
                } else if pi > diagonal.i0 && pi < diagonal.i1 {
                    pis1.append(pi)
                    polyIndexes[pi] = Set([poly1I])
                } else {
                    pis0.append(pi)
                }
            }
            
            nPolys[polyI].pis = pis0
            nPolys.append(NPolygon(pis: pis1))
        }
        return nPolys.map { Polygon(points: $0.pis.map { vs[$0].p }) }.filter {
            if $0.isMonotone {
                return true
            } else {
                print("No monotone polygon", $0.points.count)
                return false
            }
        }
    }
    
    var triangles: [Triangle] {
        guard points.count > 2 else { return [] }
        if points.count == 3 {
            return [Triangle(points[0], points[1], points[2])]
        } else if isConvex {
            var ps = [Point]()
            ps.reserveCapacity(points.count)
            ps.append(points[0])
            (1..<points.count).forEach { i in
                let i = i % 2 != 0 ?
                    i / 2 + 1 :
                    points.count - i / 2
                ps.append(points[i])
            }
            let tCount = points.count - 2
            return (0..<tCount).map {
                Triangle(points[$0], points[$0 + 1], points[$0 + 2])
            }
        } else {
            var ts = [Triangle]()
            func appendTriangle(_ i0: Int, _ i1: Int, _ i2: Int) {
                ts.append(Triangle(points[i0], points[i1], points[i2]))
            }
            
            var topIndex = 0, bottomIndex = 0
            for i in 1..<points.count {
                if points[i].isBelow(points[bottomIndex]) {
                    bottomIndex = i
                }
                if points[topIndex].isBelow(points[i]) {
                    topIndex = i
                }
            }
            
            var priority = Array(repeating: 0, count: points.count)
            var vertexTypes = Array(repeating: 0, count: points.count)
            priority[0] = topIndex
            vertexTypes[topIndex] = 0
            
            var leftIndex = topIndex + 1 < points.count ? topIndex + 1 : 0
            var rightIndex = topIndex - 1 >= 0 ? topIndex - 1 : points.count - 1
            for i in 1..<points.count - 1 {
                if leftIndex == bottomIndex {
                    priority[i] = rightIndex
                    rightIndex -= 1
                    if rightIndex < 0 {
                        rightIndex = points.count - 1
                    }
                    vertexTypes[priority[i]] = -1
                } else if rightIndex == bottomIndex {
                    priority[i] = leftIndex
                    leftIndex += 1
                    if leftIndex >= points.count {
                        leftIndex = 0
                    }
                    vertexTypes[priority[i]] = 1
                } else if points[leftIndex].isBelow(points[rightIndex]) {
                    priority[i] = rightIndex
                    rightIndex -= 1
                    if rightIndex < 0 {
                        rightIndex = points.count - 1
                    }
                    vertexTypes[priority[i]] = -1
                } else {
                    priority[i] = leftIndex
                    leftIndex += 1
                    if leftIndex >= points.count {
                        leftIndex = 0
                    }
                    vertexTypes[priority[i]] = 1
                }
            }
            priority[points.count - 1] = bottomIndex
            vertexTypes[bottomIndex] = 0
            
            var vIndex = 0
            var stack = Array(repeating: 0, count: points.count)
            stack[0] = priority[0]
            stack[1] = priority[1]
            var stackIndex = 2
            for i in 2..<points.count - 1 {
                vIndex = priority[i]
                if vertexTypes[vIndex] != vertexTypes[stack[stackIndex - 1]] {
                    for j in 0..<stackIndex - 1 {
                        if vertexTypes[vIndex] == 1 {
                            appendTriangle(stack[j + 1],
                                           stack[j],
                                           vIndex)
                        } else {
                            appendTriangle(stack[j],
                                           stack[j + 1],
                                           vIndex)
                        }
                    }
                    stack[0] = priority[i - 1]
                    stack[1] = priority[i]
                    stackIndex = 2
                } else {
                    stackIndex -= 1
                    while stackIndex > 0 {
                        if vertexTypes[vIndex] == 1 {
                            if Point.isConvex(points[vIndex],
                                              points[stack[stackIndex - 1]],
                                              points[stack[stackIndex]]) {
                                appendTriangle(vIndex,
                                               stack[stackIndex - 1],
                                               stack[stackIndex])
                                stackIndex -= 1
                            } else {
                                break
                            }
                        } else {
                            if Point.isConvex(points[vIndex],
                                              points[stack[stackIndex]],
                                              points[stack[stackIndex - 1]]) {
                                appendTriangle(vIndex,
                                               stack[stackIndex],
                                               stack[stackIndex - 1])
                                stackIndex -= 1
                            } else {
                                break
                            }
                        }
                    }
                    stackIndex += 1
                    stack[stackIndex] = vIndex
                    stackIndex += 1
                }
            }
            vIndex = priority[points.count - 1]
            for j in 0..<stackIndex - 1 {
                if vertexTypes[stack[j + 1]] == 1 {
                    appendTriangle(stack[j],
                                   stack[j + 1],
                                   vIndex)
                } else {
                    appendTriangle(stack[j + 1],
                                   stack[j],
                                   vIndex)
                }
            }
            
            return ts
        }
    }
    func floatTriangles(in floatPoints: inout [Float],
                        counts: inout [Int], oldIndex: inout Int) {
        guard points.count > 2 else { return }
        if points.count == 3 {
            var nps = [Float]()
            func append(_ p: Point) {
                nps.append(Float(p.x))
                nps.append(Float(p.y))
                nps.append(0)
                nps.append(1)
            }
            append(points[0])
            append(points[1])
            append(points[2])
            floatPoints += nps
            counts.append((floatPoints.count - oldIndex) / 4)
            oldIndex = floatPoints.count
        } else if isConvex {
            var nps = [Float]()
            func append(_ p: Point) {
                nps.append(Float(p.x))
                nps.append(Float(p.y))
                nps.append(0)
                nps.append(1)
            }
            append(points[0])
            (1..<points.count).forEach { i in
                let i = i % 2 != 0 ? i / 2 + 1 : points.count - i / 2
                append(points[i])
            }
            floatPoints += nps
            counts.append((floatPoints.count - oldIndex) / 4)
            oldIndex = floatPoints.count
        } else {
            var nps = [Float](), oldI0 = 0, oldI1 = 0
            func append(_ p: Point) {
                nps.append(Float(p.x))
                nps.append(Float(p.y))
                nps.append(0)
                nps.append(1)
            }
            func newIndex(_ i0: Int, _ i1: Int, _ i2: Int) -> Int? {
                if (oldI0 == i0 && oldI1 == i1)
                    || (oldI0 == i1 && oldI1 == i0) {
                    
                    return i2
                } else if (oldI0 == i0 && oldI1 == i2)
                            || (oldI0 == i2 && oldI1 == i0) {
                    return i1
                } else if (oldI0 == i2 && oldI1 == i1)
                            || (oldI0 == i1 && oldI1 == i2) {
                    return i0
                } else {
                    return nil
                }
            }
            func appendTriangle(_ i0: Int, _ i1: Int, _ i2: Int) {
                if let ni = newIndex(i0, i1, i2) {
                    append(points[ni])
                } else {
                    if !nps.isEmpty {
                        floatPoints += nps
                        counts.append((floatPoints.count - oldIndex) / 4)
                        oldIndex = floatPoints.count
                        nps = []
                    }
                    append(points[i0])
                    append(points[i1])
                    append(points[i2])
                }
            }
            
            var topIndex = 0, bottomIndex = 0
            for i in 1..<points.count {
                if points[i].isBelow(points[bottomIndex]) {
                    bottomIndex = i
                }
                if points[topIndex].isBelow(points[i]) {
                    topIndex = i
                }
            }
            
            var priority = Array(repeating: 0, count: points.count)
            var vertexTypes = Array(repeating: 0, count: points.count)
            priority[0] = topIndex
            vertexTypes[topIndex] = 0
            
            var leftIndex = topIndex + 1 < points.count ? topIndex + 1 : 0
            var rightIndex = topIndex - 1 >= 0 ? topIndex - 1 : points.count - 1
            for i in 1..<points.count - 1 {
                if leftIndex == bottomIndex {
                    priority[i] = rightIndex
                    rightIndex -= 1
                    if rightIndex < 0 {
                        rightIndex = points.count - 1
                    }
                    vertexTypes[priority[i]] = -1
                } else if rightIndex == bottomIndex {
                    priority[i] = leftIndex
                    leftIndex += 1
                    if leftIndex >= points.count {
                        leftIndex = 0
                    }
                    vertexTypes[priority[i]] = 1
                } else if points[leftIndex].isBelow(points[rightIndex]) {
                    priority[i] = rightIndex
                    rightIndex -= 1
                    if rightIndex < 0 {
                        rightIndex = points.count - 1
                    }
                    vertexTypes[priority[i]] = -1
                } else {
                    priority[i] = leftIndex
                    leftIndex += 1
                    if leftIndex >= points.count {
                        leftIndex = 0
                    }
                    vertexTypes[priority[i]] = 1
                }
            }
            priority[points.count - 1] = bottomIndex
            vertexTypes[bottomIndex] = 0
            
            var vIndex = 0
            var stack = Array(repeating: 0, count: points.count)
            stack[0] = priority[0]
            stack[1] = priority[1]
            var stackIndex = 2
            for i in 2..<points.count - 1 {
                vIndex = priority[i]
                if vertexTypes[vIndex] != vertexTypes[stack[stackIndex - 1]] {
                    for j in 0..<stackIndex - 1 {
                        if vertexTypes[vIndex] == 1 {
                            appendTriangle(stack[j + 1],
                                           stack[j],
                                           vIndex)
                        } else {
                            appendTriangle(stack[j],
                                           stack[j + 1],
                                           vIndex)
                        }
                    }
                    stack[0] = priority[i - 1]
                    stack[1] = priority[i]
                    stackIndex = 2
                } else {
                    stackIndex -= 1
                    while stackIndex > 0 {
                        if vertexTypes[vIndex] == 1 {
                            if Point.isConvex(points[vIndex],
                                              points[stack[stackIndex - 1]],
                                              points[stack[stackIndex]]) {
                                appendTriangle(vIndex,
                                               stack[stackIndex - 1],
                                               stack[stackIndex])
                                stackIndex -= 1
                            } else {
                                break
                            }
                        } else {
                            if Point.isConvex(points[vIndex],
                                              points[stack[stackIndex]],
                                              points[stack[stackIndex - 1]]) {
                                appendTriangle(vIndex,
                                               stack[stackIndex],
                                               stack[stackIndex - 1])
                                stackIndex -= 1
                            } else {
                                break
                            }
                        }
                    }
                    stackIndex += 1
                    stack[stackIndex] = vIndex
                    stackIndex += 1
                }
            }
            vIndex = priority[points.count - 1]
            for j in 0..<stackIndex - 1 {
                if vertexTypes[stack[j + 1]] == 1 {
                    appendTriangle(stack[j],
                                   stack[j + 1],
                                   vIndex)
                } else {
                    appendTriangle(stack[j + 1],
                                   stack[j],
                                   vIndex)
                }
            }
            
            if !nps.isEmpty {
                floatPoints += nps
                counts.append((floatPoints.count - oldIndex) / 4)
                oldIndex = floatPoints.count
                nps = []
            }
        }
    }
}

struct Topolygon {
    var polygon = Polygon()
    var holePolygons = [Polygon]()
}
extension Topolygon {
    init(points: [Point]) {
        polygon = Polygon(points: points)
        holePolygons = []
    }
}
extension Topolygon: Codable {}
extension Topolygon: Hashable {}
extension Topolygon: AppliableTransform {
    static func * (lhs: Topolygon, rhs: Transform) -> Topolygon {
        Topolygon(polygon: lhs.polygon * rhs,
                        holePolygons: lhs.holePolygons.map { $0 * rhs })
    }
}
extension Topolygon {
    var isEmpty: Bool {
        polygon.isEmpty && holePolygons.contains { $0.isEmpty }
    }
    var bounds: Rect? {
        polygon.bounds
    }
    var centroid: Point? {
        polygon.centroid
    }
    func rayCasting(_ p: Point) -> Int {
        var count = 0
        count += polygon.rayCasting(p)
        holePolygons.forEach { count += $0.rayCasting(p) }
        return count
    }
    func contains(_ p: Point) -> Bool {
        rayCasting(p) % 2 != 0
    }
    var area: Double {
        if let polygons = try? monotonePolygons() {
            return polygons.reduce(0.0) { $0 + $1.area }
        } else {
            return 0
        }
    }
}

private struct MVertex {
    enum VertexType {
        case start, end, split, merge, regular
    }
    var p: Point, type: VertexType, previousIndex, nextIndex: Int
}
private struct MEdge: Comparable {
    var index: Int, p0, p1: Point
    
    static func == (lhs: MEdge, rhs: MEdge) -> Bool {
        lhs.index == rhs.index
    }
    static func < (lhs: MEdge, rhs: MEdge) -> Bool {
        func isConvex(_ p0: Point, _ p1: Point, _ p2: Point) -> Bool {
            (p2.y - p0.y) * (p1.x - p0.x) - (p2.x - p0.x) * (p1.y - p0.y) > 0
        }
        if rhs.p0.y == rhs.p1.y {
            if lhs.p0.y == lhs.p1.y {
                return lhs.p0.y < rhs.p0.y
            } else {
                return isConvex(lhs.p0, lhs.p1, rhs.p0)
            }
        } else if lhs.p0.y == lhs.p1.y {
            return !isConvex(rhs.p0, rhs.p1, lhs.p0)
        } else if lhs.p0.y < rhs.p0.y {
            return !isConvex(rhs.p0, rhs.p1, lhs.p0)
        } else {
            return isConvex(lhs.p0, lhs.p1, rhs.p0)
        }
    }
}
extension Topolygon {
    struct TopolygonError: Error {}
    func monotonePolygons() throws -> [Polygon] {
        let oPolys = [polygon] + holePolygons
        let polygons: [Polygon] = oPolys.compactMap { polygon in
            guard polygon.points.count >= 3 else { return nil }
            let ops = polygon.points
            let points: [Point] = ops.enumerated().compactMap { i, p1 in
                let p0 = ops[i - 1 >= 0 ? i - 1 : ops.count - 1]
                let p2 = ops[i + 1 < ops.count ? i + 1 : 0]
                let d = (p1.x - p0.x) * (p1.y - p2.y)
                    - (p1.y - p0.y) * (p1.x - p2.x)
                return abs(d) <= .ulpOfOne ? nil : p1
            }
            return points.count >= 3 ? Polygon(points: points) : nil
        }
        guard !polygons.isEmpty else { return [] }
        
        let verticesCount = polygons.reduce(0) { $0 + $1.points.count }
        let maxVerticesCount = verticesCount * 3
        var vs = [MVertex]()
        vs.reserveCapacity(maxVerticesCount)
        var es = [MEdge]()
        es.reserveCapacity(maxVerticesCount)
        var count = 0
        for polygon in polygons {
            for (i, p) in polygon.points.enumerated() {
                let previousIndex = i == 0 ? polygon.points.count - 1 : i - 1
                let nextIndex = i == polygon.points.count - 1 ? 0 : i + 1
                let prevP = polygon.points[previousIndex]
                let nextP = polygon.points[nextIndex]
                let type: MVertex.VertexType
                if prevP.isBelow(p) && nextP.isBelow(p) {
                    type = Point.isConvex(nextP, prevP, p) ? .start : .split
                } else if p.isBelow(prevP) && p.isBelow(nextP) {
                    type = Point.isConvex(nextP, prevP, p) ? .end : .merge
                } else {
                    type = .regular
                }
                vs.append(MVertex(p: p, type: type,
                                  previousIndex: previousIndex + count,
                                  nextIndex: nextIndex + count))
                es.append(MEdge(index: i + count, p0: p, p1: nextP))
            }
            count += polygon.points.count
        }
        
        var eTree = BinarySearchTree<MEdge>()
        var helpers = [Int: Int]()
        
        struct Diagonal: Hashable {
            var i0, i1: Int
            func reversed() -> Diagonal {
                Diagonal(i0: i1, i1: i0)
            }
        }
        var diagonals = [Diagonal]()
        func addDiagonal(i0: Int, i1: Int) {
            if i0 < i1 {
                diagonals.append(Diagonal(i0: i0, i1: i1))
            } else {
                diagonals.append(Diagonal(i0: i1, i1: i0))
            }
        }
        
        let priorityQueue = (0..<vs.count).sorted {
            let p0 = vs[$0].p, p1 = vs[$1].p
            return p0.y > p1.y || (p0.y == p1.y && p0.x > p1.x)
        }
        for pi in 0..<priorityQueue.count {
            let i = priorityQueue[pi]
            let v = vs[i]
            switch v.type {
            case .start:
                eTree.insert(es[i])
                helpers[i] = i
            case .end:
                let preI = v.previousIndex
                guard let hi = helpers[preI] else { throw TopolygonError() }
                if vs[hi].type == .merge {
                    addDiagonal(i0: i, i1: hi)
                }
                eTree.remove(es[preI])
            case .split:
                let ve = MEdge(index: 0, p0: v.p, p1: v.p)
                guard let j = eTree.previous(at: ve)?.index,
                      let hj = helpers[j] else { throw TopolygonError() }
                addDiagonal(i0: i, i1: hj)
                helpers[j] = i
                eTree.insert(es[i])
                helpers[i] = i
            case .merge:
                let preI = v.previousIndex
                guard let hi = helpers[preI] else { throw TopolygonError() }
                if vs[hi].type == .merge {
                    addDiagonal(i0: i, i1: hi)
                }
                eTree.remove(es[preI])
                
                let ve = MEdge(index: 0, p0: vs[i].p, p1: vs[i].p)
                guard let j = eTree.previous(at: ve)?.index,
                      let hj = helpers[j] else { throw TopolygonError() }
                if vs[hj].type == .merge {
                    addDiagonal(i0: i, i1: hj)
                }
                helpers[j] = i
            case .regular:
                let preI = v.previousIndex
                if v.p.isBelow(vs[preI].p) {
                    guard let hi = helpers[preI] else { throw TopolygonError() }
                    if vs[hi].type == .merge {
                        addDiagonal(i0: i, i1: hi)
                    }
                    eTree.remove(es[preI])
                    eTree.insert(es[i])
                    helpers[i] = i
                } else {
                    let ve = MEdge(index: 0, p0: v.p, p1: v.p)
                    guard let j = eTree.previous(at: ve)?.index,
                          let hj = helpers[j] else { throw TopolygonError() }
                    if vs[hj].type == .merge {
                        addDiagonal(i0: i, i1: hj)
                    }
                    helpers[j] = i
                }
            }
        }
        
        guard !diagonals.isEmpty else {
            return [Polygon(points: vs.map { $0.p })]
        }
        
        let ds = diagonals + vs.enumerated()
            .map { Diagonal(i0: $0.offset, i1: $0.element.nextIndex) }
        var vDic = [Int: [(c: Double, d: Diagonal)]]()
        for (_, diagonal) in ds.enumerated() {
            let v01 = vs[diagonal.i1].p - vs[diagonal.i0].p
            if vDic[diagonal.i0] != nil {
                vDic[diagonal.i0]?.append((v01.angle(), diagonal))
            } else {
                vDic[diagonal.i0] = [(v01.angle(), diagonal)]
            }
            let v11 = vs[diagonal.i0].p - vs[diagonal.i1].p
            if vDic[diagonal.i1] != nil {
                vDic[diagonal.i1]?.append((v11.angle(), diagonal.reversed()))
            } else {
                vDic[diagonal.i1] = [(v11.angle(), diagonal.reversed())]
            }
        }
        for i in vDic.keys {
            vDic[i]?.sort { $0.c > $1.c }
        }
        
        func next(from d: Diagonal) -> Diagonal? {
            guard let dis = vDic[d.i1] else {
                return nil
            }
            let rd = d.reversed()
            for (j, di) in dis.enumerated() {
                if di.d == rd {
                    return dis[j + 1 < dis.count ? j + 1 : 0].d
                }
            }
            return nil
        }
        
        let nds = ds + diagonals.map { $0.reversed() }
        
        var monotonePolygons = [Polygon]()
        var usedDs = Set<Diagonal>()
        for fd in nds {
            guard !usedDs.contains(fd) else { continue }
            var points = [Point]()
            var d = fd
            while true {
                points.append(vs[d.i0].p)
                usedDs.insert(d)
                guard let nd = next(from: d) else { break }
                guard !usedDs.contains(nd) else { break }
                d = nd
            }
            if !Polygon(points: points).isMonotone {
                print("No monotone polygon", points.count)
            } else {
                monotonePolygons.append(Polygon(points: points))
            }
        }
        return monotonePolygons
    }
}
