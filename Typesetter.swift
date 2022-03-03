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

enum Alignment {
    case left, center, right, natural, justified
}

struct Typobute {
    static let minWidthCount = 4.0
    static let defaultWidthCount = 19.0
    static let maxWidthCount = 40.0
    
    var font = Font.default,
        maxTypelineWidth = Font.defaultSize * maxWidthCount,
        clippedMaxTypelineWidth = Font.defaultSize * maxWidthCount,
        alignment = Alignment.natural,
        orientation = Orientation.horizontal
}

struct Indent {
    var firstIndex, lastIndex: String.Index,
        offsetIndex: String.Index,
        isTabstop = false
}

struct Typesetter {
    let string: String,
        typobute: Typobute,
        typelines: [Typeline],
        typelineSpacing: Double,
        indents: [Indent],
        typoBounds: Rect?,
        spacingTypoBounds: Rect?
    
    init(string: String = "", typobute: Typobute) {
        self.string = string
        self.typobute = typobute
        (typelines, typelineSpacing)
            = Typesetter.typelineAndSpacingWith(string: string,
                                                typobute: typobute)
        indents = Typesetter.indents(with: string, typelines: typelines)
        typoBounds = Typesetter.typoBounds(with: typelines, with: typobute)
        
        if let typoBounds = typoBounds,
           let fl = typelines.first, let ll = typelines.last {
            switch typobute.orientation {
            case .horizontal:
                spacingTypoBounds = typoBounds
                    .outsetBy(dx: typobute.font.size, dy: 0)
                    .outset(by: fl.spacing / 2, .top)
                    .outset(by: ll.spacing / 2, .bottom)
            case .vertical:
                spacingTypoBounds = typoBounds
                    .outsetBy(dx: 0, dy: typobute.font.size)
                    .outset(by: fl.spacing / 2, .right)
                    .outset(by: ll.spacing / 2, .left)
            }
        } else {
            spacingTypoBounds = nil
        }
    }
}
extension Typesetter {
    var isEmpty: Bool {
        typelines.isEmpty
    }
    func paddingSize(from typeline: Typeline) -> Size {
        switch typobute.orientation {
        case .horizontal:
            return Size(width: typobute.font.size,
                        height: typeline.spacing / 2)
        case .vertical:
            return Size(width: typeline.spacing / 2,
                        height: typobute.font.size)
        }
    }
    func halfPaddingSize(from typeline: Typeline) -> Size {
        switch typobute.orientation {
        case .horizontal:
            return Size(width: typobute.font.size / 2,
                        height: typeline.spacing / 2)
        case .vertical:
            return Size(width: typeline.spacing / 2,
                        height: typobute.font.size / 2)
        }
    }
    func spacingSize(from typeline: Typeline) -> Size {
        switch typobute.orientation {
        case .horizontal:
            return Size(width: 0,
                        height: typeline.spacing / 2)
        case .vertical:
            return Size(width: typeline.spacing / 2,
                        height: 0)
        }
    }
}
extension Typesetter {
    static func indents(with string: String,
                        typelines: [Typeline]) -> [Indent] {
        var vs = [(i: Int, ti: String.Index, li: Int)]()
        var tsvs = [(i: Double, ti: String.Index, li: Int)]()
        for (tli, typeline) in typelines.enumerated() {
            var j = 0, minI = typeline.range.lowerBound, ni: String.Index?
            var nsi = typeline.range.lowerBound
            typelinesLoop: while nsi < typeline.range.upperBound {
                let c = string[nsi]
                switch c {
                case "\t": j += 8
                default:
                    minI = nsi
                    ni = nsi
                    break typelinesLoop
                }
                nsi = string.index(after: nsi)
            }
            if j != 0 && ni == nil {
                ni = typeline.range.upperBound
                minI = typeline.range.upperBound
            }
            if let ni = ni {
                if typeline.range.lowerBound == minI {
                    vs.append((0, ni, tli))
                } else {
                    vs.append((j, ni, tli))
                }
            }
            
            if minI < typeline.range.upperBound {
                let nextI = string.index(after: minI)
                if nextI < typeline.range.upperBound {
                    var isTab = false
                    var nsk = nextI
                    while nsk < typeline.range.upperBound {
                        switch string[nsk] {
                        case "\t": isTab = true
                        default:
                            if isTab {
                                if typeline.range.lowerBound == nsk {
                                    tsvs.append((0, nsk, tli))
                                } else {
                                    let nj = typeline.characterOffset(at: nsk)
                                        .rounded(decimalPlaces: 10)
                                    tsvs.append((nj, nsk, tli))
                                }
                                isTab = false
                            }
                        }
                        nsk = string.index(after: nsk)
                    }
                    if isTab {
                        let nsk = typeline.range.upperBound
                        if typeline.range.lowerBound == nsk {
                            tsvs.append((0, nsk, tli))
                        } else {
                            let nj = typeline.characterOffset(at: nsk)
                                .rounded(decimalPlaces: 10)
                            tsvs.append((nj, nsk, tli))
                        }
                    }
                }
            }
        }
        
        guard !vs.isEmpty || !tsvs.isEmpty else { return [] }
        
        var nvs = [Indent]()
        var ls = Array(repeating: false, count: typelines.count + 1)
        if !vs.isEmpty {
            let lis = vs.reduce(into: Set<Int>()) {
                if $1.i > 0 {
                    $0.insert($1.i)
                }
            }
            
            for li in lis {
                let ns = vs.split { li > $0.i }
                for n in ns {
                    if let tsi = n.first, let tei = n.last,
                       let minIV = n.min(by: { $0.i < $1.i }),
                       minIV.i == li {
                        
                        nvs.append(Indent(firstIndex: tsi.ti, lastIndex: tei.ti,
                                          offsetIndex: minIV.ti))
                        ls[tsi.li] = true
                        ls[tei.li + 1] = true
                    }
                }
            }
        }
        
        if !tsvs.isEmpty {
            let tslis = tsvs.reduce(into: Set<Double>()) {
                if $1.i > 0 {
                    $0.insert($1.i)
                }
            }
            for li in tslis {
                let ns = tsvs.filter { li == $0.i }
                guard var preTI = ns.first?.ti else { continue }
                var preLI: Int?, si: String.Index?
                for n in ns {
                    if let npreLI = preLI, let nsi = si {
                        if n.li - npreLI != 1 || ls[n.li] {
                            nvs.append(Indent(firstIndex: nsi, lastIndex: preTI,
                                              offsetIndex: nsi, isTabstop: true))
                            si = n.ti
                        }
                    } else {
                        si = n.ti
                    }
                    preLI = n.li
                    preTI = n.ti
                }
                if let nsi = si {
                    nvs.append(Indent(firstIndex: nsi, lastIndex: preTI,
                                      offsetIndex: nsi, isTabstop: true))
                }
            }
        }
        
        return nvs
    }
    static func typoBounds(with typelines: [Typeline],
                           with typobute: Typobute) -> Rect? {
        if let typeline = typelines.last, typeline.isLastReturnEnd {
            let lastB: Rect
            let d = typobute.font.size + typeline.spacing
            switch typobute.orientation {
            case .horizontal:
                lastB = Rect(x: typeline.origin.x,
                             y: typeline.origin.y - d,
                             width: 0, height: typobute.font.size)
            case .vertical:
                lastB = Rect(x: typeline.origin.x - d,
                             y: typeline.origin.y,
                             width: typobute.font.size, height: 0)
            }
            return typelines.reduce(into: lastB) { $0 += $1.frame }
        } else {
            return typelines.reduce(into: Rect?.none) { $0 += $1.frame }
        }
    }
}
extension Typesetter {
    func typeline(for point: Point) -> Typeline? {
        typelines.first {
            $0.frame
                .outset(by: paddingSize(from: $0))
                .contains(point)
        }
    }
    func typelineIndex(for point: Point) -> Int? {
        typelines.firstIndex {
            $0.frame
                .outset(by: paddingSize(from: $0))
                .contains(point)
        }
    }
    func typeline(at i: String.Index) -> Typeline? {
        if let ti = typelineIndex(at: i) {
            return typelines[ti]
        } else {
            return nil
        }
    }
    
