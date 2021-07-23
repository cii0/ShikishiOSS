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

import struct Foundation.Locale
import struct Foundation.Data

extension Range: Serializable where Bound == Int {}
extension Range: Protobuf where Bound == Int {
    typealias PB = PBIntClosedRange
    init(_ pb: PBIntClosedRange) throws {
        if pb.lowerBound > pb.upperBound {
            throw ProtobufError()
        }
        self = Int(pb.lowerBound)..<Int(pb.upperBound)
    }
    var pb: PBIntClosedRange {
        PBIntClosedRange.with {
            $0.lowerBound = Int64(lowerBound)
            $0.upperBound = Int64(upperBound)
        }
    }
}

extension ClosedRange: Serializable where Bound == Int {}
extension ClosedRange: Protobuf where Bound == Int {
    typealias PB = PBIntClosedRange
    init(_ pb: PBIntClosedRange) throws {
        if pb.lowerBound > pb.upperBound {
            throw ProtobufError()
        }
        self = Int(pb.lowerBound)...Int(pb.upperBound)
    }
    var pb: PBIntClosedRange {
        PBIntClosedRange.with {
            $0.lowerBound = Int64(lowerBound)
            $0.upperBound = Int64(upperBound)
        }
    }
}

extension String: Serializable {
    struct SerializableError: Error {}
    init(serializedData data: Data) throws {
        guard let string = String(data: data, encoding: .utf8) else {
            throw SerializableError()
        }
        self = string
    }
    func serializedData() throws -> Data {
        if let data = data(using: .utf8) {
            return data
        } else {
            throw SerializableError()
        }
    }
}
extension String {
    func intIndex(from i: String.Index) -> Int {
        distance(from: startIndex, to: i)
    }
    func intRange(from range: Range<String.Index>) -> Range<Int> {
        intIndex(from: range.lowerBound)..<intIndex(from: range.upperBound)
    }
    func index(fromInt i: Int) -> String.Index {
        index(startIndex, offsetBy: i)
    }
    func index(fromSafetyInt i: Int) -> String.Index? {
        if i >= 0 && i < count {
            return index(startIndex, offsetBy: i)
        } else {
            return nil
        }
    }
    func range(fromInt range: Range<Int>) -> Range<String.Index> {
        index(fromInt: range.lowerBound)..<index(fromInt: range.upperBound)
    }
    
    func range(_ range: Range<Index>, offsetBy d: Int) -> Range<Index> {
        let nsi = index(range.lowerBound, offsetBy: d)
        let nei = index(range.upperBound, offsetBy: d)
        return nsi..<nei
    }
    func count(from range: Range<Index>) -> Int {
        distance(from: range.lowerBound, to: range.upperBound)
    }
    
