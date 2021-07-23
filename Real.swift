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

import RealModule

extension BinaryFloatingPoint {
    var signValue: Self {
        self >= 0 ? 1 : -1
    }
    func notNaN() throws -> Self {
        if isNaN {
            throw ProtobufError()
        } else {
            return self
        }
    }
    func notZeroAndNaN() throws -> Self {
        if isZero || isNaN {
            throw ProtobufError()
        } else {
            return self
        }
    }
    func notInfinite() throws -> Self {
        if isInfinite {
            throw ProtobufError()
        } else {
            return self
        }
    }
}
extension SignedNumeric {
    func negated() -> Self {
        var a = self
        a.negate()
        return a
    }
}

extension Float: Interpolatable {
    static func linear(_ f0: Float, _ f1: Float, t: Double) -> Float {
        let t = Float(t)
        return f0 * (1 - t) + f1 * t
    }
    static func integralLinear(_ f0: Float, _ f1: Float,
                               a: Double, b: Double) -> Float {
        let a = Float(a), b = Float(b)
        let f01 = f1 - f0
        let fa = a * (f01 * a / 2 + f0)
        let fb = b * (f01 * b / 2 + f0)
        return fb - fa
    }
    
    /// Catmull-Rom spline
    static func firstSpline(_ f1: Float,
                            _ f2: Float, _ f3: Float, t: Double) -> Float {
        let t = Float(t)
        let a = f1 - 2 * f2 + f3
        let b = -3 * f1 + 4 * f2 - f3
        let c = 2 * f1
        return (a * t * t + b * t + c) / 2
    }
    /// Catmull-Rom spline
    static func spline(_ f0: Float, _ f1: Float,
                       _ f2: Float, _ f3: Float, t: Double) -> Float {
        let t = Float(t)
        let a = -f0 + 3 * f1 - 3 * f2 + f3
        let b = 2 * f0 - 5 * f1 + 4 * f2 - f3
        let c = -f0 + f2
        let d = 2 * f1
        return (a * t * t * t + b * t * t + c * t + d) / 2
    }
    /// Catmull-Rom spline
    static func lastSpline(_ f0: Float, _ f1: Float,
                           _ f2: Float, t: Double) -> Float {
        let t = Float(t)
        let a = f0 - 2 * f1 + f2
        let b = -f0 + f2
        let c = 2 * f1
        return (a * t * t + b * t + c) / 2
    }
}

extension Double: Interpolatable {
    static func linear(_ f0: Double, _ f1: Double, t: Double) -> Double {
        f0 * (1 - t) + f1 * t
    }
    static func integralLinear(_ f0: Double, _ f1: Double,
                               a: Double, b: Double) -> Double {
        let f01 = f1 - f0
        let fa = a * (f01 * a / 2 + f0)
        let fb = b * (f01 * b / 2 + f0)
        return fb - fa
    }
    
    /// Catmull-Rom spline
    static func firstSpline(_ f1: Double,
                            _ f2: Double, _ f3: Double, t: Double) -> Double {
        let a = f1 - 2 * f2 + f3
        let b = -3 * f1 + 4 * f2 - f3
        let c = 2 * f1
        return (a * t * t + b * t + c) / 2
    }
    /// Catmull-Rom spline
    static func spline(_ f0: Double, _ f1: Double,
                       _ f2: Double, _ f3: Double, t: Double) -> Double {
        let a = -f0 + 3 * f1 - 3 * f2 + f3
        let b = 2 * f0 - 5 * f1 + 4 * f2 - f3
        let c = -f0 + f2
        let d = 2 * f1
        return (a * t * t * t + b * t * t + c * t + d) / 2
    }
    /// Catmull-Rom spline
    static func lastSpline(_ f0: Double, _ f1: Double,
                           _ f2: Double, t: Double) -> Double {
        let a = f0 - 2 * f1 + f2
        let b = -f0 + f2
        let c = 2 * f1
        return (a * t * t + b * t + c) / 2
    }
}
extension Double {
    static let e = exp(1)
    
    static func hypotSquared(_ a: Double, _ b: Double) -> Double {
        a * a + b * b
    }
    
    static func log(_ a: Double, _ b: Double) -> Double {
        .log(b) / .log(a)
    }
    static func apow(_ a: Double, _ b: Double) -> Double {
        .log(a) / .log(b)
    }
    
    static func cbrt(_ v: Double) -> Double {
        .root(v, 3)
    }
    func cubeRoot() -> Double {
        .cbrt(self)
    }
    
    func mid(_ other: Double) -> Double {
        (self + other) / 2
    }
    
    mutating func round(decimalPlaces: Int) {
        self = rounded(decimalPlaces: decimalPlaces)
    }
    func rounded10(decimalPlaces scale: Int) -> Double {
        (self * 10 ** scale).rounded() / 10 ** scale
    }
    func rounded(decimalPlaces: Int) -> Double {
        let x = Int(Double.log2(Double(10 ** decimalPlaces)).rounded(.up))
        let powerOf2 = Double(2 ** x)
        let n = (self * powerOf2).rounded()
        return n / powerOf2
    }
    
