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

struct Double3x3 {
    var column0: Double3, column1: Double3, column2: Double3
}
extension Double3x3 {
    static let identity = Double3x3(1)
    
    init() {
        self.column0 = Double3()
        self.column1 = Double3()
        self.column2 = Double3()
    }
    init(_ m00: Double, _ m10: Double, _ m20: Double,
         _ m01: Double, _ m11: Double, _ m21: Double,
         _ m02: Double, _ m12: Double, _ m22: Double) {
        
        self.init(column0: Double3(m00, m01, m02),
                  column1: Double3(m10, m11, m12),
                  column2: Double3(m20, m21, m22))
    }
    init(_ v: Int) {
        self.init(Double(v))
    }
    init(_ v: Rational) {
        self.init(Double(v))
    }
    init(_ v: Double) {
        self.init(column0: Double3(v, 0, 0),
                  column1: Double3(0, v, 0),
                  column2: Double3(0, 0, v))
    }
    
    var row0: Double3 {
        Double3(self[0][0], self[1][0], self[2][0])
    }
    var row1: Double3 {
        Double3(self[0][1], self[1][1], self[2][1])
    }
    var row2: Double3 {
        Double3(self[0][2], self[1][2], self[2][2])
    }
    
    static func + (lhs: Double3x3, rhs: Double3x3) -> Double3x3 {
        Double3x3(column0: lhs.column0 + rhs.column0,
                  column1: lhs.column1 + rhs.column1,
                  column2: lhs.column2 + rhs.column2)
    }
    static func += (lhs: inout Double3x3, rhs: Double3x3) {
        lhs = lhs + rhs
    }
    prefix static func - (x: Double3x3) -> Double3x3 {
        Double3x3(column0: -x.column0,
                  column1: -x.column1,
                  column2: -x.column2)
    }
    static func - (lhs: Double3x3, rhs: Double3x3) -> Double3x3 {
        Double3x3(column0: lhs.column0 - rhs.column0,
                  column1: lhs.column1 - rhs.column1,
                  column2: lhs.column2 - rhs.column2)
    }
    static func -= (lhs: inout Double3x3, rhs: Double3x3) {
        lhs = lhs - rhs
    }
    static func * (lhs: Double3x3, rhs: Double3x3) -> Double3x3 {
        let a0 = lhs.column0 * rhs.column0.x
        let a1 = lhs.column1 * rhs.column0.y
        let a2 = lhs.column2 * rhs.column0.z
        let b0 = lhs.column0 * rhs.column1.x
        let b1 = lhs.column1 * rhs.column1.y
        let b2 = lhs.column2 * rhs.column1.z
        let c0 = lhs.column0 * rhs.column2.x
        let c1 = lhs.column1 * rhs.column2.y
        let c2 = lhs.column2 * rhs.column2.z
        return Double3x3(column0: a0 + a1 + a2,
                         column1: b0 + b1 + b2,
                         column2: c0 + c1 + c2)
    }
    static func * (lhs: Double3, rhs: Double3x3) -> Double3 {
        let a0 = lhs.x * rhs.row0
        let a1 = lhs.y * rhs.row1
        let a2 = lhs.z * rhs.row2
        return a0 + a1 + a2
    }
    static func * (lhs: Double3x3, rhs: Double3) -> Double3 {
        let a0 = lhs.column0 * rhs.x
        let a1 = lhs.column1 * rhs.y
        let a2 = lhs.column2 * rhs.z
        return a0 + a1 + a2
    }
    static func * (lhs: Double, rhs: Double3x3) -> Double3x3 {
        Double3x3(column0: lhs * rhs.column0,
                  column1: lhs * rhs.column1,
                  column2: lhs * rhs.column2)
    }
    static func * (lhs: Double3x3, rhs: Double) -> Double3x3 {
        Double3x3(column0: lhs.column0 * rhs,
                  column1: lhs.column1 * rhs,
                  column2: lhs.column2 * rhs)
    }
    static func *= (lhs: inout Double3x3, rhs: Double3x3) {
        lhs = lhs * rhs
    }
    var isIdentity: Bool {
        self == Double3x3.identity
    }
    func inverted() -> Double3x3 {
        let a0 = Double3(column0.x, column1.x, column2.x)
            * Double3(column1.y, column2.y, column0.y)
            * Double3(column2.z, column0.z, column1.z)
        let a1 = Double3(column2.x, column1.x, column0.x)
            * Double3(column1.y, column0.y, column2.y)
            * Double3(column0.z, column2.z, column1.z)
        
        let c0 = Double3(column1.y, column2.y, column0.y)
            * Double3(column2.z, column0.z, column1.z)
            - Double3(column2.y, column0.y, column1.y)
            * Double3(column1.z, column2.z, column0.z)
        let c1 = Double3(column2.x, column0.x, column1.x)
            * Double3(column1.z, column2.z, column0.z)
            - Double3(column1.x, column2.x, column0.x)
            * Double3(column2.z, column0.z, column1.z)
        let c2 = Double3(column1.x, column2.x, column0.x)
            * Double3(column2.y, column0.y, column1.y)
            - Double3(column2.x, column0.x, column1.x)
            * Double3(column1.y, column2.y, column0.y)
        
        let d = 1 / (a0.sum() - a1.sum())
        return d * Double3x3(column0: c0, column1: c1, column2: c2)
    }
    subscript(i: Int) -> Double3 {
        switch i {
        case 0: return column0
        case 1: return column1
        case 2: return column2
        default: fatalError()
        }
    }
    