    func difference(to toString: String) -> (intRange: Range<Int>,
                                             subString: String)? {
        let fromV = Array(self), toV = Array(toString)
        let fromCount = count, toCount = toString.count
        var startI = 0, endI = 0
        while startI < fromCount && startI < toCount
                && fromV[startI] == toV[startI] {
            startI += 1
        }
        while startI + endI < fromCount && startI + endI < toCount
                && fromV[fromCount - 1 - endI] == toV[toCount - 1 - endI] {
            endI += 1
        }
        if fromCount != startI + endI {
            let range = startI..<(fromCount - endI)
            return (range, String(toV[startI..<(toCount - endI)]))
        } else if toCount != startI + endI {
            let range = startI..<(toCount - endI)
            return (startI..<startI, String(toV[range]))
        } else {
            return nil
        }
    }
    init(intBased od: Double, roundScale: Int? = 14) {
        let d: Double
        if let r = roundScale {
            d = od.rounded10(decimalPlaces: r)
        } else {
            d = od
        }
        if let i = Int(exactly: d) {
            self.init(i)
        } else {
            self.init(oBased: d)
        }
    }
    init(oBased d: Double) {
        let str = String(d)
        if let si = str.firstIndex(of: "e") {
            let a = str[..<si]
            var b = str[str.index(after: si)...]
            if b.first == "+" {
                b.removeFirst()
            }
            let nb = b.reduce(into: "") { $0.append($1.toSuperscript ?? $1) }
            self = "\(a)*10\(nb)"
        } else if str == "inf" {
            self = "∞"
        } else if str == "-inf" {
            self = "-∞"
        } else {
            self = str
        }
    }
    func ranges<T: StringProtocol>(of s: T,
                                   options: CompareOptions = [],
                                   locale: Locale? = nil) -> [Range<Index>] {
        var ranges = [Range<Index>]()
        while let range
                = range(of: s, options: options,
                        range: (ranges.last?.upperBound ?? startIndex)..<endIndex,
                        locale: locale) {
            ranges.append(range)
        }
        return ranges
    }
    func substring(_ str: String,
                   _ range: Range<String.Index>) -> Substring {
        var s = str[range]
        s.replaceSubrange(range, with: str)
        return s
    }
    func substring(_ str: String,
                   _ range: ClosedRange<String.Index>) -> Substring {
        var s = self[range]
        s.replaceSubrange(range, with: str)
        return s
    }
    
    var toSuperscript: String {
        String(compactMap { $0.toSuperscript })
    }
    var toSubscript: String {
        String(compactMap { $0.toSubscript })
    }
}
extension Substring {
    func substring(_ str: String,
                   _ range: ClosedRange<String.Index>) -> Substring {
        var s = self[range]
        s.replaceSubrange(range, with: str)
        return s
    }
    func substring(_ str: String,
                   _ range: Range<String.Index>) -> Substring {
        var s = self[range]
        s.replaceSubrange(range, with: str)
        return s
    }
}

extension Character {
    static let superscriptScalar: Unicode.Scalar = "\u{F87E}"
    static let subscriptScalar: Unicode.Scalar = "\u{F87F}"
    
    var isSuperscript: Bool {
        fromSuperscript != nil
    }
    var isSubscript: Bool {
        fromSubscript != nil
    }
    var toSuperscript: Character? {
        let s = "\(self)\(Character.superscriptScalar)"
        return s.count == 1 ? s.first : nil
    }
    var toSubscript: Character? {
        let s = "\(self)\(Character.subscriptScalar)"
        return s.count == 1 ? s.first : nil
    }
    var fromSuperscript: Character? {
        if unicodeScalars.count == 2,
           unicodeScalars.last == Character.superscriptScalar,
           let us = unicodeScalars.first {
            
            return Character(us)
        }
        return nil
    }
    var fromSubscript: Character? {
        if unicodeScalars.count == 2,
           unicodeScalars.last == Character.subscriptScalar,
           let us = unicodeScalars.first {
            
            return Character(us)
        }
        return nil
    }
}

extension StringProtocol {
    func unionSplit<T>(separator: String,
                       handler: (SubSequence) -> (T)) -> [T] {
        var oi = startIndex, ns = [T]()
        for i in indices {
            let n = self[i...i]
            if separator.contains(n) {
                if oi < i {
                    ns.append(handler(self[oi..<i]))
                }
                ns.append(handler(n))
                oi = index(after: i)
            }
        }
        if oi < endIndex {
            if oi == startIndex {
                ns.append(handler(self[startIndex..<endIndex]))
            } else {
                ns.append(handler(self[oi...]))
            }
        }
        return ns
    }
    func unionSplit(separator: String) -> [SubSequence] {
        var oi = startIndex, ns = [SubSequence]()
        for i in indices {
            let n = self[i...i]
            if separator.contains(n) {
                if oi < i {
                    ns.append(self[oi..<i])
                }
                ns.append(n)
                oi = index(after: i)
            }
        }
        if oi < endIndex {
            if oi == startIndex {
                ns.append(self[startIndex..<endIndex])
            } else {
                ns.append(self[oi...])
            }
        }
        return ns
    }
}