    var integralPart: Double {
        rounded(.towardZero)
    }
    var decimalPart: Double {
        truncatingRemainder(dividingBy: 1)
    }
    var isInteger: Bool {
        Int(exactly: self) != nil
    }
    
    func interval(scale: Double) -> Double {
        if scale == 0 {
            return self
        } else {
            let t = (self / scale).rounded(.down) * scale
            return self - t > scale / 2 ? t + scale : t
        }
    }
    func interval(scale: Double, location: Double) -> Double {
        if scale == 0 {
            return self
        } else {
            let t = (self / scale).rounded(.down) * scale
            return self - t > scale / 2 ? t + scale : t
        }
    }
    
    func differenceRotation(_ other: Double) -> Double {
        var a = self - other
        a -= (a / (2 * .pi)).rounded(.down) * 2 * .pi
        return a > .pi ? a - 2 * .pi : a
    }
    
    var clippedRotation: Double {
        if self < -.pi {
            return (self + .pi).truncatingRemainder(dividingBy: 2 * .pi) + .pi
        } else if self > .pi {
            return (self - .pi).truncatingRemainder(dividingBy: 2 * .pi) - .pi
        } else {
            return self
        }
    }
    var clippedDegreesRotation: Double {
        self < -180 ?
            self + 360 :
            (self > 180 ? self - 360 : self)
    }
    
    func isApproximatelyEqual(_ other: Double,
                              tolerance: Double = .ulpOfOne) -> Bool {
        abs(self - other) < tolerance
    }
    
    var squared: Double { self * self }
    
    func absRatio(_ other: Double) -> Double {
        abs(self > other ? self / other : other / self)
    }
    func absSmallRatio(_ other: Double) -> Double {
        abs(self < other ? self / other : other / self)
    }
    func revision(t: Double, h: Double,
                  ct: Double = 0.5) -> Double {
        if t <= ct {
            let v = 1 - ((ct - t) / ct) ** h
            return v ** (1 / h) * 0.5
        } else {
            let t = t - ct
            let v = 1 - (t / (1 - ct)) ** h
            return -(v ** (1 / h) * 0.5) + 1
        }
    }
    
    func clipped(min: Double, max: Double,
                 newMin: Double, newMax: Double) -> Double {
        if min < max ? self <= min : self >= min {
            return newMin
        } else if min < max ? self >= max : self <= max {
            return newMax
        } else {
            return Double.linear(newMin, newMax, t: (self - min) / (max - min))
        }
    }
    
    func loopValue(_ other: Double,
                   begin: Double = 0, end: Double = 1) -> Double {
        if other < self {
            let value = (other - begin) + (end - self)
            return self - other < value ? self : self - (end - begin)
        } else {
            let value = (self - begin) + (end - other)
            return other - self < value ? self : self + (end - begin)
        }
    }
    func loopValue(begin: Double = 0, end: Double = 1) -> Double {
        self < begin ?
            self + (end - begin) :
            (self > end ? self - (end - begin) : self)
    }
    
    static func solveEquationReals(_ a: Double, _ b: Double,
                                   _ c: Double, _ d: Double) -> [Double] {
        if a == 0 {
            if b == 0 {
                if c == 0 {
                    return [.nan]
                } else {
                    return [solveLinearEquation(c, d)]
                }
            } else {
                return solveQuadraticEquationReals(b, c, d)
            }
        } else {
            return solveCubicEquationReals(a, b, c, d)
        }
    }
    static func solveLinearEquation(_ a: Double, _ b: Double) -> Double {
        guard a != 0 else {
            return .nan
        }
        return -b / a
    }
    static func solveQuadraticEquationReals(_ a: Double, _ b: Double,
                                            _ c: Double) -> [Double] {
        guard a != 0 else {
            return [.nan]
        }
        let d = b * b - 4 * a * c
        if abs(d) < .ulpOfOne {
            return [-b / (2 * a)]
        } else if d < 0 {
            return []
        } else {
            let sd = d.squareRoot()
            let nd = -b - sd
            let x0 = abs(nd) < .ulpOfOne ?
                (-b + sd) / (2 * a) : 2 * c / nd
            let x1 = nd / (2 * a)
            return [x0, x1]
        }
    }
    /// Cardano's formula
    static func solveCubicEquationReals(_ a: Double, _ b: Double,
                                        _ c: Double, _ d: Double) -> [Double] {
        guard a != 0 else {
            return [.nan]
        }
        let m = b / a, n = c / a, l = d / a
        let p = n - m * m / 3
        let q = 2 * m * m * m / 27 - m * n / 3 + l
        let dd = q * q / 4 + p * p * p / 27
        let q2 = -q / 2, m3 = -m / 3
        if dd >= 0 {
            let sd = sqrt(dd)
            let u = cbrt(q2 + sd), v = cbrt(q2 - sd)
            return [u + v + m3]
        } else {
            let theta: Double = atan2(y: sqrt(-dd), x: q2)
            let sp = 2 * sqrt(-p / 3)
            return [sp * cos(theta / 3) + m3,
                    sp * cos((theta + 2 * .pi) / 3) + m3,
                    sp * cos((theta + 4 * .pi) / 3) + m3]
        }
    }
    