    func isWarp(at si: String.Index) -> Bool {
        guard let i = typelineIndex(at: si) else { return false }
        return si == typelines[i].range.lowerBound
            && i > 0 && !typelines[i - 1].isReturnEnd
    }
    func warpCursorOffset(at p: Point) -> (offset: Double,
                                           isWarp: Bool, isLastWarp: Bool)? {
        guard let ti = typelineIndex(for: p) else { return nil }
        let typeline = typelines[ti]
        guard let nsi = typeline.characterMainIndex(for: p, padding: typobute.font.size, from: self),
              let x0 = typeline.characterOffsetUsingLast(at: nsi) else { return nil }
        if nsi == typeline.range.lowerBound
            && ti > 0 && !typelines[ti - 1].isReturnEnd,
           let _ = typelines[ti - 1].characterOffsetUsingLast(at: nsi) {
            
            return (x0, true, false)
        } else {
            let isWarp = !typeline.isReturnEnd
                && ti < typelines.count - 1
                && nsi == typeline.range.upperBound
            if isWarp {
                return (x0, true, true)
            } else {
                return (x0, false, false)
            }
        }
    }
    func warpCursorPosition(at p: Point) -> (cp0: Point, cp1: Point?,
                                             isWarp: Bool, isLastWarp: Bool)? {
        guard let si = characterIndex(for: p),
              let cr = characterRatio(for: p),
              let ti = typelineIndex(for: p) else { return nil }
        let typeline = typelines[ti]
        guard let nsi = typeline.characterMainIndex(for: p, padding: typobute.font.size, from: self),
              let cp0 = typeline.characterPositionUsingLast(at: nsi) else { return nil }
        if nsi == typeline.range.lowerBound
            && ti > 0 && !typelines[ti - 1].isReturnEnd,
           let cp1 = typelines[ti - 1].characterPositionUsingLast(at: nsi) {
            
            return (cp1, cp0, true, false)
        } else {
            let isWarp = !typeline.isReturnEnd
                && ti < typelines.count - 1
                && nsi == typeline.range.upperBound
            if isWarp {
                let sri = cr > 0.5 ? index(after: si) : si
                let cp1 = characterPosition(at: sri)
                return (cp0, cp1, true, true)
            } else {
                return (cp0, nil, false, false)
            }
        }
    }
    
