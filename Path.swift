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

struct Pathline {
    enum Element {
        case linear(Point)
        case bezier(point: Point, control: Point)
        case line(Line)
        case arc(Arc)
        var lastPoint: Point {
            switch self {
            case .linear(let p): return p
            case .bezier(let p, _): return p
            case .line(let line): return line.lastPoint
            case .arc(let arc): return arc.endPosition
            }
        }
    }
    var firstPoint: Point
    var elements: [Element]
    var isClosed: Bool
    
    init(firstPoint: Point = Point(), elements: [Element],
         isClosed: Bool = false) {
        self.firstPoint = firstPoint
        self.elements = elements
        self.isClosed = isClosed
    }
    init(_ points: [Point], isClosed: Bool = false) {
        firstPoint = points.first!
        elements = (1..<points.count).map { .linear(points[$0]) }
        self.isClosed = isClosed
    }
    init(_ polygon: Polygon) {
        firstPoint = polygon.points.first!
        elements = (1..<polygon.points.count).map { .linear(polygon.points[$0]) }
        isClosed = true
    }
    init(_ edge: Edge) {
        firstPoint = edge.p0
        elements = [.linear(edge.p1)]
        isClosed = false
    }
    init(_ bezier: Bezier) {
        firstPoint = bezier.p0
        elements = [.bezier(point: bezier.p1, control: bezier.cp)]
        isClosed = false
    }
    init(_ rect: Rect) {
        self.init([rect.minXMaxYPoint, rect.minXMinYPoint,
                   rect.maxXMinYPoint, rect.maxXMaxYPoint], isClosed: true)
    }
    init(_ rect: Rect, cornerRadius r: Double, isSquircle: Bool = true) {
        guard r > 0 else {
            self.init(rect)
            return
        }
        if isSquircle {
            var es = [Element]()
            es += Pathline.squircle(p0: rect.maxXMaxYPoint,
                                    p1: rect.minXMaxYPoint,
                                    p2: rect.minXMinYPoint, r: r)
            es += Pathline.squircle(p0: rect.minXMaxYPoint,
                                    p1: rect.minXMinYPoint,
                                    p2: rect.maxXMinYPoint, r: r)
            es += Pathline.squircle(p0: rect.minXMinYPoint,
                                    p1: rect.maxXMinYPoint,
                                    p2: rect.maxXMaxYPoint, r: r)
            es += Pathline.squircle(p0: rect.maxXMinYPoint,
                                    p1: rect.maxXMaxYPoint,
                                    p2: rect.minXMaxYPoint, r: r)
            self.init(firstPoint: Point(rect.midX, rect.maxY),
                      elements: es,
                      isClosed: true)
        } else {
            let nr = min(min(rect.width, rect.height) / 2, r)
            let cp0 = Point(rect.minX + nr, rect.maxY - nr)
            let cp1 = Point(rect.minX + nr, rect.minY + nr)
            let cp2 = Point(rect.maxX - nr, rect.minY + nr)
            let cp3 = Point(rect.maxX - nr, rect.maxY - nr)
            self.init(firstPoint: Point(rect.minX + nr, rect.maxY),
                      elements: [.arc(Arc(centerPosition: cp0, radius: nr,
                                          startAngle: .pi / 2, endAngle: .pi)),
                                 .arc(Arc(centerPosition: cp1, radius: nr,
                                          startAngle: -.pi, endAngle: -.pi / 2)),
                                 .arc(Arc(centerPosition: cp2, radius: nr,
                                          startAngle: -.pi / 2, endAngle: 0)),
                                 .arc(Arc(centerPosition: cp3, radius: nr,
                                          startAngle: 0, endAngle: .pi / 2))],
                      isClosed: true)
        }
    }
    init(circleRadius r: Double, position p: Point = Point()) {
        self.init(Arc(centerPosition: p, radius: r), isClosed: true)
    }
    init(_ line: Line, isClosed: Bool = false) {
        self.init(firstPoint: line.firstPoint,
                  elements: [Pathline.Element.line(line)],
                  isClosed: isClosed)
    }
    init(_ lines: [Line], isClosed: Bool = false) {
        for line in lines {
            if line.isEmpty {
                fatalError()
            }
        }
        self.init(firstPoint: lines.first!.firstPoint,
                  elements: lines.map { Pathline.Element.line($0) },
                  isClosed: isClosed)
    }
    init(_ arc: Arc, isClosed: Bool = false) {
        self.init(firstPoint: arc.startPosition,
                  elements: [Pathline.Element.arc(arc)],
                  isClosed: isClosed)
    }
    
