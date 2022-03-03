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

struct Rational: SignedNumeric, Hashable {
    static var ulpOfOne = Rational(.ulpOfOne)
    var p, q: Int
    
    init() {
        p = 0
        q = 1
    }
    init(_ p: Int, _ q: Int) {
        guard q != 0 else { fatalError("Division by zero") }
        let d = abs(Int.gcd(p, q)) * (q / abs(q))
        (self.p, self.q) = d == 1 ?
            (p, q) :
            (p / d, q / d)
    }
    init(_ n: Int) {
        self.init(n, 1)
    }
    init?<T>(exactly source: T) where T : BinaryInteger {
        if let integer = Int(exactly: source) {
            self.init(integer)
        } else {
            return nil
        }
    }
    init?<T>(exactly source: T) where T : BinaryFloatingPoint {
        if Int(exactly: source) != nil {
            self.init(Double(source))
        } else {
            return nil
        }
    }
    
    init(_ x: Double, maxDenominator: Int = 10000000,
         tolerance: Double = 0.000001) {
        var x = x
        var a = x.rounded(.down)
        var p0 = 1, q0 = 0, p1 = Int(a), q1 = 1
        while abs(x - a) >= tolerance {
            x = 1 / (x - a)
            a = x.rounded(.down)
            let ia = Int(a)
            let p2 = ia * p1 + p0
            let q2 = ia * q1 + q0
            if q2 > maxDenominator {
                self.init(p2, q2)
                return
            }
            (p0, q0) = (p1, q1)
            (p1, q1) = (p2, q2)
        }
        self.init(p1, q1)
    }
    
    static func random(in range: Range<Rational>) -> Rational {
        let r0 = Double(range.lowerBound), r1 = Double(range.upperBound)
        return Rational(Double.random(in: r0...r1))
    }
    static func random(in range: ClosedRange<Rational>) -> Rational {
        let r0 = Double(range.lowerBound), r1 = Double(range.upperBound)
        return Rational(Double.random(in: r0...r1))
    }
}
extension Rational {
    static func continuedFractions(with x: Double,
                                   maxCount: Int = 32) -> [Int] {
        var x = x, cfs = [Int]()
        var a = x.rounded(.down)
        for _ in 0..<maxCount {
            cfs.append(Int(a))
            if abs(x - a) < 0.000001 { break }
            x = 1 / (x - a)
            a = x.rounded(.down)
        }
        return cfs
    }
    
    var inversed: Rational? {
        p == 0 ? nil : Rational(q, p)
    }
    var integralPart: Int {
        p / q
    }
    var decimalPart: Rational {
        self - Rational(integralPart)
    }
    var isInteger: Bool {
        q == 1
    }
    var integerAndProperFraction: (integer: Int,
                                   properFraction: Rational) {
        let i = integralPart
        return isInteger ?
            (i, Rational(0, 1)) :
            (i, self - Rational(i))
    }
    func interval(scale: Rational) -> Rational {
        if scale == 0 {
            return self
        } else {
            let t = (self / scale).rounded(.down) * scale
            return self - t > scale / 2 ?
                t + scale : t
        }
    }
    
    static var min: Rational {
        Rational(Int(Int32.min))
    }
    static var max: Rational {
        Rational(Int(Int32.max))
    }
    
    var sign: FloatingPointSign {
        p < 0 ? .minus : .plus
    }
    
    var magnitude: Rational {
        Rational(abs(p), q)
    }
    typealias Magnitude = Rational
    
    static func + (lhs: Rational, rhs: Rational) -> Rational {
        Rational(lhs.p * rhs.q + lhs.q * rhs.p, lhs.q * rhs.q)
    }
    static func += (lhs: inout Rational, rhs: Rational) {
        lhs = lhs + rhs
    }
    static func - (lhs: Rational, rhs: Rational) -> Rational {
        lhs + (-rhs)
    }
    static func -= (lhs: inout Rational, rhs: Rational) {
        lhs = lhs - rhs
    }
    static func *= (lhs: inout Rational, rhs: Rational) {
        lhs = lhs * rhs
    }
    static func /= (lhs: inout Rational, rhs: Rational) {
        lhs = lhs / rhs
    }
    prefix static func - (x: Rational) -> Rational {
        Rational(-x.p, x.q)
    }
    static func * (lhs: Rational, rhs: Rational) -> Rational {
        Rational(lhs.p * rhs.p, lhs.q * rhs.q)
    }
    static func / (lhs: Rational, rhs: Rational) -> Rational {
        Rational(lhs.p * rhs.q, lhs.q * rhs.p)
    }
    static func % (lhs: Rational, rhs: Rational) -> Rational {
        lhs - rhs * (lhs / rhs).rounded(.down)
    }
    static func ** (lhs: Rational, rhs: Int) -> Rational {
        (0..<rhs).reduce(1) { v, _ in v * lhs }
    }
    
