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

struct LineIndexValue: Hashable, Codable {
    var index = 0, t = 0.0
}
extension LineIndexValue: Comparable {
    static func < (lhs: LineIndexValue, rhs: LineIndexValue) -> Bool {
        if lhs.index == rhs.index {
            return lhs.t < rhs.t
        } else {
            return lhs.index < rhs.index
        }
    }
}

struct LineRange: Hashable, Codable {
    var startIndexValue: LineIndexValue, endIndexValue: LineIndexValue
}
extension LineRange {
    init(startIndex: Int, startT: Double, endIndex: Int, endT: Double) {
        self.startIndexValue = LineIndexValue(index: startIndex, t: startT)
        self.endIndexValue = LineIndexValue(index: endIndex, t: endT)
    }
    var startIndex: Int {
        startIndexValue.index
    }
    var  startT: Double {
        startIndexValue.t
    }
    var endIndex: Int {
        endIndexValue.index
    }
    var endT: Double {
        endIndexValue.t
    }
    var isEmpty: Bool {
        startIndexValue == endIndexValue
    }
    func intersects(_ other: LineRange) -> Bool {
        endIndexValue >= other.startIndexValue
            && startIndexValue <= other.endIndexValue
    }
    func union(_ other: LineRange) -> LineRange? {
        if !intersects(other) {
            return nil
        } else {
            let sv = startIndexValue < other.startIndexValue ?
                startIndexValue : other.startIndexValue
            let ev = endIndexValue > other.endIndexValue ?
                endIndexValue : other.endIndexValue
            return LineRange(startIndexValue: sv, endIndexValue: ev)
        }
    }
}
extension Array where Element == LineRange {
    func union() -> [LineRange] {
        guard var oldRange = self.first else { return [] }
        var ranges = [LineRange]()
        ranges.reserveCapacity(count)
        ranges.append(oldRange)
        for range in self {
            if let unionRange = range.union(oldRange) {
                ranges[.last] = unionRange
                oldRange = unionRange
            } else {
                ranges.append(range)
                oldRange = range
            }
        }
        return ranges
    }
}

struct Line {
    struct Control {
        var point = Point(), weight = 0.5, pressure = 1.0
        
        init(point: Point, weight: Double = 0.5, pressure: Double = 1.0) {
            self.point = point
            self.weight = weight
            self.pressure = pressure
        }
    }
    var controls = [Control]()
    var size = Line.defaultLineWidth
}

extension Line: Protobuf {
    init(_ pb: PBLine) throws {
        controls = try pb.controls.map { try Control($0) }
        let size = (try? pb.size.notNaN()) ?? Line.defaultLineWidth
        self.size = size.clipped(min: 0, max: Line.maxLineWidth)
    }
    var pb: PBLine {
        PBLine.with {
            $0.controls = controls.map { $0.pb }
            $0.size = size
        }
    }
}
extension Line.Control: Protobuf {
    init(_ pb: PBLine.PBControl) throws {
        point = try Point(pb.point).notInfinite()
        weight = try pb.weight.notNaN().clipped(min: 0, max: 1)
        pressure = try pb.pressure.notNaN().clipped(min: 0, max: 1)
    }
    var pb: PBLine.PBControl {
        PBLine.PBControl.with {
            $0.point = point.pb
            $0.weight = weight
            $0.pressure = pressure
        }
    }
}
extension Line.Control: Hashable {}
extension Line.Control: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        point = try container.decode(Point.self).notInfinite()
        weight = (try container.decode(Double.self).notNaN())
            .clipped(min: 0, max: 1)
        pressure = (try container.decode(Double.self).notNaN())
            .clipped(min: 0, max: 1)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(point)
        try container.encode(weight)
        try container.encode(pressure)
    }
}
extension Line.Control: Interpolatable {
    static func linear(_ f0: Line.Control, _ f1: Line.Control,
                       t: Double) -> Line.Control {
        let point = Point.linear(f0.point, f1.point, t: t)
        let weight = Double.linear(f0.weight, f1.weight, t: t)
        let pressure = Double.linear(f0.pressure, f1.pressure, t: t)
        return Line.Control(point: point, weight: weight, pressure: pressure)
    }
    static func firstSpline(_ f1: Line.Control,
                            _ f2: Line.Control, _ f3: Line.Control,
                            t: Double) -> Line.Control {
        let point = Point.firstSpline(f1.point,
                                      f2.point, f3.point, t: t)
        let weight = Double.firstSpline(f1.weight,
                                        f2.weight, f3.weight, t: t)
        let pressure = Double.firstSpline(f1.pressure,
                                          f2.pressure, f3.pressure, t: t)
        return Line.Control(point: point, weight: weight, pressure: pressure)
    }
    static func spline(_ f0: Line.Control, _ f1: Line.Control,
                       _ f2: Line.Control, _ f3: Line.Control,
                       t: Double) -> Line.Control {
        let point = Point.spline(f0.point, f1.point,
                                 f2.point, f3.point, t: t)
        let weight = Double.spline(f0.weight, f1.weight,
                                   f2.weight, f3.weight, t: t)
        let pressure = Double.spline(f0.pressure, f1.pressure,
                                     f2.pressure, f3.pressure, t: t)
        return Line.Control(point: point, weight: weight, pressure: pressure)
    }
    static func lastSpline(_ f0: Line.Control, _ f1: Line.Control,
                           _ f2: Line.Control,
                           t: Double) -> Line.Control {
        let point = Point.lastSpline(f0.point, f1.point,
                                     f2.point, t: t)
        let weight = Double.lastSpline(f0.weight, f1.weight,
                                       f2.weight, t: t)
        let pressure = Double.lastSpline(f0.pressure, f1.pressure,
                                         f2.pressure, t: t)
        return Line.Control(point: point, weight: weight, pressure: pressure)
    }
}
extension Line.Control {
    var isEmpty: Bool {
        point.isEmpty && pressure == 0 && weight == 0
    }
    func mid(_ other: Line.Control) -> Line.Control {
        Line.Control(point: point.mid(other.point),
                     weight: weight.mid(other.weight),
                     pressure: pressure.mid(other.pressure))
    }
    func distance(_ other: Line.Control) -> Double {
        point.distance(other.point)
    }
    func distanceSquared(_ other: Line.Control) -> Double {
        point.distanceSquared(other.point)
    }
}