    func intersects(_ rect: Rect) -> Bool {
        typelines.contains {
            $0.frame
                .outset(by: paddingSize(from: $0))
                .intersects(rect)
        }
    }
    func intersectsHalf(_ rect: Rect) -> Bool {
        typelines.contains {
            $0.frame
                .outset(by: halfPaddingSize(from: $0))
                .intersects(rect)
        }
    }
    
    func containsFirst(_ p: Point, offset: Double) -> Bool {
        guard let typeline = typelines.first else { return false }
        switch typobute.orientation {
        case .horizontal:
            return typeline.frame.outset(by: offset, .top).contains(p)
        case .vertical:
            return typeline.frame.outset(by: offset, .right).contains(p)
        }
    }
    func containsLast(_ p: Point, offset: Double) -> Bool {
        guard let typeline = typelines.last else { return false }
        switch typobute.orientation {
        case .horizontal:
            return typeline.frame.outset(by: offset, .bottom).contains(p)
        case .vertical:
            return typeline.frame.outset(by: offset, .left).contains(p)
        }
    }
    func firstEdge(offset: Double) -> Edge {
        firstEdge(from: typelines.first!, offset: offset)
    }
    func firstEdge(from typeline: Typeline, offset: Double) -> Edge {
        switch typobute.orientation {
        case .horizontal: return typeline.frame.outset(by: offset, .top).topEdge
        case .vertical: return typeline.frame.outset(by: offset, .right).rightEdge
        }
    }
    func lastEdge(offset: Double) -> Edge {
        lastEdge(from: typelines.last!, offset: offset)
    }
    func lastEdge(from typeline: Typeline, offset: Double) -> Edge {
        switch typobute.orientation {
        case .horizontal: return typeline.frame.outset(by: offset, .bottom).bottomEdge
        case .vertical: return typeline.frame.outset(by: offset, .left).leftEdge
        }
    }
    var width: Double {
        switch typobute.orientation {
        case .horizontal: return typoBounds?.width ?? 0
        case .vertical: return typoBounds?.height ?? 0
        }
    }
    var height: Double {
        switch typobute.orientation {
        case .horizontal: return typoBounds?.height ?? 0
        case .vertical: return typoBounds?.width ?? 0
        }
    }
    func isFirst(at i: String.Index) -> Bool {
        guard let tl = typeline(at: i) else { return false }
        return tl.range.lowerBound == i
    }
    func isLast(at i: String.Index) -> Bool {
        guard let tl = typeline(at: i) else { return false }
        return !tl.isReturnEnd ?
            tl.range.upperBound == i :
            string.startIndex < tl.range.upperBound
            && string.index(before: tl.range.upperBound) == i
    }
    