    static func squircle(p0: Point, p1: Point, p2: Point, r: Double,
                         angleRatio: Double = 0.33,
                         extensionRatio: Double = 0.25) -> [Pathline.Element] {
        let da = Point.differenceAngle(p0, p1, p2)
        let phi = abs(da) / 2
        let rd = r / .tan(phi)
        let p1p0Theta = p1.angle(p0), p1p2Theta = p1.angle(p2)
        let rp0 = p1.movedRoundedWith(distance: rd, angle: p1p0Theta)
        let rp1 = p1.movedRoundedWith(distance: rd, angle: p1p2Theta)
        let r0Theta = da > 0 ? p1p0Theta - .pi / 2 : p1p0Theta + .pi / 2
        let cp = rp0.movedRoundedWith(distance: r, angle: r0Theta)
        let cpDeltaAngle = (.pi / 2 - phi) * 2
        let startAngle = r0Theta - .pi + cpDeltaAngle * angleRatio
        let endAngle = r0Theta - .pi + cpDeltaAngle * (1 - angleRatio)
        let ex = r * extensionRatio
        
        let b0p1 = cp.movedRoundedWith(distance: r, angle: startAngle)
        let b0p1l = b0p1.movedRoundedWith(distance: 1,
                                          angle: startAngle - .pi / 2)
        let b0l0 = LinearLine(b0p1, b0p1l)
        let b0l1 = LinearLine(p1, p0)
        guard let b0cp = b0l0.intersection(b0l1) else { return [] }
        let b0p0 = rp0.movedRoundedWith(distance: ex, angle: p1p0Theta)
        
        let b1p0 = cp.movedRoundedWith(distance: r, angle: endAngle)
        let b1p0l = b1p0.movedRoundedWith(distance: 1,
                                          angle: endAngle + .pi / 2)
        let b1l0 = LinearLine(b1p0, b1p0l)
        let b1l1 = LinearLine(p1, p2)
        guard let b1cp0 = b1l0.intersection(b1l1) else { return [] }
        let b1p1 = rp1.movedRoundedWith(distance: ex, angle: p1p2Theta)
        
        let b0 = Bezier(p0: b0p0, cp: b0cp, p1: b0p1)
        let arc = Arc(centerPosition: cp, radius: r,
                      startAngle: startAngle, endAngle: endAngle)
        let b1 = Bezier(p0: b1p0, cp: b1cp0, p1: b1p1)
        return [.linear(b0.p0),
                .bezier(point: b0.p1,
                        control: b0.cp),
                .arc(arc),
                .bezier(point: b1.p1,
                        control: b1.cp)]
    }
}
extension Pathline: AppliableTransform {
    static func * (lhs: Pathline, rhs: Transform) -> Pathline {
        let elements: [Element] = lhs.elements.map {
            switch $0 {
            case .linear(let p): return .linear(p * rhs)
            case .bezier(let p, let cp): return .bezier(point: p * rhs,
                                                        control: cp * rhs)
            case .line(let line): return .line(line * rhs)
            case .arc(let arc): return .arc(arc * rhs)
            }
        }
        return Pathline(firstPoint: lhs.firstPoint * rhs,
                        elements: elements,
                        isClosed: lhs.isClosed)
    }
}
extension Pathline {
    func toVertical() -> Pathline {
        let elements: [Element] = self.elements.map {
            switch $0 {
            case .linear(let p1):
                return .linear(p1.inverted())
            case .bezier(let p1, let cp):
                return .bezier(point: p1.inverted(), control: cp.inverted())
            case .line(let line):
                return .line(line.toVertical())
            case .arc(let arc):
                return .arc(arc.toVertical())
            }
        }
        return Pathline(firstPoint: firstPoint.inverted(),
                        elements: elements,
                        isClosed: isClosed)
    }
    var firstAngle: Double? {
        guard let fe = elements.first else { return nil }
        switch fe {
        case .linear(let p): return firstPoint.angle(p)
        case .bezier(let p, let cp):
            return firstPoint.angle(firstPoint == cp ? p : cp)
        case .line(let line):
            return firstPoint == line.firstPoint ?
                line.firstAngle : firstPoint.angle(line.firstPoint)
        case .arc(let arc):
            return firstPoint == arc.startPosition ?
                arc.startAngle + .pi / 2 : firstPoint.angle(arc.startPosition)
        }
    }
    var lastAngle: Double? {
        guard let le = elements.last else { return nil }
        switch le {
        case .linear(let p):
            let llp = elements.count > 2 ?
                elements[elements.count - 2].lastPoint : firstPoint
            return llp.angle(p)
        case .bezier(let p, let cp):
            if cp == p {
                let llp = elements.count > 2 ?
                    elements[elements.count - 2].lastPoint : firstPoint
                return llp.angle(p)
            } else {
                return cp.angle(p)
            }
        case .line(let line):
            return line.lastAngle
        case .arc(let arc):
            return arc.endAngle + .pi / 2
        }
    }
    var lastPoint: Point {
        guard let lastElement = elements.last else {
            return firstPoint
        }
        switch lastElement {
        case .linear(let p1): return p1
        case .bezier(let p1, _): return p1
        case .line(let line): return line.lastPoint
        case .arc(let arc): return arc.endPosition
        }
    }
    var bounds: Rect {
        var aabb = AABB(firstPoint)
        var p0 = firstPoint
        for element in elements {
            switch element {
            case .linear(let p1):
                aabb += p1
                p0 = p1
            case .bezier(let p1, let cp):
                aabb += AABB(Bezier(p0: p0, cp: cp, p1: p1))
                p0 = p1
            case .line(let line):
                if let b = line.bounds {
                    aabb += AABB(b)
                }
                p0 = line.lastPoint
            case .arc(let arc):
                aabb += AABB(arc.bounds)
                p0 = arc.endPosition
            }
        }
        return aabb.rect
    }
    func contains(_ p: Point) -> Bool {
        var count = 0
        var p0 = firstPoint
        for element in elements {
            switch element {
            case .linear(let p1):
                count += Edge(p0, p1).rayCasting(p)
                p0 = p1
            case .bezier(let p1, let cp):
                count += Bezier(p0: p0, cp: cp, p1: p1).rayCasting(p)
                p0 = p1
            case .line(let line):
                let fp = line.firstPoint
                if p0 != fp {
                    count += Edge(p0, fp).rayCasting(p)
                }
                for b in line.bezierSequence {
                    count += b.rayCasting(p)
                }
                p0 = line.lastPoint
            case .arc(let arc):
                let sp = arc.startPosition
                if p0 != sp {
                    count += Edge(p0, sp).rayCasting(p)
                }
                count += arc.rayCasting(p)
                p0 = arc.endPosition
            }
        }
        count += Edge(p0, firstPoint).rayCasting(p)
        return count % 2 != 0
    }
    func containsLine(_ p: Point, lineWidth: Double,
                      isRoundCap: Bool = true) -> Bool {
        let d = lineWidth / 2
        let dSquared = d * d
        var p0 = firstPoint, pre0 = 1.0
        for element in elements {
            switch element {
            case .linear(let p1):
                if Edge(p0, p1).distanceSquared(from: p) <= dSquared {
                    return true
                }
                p0 = p1
                pre0 = 1
            case .bezier(let p1, let cp):
                if Bezier(p0: p0, cp: cp, p1: p1).minDistanceSquared(from: p)
                    <= dSquared {
                    
                    return true
                }
                p0 = p1
                pre0 = 1
            case .line(let line):
                let fp = line.firstPoint
                if p0 != fp && Edge(p0, fp).distanceSquared(from: p) <= dSquared {
                    return true
                }
                for (i, b) in line.bezierSequence.enumerated() {
                    let preb = line.pressureInterpolation(at: i)
                    let (t, ndSquared) = b.nearest(at: p)
                    let pre = preb.position(withT: t)
                    if ndSquared <= dSquared * pre * pre {
                        return true
                    }
                }
                p0 = line.lastPoint
                pre0 = line.controls[.last].pressure
            case .arc(let arc):
                let sp = arc.startPosition
                if p0 != sp && Edge(p0, sp).distanceSquared(from: p) <= dSquared {
                    return true
                }
                if arc.distanceSquared(from: p) <= dSquared {
                    return true
                }
                p0 = arc.endPosition
                pre0 = 1
            }
        }
        if isClosed {
            if Edge(p0, firstPoint).distanceSquared(from: p) <= dSquared {
                return true
            }
        } else if isRoundCap {
            var fpre = 1.0
            if case .line(let line)? = elements.first {
                fpre = line.controls[.first].pressure
            }
            if p.distanceSquared(firstPoint) <= dSquared * fpre * fpre
                || p.distanceSquared(p0) <= dSquared * pre0 * pre0 {
                
                return true
            }
        }
        return false
    }
    func intersects(_ rect: Rect) -> Bool {
        if contains(rect.minXMinYPoint)
            || contains(rect.maxXMinYPoint)
            || contains(rect.maxXMinYPoint)
            || contains(rect.maxXMaxYPoint)
            || intersectsLine(rect) {
            
            return true
        } else {
            return false
        }
    }
    func intersectsLine(_ rect: Rect, isClosed: Bool = true) -> Bool {
        var p0 = firstPoint
        for element in elements {
            switch element {
            case .linear(let p1):
                if rect.intersects(Edge(p0, p1)) {
                    return true
                }
                p0 = p1
            case .bezier(let p1, let cp):
                if Bezier(p0: p0, cp: cp, p1: p1).intersects(rect) {
                    return true
                }
                p0 = p1
            case .line(let line):
                let fp = line.firstPoint
                if p0 != fp && rect.intersects(Edge(p0, fp)) {
                    return true
                }
                for b in line.bezierSequence {
                    if b.intersects(rect) {
                        return true
                    }
                }
                p0 = line.lastPoint
            case .arc(let arc):
                let sp = arc.startPosition
                if p0 != sp && rect.intersects(Edge(p0, sp)) {
                    return true
                }
                if arc.intersects(rect) {
                    return true
                }
                p0 = arc.endPosition
            }
        }
        if isClosed && rect.intersects(Edge(p0, firstPoint)) {
            return true
        }
        return false
    }
    func polygon(withQuality quality: Double = 0.2) -> Polygon {
        var rps = [Point]()
        func appendLinear(p0: Point, p1: Point) {
            guard p0 != p1 else { return }
            rps.append(p1)
        }
        func appendBezier(_ bezier: Bezier) {
            guard !bezier.isLineaer else {
                appendLinear(p0: bezier.p0, p1: bezier.p1)
                return
            }
            let l = bezier.length(withFlatness: 4)
            let ll = l * 0.2
            let d = Edge(bezier.p0, bezier.p1).distance(from: bezier.cp)
            let c = l * min(1, d / ll) * quality
            let count = c.isNaN ? 2 : Int(c.clipped(min: 2, max: 20))
            let rCount = 1 / Double(count)
            for i in 1...count {
                let t = Double(i) * rCount
                let p = bezier.position(withT: t)
                rps.append(p)
            }
        }
        func appendArc(_ arc: Arc) {
            let dAngle = abs(arc.endAngle - arc.startAngle)
            let count = max(16, Int(arc.radius * dAngle * quality))
            let rCount = 1 / Double(count)
            for i in 1...count {
                let theta = Double.linear(arc.startAngle, arc.endAngle,
                                          t: Double(i) * rCount)
                let p = arc.centerPosition.movedWith(distance: arc.radius,
                                                     angle: theta)
                rps.append(p)
            }
        }
        
        var p0 = firstPoint
        rps.append(p0)
        for element in elements {
            switch element {
            case .linear(let p1):
                appendLinear(p0: p0, p1: p1)
                p0 = p1
            case .bezier(let p1, let cp):
                appendBezier(Bezier(p0: p0, cp: cp, p1: p1))
                p0 = p1
            case .line(let line):
                appendLinear(p0: p0, p1: line.firstPoint)
                for b in line.bezierSequence {
                    appendBezier(b)
                }
                p0 = line.lastPoint
            case .arc(let arc):
                appendArc(arc)
                p0 = arc.endPosition
            }
        }
        if rps.first == rps.last {
            rps.removeLast()
        }
        
        return Polygon(points: rps)
    }
}