extension Line: Hashable {}
extension Line: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        controls = try container.decode([Control].self)
        let size = (try? container.decode(Double.self)) ?? Line.defaultLineWidth
        self.size = size.clipped(min: 0, max: Line.maxLineWidth)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(controls)
        try container.encode(size)
    }
}
extension Line: Interpolatable {
    static func linear(_ f0: Line, _ f1: Line, t: Double) -> Line {
        let count = max(f0.controls.count, f1.controls.count)
        let size = Double.linear(f0.size, f1.size, t: t)
        let l0 = f0.with(count: count)
        let l1 = f1.with(count: count)
        let controls = [Control].linear(l0.controls, l1.controls, t: t)
        return Line(controls: controls, size: size)
    }
    static func firstSpline(_ f1: Line,
                            _ f2: Line, _ f3: Line, t: Double) -> Line {
        let count = max(f1.controls.count, f2.controls.count, f3.controls.count)
        let size = Double.firstSpline(f1.size, f2.size, f3.size, t: t)
        let l1 = f1.with(count: count)
        let l2 = f2.with(count: count)
        let l3 = f3.with(count: count)
        let controls = [Control].firstSpline(l1.controls,
                                             l2.controls, l3.controls, t: t)
        return Line(controls: controls, size: size)
    }
    static func spline(_ f0: Line, _ f1: Line,
                       _ f2: Line, _ f3: Line, t: Double) -> Line {
        let count = max(f0.controls.count, f1.controls.count,
                        f2.controls.count, f3.controls.count)
        let size = Double.spline(f0.size, f1.size, f2.size, f3.size, t: t)
        let l0 = f0.with(count: count)
        let l1 = f1.with(count: count)
        let l2 = f2.with(count: count)
        let l3 = f3.with(count: count)
        let controls = [Control].spline(l0.controls, l1.controls,
                                        l2.controls, l3.controls, t: t)
        return Line(controls: controls, size: size)
    }
    static func lastSpline(_ f0: Line, _ f1: Line,
                           _ f2: Line, t: Double) -> Line {
        let count = max(f0.controls.count, f1.controls.count, f2.controls.count)
        let size = Double.lastSpline(f0.size, f1.size, f2.size, t: t)
        let l0 = f0.with(count: count)
        let l1 = f1.with(count: count)
        let l2 = f2.with(count: count)
        let controls = [Control].lastSpline(l0.controls, l1.controls,
                                            l2.controls, t: t)
        return Line(controls: controls, size: size)
    }
    private func control(at i: Int, maxCount: Int) -> Control {
        guard controls.count != maxCount else { return controls[i] }
        let d = maxCount - controls.count
        let minD = d / 2
        if i < minD {
            return controls[0]
        } else if i > maxCount - (d - minD) - 1 {
            return controls[controls.count - 1]
        } else {
            return controls[i - minD]
        }
    }
}
extension Line: AppliableTransform {
    static func * (lhs: Line, rhs: Transform) -> Line {
        Line(controls: lhs.controls.map {
            Control(point: $0.point * rhs,
                    weight: $0.weight,
                    pressure: $0.pressure)
        }, size: lhs.size)
    }
}
extension Line {
    static let defaultLineWidth = 1.1
    static let maxLineWidth = 1000000.0
}
extension Line {
    init(edge: Edge, size: Double = Line.defaultLineWidth) {
        self.init(beziers: [Bezier(edge)], size: size)
    }
    init(_ ps: [Point], size: Double = Line.defaultLineWidth) {
        self.init(controls: ps.map { Control(point: $0) }, size: size)
    }
    init(beziers: [Bezier], size: Double = Line.defaultLineWidth) {
        if beziers.count == 0 {
            self.init()
        } else if beziers.count == 1 {
            let bezier = beziers[0]
            self.init(controls: [Control(point: bezier.p0),
                                 Control(point: bezier.cp),
                                 Control(point: bezier.p1)], size: size)
        } else {
            var controls = [Control]()
            controls.append(Control(point: beziers[0].p0))
            for i in 0..<beziers.count - 1 {
                let bezier = beziers[i], nextBezier = beziers[i + 1]
                let weight = Edge(bezier.cp, nextBezier.cp)
                    .nearestT(from: bezier.p1)
                controls.append(Control(point: bezier.cp, weight: weight))
            }
            controls.append(Control(point: beziers[beziers.count - 1].cp))
            controls.append(Control(point: beziers[beziers.count - 1].p1))
            self.init(controls: controls, size: size)
        }
    }
    init(_ rect: Rect, size: Double = Line.defaultLineWidth) {
        self.init(controls: [Control(point: rect.minXMaxYPoint),
                             Control(point: rect.minXMaxYPoint),
                             Control(point: rect.minXMinYPoint),
                             Control(point: rect.minXMinYPoint),
                             Control(point: rect.maxXMinYPoint),
                             Control(point: rect.maxXMinYPoint),
                             Control(point: rect.maxXMaxYPoint),
                             Control(point: rect.maxXMaxYPoint)], size: size)
    }
    
    /// Catmull-Rom spline
    init(splineWith ps: [Point],
         size: Double = Line.defaultLineWidth) {
        var bs = [Bezier]()
        if ps.count <= 2 {
            self.init(controls: ps.map { Line.Control(point: $0) }, size: size)
        } else {
            for i in 0..<(ps.count - 1) {
                let p1 = ps[i]
                let p2 = ps[i + 1]
                let cp0 = i == 0 ? p1 : (p2 - ps[i - 1]) / 6 + p1
                let cp1 = i == ps.count - 2 ? p2 : (p1 - ps[i + 2]) / 6 + p2
                let b3 = Bezier3(p0: p1, cp0: cp0, cp1: cp1, p1: p2)
                let (b0, b1) = Bezier.beziersWith(b3)
                bs.append(b0)
                bs.append(b1)
            }
            self.init(beziers: bs, size: size)
        }
    }
}
extension Array where Element == Line.Control {
    var bounds: Rect? {
        if isEmpty {
            return nil
        } else if count == 1 {
            return Rect(origin: self[0].point, size: Size())
        } else if count == 2 {
            return Bezier.linear(self[0].point, self[count - 1].point).bounds
        } else if count == 3 {
            return Bezier(p0: self[0].point,
                          cp: self[1].point, p1: self[count - 1].point).bounds
        } else {
            var connectP = Point.linear(self[1].point, self[2].point,
                                        t: self[1].weight)
            var b = Bezier(p0: self[0].point,
                           cp: self[1].point,
                           p1: connectP).bounds
            for i in 1..<count - 3 {
                let newConnectP = Point.linear(self[i + 1].point,
                                               self[i + 2].point,
                                               t: self[i + 1].weight)
                b = b.union(Bezier(p0: connectP,
                                   cp: self[i + 1].point,
                                   p1: newConnectP).bounds)
                connectP = newConnectP
            }
            b = b.union(Bezier(p0: connectP,
                               cp: self[count - 2].point,
                               p1: self[count - 1].point).bounds)
            return b
        }
    }
}
extension Line {
    func reversed() -> Line {
        if controls.count >= 4 {
            var rcs = Array(controls.reversed())
            for i in 2..<(rcs.count - 1) {
                rcs[i - 1].weight = 1 - rcs[i].weight
            }
            return Line(controls: rcs, size: size)
        } else {
            return Line(controls: controls.reversed(), size: size)
        }
    }
    func toVertical() -> Line {
        Line(controls: controls.map { Control(point: $0.point.inverted(),
                                              weight: $0.weight,
                                              pressure: $0.pressure) },
             size: size)
    }
    func splited(startIndex: Int, endIndex: Int) -> Line {
        Line(controls: Array(controls[startIndex...endIndex]),
             size: size)
    }
    func splited(with range: LineRange) -> Line {
        let startIndex = range.startIndex, startT = range.startT
        let endIndex = range.endIndex, endT = range.endT
        if startIndex == endIndex {
            let b = bezier(at: startIndex).clip(startT: startT, endT: endT)
            let bpr = pressureInterpolation(at: startIndex)
                .clip(startT: startT, endT: endT)
            return Line(controls: [Control(point: b.p0,
                                           weight: 0.5, pressure: bpr.x0),
                                   Control(point: b.cp,
                                           weight: 0.5, pressure: bpr.cx),
                                   Control(point: b.p1,
                                           weight: 0.5, pressure: bpr.x1)],
                        size: size)
        } else if startIndex + 1 == endIndex {
            let p0 = bezier(at: startIndex).position(withT: startT)
            let p1 = Point.linear(controls[startIndex + 1].point,
                                  connectingPoint(at: startIndex + 1),
                                  t: startT)
            let p2 = Point.linear(connectingPoint(at: endIndex),
                                  controls[endIndex + 1].point,
                                  t: endT)
            let p3 = bezier(at: endIndex).position(withT: endT)
            let pr0 = pressureInterpolation(at: startIndex).position(withT: startT)
            let pr1 = Double.linear(controls[startIndex + 1].pressure,
                                    connectingPressure(at: startIndex + 1),
                                    t: startT)
            let pr2 = Double.linear(connectingPressure(at: endIndex),
                                    controls[endIndex + 1].pressure,
                                    t: endT)
            let pr3 = pressureInterpolation(at: endIndex).position(withT: endT)
            let w0 = controls[startIndex + 1].weight
            let wa = endT * w0 - endT - w0 + w0 * startT
            let w = wa == 0 ? 0.5 : (w0 * startT - w0) / wa
            return Line(controls: [Control(point: p0, weight: 0.5, pressure: pr0),
                                   Control(point: p1, weight: w, pressure: pr1),
                                   Control(point: p2, weight: 0.5, pressure: pr2),
                                   Control(point: p3, weight: 0.5, pressure: pr3)],
                        size: size)
        } else {
            let indexes = startIndex...endIndex + 2
            var cs = Array(controls[indexes])
            if startIndex == 0 && startT == 0 {
                cs[0].weight = 0.5
            } else {
                let fp = bezier(at: startIndex).position(withT: startT)
                let fpr = pressureInterpolation(at: startIndex)
                    .position(withT: startT)
                let w0 = controls[startIndex + 1].weight
                let w0a = 1 - w0 * startT
                let weight0 = w0a == 0 ? 0.5 : (w0 - w0 * startT) / w0a
                cs[0].point = fp
                cs[0].pressure = fpr
                cs[0].weight = 0.5
                cs[1].point
                    = Point.linear(controls[startIndex + 1].point,
                                   connectingPoint(at: startIndex + 1),
                                   t: startT)
                cs[1].pressure
                    = Double.linear(controls[startIndex + 1].pressure,
                                    connectingPressure(at: startIndex + 1),
                                    t: startT)
                cs[1].weight = weight0
            }
            if endIndex == controls.count - 3 && endT == 1 {
                cs[cs.count - 2].weight = 0.5
                cs[cs.count - 1].weight = 0.5
            } else {
                let lp = bezier(at: endIndex).position(withT: endT)
                let lpr = pressureInterpolation(at: endIndex).position(withT: endT)
                let w1 = controls[endIndex].weight
                let w1a = endT - endT * w1 + w1
                let weight1 = w1a == 0 ? 0.5 : w1 / w1a
                cs[cs.count - 3].weight = weight1
                cs[cs.count - 2].point
                    = Point.linear(connectingPoint(at: endIndex),
                                   controls[endIndex + 1].point,
                                   t: endT)
                cs[cs.count - 2].pressure
                    = Double.linear(connectingPressure(at: endIndex),
                                    controls[endIndex + 1].pressure,
                                    t: endT)
                cs[cs.count - 2].weight = 0.5
                cs[cs.count - 1].point = lp
                cs[cs.count - 1].pressure = lpr
                cs[cs.count - 1].weight = 0.5
            }
            return Line(controls: cs, size: size)
        }
    }
    func warpedWith(deltaPoint dp: Point, _ firstOrLast: FirstOrLast) -> Line {
        var allD = 0.0, oldP = firstPoint
        for i in 1..<controls.count {
            let p = controls[i].point
            allD += p.distanceSquared(oldP).squareRoot()
            oldP = p
        }
        oldP = firstPoint
        let invertAllD = allD > 0 ? 1 / allD : 0
        var cs = [Control]()
        var allAD = 0.0
        for i in 0..<controls.count {
            let p = controls[i].point
            allAD += p.distanceSquared(oldP).squareRoot()
            oldP = p
            let t: Double
            switch firstOrLast {
            case .first: t = 1 - allAD * invertAllD
            case .last: t = allAD * invertAllD
            }
            var nc = controls[i]
            nc.point += dp * t
            cs.append(nc)
        }
        return Line(controls: cs, size: size)
    }
    