    func characterIndexWithOutOfBounds(for point: Point) -> String.Index? {
        if let i = characterIndex(for: point, isHalfPadding: true),
           let cr = characterRatio(for: point, isHalfPadding: true) {
            return cr > 0.5 ? string.index(after: i) : i
        }
        guard !typelines.isEmpty else { return nil }
        switch typobute.orientation {
        case .horizontal:
            for typeline in typelines {
                let frame = typeline.frame
                    .outset(by: halfPaddingSize(from: typeline))
                if point.y > frame.minY {
                    if point.y > frame.maxY
                        || point.x < frame.minX {
                        
                        return typeline.range.lowerBound
                    } else {
                        return typeline.isReturnEnd ?
                            string.index(before: typeline.range.upperBound) :
                            typeline.range.upperBound
                    }
                }
            }
        case .vertical:
            for typeline in typelines {
                let frame = typeline.frame
                    .outset(by: halfPaddingSize(from: typeline))
                if point.x > frame.minX {
                    if point.x > frame.maxX
                        || point.y > frame.maxY {
                        
                        return typeline.range.lowerBound
                    } else {
                        return typeline.isReturnEnd ?
                            string.index(before: typeline.range.upperBound) :
                            typeline.range.upperBound
                    }
                }
            }
        }
        return typelines.last!.range.upperBound
    }
    
    var lastBounds: Rect? {
        if let typeline = typelines.last, !typeline.isLastReturnEnd {
            return typeline.lastTypoBounds() + typeline.origin
        } else{
            return lastReturnBounds
        }
    }
    var firstEditReturnBounds: Rect? {
        switch typobute.orientation {
        case .horizontal:
            if let typeline = typelines.first {
                let font = typobute.font
                let d = typobute.font.size + typeline.spacing
                let p = Point(typeline.origin.x, typeline.origin.y + d)
                return Rect(x: p.x, y: p.y - font.size / 2,
                            width: 0, height: font.size)
            }
            return nil
        case .vertical:
            if let typeline = typelines.first {
                let font = typobute.font
                let d = typobute.font.size + typeline.spacing
                let p = Point(typeline.origin.x + d, typeline.origin.y)
                return Rect(x: p.x - font.size / 2, y: p.y,
                            width: font.size, height: 0)
            }
            return nil
        }
    }
    var lastEditReturnBounds: Rect? {
        switch typobute.orientation {
        case .horizontal:
            if let typeline = typelines.last {
                let font = typobute.font
                let d = typobute.font.size + typeline.spacing
                let p = Point(typeline.origin.x, typeline.origin.y - d)
                return Rect(x: p.x, y: p.y - font.size / 2,
                            width: 0, height: font.size)
            }
            return nil
        case .vertical:
            if let typeline = typelines.last {
                let font = typobute.font
                let d = typobute.font.size + typeline.spacing
                let p = Point(typeline.origin.x - d, typeline.origin.y)
                return Rect(x: p.x - font.size / 2, y: p.y,
                            width: font.size, height: 0)
            }
            return nil
        }
    }
    var lastReturnBounds: Rect? {
        switch typobute.orientation {
        case .horizontal:
            if let typeline = typelines.last, typeline.isLastReturnEnd {
                let font = typobute.font
                let d = typobute.font.size + typeline.spacing
                let p = Point(typeline.origin.x, typeline.origin.y - d)
                return Rect(x: p.x, y: p.y - font.size / 2,
                            width: 0, height: font.size)
            }
            return nil
        case .vertical:
            if let typeline = typelines.last, typeline.isLastReturnEnd {
                let font = typobute.font
                let d = typobute.font.size + typeline.spacing
                let p = Point(typeline.origin.x - d, typeline.origin.y)
                return Rect(x: p.x - font.size / 2, y: p.y,
                            width: font.size, height: 0)
            }
            return nil
        }
    }
    