struct Path {
    var pathlines = [Pathline]() {
        didSet { updateBounds() }
    }
    var isPolygon = true, isCap = true
    private(set) var bounds: Rect?, typesetter: Typesetter?
    
    init() {}
    init(_ rect: Rect) {
        pathlines = [Pathline(rect)]
        isCap = false
        updateBounds()
    }
    init(_ rect: Rect, cornerRadius r: Double) {
        pathlines = [Pathline(rect, cornerRadius: r)]
        isCap = false
        updateBounds()
    }
    init(_ arc: Arc) {
        pathlines = [Pathline(arc)]
        updateBounds()
    }
    init(circleRadius r: Double, position p: Point = Point()) {
        pathlines = [Pathline(circleRadius: r, position: p)]
        isCap = false
        updateBounds()
    }
    init(_ line: Line) {
        if !line.isEmpty {
            pathlines = [Pathline(line)]
            updateBounds()
        }
    }
    init(_ edge: Edge) {
        pathlines = [Pathline(edge)]
        updateBounds()
    }
    init(_ polygon: Polygon) {
        if !polygon.isEmpty {
            pathlines = [Pathline(polygon)]
            isCap = false
            updateBounds()
        }
    }
    init(_ topoly: Topolygon) {
        if !topoly.polygon.isEmpty
            && !topoly.holePolygons.contains(where: { $0.isEmpty }) {
            
            pathlines = [Pathline(topoly.polygon)]
                + topoly.holePolygons.map { Pathline($0) }
            isCap = false
            updateBounds()
        }
    }
    init(_ pathlines: [Pathline], isPolygon: Bool = true, isCap: Bool = true) {
        self.pathlines = pathlines
        self.isPolygon = isPolygon
        self.isCap = isCap
        updateBounds()
    }
    init(_ typesetter: Typesetter, isPolygon: Bool = true, isCap: Bool = true) {
        self.typesetter = typesetter
        self.pathlines = typesetter.pathlines
        self.isPolygon = isPolygon
        self.isCap = isCap
        updateBounds()
    }
    
    private mutating func updateBounds() {
        bounds = pathlines.reduce(into: Rect?.none) { $0 += $1.bounds }
    }
}
extension Path: AppliableTransform {
    static func * (lhs: Path, rhs: Transform) -> Path {
        Path(lhs.pathlines.map { $0 * rhs },
             isPolygon: lhs.isPolygon, isCap: lhs.isCap)
    }
}
extension Path {
    var isEmpty: Bool {
        pathlines.isEmpty ?
            true :
            (bounds?.isEmpty ?? false)
    }
    
    func area(withQuality quality: Double = 1) -> Double {
        topolygon(withQuality: quality).area
    }
    