    mutating func split(t: Double, at i: Int) {
        if controls.count == 2 {
            controls.insert(Line.Control.linear(controls[0], controls[1],
                                                t: t),
                            at: 1)
        } else if controls.count == 3 {
            let c0 = controls[0], c1 = controls[1], c2 = controls[2]
            controls[1].point = Point.linear(c0.point, c1.point, t: t)
            controls[1].pressure = Double.linear(c0.pressure, c1.pressure, t: t)
            controls[1].weight = t
            
            let lc = Line.Control(point: Point.linear(c1.point, c2.point, t: t),
                                  weight: 0.5,
                                  pressure: Double.linear(c1.pressure,
                                                          c2.pressure,
                                                          t: t))
            controls.insert(lc, at: 2)
        } else if i == 0 {
            let c0 = controls[0], c1 = controls[1], c2 = controls[2]
            controls[1].point = Point.linear(c0.point, c1.point, t: t)
            controls[1].pressure = Double.linear(c0.pressure, c1.pressure, t: t)
            controls[1].weight = t
            
            let cp = Point.linear(c1.point, c2.point, t: c1.weight)
            let cpr = Double.linear(c1.pressure, c2.pressure, t: c1.weight)
            let w = c1.weight
            let wa = 1 - w * t
            let lc = Line.Control(point: Point.linear(c1.point, cp, t: t),
                                  weight: wa == 0 ? 0.5 : (w - w * t) / wa,
                                  pressure: Double.linear(c1.pressure, cpr, t: t))
            controls.insert(lc, at: 2)
        } else if i == controls.count - 3 {
            let c0 = controls[controls.count - 3]
            let c1 = controls[controls.count - 2]
            let c2 = controls[controls.count - 1]
            let cp = Point.linear(c0.point, c1.point, t: c0.weight)
            let cpr = Double.linear(c0.pressure, c1.pressure, t: c0.weight)
            
            let w = c0.weight
            let wa = t - t * w + w
            controls[controls.count - 3].weight = wa == 0 ? 0.5 : w / wa
            
            controls[controls.count - 2].point
                = Point.linear(cp, c1.point, t: t)
            controls[controls.count - 2].pressure
                = Double.linear(cpr, c1.pressure, t: t)
            controls[controls.count - 2].weight = t
            
            let lc = Line.Control(point: Point.linear(c1.point, c2.point, t: t),
                                  weight: 0.5,
                                  pressure: Double.linear(c1.pressure,
                                                          c2.pressure,
                                                          t: t))
            controls.insert(lc, at: controls.count - 1)
        } else {
            let c0 = controls[i], c1 = controls[i + 1], c2 = controls[i + 2]
            let cp0 = Point.linear(c0.point, c1.point, t: c0.weight)
            let cpr0 = Double.linear(c0.pressure, c1.pressure, t: c0.weight)
            let cp1 = Point.linear(c1.point, c2.point, t: c1.weight)
            let cpr1 = Double.linear(c1.pressure, c2.pressure, t: c1.weight)
            
            let w0 = c0.weight
            let wa0 = t - t * w0 + w0
            controls[i].weight = wa0 == 0 ? 0.5 : w0 / wa0
            
            controls[i + 1].point = Point.linear(cp0, c1.point, t: t)
            controls[i + 1].pressure = Double.linear(cpr0, c1.pressure, t: t)
            controls[i + 1].weight = t
            
            let w1 = c1.weight
            let w1a = 1 - w1 * t
            let lc = Line.Control(point: Point.linear(c1.point, cp1, t: t),
                                  weight: w1a == 0 ? 0.5 : (w1 - w1 * t) / w1a,
                                  pressure: Double.linear(c1.pressure, cpr1, t: t))
            controls.insert(lc, at: i + 2)
        }
    }
    
    func with(count: Int) -> Line {
        guard controls.count != count else { return self }
        guard controls.count < count else { fatalError() }
        guard controls.count > 1 else {
            return Line(controls: [Control](repeating: controls[0], count: count),
                        size: size)
        }
        var line = self
        line.controls.reserveCapacity(count)
        var ds = (1..<controls.count).map {
            (controls[$0].point.distance(controls[$0 - 1].point), $0)
        }
        ds.sort(by: { $0.0 < $1.0 })
        for _ in 0..<(count - controls.count) {
            let ld = ds[.last]
            line.split(t: 0.5, at: ld.1 - 1)
            ds.removeLast()
            var isInsert = false
            for (i, d) in ds.enumerated() {
                if ld.0 < d.0 {
                    var nd = ld
                    nd.0 /= 2
                    ds.insert(nd, at: i)
                    ds.insert(nd, at: i + 1)
                    isInsert = true
                    break
                }
            }
            if !isInsert {
                var nd = ld
                nd.0 /= 2
                ds.append(nd)
                ds.append(nd)
            }
        }
        return line
    }
    