    func rounded(_ rule: FloatingPointRoundingRule
                    = .toNearestOrAwayFromZero) -> Double3x3 {
        Double3x3(column0: column0.rounded(rule),
                  column1: column1.rounded(rule),
                  column2: column2.rounded(rule))
    }
}
extension Double3x3: Hashable {}
extension Double3x3: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let column0 = try container.decode(Double3.self)
        let column1 = try container.decode(Double3.self)
        let column2 = try container.decode(Double3.self)
        self.init(column0: column0, column1: column1, column2: column2)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self[0])
        try container.encode(self[1])
        try container.encode(self[2])
    }
}
extension Double3x3: CustomStringConvertible {
    var description: String {
        """
\(column0.x) \(column1.x) \(column2.x)
\(column0.y) \(column1.y) \(column2.y)
\(column0.z) \(column1.z) \(column2.z)
"""
    }
}
typealias Transform = Double3x3
extension Transform {
    init(translation t: Point) {
        self.init(1, 0, 0,
                  0, 1, 0,
                  t.x, t.y, 1)
    }
    init(translationX x: Double, y: Double) {
        self.init(1, 0, 0,
                  0, 1, 0,
                  x, y, 1)
    }
    init(scale: Double) {
        self.init(scale, 0, 0,
                  0, scale, 0,
                  0, 0, 1)
    }
    init(scaleX x: Double, y: Double) {
        self.init(x, 0, 0,
                  0, y, 0,
                  0, 0, 1)
    }
    init(rotation: Double) {
        let cosR = Double.cos(rotation), sinR = Double.sin(rotation)
        self.init(cosR, sinR, 0,
                  -sinR, cosR, 0,
                  0, 0, 1)
    }
    init(viewportSize s: Size) {
        let w2 = s.width / 2, h2 = s.height / 2
        self.init(w2, 0, 0,
                  0, h2, 0,
                  w2, h2, 1)
    }
    init(invertedViewportSize s: Size) {
        self.init(2 / s.width, 0, 0,
                  0, 2 / s.height, 0,
                  -1, -1, 1)
    }
    