    func contains(_ p: Point) -> Bool {
        guard bounds?.contains(p) ?? false else { return false }
        for pathline in pathlines {
            if pathline.contains(p) {
                return true
            }
        }
        return false
    }
    func containsLine(_ p: Point, lineWidth lw: Double) -> Bool {
        guard bounds?.inset(by: -lw / 2).contains(p)
                ?? false else { return false }
        for pathline in pathlines {
            if pathline.containsLine(p, lineWidth: lw) {
                return true
            }
        }
        return false
    }
    func intersects(_ rect: Rect) -> Bool {
        guard bounds?.intersects(rect)
                ?? false else { return false }
        for pathline in pathlines {
            if pathline.intersects(rect) {
                return true
            }
        }
        return false
    }
    func intersectsLine(_ rect: Rect) -> Bool {
        guard bounds?.intersects(rect)
                ?? false else { return false }
        for pathline in pathlines {
            if pathline.intersectsLine(rect) {
                return true
            }
        }
        return false
    }
    func intersectsLine(_ other: Path) -> Bool {
        for pathline in pathlines {
            var oldP = pathline.firstPoint
            for element in pathline.elements {
                switch element {
                case .linear(let p):
                    let edge = Edge(oldP, p)
                    for otherPathline in other.pathlines {
                        var oOldP = otherPathline.firstPoint
                        for oElement in otherPathline.elements {
                            switch oElement {
                            case .linear(let op):
                                if edge.intersects(Edge(oOldP, op)) {
                                    return true
                                }
                                oOldP = op
                            case .bezier(let op, let ocp):
                                let ob = Bezier(p0: oOldP, cp: ocp, p1: op)
                                if ob.intersects(edge){
                                    return true
                                }
                                oOldP = op
                            case .arc(let oArc):
                                if oArc.intersects(edge) {
                                    return true
                                }
                                oOldP = oArc.endPosition
                            case .line(let oLine):
                                if oLine.intersects(edge) {
                                    return true
                                }
                                oOldP = oLine.lastPoint
                            }
                        }
                    }
                    oldP = p
                case .bezier(let p, let cp):
                    let b = Bezier(p0: oldP, cp: cp, p1: p)
                    for otherPathline in other.pathlines {
                        var oOldP = otherPathline.firstPoint
                        for oElement in otherPathline.elements {
                            switch oElement {
                            case .linear(let op):
                                if b.intersects(Edge(oOldP, op)) {
                                    return true
                                }
                                oOldP = op
                            case .bezier(let op, let ocp):
                                let ob = Bezier(p0: oOldP, cp: ocp, p1: op)
                                if ob.intersects(b) {
                                    return true
                                }
                                oOldP = op
                            case .arc(let oArc):
                                if b.intersects(oArc) {
                                    return true
                                }
                                oOldP = oArc.endPosition
                            case .line(let oLine):
                                if oLine.intersects(b) {
                                    return true
                                }
                                oOldP = oLine.lastPoint
                            }
                        }
                    }
                    oldP = p
                case .arc(let arc):
                    for otherPathline in other.pathlines {
                        var oOldP = otherPathline.firstPoint
                        for oElement in otherPathline.elements {
                            switch oElement {
                            case .linear(let op):
                                if arc.intersects(Edge(oOldP, op)) {
                                    return true
                                }
                                oOldP = op
                            case .bezier(let op, let ocp):
                                let ob = Bezier(p0: oOldP, cp: ocp, p1: op)
                                if ob.intersects(arc) {
                                    return true
                                }
                                oOldP = op
                            case .arc(let oArc):
                                if oArc.intersects(arc) {
                                    return true
                                }
                                oOldP = oArc.endPosition
                            case .line(let oLine):
                                for ob in oLine.bezierSequence {
                                    if ob.intersects(arc) {
                                        return true
                                    }
                                }
                                oOldP = oLine.lastPoint
                            }
                        }
                    }
                    oldP = arc.endPosition
                case .line(let line):
                    for otherPathline in other.pathlines {
                        var oOldP = otherPathline.firstPoint
                        for oElement in otherPathline.elements {
                            switch oElement {
                            case .linear(let op):
                                if line.intersects(Edge(oOldP, op)) {
                                    return true
                                }
                                oOldP = op
                            case .bezier(let op, let ocp):
                                let ob = Bezier(p0: oOldP, cp: ocp, p1: op)
                                if line.intersects(ob) {
                                    return true
                                }
                                oOldP = op
                            case .arc(let oArc):
                                if line.intersects(oArc) {
                                    return true
                                }
                                oOldP = oArc.endPosition
                            case .line(let oLine):
                                if line.intersects(oLine) {
                                    return true
                                }
                                oOldP = oLine.lastPoint
                            }
                        }
                    }
                    oldP = line.lastPoint
                }
            }
        }
        return false
    }
    func intersects(_ other: Path) -> Bool {
        guard bounds.intersects(other.bounds) else { return false }
        for oPathline in other.pathlines {
            if contains(oPathline.firstPoint) {
                return true
            }
            for element in oPathline.elements {
                switch element {
                case .linear(let p):
                    if contains(p) {
                        return true
                    }
                case .bezier(let p, _):
                    if contains(p) {
                        return true
                    }
                case .arc(let arc):
                    if contains(arc.endPosition) {
                        return true
                    }
                case .line(let line):
                    if contains(line.firstPoint) {
                        return true
                    }
                    for b in line.bezierSequence {
                        if contains(b.p1) {
                            return true
                        }
                    }
                }
            }
        }
        for pathline in pathlines {
            if other.contains(pathline.firstPoint) {
                return true
            }
            for element in pathline.elements {
                switch element {
                case .linear(let p):
                    if other.contains(p) {
                        return true
                    }
                case .bezier(let p, _):
                    if other.contains(p) {
                        return true
                    }
                case .arc(let arc):
                    if other.contains(arc.endPosition) {
                        return true
                    }
                case .line(let line):
                    if other.contains(line.firstPoint) {
                        return true
                    }
                    for b in line.bezierSequence {
                        if other.contains(b.p1) {
                            return true
                        }
                    }
                }
            }
        }
        return intersectsLine(other)
    }
    func contains(_ other: Path) -> Bool {
        guard bounds.contains(other.bounds) else { return false }
        for oPathline in other.pathlines {
            if !contains(oPathline.firstPoint) {
                return false
            }
            for element in oPathline.elements {
                switch element {
                case .linear(let p):
                    if !contains(p) {
                        return false
                    }
                case .bezier(let p, _):
                    if !contains(p) {
                        return false
                    }
                case .arc(let arc):
                    if !contains(arc.endPosition) {
                        return false
                    }
                case .line(let line):
                    if !contains(line.firstPoint) {
                        return false
                    }
                    for b in line.bezierSequence {
                        if !contains(b.p1) {
                            return false
                        }
                    }
                }
            }
        }
        return !intersectsLine(other)
    }
}
extension Path {
    func topolygon(withQuality quality: Double = 1) -> Topolygon {
        if pathlines.isEmpty {
            return Topolygon()
        } else {
            let polygon = pathlines[0].polygon(withQuality: quality)
            let hps = pathlines[1...].map { $0.polygon(withQuality: quality)}
            return Topolygon(polygon: polygon, holePolygons: hps)
        }
    }
    func stencilFillData() -> (pointsData: [Float],
                               counts: [Int],
                               bezierCounts: [Int], aroundCounts: [Int]) {
        var points = [Float]()
        var counts = [Int](), bezierCounts = [Int](), aroundCounts = [Int]()
        
        func append(_ p: Point) {
            points.append(Float(p.x))
            points.append(Float(p.y))
            points.append(0)
            points.append(1)
        }
        func appendTriangle(p0: Point, p1: Point, p2: Point) {
            append(p0)
            append(p1)
            append(p2)
            counts.append(3)
        }
        
        var isBezier = false
        for pathline in pathlines {
            let fp = pathline.firstPoint
            var oldP = fp
            for element in pathline.elements {
                switch element {
                case .linear(let p):
                    appendTriangle(p0: fp, p1: oldP, p2: p)
                    oldP = p
                case .bezier(let p, _):
                    isBezier = true
                    appendTriangle(p0: fp, p1: oldP, p2: p)
                    oldP = p
                case .arc: break
                case .line(let line):
                    isBezier = true
                    for bezier in line.bezierSequence {
                        appendTriangle(p0: fp, p1: bezier.p0, p2: bezier.p1)
                    }
                    oldP = line.lastPoint
                }
            }
        }
        
        if isBezier {
            func appendBezier(p0: Point, cp: Point, p1: Point) {
                points.append(Float(p0.x))
                points.append(Float(p0.y))
                points.append(0)
                points.append(0)
                points.append(Float(cp.x))
                points.append(Float(cp.y))
                points.append(0.5)
                points.append(0)
                points.append(Float(p1.x))
                points.append(Float(p1.y))
                points.append(1)
                points.append(1)
                bezierCounts.append(3)
            }
            for pathline in pathlines {
                var oldP = pathline.firstPoint
                for element in pathline.elements {
                    switch element {
                    case .linear(let p):
                        oldP = p
                    case .bezier(let p, let cp):
                        appendBezier(p0: oldP, cp: cp, p1: p)
                        oldP = p
                    case .arc: break
                    case .line(let line):
                        for bezier in line.bezierSequence {
                            appendBezier(p0: bezier.p0, cp: bezier.cp,
                                         p1: bezier.p1)
                        }
                        oldP = line.lastPoint
                    }
                }
            }
        }
        
        for pathline in pathlines {
            var allPoints = [Point]()
            allPoints.append(pathline.firstPoint)
            for element in pathline.elements {
                switch element {
                case .linear(let p):
                    allPoints.append(p)
                case .bezier(let p, let cp):
                    allPoints.append(cp)
                    allPoints.append(p)
                case .arc: break
                case .line(let line):
                    for bezier in line.bezierSequence {
                        allPoints.append(bezier.cp)
                        allPoints.append(bezier.p1)
                    }
                }
            }
            let ps = Polygon(points: allPoints).convexHull.strip.points
            ps.forEach { append($0) }
            aroundCounts.append(ps.count)
        }
        
        return (points, counts, bezierCounts, aroundCounts)
    }
    func fillPointsData(withQuality quality: Double = 1) -> (pointsData: [Float],
                                                             counts: [Int]) {
        let topoly = topolygon(withQuality: quality)
        do {
            let monotonePolygons = try topoly.monotonePolygons()
            var floatPoints = [Float](), counts = [Int](), oldIndex = 0
            monotonePolygons.forEach {
                $0.floatTriangles(in: &floatPoints, counts: &counts,
                                  oldIndex: &oldIndex)
            }
            return (floatPoints, counts)
        } catch {
            guard topoly.holePolygons.isEmpty else {
                return ([], [])
            }
            let nPolygons = topoly.polygon.noIntersectedPolygons()
            var floatPoints = [Float](), counts = [Int](), oldIndex = 0
            for nPolygon in nPolygons {
                let ntopoly = Topolygon(polygon: nPolygon, holePolygons: [])
                if let mPolygons = try? ntopoly.monotonePolygons() {
                    mPolygons.forEach {
                        $0.floatTriangles(in: &floatPoints, counts: &counts,
                                          oldIndex: &oldIndex)
                    }
                }
            }
            return (floatPoints, counts)
        }
    }
    
