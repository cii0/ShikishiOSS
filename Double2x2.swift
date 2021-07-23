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

struct Double2x2 {
    var column0: Double2, column1: Double2
}
extension Double2x2 {
    static let zero = Double2x2(0)
    static let identity = Double2x2(1)
    static let im = Double2x2(column0: Double2(0, 1),
                              column1: Double2(-1, 0))
    static let nan = Double2x2(column0: Double2(.nan, .nan),
                               column1: Double2(.nan, .nan))
    
    init() {
        self.column0 = Double2()
        self.column1 = Double2()
    }
    init(_ m00: Double, _ m10: Double,
         _ m01: Double, _ m11: Double) {
        
        self.init(column0: Double2(m00, m01),
                  column1: Double2(m10, m11))
    }
    init(_ v: Int) {
        self.init(Double(v))
    }
    init(_ v: Rational) {
        self.init(Double(v))
    }
    init(_ v: Double) {
        self.init(column0: Double2(v, 0),
                  column1: Double2(0, v))
    }
    
    var row0: Double2 {
        Double2(self[0][0], self[1][0])
    }
    var row1: Double2 {
        Double2(self[0][1], self[1][1])
    }
    
    static func + (lhs: Double2x2, rhs: Double2x2) -> Double2x2 {
        Double2x2(column0: lhs.column0 + rhs.column0,
                  column1: lhs.column1 + rhs.column1)
    }
    static func += (lhs: inout Double2x2, rhs: Double2x2) {
        lhs = lhs + rhs
    }
    prefix static func - (x: Double2x2) -> Double2x2 {
        Double2x2(column0: -x.column0,
                  column1: -x.column1)
    }
    static func - (lhs: Double2x2, rhs: Double2x2) -> Double2x2 {
        Double2x2(column0: lhs.column0 - rhs.column0,
                  column1: lhs.column1 - rhs.column1)
    }
    static func -= (lhs: inout Double2x2, rhs: Double2x2) {
        lhs = lhs - rhs
    }
    static func * (lhs: Double2x2, rhs: Double2x2) -> Double2x2 {
        let a0 = lhs.column0 * rhs.column0.x
        let a1 = lhs.column1 * rhs.column0.y
        let b0 = lhs.column0 * rhs.column1.x
        let b1 = lhs.column1 * rhs.column1.y
        return Double2x2(column0: a0 + a1,
                         column1: b0 + b1)
    }
    static func * (lhs: Double2, rhs: Double2x2) -> Double2 {
        let a0 = lhs.x * rhs.row0
        let a1 = lhs.y * rhs.row1
        return a0 + a1
    }
    static func * (lhs: Double2x2, rhs: Double2) -> Double2 {
        let a0 = lhs.column0 * rhs.x
        let a1 = lhs.column1 * rhs.y
        return a0 + a1
    }
    static func * (lhs: Double, rhs: Double2x2) -> Double2x2 {
        Double2x2(column0: lhs * rhs.column0,
                  column1: lhs * rhs.column1)
    }
    static func * (lhs: Double2x2, rhs: Double) -> Double2x2 {
        Double2x2(column0: lhs.column0 * rhs,
                  column1: lhs.column1 * rhs)
    }
    static func *= (lhs: inout Double2x2, rhs: Double2x2) {
        lhs = lhs * rhs
    }
    var isIdentity: Bool {
        self == Double2x2.identity
    }
    func inverted() -> Double2x2 {
        let a = column0 * Double2(column1.y, column1.x)
        let d = 1 / (a.x - a.y)
        return d * Double2x2(column0: Double2(column1.y, -column0.y),
                             column1: Double2(-column1.x, column0.x))
    }
    subscript(i: Int) -> Double2 {
        switch i {
        case 0: return column0
        case 1: return column1
        default: fatalError()
        }
    }
}
extension Double2x2: Hashable {}
extension Double2x2 {
    init(re a: Double, im b: Double) {
        self = Double2x2(column0: Double2(a, b), column1: Double2(-b, a))
    }
    
    var complexPoint: Point? {
        if self[0][0] == self[1][1] && self[0][1] == -self[1][0] {
            return Point(self[0][0], self[0][1])
        } else {
            return nil
        }
    }
    
    var isInteger: Bool {
        self[0][0].isInteger && self[1][1].isInteger
            && self[0][0] == self[1][1]
            && self[0][1] == 0 && self[1][0] == 0
    }
    var isDouble: Bool {
        self[0][0] == self[1][1]
            && self[0][1] == 0 && self[1][0] == 0
    }
    var intValue: Int? {
        isInteger ? Int(exactly: self[0][0]) : nil
    }
    var doubleValue: Double? {
        isDouble ? self[0][0] : nil
    }
    