struct Text {
    var string = ""
    var orientation = Orientation.horizontal
    var size = Font.defaultSize
    var widthCount = Typobute.defaultWidthCount
    var origin = Point()
}
extension Text {
    init(autoWidthCountWith string: String) {
        var maxCount = 0
        string.enumerateLines { (str, stop) in
            maxCount = max(str.count, maxCount)
        }
        let widthCount = Double(maxCount)
            .clipped(min: 25, max: 40,
                     newMin: Typobute.defaultWidthCount,
                     newMax: Typobute.maxWidthCount)
        self.init(string: string,
                  widthCount: widthCount)
    }
}
extension Text: Protobuf {
    init(_ pb: PBText) throws {
        string = pb.string
        orientation = (try? Orientation(pb.orientation)) ?? .horizontal
        let size = (try? pb.size.notNaN()) ?? Font.defaultSize
        self.size = size.clipped(min: 0, max: Font.maxSize)
        let wc = (try? pb.widthCount.notZeroAndNaN()) ?? Typobute.defaultWidthCount
        self.widthCount = wc.clipped(min: Typobute.minWidthCount,
                                     max: Typobute.maxWidthCount)
        origin = (try? Point(pb.origin).notInfinite()) ?? Point()
    }
    var pb: PBText {
        PBText.with {
            $0.string = string
            $0.orientation = orientation.pb
            $0.size = size
            $0.widthCount = widthCount
            $0.origin = origin.pb
        }
    }
}
extension Text: Hashable, Codable {}
extension Text: AppliableTransform {
    static func * (lhs: Text, rhs: Transform) -> Text {
        var lhs = lhs
        lhs.size *= rhs.absXScale
        lhs.origin *= rhs
        return lhs
    }
}
extension Text {
    var isEmpty: Bool {
        string.isEmpty
    }
}
extension Text {
    var font: Font {
        Font(name: Font.defaultName, size: size)
    }
    var typobute: Typobute {
        Typobute(font: font,
                 maxTypelineWidth: size * widthCount,
                 orientation: orientation)
    }
    var typesetter: Typesetter {
        Typesetter(string: string, typobute: typobute)
    }
    var bounds: Rect? {
        typesetter.typoBounds
    }
    var frame: Rect? {
        if let b = self.typesetter.typoBounds {
            return b + origin
        } else {
            return nil
        }
    }
    func distanceSquared(at p: Point) -> Double? {
        let typesetter = self.typesetter
        guard !typesetter.typelines.isEmpty else { return nil }
        var minDSquared = Double.infinity
        for typeline in typesetter.typelines {
            let dSquared = typeline.frame.distanceSquared(p)
            if dSquared < minDSquared {
                minDSquared = dSquared
            }
        }
        return minDSquared
    }
    
    mutating func replaceSubrange(_ nString: String,
                                  from range: Range<Int>, clipFrame sb: Rect) {
        let oldRange = string.range(fromInt: range)
        string.replaceSubrange(oldRange, with: nString)
        if let textFrame = frame, !sb.contains(textFrame) {
            let nFrame = sb.clipped(textFrame)
            origin += nFrame.origin - textFrame.origin
            
            if let textFrame = frame, !sb.outset(by: 1).contains(textFrame) {
                let scale = min(sb.width / textFrame.width,
                                sb.height / textFrame.height)
                let dp = sb.clipped(textFrame).origin - textFrame.origin
                size *= scale
                origin += dp
            }
        }
    }
}
extension Text {
    func rounded(_ rule: FloatingPointRoundingRule
                    = .toNearestOrAwayFromZero) -> Text {
        Text(string: string,
             orientation: orientation,
             size: size.rounded(rule),
             widthCount: widthCount.rounded(rule),
             origin: origin.rounded(rule))
    }
}