    func fillTexturePointsData() -> [Float] {
        let bounds = self.bounds ?? Rect()
        let minX = Float(bounds.minX), maxX = Float(bounds.maxX)
        let minY = Float(bounds.minY), maxY = Float(bounds.maxY)
        let (points, counts) = fillPointsData()
        guard maxX - minX > 0 && maxY - minY > 0 else {
            return (0..<points.count).map { _ in Float(0.0) }
        }
        let count = counts.reduce(0) { $0 + $1 }
        var tPoints = [Float]()
        tPoints.reserveCapacity(points.count)
        func value(with t: Float, minT: Float, maxT: Float) -> Float {
            return (t - minT) / (maxT - minT)
        }
        (0..<count).forEach { i in
            let j = i * 4
            tPoints.append(value(with: points[j], minT: minX, maxT: maxX) / 1)
            tPoints.append(1 - value(with: points[j + 1],
                                     minT: minY, maxT: maxY) / 1)
            tPoints.append(0)
            tPoints.append(0)
        }
        return tPoints
    }
}
extension Path {
    func linePointsDataWith(quality: Double = 1,
                            lineWidth lw: Double) -> (pointsData: [Float],
                                                      counts: [Int]) {
        var points = [Float](), counts = [Int]()
        let s = lw / 2, rlw = Line.defaultLineWidth / lw
        
        func append(_ p: Point) {
            points.append(Float(p.x))
            points.append(Float(p.y))
            points.append(0)
            points.append(1)
        }
        
        func appendFirstCap(_ p: Point, angle a: Double, radius r: Double,
                            arcAngle: Double = .pi / 2) {
            append(p.movedWith(distance: r, angle: a))
            let c = r * arcAngle * 2
            let count = c.isNaN ? 4 : max(4, Int(c) * 2)
            let rCount = 1 / Double(count)
            for i in 1...count {
                let da = (Double(i) * rCount) * arcAngle
                append(p.movedWith(distance: r, angle: a + da))
                append(p.movedWith(distance: r, angle: a - da))
            }
        }
        func appendFirstCap(with fb: Bezier, _ preb: BezierInterpolation) {
            let fp = fb.p0, fa = fb.firstAngle
            let a = fa - .pi
            let fpr = preb.x0, npr = preb.cx
            let fs = s * fpr
            guard fpr < npr else {
                appendFirstCap(fp, angle: a, radius: fs)
                return
            }
            let d = fb.p0.distance(fb.cp) + fb.cp.distance(fb.p1)
            
            let arcAngle = .pi / 2 - .atan2(y: npr - fpr, x: d)
            let sinAA: Double = .sin(arcAngle)
            guard !sinAA.isApproximatelyEqual(0) else {
                appendFirstCap(fp, angle: a, radius: fs)
                return
            }
            let r = fs / sinAA
            let pd = (r * r - fs * fs).squareRoot()
            let p = fp.movedWith(distance: pd, angle: fa)
            
            appendFirstCap(p, angle: a, radius: r, arcAngle: arcAngle)
        }
        func appendFirstCap(with line: Line) {
            guard line.controls.count >= 2 else {
                let fp = line.firstPoint, fa = line.firstAngle
                let a = fa - .pi
                let fpr = line.controls[0].pressure
                let fs = s * fpr
                appendFirstCap(fp, angle: a, radius: fs)
                return
            }
            appendFirstCap(with: line.bezier(at: 0),
                           line.pressureInterpolation(at: 0))
        }
        
        func appendLastCap(_ p: Point, angle a: Double, radius r: Double,
                           arcAngle: Double = .pi / 2) {
            let c = r * arcAngle * 2
            let count = c.isNaN ? 4 : max(4, Int(c) * 2)
            let rCount = 1 / Double(count)
            for i in (1...count).reversed() {
                let da = (Double(i) * rCount) * arcAngle
                append(p.movedWith(distance: r, angle: a - da))
                append(p.movedWith(distance: r, angle: a + da))
            }
            append(p.movedWith(distance: r, angle: a))
        }
        func appendLastCap(with lb: Bezier, _ preb: BezierInterpolation) {
            let lp = lb.p1, la = lb.lastAngle
            let a = la - .pi
            let lpr = preb.x1, ppr = preb.cx
            let ls = s * lpr
            guard lpr < ppr else {
                appendLastCap(lp, angle: la, radius: ls)
                return
            }
            let d = lb.p0.distance(lb.cp) + lb.cp.distance(lb.p1)
            
            let arcAngle = .pi / 2 - .atan2(y: ppr - lpr, x: d)
            let sinAA: Double = .sin(arcAngle)
            guard !sinAA.isApproximatelyEqual(0) else {
                appendLastCap(lp, angle: la, radius: ls)
                return
            }
            let r = ls / sinAA
            let pd = (r * r - ls * ls).squareRoot()
            let p = lp.movedWith(distance: pd, angle: a)
            
            appendLastCap(p, angle: la, radius: r, arcAngle: arcAngle)
        }
        func appendLastCap(with line: Line) {
            guard line.controls.count >= 3 else {
                let lp = line.lastPoint, la = line.lastAngle
                let lpr = line.controls[.last].pressure
                let ls = s * lpr
                appendLastCap(lp, angle: la, radius: ls)
                return
            }
            let li = line.maxBezierIndex
            appendLastCap(with: line.bezier(at: li),
                          line.pressureInterpolation(at: li))
        }
        
        func appendLinear(p0: Point, p1: Point) {
            guard p0 != p1 else { return }
            let dp = (p1 - p0).perpendicularDeltaPoint(withDistance: s)
            append(p0 - dp)
            append(p0 + dp)
            append(p1 - dp)
            append(p1 + dp)
        }
        
        func appendBezier(_ bezier: Bezier) {
            guard !bezier.isLineaer else {
                appendLinear(p0: bezier.p0, p1: bezier.p1)
                return
            }
            let l = bezier.length(withFlatness: 4)
            let ll = l * 0.2
            let d = Edge(bezier.p0, bezier.p1).distance(from: bezier.cp)
            let c = l * min(1, d / ll) * quality
            let count = c.isNaN ? 2 : Int(c.clipped(min: 2, max: 20))
            let rCount = 1 / Double(count)
            for i in 0..<count {
                let t = Double(i) * rCount
                let p = bezier.position(withT: t)
                let dp = bezier.difference(withT: t)
                    .perpendicularDeltaPoint(withDistance: s)
                append(p - dp)
                append(p + dp)
            }
        }
        
        func appendLine(_ line: Line) {
            guard line.controls.count >= 3 else {
                let p0 = line.firstPoint, p1 = line.lastPoint
                guard p0 != p1 else { return }
                let fs = s * line.controls[.first].pressure
                let ls = s * line.controls[.last].pressure
                let v10 = p1 - p0
                let dp0 = v10.perpendicularDeltaPoint(withDistance: fs)
                append(p0 - dp0)
                append(p0 + dp0)
                let dp1 = v10.perpendicularDeltaPoint(withDistance: ls)
                append(p1 - dp1)
                append(p1 + dp1)
                return
            }
            
            var oldB = Bezier(), oldBI = BezierInterpolation()
            for (i, bezier) in line.bezierSequence.enumerated() {
                let preb = line.pressureInterpolation(at: i)
                
                let isFirstEqual = bezier.p0 == bezier.cp
                let isLastEqual = bezier.cp == bezier.p1
                let isPreEqual = oldB.cp == oldB.p1
                let v = isFirstEqual ?
                    bezier.p1 - bezier.p0 : bezier.cp - bezier.p0
                if i > 0 && (isPreEqual || isFirstEqual) {
                    appendLastCap(with: oldB, oldBI)
                    appendFirstCap(with: bezier, preb)
                }
                oldB = bezier
                oldBI = preb
                
                if isFirstEqual || isLastEqual {
                    let ns = s * preb.x0
                    let p = bezier.p0
                    let dp = v.perpendicularDeltaPoint(withDistance: ns)
                    append(p - dp)
                    append(p + dp)
                    continue
                }
                
                func appendB(_ bezier: Bezier, _ preb: BezierInterpolation) {
                    let da = abs(Point.differenceAngle(bezier.cp - bezier.p0,
                                                       bezier.p1 - bezier.cp))
                    func isMiniCross() -> Bool {
                        if da > .pi * 0.6 {
                            let d0 = bezier.p0.distanceSquared(bezier.cp)
                            let d1 = bezier.cp.distanceSquared(bezier.p1)
                            return (d0 / s * s < 4 * 4 || d1 / s * s < 4 * 4)
                        } else {
                            return false
                        }
                    }
                    if da > .pi * 0.9 || isMiniCross() {
                        let ns0 = s * preb.x0, ncs = s * preb.cx
                        let p0 = bezier.p0, cp = bezier.position(withT: 0.5)
                        let fa = bezier.firstAngle, la = bezier.lastAngle
                        let dp0 = Point().movedWith(distance: ns0,
                                                    angle: fa + .pi / 2)
                        append(p0 - dp0)
                        append(p0 + dp0)
                        appendLastCap(cp, angle: fa, radius: ncs)
                        appendFirstCap(cp, angle: la - .pi, radius: ncs)
                    } else {
                        let l = bezier.length(withFlatness: 4)
                        let ct = da < .pi * 0.1 ?
                            da.clipped(min: 0, max: .pi * 0.3,
                                       newMin: 0, newMax: 1.5) :
                            da.clipped(min: .pi * 0.3, max: .pi * 0.9,
                                       newMin: 1.5, newMax: 16)
                        let c = l * ct * rlw * quality
                        let count = c.isNaN ? 2 : Int(c.clipped(min: 2, max: 32))
                        let rCount = 1 / Double(count)
                        for i in 0..<count {
                            let t = Double(i) * rCount
                            let ns = s * preb.position(withT: t)
                            let p = bezier.position(withT: t)
                            let dp = bezier.difference(withT: t)
                                .perpendicularDeltaPoint(withDistance: ns)
                            append(p - dp)
                            append(p + dp)
                        }
                    }
                }
                let d0 = bezier.p0.distance(bezier.cp)
                let d1 = bezier.cp.distance(bezier.p1)
                let t0 = d0 < d1 ? d0 / d1 : d1 / d0
                if t0 < 0.35 {
                    let t = (d0 < d1 ? d0 / d1 : (d0 - d1) / d0).mid(0.5)
                    let (b0, b1) = bezier.split(withT: t)
                    let (preb0, preb1) = preb.split(withT: t)
                    appendB(b0, preb0)
                    appendB(b1, preb1)
                } else {
                    appendB(bezier, preb)
                }
            }
            let lp = line.lastPoint, lastAngle = line.lastAngle
            let lpr = line.controls[.last].pressure
            let dp = PolarPoint(s * lpr, lastAngle + .pi / 2).rectangular
            append(lp - dp)
            append(lp + dp)
        }
        
        func appendArc(_ arc: Arc) {
            let dAngle = abs(arc.endAngle - arc.startAngle)
            let c = arc.radius * dAngle * quality
            let count = c.isNaN ? 1 : max(1, Int(c))
            let rCount = 1 / Double(count)
            for i in 0..<count {
                let theta = Double.linear(arc.startAngle, arc.endAngle,
                                          t: Double(i) * rCount)
                let unitP = PolarPoint(1, theta).rectangular
                let p = arc.centerPosition + unitP * arc.radius
                let dp = arc.orientation == .clockwise ? unitP * s : -unitP * s
                append(p - dp)
                append(p + dp)
            }
        }
        
        var oldIndex = 0
        for pathline in pathlines {
            var p0 = pathline.firstPoint
            if !pathline.isClosed && isCap {
                if case .line(let line)? = pathline.elements.first,
                   p0 == line.firstPoint {
                    appendFirstCap(with: line)
                } else {
                    appendFirstCap(p0,
                                   angle: (pathline.firstAngle ?? 0) - .pi,
                                   radius: s)
                }
            }
            for element in pathline.elements {
                switch element {
                case .linear(let p1):
                    appendLinear(p0: p0, p1: p1)
                    p0 = p1
                case .bezier(let p1, let cp):
                    appendBezier(Bezier(p0: p0, cp: cp, p1: p1))
                    p0 = p1
                case .line(let line):
                    let fp = line.firstPoint
                    if p0 != fp {
                        appendLinear(p0: p0, p1: fp)
                    }
                    appendLine(line)
                    p0 = line.lastPoint
                case .arc(let arc):
                    let sp = arc.startPosition
                    if p0 != sp {
                        appendLinear(p0: p0, p1: sp)
                    }
                    appendArc(arc)
                    p0 = arc.endPosition
                }
            }
            if pathline.isClosed {
                appendLinear(p0: p0, p1: pathline.firstPoint)
                if points.count - oldIndex >= 8 {
                    points += points[oldIndex..<(8 + oldIndex)]
                }
            } else if isCap {
                if case .line(let line)? = pathline.elements.last {
                    appendLastCap(with: line)
                } else {
                    appendLastCap(p0,
                                  angle: pathline.lastAngle ?? .pi,
                                  radius: s)
                }
            }
            
            counts.append((points.count - oldIndex) / 4)
            oldIndex = points.count
        }
        return (points, counts)
    }
    func outlinePointsDataWith(quality: Double = 1,
                               lineWidth lw: Double) -> (pointsData: [Float],
                                                         counts: [Int]) {
        let (pd, counts) = linePointsDataWith(quality: quality, lineWidth: lw)
        var i = 0
        var npd = [Float](), nCounts = [Int]()
        for (pi, pathline) in pathlines.enumerated() {
            let count = counts[pi]
            if !pathline.isClosed && isCap {
                let sCount = (count - 2) / 2
                npd += pd[i..<(i + 4)]
                var j = 4
                for _ in 0..<sCount {
                    npd += pd[(i + j)..<(i + j + 4)]
                    j += 2 * 4
                }
                npd += pd[(i + count * 4 - 4)..<(i + count * 4)]
                j = (sCount - 1) * (2 * 4) + 4 + 4
                for _ in 0..<sCount {
                    npd += pd[(i + j)..<(i + j + 4)]
                    j -= 2 * 4
                }
                npd += pd[i..<(i + 4)]
                i += count * 4
                nCounts.append(count + 1)
            } else {
                let sCount = count / 2
                var j = 0
                for _ in 0..<sCount {
                    npd += pd[(i + j)..<(i + j + 4)]
                    j += 2 * 4
                }
                j = (sCount - 1) * (2 * 4) + 4
                for _ in 0..<sCount {
                    npd += pd[(i + j)..<(i + j + 4)]
                    j -= 2 * 4
                }
                npd += pd[i..<(i + 4)]
                i += count * 4
                nCounts.append(count + 1)
            }
        }
        return (npd, nCounts)
    }
    