    func translatedBy(x: Double, y: Double) -> Transform {
        self * Transform(translationX: x, y: y)
    }
    func translated(by t: Point) -> Transform {
        translatedBy(x: t.x, y: t.y)
    }
    mutating func translateBy(x: Double, y: Double) {
        self *= Transform(translationX: x, y: y)
    }
    mutating func translate(by t: Point) {
        self *= Transform(translation: t)
    }
    
    func scaledBy(x: Double, y: Double) -> Transform {
        self * Transform(scaleX: x, y: y)
    }
    func scaled(by scale: Double) -> Transform {
        scaledBy(x: scale, y: scale)
    }
    func scaled(byLogScale logScale: Double) -> Transform {
        let scale = 2 ** logScale
        return scaledBy(x: scale, y: scale)
    }
    mutating func scaleBy(x: Double, y: Double) {
        self *= Transform(scaleX: x, y: y)
    }
    mutating func scale(by scale: Double) {
        self *= Transform(scale: scale)
    }
    mutating func scale(byLog2Scale log2Scale: Double) {
        let scale = 2 ** log2Scale
        scaleBy(x: scale, y: scale)
    }
    
    func rotated(by rotation: Double) -> Transform {
        self * Transform(rotation: rotation)
    }
    mutating func rotate(by rotation: Double) {
        self *= Transform(rotation: rotation)
    }
    
    var position: Point {
        Point(self[0][2], self[1][2])
    }
    var xScale: Double {
        let m00 = self[0][0], m10 = self[1][0]
        return m10 == 0 ? m00 : m00.signValue * .hypot(m00, m10)
    }
    var yScale: Double {
        let m01 = self[0][1], m11 = self[1][1]
        return m01 == 0 ? m11 : m11.signValue * .hypot(m01, m11)
    }
    var absScale: Size {
        Size(width: absXScale, height: absYScale)
    }
    var absXScale: Double {
        let m00 = self[0][0], m10 = self[1][0]
        return .hypot(m00, m10)
    }
    var absYScale: Double {
        let m01 = self[0][1], m11 = self[1][1]
        return .hypot(m01, m11)
    }
    var log2Scale: Double {
        .log2(absXScale)
    }
    var angle: Double {
        .atan2(y: self[1][0], x: self[0][0])
    }
}
extension Transform {
    static func centering(from fromFrame: Rect,
                          to toFrame: Rect) -> (scale: Double,
                                                transform: Transform) {
        guard !fromFrame.isEmpty && !toFrame.isEmpty else {
            return (1, .identity)
        }
        var transform = Transform.identity
        let fromRatio = fromFrame.width / fromFrame.height
        let toRatio = toFrame.width / toFrame.height
        if fromRatio > toRatio {
            let xScale = toFrame.width / fromFrame.size.width
            let y = toFrame.origin.y
                + (toFrame.height - fromFrame.height * xScale) / 2
            transform.translate(by: -fromFrame.origin)
            transform.scale(by: xScale)
            transform.translateBy(x: toFrame.origin.x, y: y)
            return (xScale, transform)
        } else {
            let yScale = toFrame.height / fromFrame.size.height
            let x = toFrame.origin.x
                + (toFrame.width - fromFrame.width * yScale) / 2
            transform.translate(by: -fromFrame.origin)
            transform.scale(by: yScale)
            transform.translateBy(x: x, y: toFrame.origin.y)
            return (yScale, transform)
        }
    }
}
extension Transform {
    var floatData4x4: [Float] {
        [Float(self[0][0]), Float(self[0][1]), 0, Float(self[0][2]),
         Float(self[1][0]), Float(self[1][1]), 0, Float(self[1][2]),
         0, 0, 1, 0,
         Float(self[2][0]), Float(self[2][1]), 0, Float(self[2][2])]
    }
}
protocol AppliableTransform {
    static func * (lhs: Self, rhs: Transform) -> Self
}
extension AppliableTransform {
    static func *= (lhs: inout Self, rhs: Transform) {
        lhs = lhs * rhs
    }
}