    var firstIndexValue: LineIndexValue {
        LineIndexValue(index: 0, t: 0)
    }
    var lastIndexValue: LineIndexValue {
        LineIndexValue(index: maxBezierIndex, t: 1)
    }
    
    func extensionRange(_ range: LineRange, distance: Double,
                        toleranceDistance td: Double = 0.1) -> LineRange {
        let maxI = maxBezierIndex
        var nRange = range
        
        func updateStart() {
            var nd = 0.0, endT = range.startT
            for i in (0...range.startIndex).reversed() {
                let b = bezier(at: i)
                let l = nd + b.clip(startT: 0, endT: endT).length()
                if abs(l - distance) < td {
                    nRange.startIndexValue = LineIndexValue(index: i, t: 0)
                    return
                } else if l < distance {
                    nd += l
                    endT = 1
                } else {
                    var minT = 0.0, maxT = endT
                    while true {
                        let t = (minT + maxT) / 2
                        let l = nd + b.clip(startT: t, endT: endT).length()
                        if l.isApproximatelyEqual(distance, tolerance: td)
                            || maxT.isApproximatelyEqual(minT,
                                                         tolerance: 0.000001) {
                            nRange.startIndexValue = LineIndexValue(index: i, t: t)
                            return
                        } else if l < distance {
                            maxT = t
                        } else {
                            minT = t
                        }
                    }
                }
            }
            nRange.startIndexValue = LineIndexValue(index: 0, t: 0)
        }
        func updateEnd() {
            var nd = 0.0, startT = range.endT
            for i in range.endIndex...maxI {
                let b = bezier(at: i)
                let l = nd + b.clip(startT: startT, endT: 1).length()
                if abs(l - distance) < td {
                    nRange.endIndexValue = LineIndexValue(index: i, t: 1)
                    return
                } else if l < distance {
                    nd += l
                    startT = 0
                } else {
                    var minT = startT, maxT = 1.0
                    while true {
                        let t = (minT + maxT) / 2
                        let l = nd + b.clip(startT: startT, endT: t).length()
                        if l.isApproximatelyEqual(distance, tolerance: td)
                            || maxT.isApproximatelyEqual(minT,
                                                         tolerance: 0.000001) {
                            nRange.endIndexValue = LineIndexValue(index: i, t: t)
                            return
                        } else if l < distance {
                            minT = t
                        } else {
                            maxT = t
                        }
                    }
                }
            }
            nRange.endIndexValue = LineIndexValue(index: maxI, t: 1)
        }
        
        updateStart()
        updateEnd()
        
        return nRange
    }
    
    func rounded(_ rule: FloatingPointRoundingRule
                    = .toNearestOrAwayFromZero) -> Line {
        Line(controls: controls.map {
            Control(point: $0.point.rounded(rule),
                    weight: $0.weight.rounded(rule),
                    pressure: $0.pressure.rounded(rule))
        }, size: size.rounded(rule))
    }
    var isEmpty: Bool {
        controls.isEmpty
    }
    var firstPoint: Point {
        controls[0].point
    }
    var lastPoint: Point {
        controls[controls.count - 1].point
    }
    func connectingPoint(at i: Int) -> Point {
        Point.linear(controls[i].point, controls[i + 1].point,
                     t: controls[i].weight)
    }
    func connectingPressure(at i: Int) -> Double {
        Double.linear(controls[i].pressure, controls[i + 1].pressure,
                      t: controls[i].weight)
    }
    func isFirst(at index: Int, t: Double) -> Bool {
        controls.count <= 2 ?
            t < 0.5 : (Double(index) + t < Double(controls.count - 2) / 2)
    }
    var isEmptyBounds: Bool {
        guard controls.count >= 2 else { return true }
        let fp = controls[0].point
        for i in 1..<controls.count {
            if controls[i].point != fp {
                return false
            }
        }
        return true
    }
    var bounds: Rect? {
        controls.bounds
    }
    var maxBezierIndex: Int {
        max(0, controls.count - 3)
    }
    
    func pressure(at liv: LineIndexValue) -> Double {
        pressureInterpolation(at: liv.index).position(withT: liv.t)
    }
    func size(at liv: LineIndexValue) -> Double {
        size * pressureInterpolation(at: liv.index).position(withT: liv.t)
    }
    
    struct BezierSequence: Sequence, IteratorProtocol {
        private let controls: [Line.Control]
        let underestimatedCount: Int
        
        init(_ controls: [Line.Control]) {
            self.controls = controls
            guard controls.count > 3 else {
                oldPoint = controls.first?.point ?? Point()
                underestimatedCount = controls.isEmpty ? 0 : 1
                return
            }
            oldPoint = controls[0].point
            underestimatedCount = controls.count - 2
        }
        
        private var i = 0, oldPoint: Point
        mutating func next() -> Bezier? {
            guard controls.count > 3 else {
                if i == 0 && !controls.isEmpty {
                    i += 1
                    return controls.count < 3 ?
                        Bezier.linear(controls[0].point,
                                      controls[controls.count - 1].point) :
                        Bezier(p0: controls[0].point,
                               cp: controls[1].point,
                               p1: controls[2].point)
                } else {
                    return nil
                }
            }
            if i < controls.count - 3 {
                let connectP = Point.linear(controls[i + 1].point,
                                            controls[i + 2].point,
                                            t: controls[i + 1].weight)
                let bezier = Bezier(p0: oldPoint,
                                    cp: controls[i + 1].point,
                                    p1: connectP)
                oldPoint = connectP
                i += 1
                return bezier
            } else if i == controls.count - 3 {
                i += 1
                return Bezier(p0: oldPoint,
                              cp: controls[controls.count - 2].point,
                              p1: controls[controls.count - 1].point)
            } else {
                return nil
            }
        }
    }
    var bezierSequence: BezierSequence {
        BezierSequence(controls)
    }
    