    func lineColorsDataWith(_ colors: [Color], lineWidth lw: Double,
                            quality: Double = 1) -> [RGBA] {
        var rgbas = [RGBA](), k = 0
        let s = lw / 2, rlw = Line.defaultLineWidth / lw
        
        func append(from m: Int) {
            rgbas.append(colors[m].rgba)
        }
        func append(from m: Int, t: Double) {
            let rgba = Color.linear(colors[m - 1], colors[m], t: t).rgba
            rgbas.append(rgba)
        }
        
        func appendFirstCap(_ p: Point, angle a: Double, radius r: Double,
                            arcAngle: Double = .pi / 2,
                            at m: Int) {
            rgbas.append(colors[m].rgba)
            let c = r * arcAngle * 2
            let count = c.isNaN ? 4 : max(4, Int(c) * 2)
            for _ in 1...count {
                rgbas.append(colors[m].rgba)
                rgbas.append(colors[m].rgba)
            }
        }
        func appendFirstCap(with fb: Bezier, _ preb: BezierInterpolation,
                            at m: Int) {
            let fp = fb.p0, fa = fb.firstAngle
            let a = fa - .pi
            let fpr = preb.x0, npr = preb.cx
            let fs = s * fpr
            guard fpr < npr else {
                appendFirstCap(fp, angle: a, radius: fs, at: m)
                return
            }
            let d = fb.p0.distance(fb.cp) + fb.cp.distance(fb.p1)
            
            let arcAngle = .pi / 2 - .atan2(y: npr - fpr, x: d)
            let sinAA: Double = .sin(arcAngle)
            guard !sinAA.isApproximatelyEqual(0) else {
                appendFirstCap(fp, angle: a, radius: fs, at: m)
                return
            }
            let r = fs / sinAA
            let pd = (r * r - fs * fs).squareRoot()
            let p = fp.movedWith(distance: pd, angle: fa)
            
            appendFirstCap(p, angle: a, radius: r, arcAngle: arcAngle, at: m)
        }
        func appendFirstCap(with line: Line,
                            at m: Int) {
            guard line.controls.count >= 2 else {
                let fp = line.firstPoint, fa = line.firstAngle
                let a = fa - .pi
                let fpr = line.controls[0].pressure
                let fs = s * fpr
                appendFirstCap(fp, angle: a, radius: fs, at: m)
                return
            }
            appendFirstCap(with: line.bezier(at: 0),
                           line.pressureInterpolation(at: 0), at: m)
        }
        
        func appendLastCap(_ p: Point, angle a: Double, radius r: Double,
                           arcAngle: Double = .pi / 2,
                           at m: Int) {
            let c = r * arcAngle * 2
            let count = c.isNaN ? 4 : max(4, Int(c) * 2)
            for _ in (1...count).reversed() {
                rgbas.append(colors[m].rgba)
                rgbas.append(colors[m].rgba)
            }
            rgbas.append(colors[m].rgba)
        }
        func appendLastCap(with lb: Bezier, _ preb: BezierInterpolation,
                           at m: Int) {
            let lp = lb.p1, la = lb.lastAngle
            let a = la - .pi
            let lpr = preb.x1, ppr = preb.cx
            let ls = s * lpr
            guard lpr < ppr else {
                appendLastCap(lp, angle: la, radius: ls, at: m)
                return
            }
            let d = lb.p0.distance(lb.cp) + lb.cp.distance(lb.p1)
            
            let arcAngle = .pi / 2 - .atan2(y: ppr - lpr, x: d)
            let sinAA: Double = .sin(arcAngle)
            guard !sinAA.isApproximatelyEqual(0) else {
                appendLastCap(lp, angle: la, radius: ls, at: m)
                return
            }
            let r = ls / sinAA
            let pd = (r * r - ls * ls).squareRoot()
            let p = lp.movedWith(distance: pd, angle: a)
            
            appendLastCap(p, angle: la, radius: r, arcAngle: arcAngle, at: m)
        }
        func appendLastCap(with line: Line,
                           at m: Int) {
            guard line.controls.count >= 3 else {
                let lp = line.lastPoint, la = line.lastAngle
                let lpr = line.controls[.last].pressure
                let ls = s * lpr
                appendLastCap(lp, angle: la, radius: ls, at: m)
                return
            }
            let li = line.maxBezierIndex
            appendLastCap(with: line.bezier(at: li),
                          line.pressureInterpolation(at: li), at: m)
        }
        
        func appendLinear(p0: Point, p1: Point) {
            guard p0 != p1 else { return }
            append(from: k - 1)
            append(from: k - 1)
            append(from: k)
            append(from: k)
            k += 1
        }
        
        func appendBezier(_ bezier: Bezier) {
            guard !bezier.isLineaer else {
                appendLinear(p0: bezier.p0, p1: bezier.p1)
                return
            }
            let l = bezier.length(withFlatness: 4)
            let ll = l * 0.2
            let d = Edge(bezier.p0, bezier.p1).distance(from: bezier.cp)
            let c = l * min(1, d / ll) * quality
            let count = c.isNaN ? 2 : Int(c.clipped(min: 2, max: 20))
            let rCount = 1 / Double(count)
            for i in 0..<count {
                let t = Double(i) * rCount
                append(from: k, t: t)
                append(from: k, t: t)
            }
            k += 1
        }
        
        func appendLine(_ line: Line) {
            guard line.controls.count >= 3 else {
                let p0 = line.firstPoint, p1 = line.lastPoint
                guard p0 != p1 else { return }
                append(from: k - 1)
                append(from: k - 1)
                append(from: k)
                append(from: k)
                k += 1
                return
            }
            
            var oldB = Bezier(), oldBI = BezierInterpolation()
            for (i, bezier) in line.bezierSequence.enumerated() {
                let preb = line.pressureInterpolation(at: i)
                
                let isFirstEqual = bezier.p0 == bezier.cp
                let isLastEqual = bezier.cp == bezier.p1
                let isPreEqual = oldB.cp == oldB.p1
                if i > 0 && (isPreEqual || isFirstEqual) {
                    appendLastCap(with: oldB, oldBI, at: k - 1)
                    appendFirstCap(with: bezier, preb, at: k - 1)
                }
                oldB = bezier
                oldBI = preb
                
                if isFirstEqual || isLastEqual {
                    append(from: k - 1)
                    append(from: k - 1)
                    continue
                }
                
                func appendB(_ bezier: Bezier, _ preb: BezierInterpolation,
                             preT: Double, nextT: Double) {
                    let da = abs(Point.differenceAngle(bezier.cp - bezier.p0,
                                                       bezier.p1 - bezier.cp))
                    func isMiniCross() -> Bool {
                        if da > .pi * 0.6 {
                            let d0 = bezier.p0.distanceSquared(bezier.cp)
                            let d1 = bezier.cp.distanceSquared(bezier.p1)
                            return (d0 / s * s < 4 * 4 || d1 / s * s < 4 * 4)
                        } else {
                            return false
                        }
                    }
                    if da > .pi * 0.9 || isMiniCross() {
                        let ncs = s * preb.cx
                        let cp = bezier.position(withT: 0.5)
                        let fa = bezier.firstAngle, la = bezier.lastAngle
                        append(from: k - 1)
                        append(from: k - 1)
                        appendLastCap(cp, angle: fa, radius: ncs,
                                      at: k - 1)
                        appendFirstCap(cp, angle: la - .pi, radius: ncs,
                                       at: k - 1)
                    } else {
                        let l = bezier.length(withFlatness: 4)
                        let ct = da < .pi * 0.1 ?
                            da.clipped(min: 0, max: .pi * 0.3,
                                       newMin: 0, newMax: 1.5) :
                            da.clipped(min: .pi * 0.3, max: .pi * 0.9,
                                       newMin: 1.5, newMax: 16)
                        let c = l * ct * rlw * quality
                        let count = c.isNaN ? 2 : Int(c.clipped(min: 2, max: 32))
                        let rCount = 1 / Double(count)
                        for i in 0..<count {
                            let t = Double.linear(preT, nextT,
                                                  t: Double(i) * rCount)
                            append(from: k, t: t)
                            append(from: k, t: t)
                        }
                    }
                }
                let d0 = bezier.p0.distance(bezier.cp)
                let d1 = bezier.cp.distance(bezier.p1)
                let t0 = d0 < d1 ? d0 / d1 : d1 / d0
                if t0 < 0.35 {
                    let t = (d0 < d1 ? d0 / d1 : (d0 - d1) / d0).mid(0.5)
                    let (b0, b1) = bezier.split(withT: t)
                    let (preb0, preb1) = preb.split(withT: t)
                    appendB(b0, preb0, preT: 0, nextT: t)
                    appendB(b1, preb1, preT: t, nextT: 1)
                } else {
                    appendB(bezier, preb, preT: 0, nextT: 1)
                }
                k += 1
            }
            append(from: k)
            append(from: k)
            
            k += 1
        }
        
        func appendArc(_ arc: Arc) {
            let dAngle = abs(arc.endAngle - arc.startAngle)
            let c = arc.radius * dAngle * quality
            let count = c.isNaN ? 1 : max(1, Int(c))
            let rCount = 1 / Double(count)
            for i in 0..<count {
                let t = Double(i) * rCount
                append(from: k, t: t)
                append(from: k, t: t)
            }
            k += 1
        }
        
        for pathline in pathlines {
            let fk = k
            var p0 = pathline.firstPoint
            if !pathline.isClosed && isCap {
                if case .line(let line)? = pathline.elements.first,
                   p0 == line.firstPoint {
                    appendFirstCap(with: line,
                                   at: 0)
                } else {
                    appendFirstCap(p0,
                                   angle: (pathline.firstAngle ?? 0) - .pi,
                                   radius: s,
                                   at: 0)
                }
            }
            k += 1
            for element in pathline.elements {
                switch element {
                case .linear(let p1):
                    appendLinear(p0: p0, p1: p1)
                    p0 = p1
                case .bezier(let p1, let cp):
                    appendBezier(Bezier(p0: p0, cp: cp, p1: p1))
                    p0 = p1
                case .line(let line):
                    let fp = line.firstPoint
                    if p0 != fp {
                        appendLinear(p0: p0, p1: fp)
                    }
                    appendLine(line)
                    p0 = line.lastPoint
                case .arc(let arc):
                    let sp = arc.startPosition
                    if p0 != sp {
                        appendLinear(p0: p0, p1: sp)
                    }
                    appendArc(arc)
                    p0 = arc.endPosition
                }
            }
            if pathline.isClosed {
                append(from: k - 1)
                append(from: k - 1)
                append(from: fk)
                append(from: fk)
                
                append(from: fk)
                append(from: fk)
            } else if isCap {
                if case .line(let line)? = pathline.elements.last {
                    appendLastCap(with: line, at: k - 1)
                } else {
                    appendLastCap(p0,
                                  angle: pathline.lastAngle ?? .pi,
                                  radius: s, at: k - 1)
                }
            }
        }
        
        return rgbas
    }
}