    func characterIndex(for point: Point,
                        isHalfPadding: Bool = false) -> String.Index? {
        guard let typeline = self.typeline(for: point) else {
            switch typobute.orientation {
            case .horizontal:
                if let typeline = typelines.last, typeline.isLastReturnEnd {
                    let font = typobute.font
                    let d = typobute.font.size + typeline.spacing
                    let p = Point(typeline.origin.x, typeline.origin.y - d)
                    let frame = Rect(x: p.x, y: p.y - font.size / 2,
                                     width: 0, height: font.size)
                        .outset(by: isHalfPadding ?
                                    halfPaddingSize(from: typeline) :
                                    paddingSize(from: typeline))
                    if frame.contains(point) {
                        return typeline.range.upperBound
                    }
                }
                return nil
            case .vertical:
                if let typeline = typelines.last, typeline.isLastReturnEnd {
                    let font = typobute.font
                    let d = typobute.font.size + typeline.spacing
                    let p = Point(typeline.origin.x - d, typeline.origin.y)
                    let frame = Rect(x: p.x - font.size / 2, y: p.y,
                                 width: font.size, height: 0)
                        .outset(by: isHalfPadding ?
                                    halfPaddingSize(from: typeline) :
                                    paddingSize(from: typeline))
                    if frame.contains(point) {
                        return typeline.range.upperBound
                    }
                }
                return nil
            }
        }
        let padding = isHalfPadding ? typobute.font.size / 2 : typobute.font.size
        return typeline.characterIndex(for: point - typeline.origin,
                                       padding: padding)
    }
    
    func characterRatio(for point: Point,
                        isHalfPadding: Bool = false) -> Double? {
        guard let typeline = self.typeline(for: point) else {
            switch typobute.orientation {
            case .horizontal:
                if let typeline = typelines.last, typeline.isLastReturnEnd {
                    let font = typobute.font
                    let d = typobute.font.size + typeline.spacing
                    let p = Point(typeline.origin.x, typeline.origin.y - d)
                    let frame = Rect(x: p.x, y: p.y - font.size / 2,
                                     width: 0, height: font.size)
                        .outset(by: isHalfPadding ?
                                    halfPaddingSize(from: typeline) :
                                    paddingSize(from: typeline))
                    if frame.contains(point) {
                        return 0
                    }
                }
                return nil
            case .vertical:
                if let typeline = typelines.last, typeline.isLastReturnEnd {
                    let font = typobute.font
                    let d = typobute.font.size + typeline.spacing
                    let p = Point(typeline.origin.x - d, typeline.origin.y)
                    let frame = Rect(x: p.x - font.size / 2, y: p.y,
                                     width: font.size, height: 0)
                        .outset(by: isHalfPadding ?
                                    halfPaddingSize(from: typeline) :
                                    paddingSize(from: typeline))
                    if frame.contains(point) {
                        return 0
                    }
                }
                return nil
            }
        }
        let padding = isHalfPadding ? typobute.font.size / 2 : typobute.font.size
        return typeline.characterRatio(for: point - typeline.origin,
                                       padding: padding)
    }
    
    func characterAdvance(at i: String.Index) -> Double {
        for typeline in typelines {
            if typeline.range.contains(i) {
               return typeline.characterAdvance(at: i)
            }
        }
        return 0
    }
    func characterOffset(at i: String.Index) -> Double {
        for typeline in typelines {
            if typeline.range.contains(i) {
               return typeline.characterOffset(at: i)
            }
        }
        if let typeline = typelines.last {
            if !typeline.isLastReturnEnd && i == typeline.range.upperBound {
                return typeline.characterOffset(at: i)
            }
        }
        return 0
    }
    
    func characterPosition(at i: String.Index) -> Point {
        for typeline in typelines {
            if let p = typeline.characterPosition(at: i) {
                return p
            }
        }
        switch typobute.orientation {
        case .horizontal:
            if let typeline = typelines.last {
                if typeline.isLastReturnEnd && i == typeline.range.upperBound {
                    let d = typobute.font.size + typeline.spacing
                    return Point(typeline.origin.x, typeline.origin.y - d)
                } else {
                    let li = typeline.range.upperBound
                    let x = typeline.characterOffset(at: li)
                    return Point(x + typeline.origin.x, typeline.origin.y)
                }
            } else {
                return Point()
            }
        case .vertical:
            if let typeline = typelines.last {
                if typeline.isLastReturnEnd && i == typeline.range.upperBound {
                    let d = typobute.font.size + typeline.spacing
                    return Point(typeline.origin.x - d, typeline.origin.y)
                } else {
                    let li = typeline.range.upperBound
                    let y = typeline.characterOffset(at: li)
                    return Point(typeline.origin.x, typeline.origin.y - y)
                }
            } else {
                return Point()
            }
        }
    }
    