    func rounded(_ rule: FloatingPointRoundingRule
                    = .toNearestOrAwayFromZero) -> Double2x2 {
        Double2x2(column0: column0.rounded(rule),
                  column1: column1.rounded(rule))
    }
}
extension Double2x2 {
    static func ** (lhs: Double, rhs: Double2x2) -> Double2x2 {
        let rhs = lhs == .e ? rhs : rhs * .log(lhs)
        if let cp = rhs.complexPoint {
            return .exp(cp.x) * Double2x2(re: .cos(cp.y), im: .sin(cp.y))
        } else {
            var y = identity
            for i in 1..<15 {
                y += (rhs ** i) / Double(i.factorial)
            }
            return y
        }
    }
    static func ** (lhs: Double2x2, rhs: Double) -> Double2x2 {
        exp(log(lhs) * rhs)
    }
    static func ** (lhs: Double2x2, rhs: Double2x2) -> Double2x2 {
        if let lz = lhs.complexPoint, let rz = rhs.complexPoint {
            let polar = lz.polar
            let logZ: Double = .log(polar.r)
            let alpha = rz.x * logZ - rz.y * polar.theta
            let beta = rz.y * logZ + rz.x * polar.theta
            let ea = .e ** alpha
            return Double2x2(re: .cos(beta) * ea, im: .sin(beta) * ea)
        } else {
            return exp(log(lhs) * rhs)
        }
    }
    func squareRoot() -> Double2x2 {
        .sqrt(self)
    }
    static func sqrt(_ v: Double2x2) -> Double2x2 {
        exp(0.5 * log(v))
    }
    static func exp(_ rhs: Double2x2) -> Double2x2 {
        if let cp = rhs.complexPoint {
            return .exp(cp.x) * Double2x2(re: .cos(cp.y), im: .sin(cp.y))
        } else {
            var y = identity
            for i in 1..<15 {
                y += (rhs ** i) / Double(i.factorial)
            }
            return y
        }
    }
    static func log(_ x: Double2x2) -> Double2x2 {
        if let cp = x.complexPoint {
            let polar = cp.polar
            return Double2x2(re: .log(polar.r), im: polar.theta)
        } else {
            let xx = x - .identity
            var y = Double2x2()
            for n in 1..<20 {
                if (n + 1) % 2 == 0 {
                    y += (xx ** n) / Double2x2(n)
                } else {
                    y -= (xx ** n) / Double2x2(n)
                }
            }
            return y
        }
    }
    static func log(_ a: Double2x2, _ b: Double2x2) -> Double2x2 {
        .log(b) / .log(a)
    }
    static func ** (lhs: Double2x2, rhs: Int) -> Double2x2 {
        (0..<rhs).reduce(.identity) { v, _ in v * lhs }
    }
    static func / (lhs: Double2x2, rhs: Double) -> Double2x2 {
        lhs * (1 / rhs)
    }
    static func / (lhs: Double, rhs: Double2x2) -> Double2x2 {
        lhs * rhs.inverted()
    }
    static func / (lhs: Double2x2, rhs: Double2x2) -> Double2x2 {
        lhs * rhs.inverted()
    }
    static func sin(_ v: Double2x2) -> Double2x2 {
        let a = .exp(.im * v) - .exp(-.im * v)
        return -0.5 * .im * a
    }
    static func cos(_ v: Double2x2) -> Double2x2 {
        let a = .exp(.im * v) + .exp(-.im * v)
        return 0.5 * a
    }
    static func tan(_ v: Double2x2) -> Double2x2 {
        sin(v) / cos(v)
    }
    static func acos(_ v: Double2x2) -> Double2x2 {
        let a = v + .im * .sqrt(.identity - v * v)
        return -.im * .log(a)
    }
    static func asin(_ v: Double2x2) -> Double2x2 {
        let a = .im * v + .sqrt(.identity - v * v)
        return -.im * .log(a)
    }
    static func atan(_ v: Double2x2) -> Double2x2 {
        let a0: Double2x2 = .log(.identity - .im * v)
        let a1: Double2x2 = .log(.identity + .im * v)
        return 0.5 * .im * (a0 - a1)
    }
    static func atan2(y: Double2x2, x: Double2x2) -> Double2x2 {
        if x == .zero && y == .zero {
            return .zero
        }
        return -.im * .log((x + .im * y) / sqrt(x * x + y * y))
    }
    
    func abs() -> Double? {
        complexPoint?.length()
    }
}