    enum OverResult {
        case rational(Rational), double(Double)
        init(_ p: Double, _ q: Double) {
            if let p = Int(exactly: p), let q = Int(exactly: q) {
                self = .rational(Rational(p, q))
            } else {
                self = .double(p / q)
            }
        }
    }
    static func overAdd(_ lhs: Rational, _ rhs: Rational) -> OverResult {
        let lhsp = Double(lhs.p), lhsq = Double(lhs.q)
        let rhsp = Double(rhs.p), rhsq = Double(rhs.q)
        let p = lhsp * rhsq + lhsq * rhsp
        let q = lhsq * rhsq
        return OverResult(p, q)
    }
    static func overDiff(_ lhs: Rational, _ rhs: Rational) -> OverResult {
        overAdd(lhs, Rational(-rhs.p, rhs.q))
    }
    static func overMulti(_ lhs: Rational, _ rhs: Rational) -> OverResult {
        let p = Double(lhs.p) * Double(rhs.p)
        let q = Double(lhs.q) * Double(rhs.q)
        return OverResult(p, q)
    }
    static func overDiv(_ lhs: Rational, _ rhs: Rational) -> OverResult {
        let p = Double(lhs.p) * Double(rhs.q)
        let q = Double(lhs.q) * Double(rhs.p)
        return OverResult(p, q)
    }
    static func overMod(_ lhs: Rational, _ rhs: Rational) -> OverResult {
        switch Rational.overDiv(lhs, rhs) {
        case .rational(let r0):
            switch Rational.overMulti(rhs, r0.rounded(.down)) {
            case .rational(let r1):
                switch Rational.overDiff(lhs, r1) {
                case .rational(let nr): return .rational(nr)
                case .double: break
                }
            case .double: break
            }
        case .double: break
        }
        return .double(Double(lhs)
                        .truncatingRemainder(dividingBy: Double(rhs)))
    }
    static func overPow(_ lhs: Rational, _ rhs: Int) -> OverResult {
        guard rhs < 10000 else {
            return .double(Double(lhs) ** rhs)
        }
        var n = Rational(1)
        for _ in 0..<abs(rhs) {
            switch overMulti(n, lhs) {
            case .rational(let r): n = r
            case .double: return .double(Double(lhs) ** rhs)
            }
        }
        if rhs < 0 {
            return n != 0 ?
                .rational(1 / n) :
                .double(1 / Double(n))
        } else {
            return .rational(n)
        }
    }
    
    func description(q: Int) -> String? {
        switch q % self.q {
        case 0: return "\(p * (q / self.q))/\(q)"
        default: return nil
        }
    }
    
    mutating func round(_ rule: FloatingPointRoundingRule
                            = .toNearestOrAwayFromZero) {
        self = rounded(rule)
    }
    func rounded(_ rule: FloatingPointRoundingRule
                    = .toNearestOrAwayFromZero) -> Rational {
        guard decimalPart.p != 0 else { return self }
        switch rule {
        case .awayFromZero:
            let i = integralPart
            let ni = i < 0 ? i - 1 : i + 1
            return Rational(ni)
        case .down:
            let i = integralPart
            let ni = i <= 0 ?
                (sign == .minus ? i - 1 : i) :
                i
            return Rational(ni)
        case .toNearestOrAwayFromZero:
            let i = integralPart, d = decimalPart, half = Rational(1, 2)
            let ni = d < half ?
                i :
                (i < 0 ? i - 1 : i + 1)
            return Rational(ni)
        case .toNearestOrEven:
            let i = integralPart, d = decimalPart, half = Rational(1, 2)
            if d < half {
                return Rational(i)
            } else if d > half {
                return Rational(i + 1)
            } else {
                let round = Rational(i)
                return round.integralPart % 2 == 0 ?
                    round : Rational(i + 1)
            }
        case .towardZero:
            return Rational(integralPart)
        case .up:
            return Rational(integralPart + 1)
        @unknown default:
            fatalError()
        }
    }
}
extension Rational {
    init(_ o: Bool) {
        self = o ? 1 : 0
    }
}
extension Rational {
    static let basicEffectiveFieldOfView = Rational(152, 100)
}
extension Rational: Equatable {
    static func == (lhs: Rational, rhs: Rational) -> Bool {
        lhs.p * rhs.q == lhs.q * rhs.p
    }
}
extension Rational: Comparable {
    static func < (lhs: Rational, rhs: Rational) -> Bool {
        lhs.p * rhs.q < rhs.p * lhs.q
    }
}
extension Rational: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        p = try container.decode(Int.self)
        q = try container.decode(Int.self)
        if q == 0 {
            throw DecodingError
            .dataCorruptedError(in: container,
                                debugDescription: "Division by zero")
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(p)
        try container.encode(q)
    }
}
extension Rational: LosslessStringConvertible {
    init?<S>(_ text: S) where S : StringProtocol {
        let values = text.split(separator: "/")
        if values.count == 2,
           let p = Int(values[0]), let q = Int(values[1]), q != 0 {
            
            self = Rational(p, q)
        } else if let value = Int(text) {
            self = Rational(value)
        } else {
            return nil
        }
    }
}
extension Rational: CustomStringConvertible {
    var description: String {
        switch q {
        case 1: return "\(p)"
        default: return "\(p)/\(q)"
        }
    }
}
extension Rational: ExpressibleByIntegerLiteral {
    typealias IntegerLiteralType = Int
    init(integerLiteral value: Int) {
        self.init(value)
    }
}