    func bezier(at i: Int) -> Bezier {
        guard controls.count > 3 else {
            return controls.count < 3 ?
                Bezier.linear(controls[0].point,
                              controls[controls.count - 1].point) :
                Bezier(p0: controls[0].point,
                       cp: controls[1].point,
                       p1: controls[2].point)
        }
        if i == 0 {
            let p0 = controls[0].point
            let cp = controls[1].point
            let p1 = connectingPoint(at: 1)
            return Bezier(p0: p0, cp: cp, p1: p1)
        } else if i == controls.count - 3 {
            let p0 = connectingPoint(at: controls.count - 3)
            let cp = controls[controls.count - 2].point
            let p1 = controls[controls.count - 1].point
            return Bezier(p0: p0, cp: cp, p1: p1)
        } else {
            let p0 = connectingPoint(at: i)
            let cp = controls[i + 1].point
            let p1 = connectingPoint(at: i + 1)
            return Bezier(p0: p0, cp: cp, p1: p1)
        }
    }
    func pressureInterpolation(at i: Int) -> BezierInterpolation {
        guard controls.count > 3 else {
            return controls.count < 3 ?
                BezierInterpolation.linear(controls[0].pressure,
                                           controls[controls.count - 1].pressure) :
                BezierInterpolation(x0: controls[0].pressure,
                                    cx: controls[1].pressure,
                                    x1: controls[2].pressure)
        }
        if i == 0 {
            let x0 = controls[0].pressure
            let cx = controls[1].pressure
            let x1 = connectingPressure(at: 1)
            return BezierInterpolation(x0: x0, cx: cx, x1: x1)
        } else if i == controls.count - 3 {
            let x0 = connectingPressure(at: controls.count - 3)
            let cx = controls[controls.count - 2].pressure
            let x1 = controls[controls.count - 1].pressure
            return BezierInterpolation(x0: x0, cx: cx, x1: x1)
        } else {
            let x0 = connectingPressure(at: i)
            let cx = controls[i + 1].pressure
            let x1 = connectingPressure(at: i + 1)
            return BezierInterpolation(x0: x0, cx: cx, x1: x1)
        }
    }
    func bezierT(at p: Point) -> (bezierIndex: Int, t: Double, distanceSquared: Double)? {
        guard controls.count > 2 else {
            if controls.isEmpty {
                return nil
            } else {
                let edge = Edge(firstPoint, lastPoint)
                return (0, edge.nearestT(from: p), edge.distanceSquared(from: p))
            }
        }
        var minDSquared = Double.infinity, minT = 0.0, minBezierIndex = 0
        for (i, bezier) in bezierSequence.enumerated() {
            let nearest = bezier.nearest(at: p)
            if nearest.distanceSquared < minDSquared {
                minDSquared = nearest.distanceSquared
                minT = nearest.t
                minBezierIndex = i
            }
        }
        return (minBezierIndex, minT, minDSquared)
    }
    func bezierT(withLength length: Double) -> (b: Bezier, t: Double)? {
        var bs: (b: Bezier, t: Double)?, allD = 0.0
        for b in bezierSequence {
            let d = b.length()
            let newAllD = allD + d
            if length < newAllD && d > 0 {
                bs = (b, b.t(withLength: length - allD))
                break
            }
            allD = newAllD
        }
        return bs
    }
    var bezierCurveElementsTuple: (firstPoint: Point,
                                   elements: [Pathline.Element])? {
        guard let fp = controls.first?.point, let lp = controls.last?.point else {
            return nil
        }
        var elements = [Pathline.Element]()
        if controls.count >= 3 {
            for i in 2..<controls.count - 1 {
                let p = connectingPoint(at: i - 1)
                let control = controls[i - 1]
                elements.append(.bezier(point: p, control: control.point))
            }
            elements.append(.bezier(point: lp,
                                    control: controls[controls.count - 2].point))
        } else {
            elements.append(.linear(lp))
        }
        return (fp, elements)
    }
    
    static func maxDistanceSquared(at p: Point, with lines: [Line]) -> Double {
        lines.reduce(0.0) { max($0, $1.maxDistanceSquared(at: p)) }
    }
    var centroid: Point? {
        guard !controls.isEmpty else { return nil }
        return controls.reduce(Point()) { $0 + $1.point } / Double(controls.count)
    }
    static func centroidPoint(with lines: [Line]) -> Point? {
        let allPointsCount = lines.reduce(0) { $0 + $1.controls.count }
        guard allPointsCount > 0 else {
            return nil
        }
        let reciprocalCount = Double(1 / allPointsCount)
        let p = lines.reduce(Point()) { $1.controls.reduce($0) { $0 + $1.point } }
        return p * reciprocalCount
    }
    func minDistanceSquared(at p: Point) -> Double {
        var minDSquared = Double.infinity
        for b in bezierSequence {
            minDSquared = min(minDSquared, b.minDistanceSquared(from: p))
        }
        return minDSquared
    }
    func nearest(at p: Point)
    -> (bezierIndex: Int, t: Double, point: Point, distanceSquared: Double) {
        var minDSquared = Double.infinity, minIndex = 0, minT = 0.0
        for (i, b) in bezierSequence.enumerated() {
            let nearest = b.nearest(at: p)
            if nearest.distanceSquared <= minDSquared {
                minDSquared = nearest.distanceSquared
                minIndex = i
                minT = nearest.t
            }
        }
        let minP = bezier(at: minIndex).position(withT: minT)
        return (minIndex, minT, minP, minDSquared)
    }
    func nearest(at p: Point, minDistance: Double, isReversed: Bool)
    -> (bezierIndex: Int, t: Double, point: Point, distanceSquared: Double)? {
        var l = 0.0
        var minDSquared = Double.infinity, minIndex: Int?, minT = 0.0
        if isReversed {
            var oldI = controls.count - 3
            for (i, b) in bezierSequence.enumerated().reversed() {
                guard i != controls.count - 3 else { continue }
                let nearest = b.nearest(at: p)
                guard nearest.distanceSquared <= minDSquared else { continue }
                ((i + 1)...oldI).forEach { _ in l += bezier(at: i).length() }
                oldI = i
                let nl = l + b.clip(startT: nearest.t, endT: 1).length()
                guard nl > minDistance else { continue }
                minDSquared = nearest.distanceSquared
                minIndex = i
                minT = nearest.t
            }
        } else {
            var oldI = 0
            for (i, b) in bezierSequence.enumerated() {
                guard i != 0 else { continue }
                let nearest = b.nearest(at: p)
                guard nearest.distanceSquared <= minDSquared else { continue }
                (oldI..<i).forEach { _ in l += bezier(at: i).length() }
                oldI = i
                let nl = l + b.clip(startT: 0, endT: nearest.t).length()
                guard nl > minDistance else { continue }
                minDSquared = nearest.distanceSquared
                minIndex = i
                minT = nearest.t
            }
        }
        if let minIndex = minIndex {
            let minP = bezier(at: minIndex).position(withT: minT)
            return (minIndex, minT, minP, minDSquared)
        } else {
            return nil
        }
    }
    func maxDistanceSquared(at p: Point) -> Double {
        var maxDSquared = 0.0
        for b in bezierSequence {
            maxDSquared = max(maxDSquared, b.maxDistanceSquared(from: p))
        }
        return maxDSquared
    }
    func minDistanceSquared(_ other: Line) -> Double {
        var minDSquared = Double.infinity
        var p0 = firstPoint
        for p1 in mainPointSequence {
            let edge0 = Edge(p0, p1)
            var p2 = other.firstPoint
            for p3 in other.mainPointSequence {
                let edge1 = Edge(p2, p3)
                if edge0.intersects(edge1) {
                    return 0
                } else {
                    let dSquared = min(edge1.distanceSquared(from: p0),
                                       edge1.distanceSquared(from: p1),
                                       edge0.distanceSquared(from: p2),
                                       edge0.distanceSquared(from: p3))
                    if dSquared < minDSquared {
                        minDSquared = dSquared
                    }
                }
                p2 = p3
            }
            p0 = p1
        }
        return minDSquared
    }
    
    var controlEdges: [Edge] {
        guard controls.count >= 2 else { return [] }
        var preP = firstPoint
        var edges = [Edge]()
        edges.reserveCapacity(controls.count - 1)
        for i in 1..<controls.count {
            let p = controls[i].point
            edges.append(Edge(preP, p))
            preP = p
        }
        return edges
    }
    
    struct MainPointSequence: Sequence, IteratorProtocol {
        private let controls: [Line.Control]
        private var bezierSequence: BezierSequence
        let underestimatedCount: Int
        
        private var i = 0
        mutating func next() -> Point? {
            if i == 0 {
                i += 1
                return controls.first?.point
            } else if i < controls.count - 1 {
                i += 1
                return bezierSequence.next()?.position(withT: 0.5)
            } else if i == controls.count - 1 {
                i += 1
                return controls.last?.point
            } else {
                return nil
            }
        }
        
        init(_ controls: [Line.Control]) {
            self.controls = controls
            bezierSequence = BezierSequence(controls)
            underestimatedCount = controls.count
        }
    }
    var mainPointSequence: MainPointSequence {
        MainPointSequence(controls)
    }
    