    /// Simpson's rule
    static func integral(splitHalfCount m: Int, a: Double, b: Double,
                         f: (Double) -> (Double)) -> Double {
        let n = Double(2 * m)
        let h = (b - a) / n
        func x(at i: Int) -> Double {
            return a + Double(i) * h
        }
        let s0 = 2 * (1..<m - 1).reduce(0.0) { $0 + f(x(at: 2 * $1)) }
        let s1 = 4 * (1..<m).reduce(0.0) { $0 + f(x(at: 2 * $1 - 1)) }
        return (h / 3) * (f(a) + s0 + s1 + f(b))
    }
    /// Simpson's rule
    static func integralB(splitHalfCount m: Int, a: Double, maxB: Double,
                          s: Double, bisectionCount: Int = 3,
                          f: (Double) -> (Double)) -> Double {
        let n = 2 * m
        let h = (maxB - a) / Double(n)
        func x(at i: Int) -> Double {
            return a + Double(i) * h
        }
        let h3 = h / 3
        var a = a
        var fa = f(a), allS = 0.0
        for i in (0..<m) {
            let ab = x(at: i * 2 + 1), b = x(at: i * 2 + 2)
            let fab = f(ab), fb = f(b)
            let abS = fa + 4 * fab + fb
            let nAllS = allS + abS
            if h3 * nAllS >= s {
                let hAllS = h3 * allS
                var bA = a, bB = b
                var fbA = fa
                for _ in (0..<bisectionCount) {
                    let bAB = (bA + bB) / 2
                    let bS = fbA + 4 * f((bA + bAB) / 2) + f(bAB)
                    let hBS = hAllS + ((bB - bA) / 6) * bS
                    if hBS >= s {
                        bA = bAB
                        fbA = f(bA)
                    } else {
                        bB = bAB
                    }
                }
                return bA
            }
            allS = nAllS
            a = b
            fa = fb
        }
        return maxB
    }
    
    static func factorial(_ v: Double) -> Double {
        .gamma(v + 1)
    }
    
    static func binom(_ n: Double, _ k: Double) -> Double {
        var n = n, k = k
        var stack = Stack<(Double, Double)>()
        while true {
            k = Swift.min(k, n - k)
            if k == 0 { break }
            stack.push((n, k))
            n = n - 1
            k = k - 1
        }
        var y = 1.0
        while let v = stack.pop() { y *= v.0 / v.1 }
        return y
    }
}
extension Double {
    static func ** (lhs: Double, rhs: Double) -> Double {
        if lhs < 0, let rhs = Int(exactly: rhs) {
            return rhs % 2 == 0 ? pow(-lhs, rhs) : -pow(-lhs, rhs)
        }
        return pow(lhs, rhs)
    }
    static func ** (lhs: Double, rhs: Int) -> Double {
        if lhs < 0 {
            return rhs % 2 == 0 ? pow(-lhs, rhs) : -pow(-lhs, rhs)
        }
        return pow(lhs, rhs)
    }
}
extension Double {
    init(_ x: Rational) {
        self = Double(x.p) / Double(x.q)
    }
}
extension Double {
    init(_ o: Bool) {
        self = o ? 1 : 0
    }
}

struct DoubleRange: Codable, Hashable {
    var lowerBound = 0.0, upperBound = 0.0
}
extension DoubleRange {
    init(_ v: Double) {
        lowerBound = v
        upperBound = v
    }
    init(_ v0: Double, _ v1: Double) {
        lowerBound = min(v0, v1)
        upperBound = max(v0, v1)
    }
    
    var width: Double {
        upperBound - lowerBound
    }
    var mid: Double {
        (lowerBound + upperBound) / 2
    }
    
    func clipped(_ x: Double) -> Double {
        x < lowerBound ?
            lowerBound :
            (x > upperBound ? upperBound : x)
    }
    
    func contains(_ v: Double) -> Bool {
        v >= lowerBound && v < upperBound
    }
    
    func intersects(_ other: DoubleRange) -> Bool {
        lowerBound < other.upperBound && upperBound > other.lowerBound
    }
    
    static func + (lhs: DoubleRange, rhs: Double) -> DoubleRange {
        DoubleRange(lowerBound: min(lhs.lowerBound, rhs),
                    upperBound: max(lhs.upperBound, rhs))
    }
    static func + (lhs: DoubleRange, rhs: DoubleRange) -> DoubleRange {
        DoubleRange(lowerBound: min(lhs.lowerBound, rhs.lowerBound),
                    upperBound: max(lhs.upperBound, rhs.upperBound))
    }
}