    func characterBasePosition(at i: String.Index) -> Point {
        if let li = typelineIndex(at: i) {
            return characterPosition(at: i) + typelines[li].baseDeltaOrigin
        } else {
            return Point()
        }
    }
    
    func characterBounds(at i: String.Index) -> Rect? {
        for typeline in typelines {
            let ei = string.index(after: i)
            if let bounds = typeline.typoBounds(for: i..<ei) {
                return Rect(origin: typeline.origin + bounds.origin,
                            size: bounds.size)
            }
        }
        return nil
    }
    
    func typelineIndex(at i: String.Index) -> Int? {
        guard !typelines.isEmpty else { return nil }
        for (li, typeline) in typelines.enumerated() {
            if typeline.range.contains(i) {
                return li
            }
        }
        if let typeline = typelines.last {
            if !typeline.isLastReturnEnd && i == typeline.range.upperBound {
                return typelines.count - 1
            }
        }
        return nil
    }
    
    func isFirstOrLast(at i: String.Index) -> Bool {
        for typeline in typelines {
            if i == typeline.range.lowerBound
                || i == typeline.range.upperBound {
                
                return true
            }
        }
        return false
    }
    
    func cursorBounds(at i: String.Index,
                      halfWidth l: Double = 1,
                      heightRatio hr: Double = 1.0) -> Rect {
        let p = characterPosition(at: i)
        let font = typobute.font
        let d = l * typobute.font.size / Font.defaultSize
        switch typobute.orientation {
        case .horizontal:
            return Rect(x: p.x - d, y: p.y - font.size / 2 * hr - d,
                        width: d * 2, height: font.size * hr + d * 2)
        case .vertical:
            return Rect(x: p.x - font.size / 2 * hr - d, y: p.y - d,
                        width: font.size * hr + d * 2, height: d * 2)
        }
    }
    func cursorPath(at i: String.Index,
                    halfWidth l: Double = 1,
                    warpWidth ww: Double = 2,
                    heightRatio hr: Double = 1.0) -> Path {
        let p = characterPosition(at: i)
        let hd = typobute.font.size / 2 * hr
        let d = l * typobute.font.size / Font.defaultSize
        let wd = ww * typobute.font.size / Font.defaultSize
        switch typobute.orientation {
        case .horizontal:
            if isWarp(at: i) {
                return Path([Pathline([Point(p.x - d, p.y - hd - d),
                                       Point(p.x + d, p.y - hd - d),
                                       Point(p.x + d, p.y + hd + d),
                                       Point(p.x - d, p.y + hd + d),
                                       Point(p.x - d, p.y + d),
                                       Point(p.x - d - wd, p.y + d),
                                       Point(p.x - d - wd, p.y - d),
                                       Point(p.x - d, p.y - d)],
                                      isClosed: true)])
            } else {
                return Path(Rect(x: p.x - d, y: p.y - hd - d,
                                 width: d * 2, height: hd * 2 + d * 2))
            }
        case .vertical:
            if isWarp(at: i) {
                return Path([Pathline([Point(p.x - hd - d, p.y - d),
                                       Point(p.x + hd + d, p.y - d),
                                       Point(p.x + hd + d, p.y + d),
                                       Point(p.x + d, p.y + d),
                                       Point(p.x + d, p.y + wd + d),
                                       Point(p.x - d, p.y + wd + d),
                                       Point(p.x - d, p.y + d),
                                       Point(p.x - hd - d, p.y + d)],
                                      isClosed: true)])
            } else {
                return Path(Rect(x: p.x - hd - d, y: p.y - d,
                                 width: hd * 2 + d * 2, height: d * 2))
            }
        }
    }
    func warpCursorPath(at op: Point,
                        heightRatio hr: Double = 1.0) -> Path? {
        guard let result = warpCursorPosition(at: op),
              result.isLastWarp else { return nil }
        let p = result.cp0
        let hd = typobute.font.size / 2 * hr
        var pathlines = [Pathline]()
        switch typobute.orientation {
        case .horizontal:
            pathlines.append(Pathline(Edge(Point(p.x, p.y - hd),
                                           Point(p.x, p.y + hd))))
        case .vertical:
            pathlines.append(Pathline(Edge(Point(p.x - hd, p.y),
                                           Point(p.x + hd, p.y))))
        }
        return Path(pathlines, isCap: false)
    }
    