    func mainPoint(at i: Int) -> Point {
        if i == 0 {
            return controls[0].point
        } else if i == controls.count - 1 {
            return controls[controls.count - 1].point
        } else {
            return bezier(at: i - 1).position(withT: 0.5)
        }
    }
    func mainPoint(withMainCenterPoint xp: Point, at i: Int) -> Point {
        guard i > 0 && i < controls.count - 1 else { return xp }
        let bi = i - 1
        let m0 = bi == 0 ? 0 : 0.5, m1 = bi == controls.count - 3 ? 1 : 0.5
        let n0 = 1 - m0, n1 = 1 - m1
        let p0 = controls[bi].point, p2 = controls[bi + 2].point
        let v0 = 4 * xp - n0 * p0 - m1 * p2
        let v1 = m0 + n1 + 2
        return v0 / v1
    }
    
    var firstAngle: Double {
        if controls.count < 2 {
            return 0
        } else if controls.count >= 3 && controls[0].point == controls[1].point {
            return controls[0].point.angle(controls[2].point)
        } else {
            return controls[0].point.angle(controls[1].point)
        }
    }
    var firstVector: Point {
        if controls.count < 2 {
            return Point()
        } else if controls.count >= 3 && controls[0].point == controls[1].point {
            return controls[2].point - controls[0].point
        } else {
            return controls[1].point - controls[0].point
        }
    }
    var lastAngle: Double {
        if controls.count < 2 {
            return 0
        } else if controls.count >= 3 &&
                    controls[controls.count - 2].point
                    == controls[controls.count - 1].point {
            
            if controls.count >= 4 &&
                controls[controls.count - 3].point
                == controls[controls.count - 1].point {
                
                return controls[controls.count - 4].point
                    .angle(controls[controls.count - 1].point)
            } else {
                return controls[controls.count - 3].point
                    .angle(controls[controls.count - 1].point)
            }
        } else {
            return controls[controls.count - 2].point
                .angle(controls[controls.count - 1].point)
        }
    }
    var lastVector: Point {
        if controls.count < 2 {
            return Point()
        } else if controls.count >= 3 &&
                    controls[controls.count - 2].point
                    == controls[controls.count - 1].point {
            
            if controls.count >= 4 &&
                controls[controls.count - 3].point
                == controls[controls.count - 1].point {
                
                return controls[controls.count - 1].point
                    - controls[controls.count - 4].point
            } else {
                return controls[controls.count - 1].point
                    - controls[controls.count - 3].point
            }
        } else {
            return controls[controls.count - 1].point
                - controls[controls.count - 2].point
        }
    }
    func angle(withPreviousLine preLine: Line) -> Double {
        abs(lastAngle.differenceRotation(firstAngle))
    }
    
    var pointsLength: Double {
        var length = 0.0
        if var oldPoint = controls.first?.point {
            for control in controls {
                length += (control.point - oldPoint).length()
                oldPoint = control.point
            }
        }
        return length
    }
    func length() -> Double {
        bezierSequence.reduce(0.0) { $0 + $1.length() }
    }
    func length(with range: LineRange) -> Double {
        if range.startIndex == range.endIndex {
            return bezier(at: range.startIndex)
                .clip(startT: range.startT, endT: range.endT)
                .length()
        } else {
            var length = bezier(at: range.startIndex)
                .clip(startT: range.startT, endT: 1)
                .length()
            if range.endIndex - range.startIndex >= 2 {
                for i in (range.startIndex + 1)..<range.endIndex {
                    length += bezier(at: i).length()
                }
            }
            length += bezier(at: range.endIndex)
                .clip(startT: 0, endT: range.endT)
                .length()
            return length
        }
    }
    
    func reversedRanges(_ ranges: [LineRange]) -> [LineRange] {
        let siv = LineIndexValue(index: 0, t: 0)
        let eiv = LineIndexValue(index: maxBezierIndex, t: 1)
        guard !ranges.isEmpty else {
            return [LineRange(startIndexValue: siv, endIndexValue: eiv)]
        }
        var iv = ranges[0].startIndexValue == siv ?
            ranges[0].startIndexValue :
            siv
        var nRanges = [LineRange]()
        for range in ranges {
            if iv != range.startIndexValue {
                nRanges.append(LineRange(startIndexValue: iv,
                                         endIndexValue: range.startIndexValue))
            }
            iv = range.endIndexValue
        }
        if iv != eiv {
            nRanges.append(LineRange(startIndexValue: iv,
                                     endIndexValue: eiv))
        }
        return nRanges
    }
    
    func intersects(_ otherEdge: Edge) -> Bool {
        guard bounds?.intersects(otherEdge.bounds) ?? false else {
            return false
        }
        for b in bezierSequence {
            if b.intersects(otherEdge) {
                return true
            }
        }
        return false
    }
    func intersects(_ otherArc: Arc) -> Bool {
        for b in bezierSequence {
            if b.intersects(otherArc) {
                return true
            }
        }
        return false
    }
    func intersects(_ otherBezier: Bezier) -> Bool {
        guard bounds?.intersects(otherBezier.controlBounds) ?? false else {
            return false
        }
        for b in bezierSequence {
            if otherBezier.intersects(b) {
                return true
            }
        }
        return false
    }
    func intersects(_ other: Line) -> Bool {
        guard let otherBounds = other.bounds,
              bounds?.intersects(otherBounds) ?? false else {
            return false
        }
        for bezier in bezierSequence {
            if other.intersects(bezier) {
                return true
            }
        }
        return false
    }
    func intersects(_ otherRect: Rect) -> Bool {
        guard bounds?.intersects(otherRect) ?? false else {
            return false
        }
        if otherRect.contains(firstPoint) {
            return true
        } else {
            let x0y0 = otherRect.origin
            let x1y0 = Point(otherRect.maxX, otherRect.minY)
            let x0y1 = Point(otherRect.minX, otherRect.maxY)
            let x1y1 = Point(otherRect.maxX, otherRect.maxY)
            return intersects(Bezier.linear(x0y0, x1y0))
                || intersects(Bezier.linear(x1y0, x1y1))
                || intersects(Bezier.linear(x1y1, x0y1))
                || intersects(Bezier.linear(x0y1, x0y0))
        }
    }
    func lassoIntersects(_ otherRect: Rect) -> Bool {
        guard let bounds = bounds else { return false }
        guard bounds.intersects(otherRect) else { return false }
        return path(isClosed: true).intersects(otherRect)
    }
    
    func indexValues(with splitLine: Line) -> [(l0: LineIndexValue,
                                                l1: LineIndexValue)] {
        let bb = splitLine.bounds
        var values = [(l0: LineIndexValue,
                       l1: LineIndexValue)]()
        for (i0, b0) in bezierSequence.enumerated() {
            guard bb.intersects(b0.controlBounds) else { continue }
            for (i1, b1) in splitLine.bezierSequence.enumerated() {
                values += b0.intersections(b1).map {
                    (LineIndexValue(index: i0, t: $0.t),
                     LineIndexValue(index: i1, t: $0.otherT))
                }
            }
        }
        return values
    }
    
