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

extension Int {
    static func ** (lhs: Int, rhs: Int) -> Int {
        if lhs == -1 {
            return rhs % 2 == 0 ? 1 : -1
        } else if lhs == 0 {
            return 0
        } else if lhs == 1 {
            return 1
        } else {
            return (0..<rhs).reduce(1) { v, _ in v * lhs }
        }
    }
}
extension Int {
    static func gcd(_ m: Int, _ n: Int) -> Int {
        n == 0 ? m : gcd(n, m % n)
    }
    static func lcd(_ m: Int, _ n: Int) -> Int {
        let (v, overflow) = m.multipliedReportingOverflow(by: n)
        if overflow {
            return .max
        }
        return v / gcd(m, n)
    }
    static func lcd(_ vs: [Int]) -> Int {
        if vs.count == 1 {
            return vs[0]
        }
        var n = lcd(vs[0], vs[1])
        for i in 2..<vs.count {
            n = lcd(n, vs[i])
        }
        return n
    }
    func interval(scale: Int) -> Int {
        if scale == 0 {
            return self
        } else {
            let t = (self / scale) * scale
            return self - t > scale / 2 ?
                t + scale : t
        }
    }
    var factorial: Int {
        guard self >= 0 else { fatalError() }
        if self < 2 {
            return 1
        } else {
            return (2...self).reduce(1) { $0 * $1 }
        }
    }
    init(_ x: Rational) {
        self = x.integralPart
    }
    
    enum OverResult {
        case int(Int), double(Double)
        init(_ v: Double) {
            if let v = Int(exactly: v) {
                self = .int(v)
            } else {
                self = .double(v)
            }
        }
    }
    static func overAdd(_ lhs: Int, _ rhs: Int) -> OverResult {
        let (v, o) = lhs.addingReportingOverflow(rhs)
        if o {
            return lhs < 0 && rhs < 0 ?
                .double(Double(Int.min) + Double(v)) :
                .double(Double(Int.max) + Double(v))
        } else {
            return .int(v)
        }
    }
    static func overDiff(_ lhs: Int, _ rhs: Int) -> OverResult {
        overAdd(lhs, -rhs)
    }
    static func overMulti(_ lhs: Int, _ rhs: Int) -> OverResult {
        OverResult(Double(lhs) * Double(rhs))
    }
    static func overDiv(_ lhs: Int, _ rhs: Int) -> OverResult {
        OverResult(Double(lhs) / Double(rhs))
    }
    static func overMod(_ lhs: Int, _ rhs: Int) -> OverResult {
        OverResult(Double(lhs).truncatingRemainder(dividingBy: Double(rhs)))
    }
    static func overPow(_ lhs: Int, _ rhs: Int) -> OverResult {
        OverResult(Double(lhs) ** rhs)
    }
    var overFactorial: OverResult {
        guard self >= 0 else { return .double(.nan) }
        if self < 2 {
            return .int(1)
        } else {
            var i = 1
            for j in 2...self {
                switch Int.overMulti(i, j) {
                case .int(let ni): i = ni
                case .double: return .double(.factorial(Double(self)))
                }
            }
            return .int(i)
        }
    }
    var overGamma: OverResult {
        guard self >= 1 else { return .double(.nan) }
        if self < 1 {
            return .int(1)
        } else {
            var i = 1
            for j in 2..<self {
                switch Int.overMulti(i, j) {
                case .int(let ni): i = ni
                case .double: return .double(.gamma(Double(self)))
                }
            }
            return .int(i)
        }
    }
    
    static func binomFromStack(_ n: Int, _ k: Int) -> Int {
        let k = Swift.min(k, n - k)
        if k == 0 {
            return 1
        }
        return binom(n - 1, k - 1) * n / k
    }
    static func binom(_ n: Int, _ k: Int) -> Int {
        var n = n, k = k
        var stack = Stack<(Int, Int)>()
        while true {
            k = Swift.min(k, n - k)
            if k == 0 { break }
            stack.push((n, k))
            n = n - 1
            k = k - 1
        }
        var y = 1
        while let v = stack.pop() { y *= v.0 / v.1 }
        return y
    }
    static func binomDouble(_ n: Int, _ k: Int) -> Double {
        var n = Double(n), k = Double(k)
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
    static func overBinom(_ on: Int, _ ok: Int) -> OverResult {
        var n = on, k = ok
        var stack = Stack<(Int, Int)>()
        while true {
            guard case .int(let nk) = overDiff(n, k) else {
                return .double(binomDouble(on, ok))
            }
            k = Swift.min(k, nk)
            if k == 0 { break }
            stack.push((n, k))
            guard case .int(let nn) = overDiff(n, 1) else {
                return .double(binomDouble(on, ok))
            }
            guard case .int(let kk) = overDiff(k, 1) else {
                return .double(binomDouble(on, ok))
            }
            n = nn
            k = kk
        }
        var y = 1
        while let v = stack.pop() {
            guard case .int(let yv0) = overMulti(y, v.0) else {
                return .double(binomDouble(on, ok))
            }
            guard case .int(let yv0v1) = overDiv(yv0, v.1) else {
                return .double(binomDouble(on, ok))
            }
            y = yv0v1
        }
        return .int(y)
    }
}
extension Int: Interpolatable {
    static func linear(_ f0: Int, _ f1: Int,
                       t: Double) -> Int {
        Int(Double.linear(Double(f0), Double(f1), t: t))
    }
    static func firstSpline(_ f1: Int,
                            _ f2: Int, _ f3: Int, t: Double) -> Int {
        Int(Double.firstSpline(Double(f1), Double(f2), Double(f3), t: t))
    }
    static func spline(_ f0: Int, _ f1: Int,
                       _ f2: Int, _ f3: Int, t: Double) -> Int {
        Int(Double.spline(Double(f0), Double(f1), Double(f2), Double(f3), t: t))
    }
    static func lastSpline(_ f0: Int, _ f1: Int,
                           _ f2: Int, t: Double) -> Int {
        Int(Double.lastSpline(Double(f0), Double(f1), Double(f2), t: t))
    }
}
extension Int {
    init(_ o: Bool) {
        self = o ? 1 : 0
    }
}

struct IndexValue<Value> {
    var value: Value
    var index: Int
}
extension IndexValue: Equatable where Value: Equatable {}
extension IndexValue: Hashable where Value: Hashable {}
extension IndexValue: CustomStringConvertible {
    var description: String {
        "(\(value) at: \(index))"
    }
}
extension IndexValue: Codable where Value: Codable {}