    func typoBounds(for range: Range<String.Index>) -> Rect? {
        let rect = typelines.reduce(into: Rect?.none) {
            if let bounds = $1.typoBounds(for: range) {
                $0 += Rect(origin: $1.origin + bounds.origin,
                           size: bounds.size)
            }
        }
        if let typeline = typelines.last,
           range.lowerBound == typeline.range.upperBound
            || range.upperBound == typeline.range.upperBound {
            
            return rect + lastBounds
        }
        return rect
    }
    func firstRect(for range: Range<String.Index>) -> Rect? {
        for typeline in typelines {
            if let bounds = typeline.typoBounds(for: range) {
                return Rect(origin: typeline.origin + bounds.origin,
                            size: bounds.size)
            }
        }
        if let typeline = typelines.last,
           range.isEmpty && range.lowerBound == typeline.range.upperBound {
            
            return lastBounds
        }
        return nil
    }
    
    func allRects() -> [Rect] {
        rects(for: string.startIndex..<string.endIndex)
    }
    func rects(for range: Range<String.Index>) -> [Rect] {
        let rects: [Rect] = typelines.compactMap {
            if let bounds = $0.typoBounds(for: range) {
                return Rect(origin: $0.origin + bounds.origin,
                            size: bounds.size)
            } else {
                return nil
            }
        }
        if let typeline = typelines.last {
            if range.isEmpty && range.lowerBound == typeline.range.upperBound,
               let lb = lastBounds {
                
                return rects + [lb]
            } else if typeline.isLastReturnEnd
                        && range.upperBound == typeline.range.upperBound,
                      let lb = lastReturnBounds {
                
                return rects + [lb]
            }
        }
        return rects
    }
    func allPaddingRects() -> [Rect] {
        paddingRects(for: string.startIndex..<string.endIndex)
    }
    func paddingRects(for range: Range<String.Index>) -> [Rect] {
        let rects: [Rect] = typelines.compactMap {
            if let bounds = $0.typoBounds(for: range) {
                return Rect(origin: $0.origin + bounds.origin,
                            size: bounds.size).outset(by: spacingSize(from: $0))
            } else {
                return nil
            }
        }
        if let typeline = typelines.last {
            if range.isEmpty && range.lowerBound == typeline.range.upperBound,
               let lb = lastBounds {
                
                return rects + [lb.outset(by: spacingSize(from: typeline))]
            } else if typeline.isLastReturnEnd
                        && range.upperBound == typeline.range.upperBound,
                      let lb = lastReturnBounds {
                
                return rects + [lb.outset(by: spacingSize(from: typeline))]
            }
        }
        if let typeline = typeline(at: range.upperBound),
           typeline.range.lowerBound == range.upperBound {
            let lb = typeline.firstTypoBounds() + typeline.origin
            return rects + [lb.outset(by: spacingSize(from: typeline))]
        }
        return rects
    }
    
    var underlineEdges: [Edge] {
        underlineEdges(for: string.startIndex..<string.endIndex)
    }
    func underlineEdges(for range: Range<String.Index>,
                        delta: Double = Line.defaultLineWidth) -> [Edge] {
        typelines.compactMap { $0.underlineEdges(for: range, delta: delta) }
    }
    
    func baselineDelta(at i: String.Index) -> Double {
        for typeline in typelines {
            if typeline.range.contains(i) {
                return typeline.baselineDelta
            }
        }
        if let typeline = typelines.last {
            if !typeline.isLastReturnEnd && i == typeline.range.upperBound {
                return typeline.baselineDelta
            }
        }
        return 0.0
    }
    
    func index(before oi: String.Index) -> String.Index {
        var i = string.index(before: oi)
        while i > string.startIndex {
            let d = characterAdvance(at: i)
            if d > 0 {
                return i
            }
            i = string.index(before: i)
        }
        return i
    }
    func index(after oi: String.Index) -> String.Index {
        var i = string.index(after: oi)
        while i < string.endIndex {
            let d = characterAdvance(at: i)
            if d > 0 {
                return i
            }
            i = string.index(after: i)
        }
        return i
    }
    