    func firstRoundedEdge() -> Edge? {
        guard controls.count >= 2 else { return nil }
        let fc = controls.first!
        let ep = fc.point.movedWith(distance: size * fc.pressure,
                                    angle: firstAngle - .pi)
        return Edge(ep, fc.point)
    }
    func lastRoundedEdge() -> Edge? {
        guard controls.count >= 2 else { return nil }
        let lc = controls.last!
        let ep = lc.point.movedWith(distance: size * lc.pressure,
                                    angle: lastAngle)
        return Edge(lc.point, ep)
    }
}
extension Line {
    func autoFillLineWith(extensionLength l: Double = Line.defaultLineWidth * 2,
                          lineWidth: Double,
                          minLineWidth: Double
                            = Line.defaultLineWidth / 2) -> Line {
        guard controls.count > 1 else {
            return self
        }
        let minPressure = minLineWidth / lineWidth
        var line = self
        line.controls = line.controls.map {
            Line.Control(point: $0.point, weight: $0.weight,
                         pressure: max($0.pressure, minPressure))
        }
        let fpr = line.controls[0].pressure
        let fp = line.firstPoint.movedWith(distance: l * fpr,
                                           angle: line.firstAngle - .pi)
        line.controls.insert(Line.Control(point: fp, weight: 0.5, pressure: fpr),
                             at: 0)
        line.controls[1].weight = 0
        let lpr = line.controls[.last].pressure
        let lp = line.lastPoint.movedWith(distance: l * lpr,
                                          angle: line.lastAngle)
        line.controls.append(Line.Control(point: lp, weight: 0.5, pressure: lpr))
        line.controls[line.controls.count - 2].weight = 1
        return line
    }
    func autoFillNode(lineWidth: Double = Line.defaultLineWidth * 1.05,
                      lineColor: Color) -> Node {
        Node(path: Path(autoFillLineWith(lineWidth: lineWidth)),
             lineWidth: lineWidth, lineType: .color(lineColor))
    }
    func path(isClosed: Bool, isPolygon: Bool = true) -> Path {
        guard let elementsTuple = bezierCurveElementsTuple else {
            return Path()
        }
        return Path(([Pathline(firstPoint: elementsTuple.firstPoint,
                               elements: elementsTuple.elements,
                               isClosed: isClosed)]),
                    isPolygon: isPolygon)
    }
}
extension Array where Element == Line {
    var bounds: Rect? {
        var rect = Rect?.none
        for line in self {
            rect = rect + line.bounds
        }
        return rect
    }
}
extension Line {
    static func circle(centerPosition cp: Point = Point(),
                       radius r: Double = 50,
                       size: Double = Line.defaultLineWidth) -> Line {
        let count = 8
        let theta = .pi / Double(count)
        let fp = Point(x: cp.x, y: cp.y + r)
        let points = [Point].circle(centerPosition: cp,
                                    radius: r / .cos(theta),
                                    firstAngle: .pi / 2 + theta,
                                    count: count)
        let nps = [fp] + points + [fp]
        return Line(controls: nps.map { Line.Control(point: $0) }, size: size)
    }
    static func wave(_ edge: Edge, a: Double, length: Double,
                     size: Double) -> Line {
        let maxLength = edge.length
        let ea = edge.angle()
        var l = 0.0
        var cs = [Control](), angle = ea + .pi / 2
        cs.append(Control(point: edge.p0))
        while l < maxLength {
            let p0 = edge.p0
                .movedWith(distance: l + length / 2, angle: ea)
                .movedWith(distance: a, angle: angle)
            let p1 = edge.p0
                .movedWith(distance: l + length, angle: ea)
            cs.append(Control(point: p0))
            cs.append(Control(point: p1))
            l += length
            angle *= -1
        }
        return Line(controls: cs, size: size)
    }
}
extension Array where Element == Line {
    static func triangle(centerPosition cp: Point = Point(),
                         radius r: Double = 50,
                         size: Double = Line.defaultLineWidth) -> [Line] {
        regularPolygon(centerPosition: cp, radius: r, count: 3,
                       size: size)
    }
    static func square(centerPosition cp: Point = Point(),
                       polygonRadius r: Double = 50,
                       size: Double = Line.defaultLineWidth) -> [Line] {
        let p0 = Point(x: cp.x - r, y: cp.y - r)
        let p1 = Point(x: cp.x + r, y: cp.y - r)
        let p2 = Point(x: cp.x + r, y: cp.y + r)
        let p3 = Point(x: cp.x - r, y: cp.y + r)
        let l0 = Line(controls: [Line.Control(point: p0),
                                 Line.Control(point: p1)], size: size)
        let l1 = Line(controls: [Line.Control(point: p1),
                                 Line.Control(point: p2)], size: size)
        let l2 = Line(controls: [Line.Control(point: p2),
                                 Line.Control(point: p3)], size: size)
        let l3 = Line(controls: [Line.Control(point: p3),
                                 Line.Control(point: p0)], size: size)
        return [l0, l1, l2, l3]
    }
    static func rectangle(_ rect: Rect,
                          size: Double = Line.defaultLineWidth) -> [Line] {
        let p0 = Point(x: rect.minX, y: rect.minY)
        let p1 = Point(x: rect.maxX, y: rect.minY)
        let p2 = Point(x: rect.maxX, y: rect.maxY)
        let p3 = Point(x: rect.minX, y: rect.maxY)
        let l0 = Line(controls: [Line.Control(point: p0),
                                 Line.Control(point: p1)], size: size)
        let l1 = Line(controls: [Line.Control(point: p1),
                                 Line.Control(point: p2)], size: size)
        let l2 = Line(controls: [Line.Control(point: p2),
                                 Line.Control(point: p3)], size: size)
        let l3 = Line(controls: [Line.Control(point: p3),
                                 Line.Control(point: p0)], size: size)
        return [l0, l1, l2, l3]
    }
    static func pentagon(centerPosition cp: Point = Point(),
                         radius r: Double = 50,
                         size: Double = Line.defaultLineWidth) -> [Line] {
        regularPolygon(centerPosition: cp, radius: r, count: 5,
                       size: size)
    }
    static func hexagon(centerPosition cp: Point = Point(),
                        radius r: Double = 50,
                        size: Double = Line.defaultLineWidth) -> [Line] {
        regularPolygon(centerPosition: cp, radius: r, count: 6,
                       size: size)
    }
    static func regularPolygon(centerPosition cp: Point = Point(),
                               radius r: Double = 50,
                               firstAngle: Double = .pi / 2, count: Int,
                               size: Double = Line.defaultLineWidth) -> [Line] {
        let points = [Point].circle(centerPosition: cp, radius: r,
                                    firstAngle: firstAngle, count: count)
        return points.enumerated().map {
            let p0 = $0.element, i = $0.offset
            let p1 = i + 1 < points.count ? points[i + 1] : points[0]
            return Line(controls: [Line.Control(point: p0),
                                   Line.Control(point: p1)],
                        size: size)
        }
    }
}
extension Array where Element == Line {
    var orientation: CircularOrientation? {
        var area = 0.0
        for line in self {
            guard var c0 = line.controls.first else { continue }
            for c1 in line.controls {
                area += c0.point.cross(c1.point)
                c0 = c1
            }
        }
        if area > 0 {
            return .counterClockwise
        } else if area < 0 {
            return .clockwise
        } else {
            return nil
        }
    }
}

struct Lasso {
    var line: Line {
        didSet {
            path = Path(line)
        }
    }
    private(set) var path: Path
    