struct Attitude {
    var position = Point(), scale = Size(square: 1), rotation = 0.0
}
extension Attitude: Protobuf {
    init(_ pb: PBAttitude) throws {
        position = try Point(pb.position).notInfinite()
        scale = try Size(pb.scale).notInfinite()
        rotation = try pb.rotation.notNaN()
    }
    var pb: PBAttitude {
        PBAttitude.with {
            $0.position = position.pb
            $0.scale = scale.pb
            $0.rotation = rotation
        }
    }
}
extension Attitude {
    init(position: Point = Point(), z: Double, rotation: Double = 0) {
        self.position = position
        scale = Size(square: 2 ** z)
        self.rotation = rotation
    }
    init(_ transform: Transform) {
        self.position = transform.position
        self.scale = Size(width: transform.absXScale,
                          height: transform.absYScale)
        self.rotation = transform.angle
    }
    var transform: Transform {
        if scale == Size(square: 1) {
            if rotation == 0 {
                return Transform(translation: position)
            } else {
                return Transform(rotation: rotation)
                    .translated(by: position)
            }
        } else {
            if rotation == 0 {
                return Transform(scaleX: scale.width, y: scale.height)
                    .translated(by: position)
            } else {
                return Transform(scaleX: scale.width, y: scale.height)
                    .rotated(by: rotation)
                    .translated(by: position)
            }
        }
    }
}
extension Attitude: Hashable, Codable {}
extension Attitude: AppliableTransform {
    static func * (lhs: Attitude, rhs: Transform) -> Attitude {
        Attitude(lhs.transform * rhs)
    }
}
extension Attitude: Interpolatable {
    static func linear(_ f0: Attitude, _ f1: Attitude,
                       t: Double) -> Attitude {
        let position = Point.linear(f0.position, f1.position, t: t)
        let scale = Size.linear(f0.scale, f1.scale, t: t)
        let rotation = Double.linear(f0.rotation, f1.rotation, t: t)
        return Attitude(position: position, scale: scale, rotation: rotation)
    }
    static func firstSpline(_ f1: Attitude,
                            _ f2: Attitude, _ f3: Attitude,
                            t: Double) -> Attitude {
        let position = Point.firstSpline(f1.position,
                                         f2.position, f3.position, t: t)
        let scale = Size.firstSpline(f1.scale,
                                     f2.scale, f3.scale, t: t)
        let rotation = Double.firstSpline(f1.rotation,
                                          f2.rotation, f3.rotation, t: t)
        return Attitude(position: position, scale: scale, rotation: rotation)
    }
    static func spline(_ f0: Attitude, _ f1: Attitude,
                       _ f2: Attitude, _ f3: Attitude,
                       t: Double) -> Attitude {
        let position = Point.spline(f0.position, f1.position,
                                    f2.position, f3.position, t: t)
        let scale = Size.spline(f0.scale, f1.scale,
                                f2.scale, f3.scale, t: t)
        let rotation = Double.spline(f0.rotation, f1.rotation,
                                     f2.rotation, f3.rotation, t: t)
        return Attitude(position: position, scale: scale, rotation: rotation)
    }
    static func lastSpline(_ f0: Attitude, _ f1: Attitude,
                           _ f2: Attitude,
                           t: Double) -> Attitude {
        let position = Point.lastSpline(f0.position, f1.position,
                                        f2.position, t: t)
        let scale = Size.lastSpline(f0.scale, f1.scale,
                                    f2.scale, t: t)
        let rotation = Double.lastSpline(f0.rotation, f1.rotation,
                                         f2.rotation, t: t)
        return Attitude(position: position, scale: scale, rotation: rotation)
    }
}
extension Attitude {
    var logScale: Double {
        get { .log2(scale.width) }
        set {
            let pow2 = 2 ** newValue
            scale = Size(width: pow2, height: pow2)
        }
    }
}