    private func indentLinePathline(x: Double,
                                    minY: Double, maxY: Double,
                                    ratio: Double,
                                    isVertical: Bool) -> Pathline {
        let hlw = Line.defaultLineWidth / 2 * ratio
        let d0 = hlw * 9, d1 = hlw * 2 * 0.6
        if isVertical {
            let x0 = x + hlw, x1 = x - hlw
            let x2 = x0 - d0, y0 = minY - d0, y1 = maxY + d0
            return Pathline(firstPoint: Point(maxY, x0),
                            elements: [.linear(Point(minY, x0)),
                                       .bezier(point: Point(y0, x2),
                                               control: Point(y0, x0)),
                                       .linear(Point(y0 + d1, x2)),
                                       .bezier(point: Point(minY, x1),
                                               control: Point(y0 + d1 + hlw, x1)),
                                       .linear(Point(maxY, x1)),
                                       .bezier(point: Point(y1 - d1, x2),
                                               control: Point(y1 - d1 - hlw, x1)),
                                       .linear(Point(y1, x2)),
                                       .bezier(point: Point(maxY, x0),
                                               control: Point(y1, x0))])
        } else {
            let x0 = x - hlw, x1 = x + hlw
            let x2 = x0 + d0, y0 = minY - d0, y1 = maxY + d0
            return Pathline(firstPoint: Point(x0, maxY),
                            elements: [.linear(Point(x0, minY)),
                                       .bezier(point: Point(x2, y0),
                                               control: Point(x0, y0)),
                                       .linear(Point(x2, y0 + d1)),
                                       .bezier(point: Point(x1, minY),
                                               control: Point(x1, y0 + d1 + hlw)),
                                       .linear(Point(x1, maxY)),
                                       .bezier(point: Point(x2, y1 - d1),
                                               control: Point(x1, y1 - d1 - hlw)),
                                       .linear(Point(x2, y1)),
                                       .bezier(point: Point(x0, maxY),
                                               control: Point(x0, y1))])
        }
    }
    func indentPathlines() -> [Pathline] {
        let ratio = typobute.font.size / Font.defaultSize
        let xPadding = 6.0 * ratio, yPadding = 3.0 * ratio
        return indents.map {
            let fi = $0.firstIndex, li = $0.lastIndex, mi = $0.offsetIndex
            switch typobute.orientation {
            case .horizontal:
                if $0.isTabstop {
                    let xPadding = 4.0 * ratio, yPadding = 6.0 * ratio
                    let x = characterPosition(at: mi).x - xPadding
                    let maxY = characterPosition(at: fi).y + yPadding
                    let minY = characterPosition(at: li).y - yPadding
                    let lw = Line.defaultLineWidth / 2 * ratio
                    return Pathline(Rect(x: x, y: minY,
                                         width: lw, height: maxY - minY))
                } else {
                    let x = characterPosition(at: mi).x - xPadding
                    let maxY = characterPosition(at: fi).y + yPadding
                    let minY = characterPosition(at: li).y - yPadding
                    return indentLinePathline(x: x,
                                              minY: minY, maxY: maxY,
                                              ratio: ratio,
                                              isVertical: false)
                }
            case .vertical:
                if $0.isTabstop {
                    let xPadding = 4.0 * ratio, yPadding = 6.0 * ratio
                    let y = characterPosition(at: mi).y + xPadding
                    let maxX = characterPosition(at: fi).x + yPadding
                    let minX = characterPosition(at: li).x - yPadding
                    let lw = Line.defaultLineWidth / 2 * ratio
                    return Pathline(Rect(x: minX, y: y,
                                         width: maxX - minX, height: lw))
                } else {
                    let y = characterPosition(at: mi).y + xPadding
                    let maxX = characterPosition(at: fi).x + yPadding
                    let minX = characterPosition(at: li).x - yPadding
                    return indentLinePathline(x: y,
                                              minY: minX, maxY: maxX,
                                              ratio: ratio,
                                              isVertical: true)
                }
            }
        }
    }
    
    func path(isPolygon: Bool = false) -> Path {
        Path(self, isPolygon: isPolygon)
    }
    var pathlines: [Pathline] {
        var pathlines = [Pathline]()
        for typeline in typelines {
            pathlines += typeline.pathlines()
        }
        pathlines += indentPathlines()
        return pathlines
    }
    
    var maxTypelineWidthPath: Path {
        guard let b = typoBounds else { return Path() }
        let w = typobute.maxTypelineWidth
        switch typobute.orientation {
        case .horizontal:
            return Path(Edge(Point(w + b.minX, b.minY),
                             Point(w + b.minX, b.maxY)))
        case .vertical:
            return Path(Edge(Point(b.minX, b.maxY - w),
                             Point(b.maxX, b.maxY - w)))
        }
    }
}