    init(line: Line) {
        self.line = line
        path = line.path(isClosed: true, isPolygon: false)
    }
}
extension Lasso: Codable {
    private enum CodingKeys: String, CodingKey {
        case line
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        line = try values.decode(Line.self, forKey: .line)
        path = line.path(isClosed: true, isPolygon: false)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(line, forKey: .line)
    }
}
extension Lasso: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(line)
    }
    static func == (lhs: Lasso, rhs: Lasso) -> Bool {
        lhs.line == rhs.line
    }
}
extension Lasso: AppliableTransform {
    static func * (lhs: Lasso, rhs: Transform) -> Lasso {
        Lasso(line: lhs.line * rhs)
    }
}
extension Lasso {
    var bounds: Rect? {
        line.bounds
    }
}
extension Lasso {
    func isStraight(withMaxDistance d: Double = 1,
                    maxLineWidth: Double = 2) -> Bool {
        let dSquared = d * d
        if line.length() < maxLineWidth {
            let edge = Edge(line.firstPoint, line.lastPoint)
            for c in line.controls {
                if edge.distanceSquared(from: c.point) > dSquared {
                    return false
                }
            }
            return true
        }
        return false
    }
    enum LassoType {
        case around, split([LineRange])
    }
    func lassoType(with otherLine: Line) -> LassoType? {
        let bb = line.bounds
        guard !otherLine.isEmpty && otherLine.bounds.intersects(bb) else {
            return nil
        }
        
        var ranges = [LineRange](), oldIndex = 0, oldT = 0.0
        let firstPointInPath = path.contains(otherLine.firstPoint)
        let lastPointInPath = path.contains(otherLine.lastPoint)
        var isSplitLine = false, leftIndex = firstPointInPath ? 1 : 0
        func append(startIndex: Int, startT: Double, endIndex: Int, endT: Double) {
            guard !(startIndex == endIndex && startT == endT) else { return }
            ranges.append(LineRange(startIndex: startIndex, startT: startT,
                                    endIndex: endIndex, endT: endT))
        }
        for (i0, b0) in otherLine.bezierSequence.enumerated() {
            guard bb.intersects(b0.controlBounds) else { continue }
            var bis = [BezierIntersection]()
            let lp = line.lastPoint, fp = line.firstPoint
            if lp != fp {
                bis += b0.intersections(Bezier.linear(lp, fp))
            }
            for b1 in line.bezierSequence {
                bis += b0.intersections(b1)
            }
            guard !bis.isEmpty else { continue }
            
            let sbis = bis.sorted { $0.t < $1.t }
            for bi in sbis {
                leftIndex += 1
                if leftIndex % 2 == 0 {
                    append(startIndex: oldIndex, startT: oldT,
                           endIndex: i0, endT: bi.t)
                } else {
                    oldIndex = i0
                    oldT = bi.t
                }
            }
            isSplitLine = true
        }
        if isSplitLine && lastPointInPath {
            let endIndex = otherLine.controls.count <= 2 ?
                0 : otherLine.controls.count - 3
            append(startIndex: oldIndex, startT: oldT,
                   endIndex: endIndex, endT: 1)
        }
        if !ranges.isEmpty {
            return LassoType.split(ranges.union())
        } else if !isSplitLine && firstPointInPath && lastPointInPath {
            return LassoType.around
        } else {
            return nil
        }
    }
    enum SplitedLine {
        case around(Line), split((inLines: [Line], outLines: [Line]))
    }
    func splitedLine(with otherLine: Line,
                     splitLines: [Line] = [],
                     distance d: Double = 0) -> SplitedLine? {
        guard let splited = self.lassoType(with: otherLine) else {
            if d > 0 && !splitLines.isEmpty {
                let isFirstSnap: Bool
                if let edge = otherLine.firstRoundedEdge(), line.intersects(edge) {
                    isFirstSnap = true
                } else {
                    isFirstSnap = false
                }
                let isLastSnap: Bool
                if let edge = otherLine.lastRoundedEdge(), line.intersects(edge) {
                    isLastSnap = true
                } else {
                    isLastSnap = false
                }
                
                if isFirstSnap || isLastSnap {
                    var inRanges = [LineRange]()
                    
                    var ivs = [(d: Double, liv: LineIndexValue)]()
                    for splitLine in splitLines {
                        ivs += otherLine.indexValues(with: splitLine).map {
                            (splitLine.size(at: $0.l1) / 2, $0.l0)
                        }
                    }
                    ivs.sort(by: { $0.liv < $1.liv })
                    
                    if let (ivd, iv) = ivs.first {
                        let flRange
                            = LineRange(startIndexValue: LineIndexValue(),
                                        endIndexValue: iv)
                        let fl = otherLine.length(with: flRange)
                        if fl > otherLine.size * 0.01 && fl < d + ivd {
                            inRanges.append(flRange)
                        }
                    }
                    if let (ivd, iv) = ivs.last, iv != ivs.first?.liv {
                        let endIndex = otherLine.controls.count <= 2 ?
                            0 : otherLine.controls.count - 3
                        let lliv = LineIndexValue(index: endIndex, t: 1)
                        let llRange
                            = LineRange(startIndexValue: iv,
                                        endIndexValue: lliv)
                        let ll = otherLine.length(with: llRange)
                        if ll > otherLine.size * 0.01 && ll < d + ivd {
                            inRanges.append(llRange)
                        }
                    }
                    
                    if !inRanges.isEmpty {
                        let outRanges = otherLine.reversedRanges(inRanges)
                        let nInRanges = otherLine.reversedRanges(outRanges)
                        let nInLines = nInRanges.map { otherLine.splited(with: $0) }
                        let nOutLines = outRanges.map { otherLine.splited(with: $0) }
                        return .split((nInLines, nOutLines))
                    }
                }
            }
            
            return nil
        }
        switch splited {
        case .around:
            return .around(otherLine)
        case .split(var inRanges):
            if d > 0 && !splitLines.isEmpty {
                var ivs = [(d: Double, liv: LineIndexValue)]()
                for splitLine in splitLines {
                    ivs += otherLine.indexValues(with: splitLine).map {
                        (splitLine.size(at: $0.l1) / 2, $0.l0)
                    }
                }
                ivs.sort(by: { $0.liv < $1.liv })
                
                for i in 0..<inRanges.count {
                    let preIV = i == 0 ?
                        otherLine.firstIndexValue : inRanges[i - 1].endIndexValue
                    let nextIV = i == inRanges.count - 1 ?
                        otherLine.lastIndexValue : inRanges[i + 1].startIndexValue
                    let range = inRanges[i]
                    if range.startIndexValue != otherLine.firstIndexValue {
                        var minIV: LineIndexValue?, minD = Double.infinity
                        for (ivd, iv) in ivs {
                            let flRange = iv < range.startIndexValue ?
                                LineRange(startIndexValue: iv,
                                          endIndexValue: range.startIndexValue) :
                                LineRange(startIndexValue: range.startIndexValue,
                                          endIndexValue: iv)
                            let fl = otherLine.length(with: flRange)
                            if fl < d + ivd && fl < minD {
                                minD = fl
                                minIV = iv
                            }
                        }
                        if let iv = minIV, preIV < iv && iv < range.endIndexValue {
                            inRanges[i].startIndexValue = iv
                        }
                    }
                    if range.endIndexValue != otherLine.lastIndexValue {
                        var minIV: LineIndexValue?, minD = Double.infinity
                        for (ivd, iv) in ivs {
                            let llRange = iv < range.endIndexValue ?
                                LineRange(startIndexValue: iv,
                                          endIndexValue: range.endIndexValue) :
                                LineRange(startIndexValue: range.endIndexValue,
                                          endIndexValue: iv)
                            let ll = otherLine.length(with: llRange)
                            if ll < d + ivd && ll < minD {
                                minD = ll
                                minIV = iv
                            }
                        }
                        if let iv = minIV, range.startIndexValue < iv && iv < nextIV {
                            inRanges[i].endIndexValue = iv
                        }
                    }
                }
            }
            
            let outRanges = otherLine.reversedRanges(inRanges)
            let nInRanges = otherLine.reversedRanges(outRanges)
            let nInLines = nInRanges.map { otherLine.splited(with: $0) }
            let nOutLines = outRanges.map { otherLine.splited(with: $0) }
            return .split((nInLines, nOutLines))
        }
    }
}
extension Lasso {
    func contains(_ p: Point) -> Bool {
        path.contains(p)
    }
    func intersects(_ other: Lasso) -> Bool {
        guard !line.bounds.intersects(other.line.bounds) else {
            return false
        }
        if other.line.intersects(line) {
            return true
        }
        if other.path.contains(line.firstPoint)
            || other.path.contains(line.lastPoint) {
            
            return true
        }
        return false
    }
    func intersects(_ otherLine: Line) -> Bool {
        guard bounds.intersects(otherLine.bounds) else {
            return false
        }
        if line.intersects(otherLine) {
            return true
        }
        for p in otherLine.mainPointSequence {
            if contains(p) {
                return true
            }
        }
        return false
    }
}
