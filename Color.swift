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

struct Color {
    var lcha: LCHA {
        didSet { updateRGBA() }
    }
    private(set) var rgba: RGBA
    var rgbColorSpace: RGBColorSpace {
        didSet { updateRGBA() }
    }
    private mutating func updateRGBA() {
        rgba = lcha.safetyRGBAAndChroma(with: rgbColorSpace).rgba
    }
    
    init() {
        lcha = LCHA()
        rgba = RGBA()
        rgbColorSpace = .sRGB
    }
    init?(lightness: Double, chroma: Double, hue: Double,
          opacity: Double = 1,
          _ rgbColorSpace: RGBColorSpace = .sRGB) {
        
        let lcha = LCHA(lightness, chroma, hue, opacity)
        guard let rgba = RGBA(lcha, rgbColorSpace).clipped() else {
            return nil
        }
        self.lcha = lcha
        self.rgba = rgba
        self.rgbColorSpace = rgbColorSpace
    }
    init(lightness: Double, a: Double, b: Double, opacity: Double = 1,
         _ rgbColorSpace: RGBColorSpace = .sRGB) {
        
        let tint = Point(a, b).polar
        let lcha = LCHA(lightness, tint.r, tint.theta, opacity)
        self.lcha = lcha
        self.rgba = lcha.safetyRGBAAndChroma(with: rgbColorSpace).rgba
        self.rgbColorSpace = rgbColorSpace
    }
    init(lightness: Double, nearestChroma: Double, hue: Double,
         opacity: Double = 1,
         _ rgbColorSpace: RGBColorSpace = .sRGB) {
        
        let lcha = LCHA(lightness, nearestChroma, hue, opacity)
        self.lcha = lcha
        self.rgba = lcha.safetyRGBAAndChroma(with: rgbColorSpace).rgba
        self.rgbColorSpace = rgbColorSpace
    }
    init(lightness: Double, unsafetyChroma: Double, hue: Double,
         opacity: Double = 1,
         _ rgbColorSpace: RGBColorSpace = .sRGB) {
        
        var lcha = LCHA(lightness, unsafetyChroma, hue, opacity)
        let (rgba, chroma) = lcha.safetyRGBAAndChroma(with: rgbColorSpace)
        lcha.c = chroma
        self.lcha = lcha
        self.rgba = rgba
        self.rgbColorSpace = rgbColorSpace
    }
    init(lightness: Double, opacity: Double = 1,
         _ rgbColorSpace: RGBColorSpace = .sRGB) {
        
        self.init(lightness: lightness, unsafetyChroma: 0, hue: 0,
                  opacity: opacity)
    }
    init(white: Double, opacity: Double = 1,
         _ rgbColorSpace: RGBColorSpace = .sRGB) {
        
        let lightness = Double.linear(Color.minLightness, Color.whiteLightness,
                                      t: white)
        self.init(lightness: lightness,
                  unsafetyChroma: 0, hue: 0,
                  opacity: opacity)
    }
    init(red r: Float, green g: Float, blue b: Float, opacity: Double = 1,
         _ rgbColorSpace: RGBColorSpace = .sRGB) {
        
        self.init(RGBA(r, g, b, Float(opacity)), rgbColorSpace)
    }
    init(_ rgba: RGBA, _ rgbColorSpace: RGBColorSpace = .sRGB) {
        self.lcha = LCHA(rgba, rgbColorSpace)
        self.rgba = rgba
        self.rgbColorSpace = rgbColorSpace
    }
}
extension Color: Protobuf {
    init(_ pb: PBColor) throws {
        lcha = try LCHA(pb.lcha)
        rgba = try RGBA(pb.rgba)
        rgbColorSpace = try RGBColorSpace(pb.rgbColorSpace)
    }
    var pb: PBColor {
        PBColor.with {
            $0.lcha = lcha.pb
            $0.rgba = rgba.pb
            $0.rgbColorSpace = rgbColorSpace.pb
        }
    }
}
extension Color {
    static let minLightness = 0.0
    static let whiteLightness = 100.0
    static let minChroma = 0.0
    static let maxChroma = 200.0
}
extension Color {
    static let background = Color(white: 1)
    static let disabled = Color(white: 0.97)
    static let border = Color(white: 0.88)
    static let subBorder = Color(white: 0.8)

    static let selectedWhite = 0.5
    static let subSelectedWhite = 0.8
    static let subSelectedOpacity = 0.25
    static var selected = Color(white: selectedWhite)
    static var subSelected = Color(white: subSelectedWhite,
                                   opacity: subSelectedOpacity)
    static let diselected = Color(white: 0.75)
    static let subDiselected = Color(white: 0.9,
                                     opacity: subSelectedOpacity)

    static let removing = Color(white: 0.7)
    static let subRemoving = Color(white: 1, opacity: 0.8)
    static let content = Color(white: 0)
}

extension Color {
    var lightness: Double {
        get { lcha.l }
        set { lcha.l = newValue }
    }
    var chroma: Double {
        get { lcha.c }
        set { lcha.c = newValue }
    }
    var hue: Double {
        get { lcha.h }
        set { lcha.h = newValue }
    }
    var opacity: Double {
        get { lcha.a }
        set { lcha.a = newValue }
    }
    var white: Double {
        get { lcha.l.clipped(min: Color.minLightness,
                             max: Color.whiteLightness,
                             newMin: 0, newMax: 1) }
        set { lcha.l = Double.linear(Color.minLightness, Color.whiteLightness,
                                     t: newValue) }
    }
    var tint: PolarPoint {
        PolarPoint(chroma, hue)
    }
    var a: Double {
        tint.rectangular.x
    }
    var b: Double {
        tint.rectangular.y
    }
    
    static func randomLightness(_ range: ClosedRange<Double>,
                                interval: Double = 0.0,
                                opacity: Double = 1.0,
                                rgbColorSpace: RGBColorSpace = .sRGB) -> Color {
        let l = interval == 0 ?
            Double.random(in: range) :
            Double(Int.random(in: 0...Int(1 / interval))) * interval
        return Color(lightness: l, unsafetyChroma: 0, hue: 0,
                     opacity: opacity, rgbColorSpace)
    }
    func randomLightness(length: Double = 5) -> Color {
        let minL = max(Color.minLightness, lightness - length)
        let maxL = min(Color.whiteLightness, lightness + length)
        let l = Double.random(in: minL...maxL)
        return Color(lightness: l, unsafetyChroma: chroma, hue: hue,
                     opacity: opacity, rgbColorSpace)
    }
    func with(opacity: Double) -> Color {
        var color = self
        color.opacity = opacity
        return color
    }
}
extension Color {
    static func + (lhs: Color, rhs: Color) -> Color {
        let ll = lhs.lightness, rl = rhs.lightness
        let la = lhs.a, lb = lhs.b, ra = rhs.a, rb = rhs.b
        let nLightness = (ll + rl) / 2
        let na = (la + ra) / 2
        let nb = (lb + rb) / 2
        let tint = Point(na, nb).polar
        let nChroma = tint.r, nHue = tint.theta
        let opacity = (lhs.opacity + rhs.opacity) / 2
        return Color(lightness: nLightness, unsafetyChroma: nChroma, hue: nHue,
                     opacity: opacity)
    }
}
extension Color: Equatable {
    static func == (lhs: Color, rhs: Color) -> Bool {
        lhs.lcha == rhs.lcha
            && lhs.rgbColorSpace == rhs.rgbColorSpace
    }
}
extension Color: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(lcha)
        hasher.combine(rgbColorSpace)
    }
}
extension Color: Interpolatable {
    static func rgbLinear(_ f0: Color, _ f1: Color, t: Double) -> Color {
        Color(RGBA.linear(f0.rgba, f1.rgba, t: t), f0.rgbColorSpace)
    }
    static func linear(_ f0: Color, _ f1: Color, t: Double) -> Color {
        let lightness = Double.linear(f0.lightness, f1.lightness, t: t)
        let a = Double.linear(f0.a, f1.a, t: t)
        let b = Double.linear(f0.b, f1.b, t: t)
        let opacity = Double.linear(f0.opacity, f1.opacity, t: t)
        return Color(lightness: lightness, a: a, b: b, opacity: opacity,
                     f0.rgbColorSpace)
    }
    static func firstSpline(_ f1: Color, _ f2: Color, _ f3: Color,
                            t: Double) -> Color {
        let lightness = Double.firstSpline(f1.lightness,
                                           f2.lightness, f3.lightness, t: t)
        let a = Double.firstSpline(f1.a, f2.a, f3.a, t: t)
        let b = Double.firstSpline(f1.b, f2.b, f3.b, t: t)
        let opacity = Double.firstSpline(f1.opacity,
                                         f2.opacity, f3.opacity, t: t)
        return Color(lightness: lightness, a: a, b: b, opacity: opacity,
                     f1.rgbColorSpace)
    }
    static func spline(_ f0: Color, _ f1: Color, _ f2: Color, _ f3: Color,
                       t: Double) -> Color {
        let lightness = Double.spline(f0.lightness, f1.lightness,
                                      f2.lightness, f3.lightness, t: t)
        let a = Double.spline(f0.a, f1.a, f2.a, f3.a, t: t)
        let b = Double.spline(f0.b, f1.b, f2.b, f3.b, t: t)
        let opacity = Double.spline(f0.opacity, f1.opacity,
                                    f2.opacity, f3.opacity, t: t)
        return Color(lightness: lightness, a: a, b: b, opacity: opacity,
                     f1.rgbColorSpace)
    }
    static func lastSpline(_ f0: Color, _ f1: Color, _ f2: Color,
                           t: Double) -> Color {
        let lightness = Double.lastSpline(f0.lightness, f1.lightness,
                                          f2.lightness, t: t)
        let a = Double.lastSpline(f0.a, f1.a, f2.a, t: t)
        let b = Double.lastSpline(f0.b, f1.b, f2.b, t: t)
        let opacity = Double.lastSpline(f0.opacity, f1.opacity,
                                        f2.opacity, t: t)
        return Color(lightness: lightness, a: a, b: b, opacity: opacity,
                     f1.rgbColorSpace)
    }
}
extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case lcha, rgba, rgbColorSpace = "cs"
    }
}

/// LCH (lightness, chroma, hue) is based on the CIELAB color space.
struct LCHA: Hashable {
    var l, c, h, a: Double
    
    init() {
        l = 0
        c = 0
        h = 0
        a = 1
    }
    init(_ l: Double, _ c: Double, _ h: Double, _ a: Double = 1) {
        self.l = l
        self.c = c
        self.h = h
        self.a = a
    }
}
extension LCHA: Protobuf {
    init(_ pb: PBLCHA) throws {
        l = try pb.l.notNaN()
            .clipped(min: Color.minLightness, max: Color.whiteLightness)
        c = try pb.c.notNaN()
            .clipped(min: Color.minChroma, max: Color.maxChroma)
        h = try pb.h.notNaN().notInfinite()
            .clippedRotation
        a = try pb.a.notNaN()
            .clipped(min: 0, max: 1)
    }
    var pb: PBLCHA {
        PBLCHA.with {
            $0.l = l
            $0.c = c
            $0.h = h
            $0.a = a
        }
    }
}
extension LCHA: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        l = try container.decode(Double.self).notNaN()
            .clipped(min: Color.minLightness, max: Color.whiteLightness)
        c = try container.decode(Double.self).notNaN()
            .clipped(min: Color.minChroma, max: Color.maxChroma)
        h = try container.decode(Double.self).notNaN().notInfinite()
            .clippedRotation
        a = try container.decode(Double.self).notNaN()
            .clipped(min: 0, max: 1)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(l)
        try container.encode(c)
        try container.encode(h)
        try container.encode(a)
    }
}
extension LCHA {
    init(_ rgba: RGBA, _ rgbColorSpace: RGBColorSpace = .sRGB) {
        let rgb = Double3(Double(rgba.r), Double(rgba.g), Double(rgba.b))
        let lab = rgbColorSpace.rgbToLAB(rgb)
        
        let tint = Point(lab.a, lab.b).polar
        self.l = lab.l
        self.c = rgba.isGrayscale ? 0 : tint.r
        self.h = tint.theta
        self.a = Double(rgba.a)
    }
    
    func safetyRGBAAndChroma(with cs: RGBColorSpace)
    -> (rgba: RGBA, chroma: Double) {
        if l >= Color.whiteLightness {
            return (RGBA(1, 1, 1, Float(a)), 0)
        } else if l <= Color.minLightness {
            return (RGBA(0, 0, 0, Float(a)), 0)
        } else if let rgba = RGBA(self, cs).clipped() {
            return (rgba, c)
        } else {
            var newRGBA = RGBA(0, 0, 0, Float(a))
            var newChroma = Color.minChroma
            func bisection(minChroma: Double, maxChroma: Double) {
                let midChroma = (minChroma + maxChroma) / 2
                if let rgba = RGBA(LCHA(l, midChroma, h, a), cs).clipped() {
                    newRGBA = rgba
                    newChroma = midChroma
                    if maxChroma - minChroma <= 0.1 {
                        return
                    } else {
                        bisection(minChroma: midChroma, maxChroma: maxChroma)
                    }
                } else {
                    if maxChroma - minChroma <= 0.001 {
                        return
                    }
                    bisection(minChroma: minChroma, maxChroma: midChroma)
                }
            }
            bisection(minChroma: 0, maxChroma: min(Color.maxChroma, c))
            return (newRGBA, newChroma)
        }
    }
}

struct RGBA: Hashable {
    var r, g, b, a: Float
    
    init() {
        r = 0
        g = 0
        b = 0
        a = 1
    }
    init(_ r: Float, _ g: Float, _ b: Float, _ a: Float = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}
extension RGBA: Protobuf {
    init(_ pb: PBRGBA) throws {
        r = try pb.r.notNaN().notInfinite()
        g = try pb.g.notNaN().notInfinite()
        b = try pb.b.notNaN().notInfinite()
        a = try pb.a.notNaN().clipped(min: 0, max: 1)
    }
    var pb: PBRGBA {
        PBRGBA.with {
            $0.r = Float(r)
            $0.g = Float(g)
            $0.b = Float(b)
            $0.a = Float(a)
        }
    }
}
extension RGBA {
    init(_ lcha: LCHA, _ rgbColorSpace: RGBColorSpace) {
        let rgb = rgbColorSpace.labToRGB(LAB(lcha))
        if lcha.c == 0 {
            r = Float(rgb[0])
            g = Float(rgb[0])
            b = Float(rgb[0])
        } else {
            r = Float(rgb[0])
            g = Float(rgb[1])
            b = Float(rgb[2])
        }
        a = Float(lcha.a)
    }
    
    var isGrayscale: Bool {
        r == g && r == b
    }
    
    func clipped() -> RGBA? {
        let range: ClosedRange<Float> = 0.0...1.0
        if range.contains(r) && range.contains(g) && range.contains(b) {
            return self
        } else {
            return nil
        }
    }
}
extension RGBA: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        r = try container.decode(Float.self).notNaN().notInfinite()
        g = try container.decode(Float.self).notNaN().notInfinite()
        b = try container.decode(Float.self).notNaN().notInfinite()
        a = try container.decode(Float.self).notNaN().clipped(min: 0, max: 1)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(r)
        try container.encode(g)
        try container.encode(b)
        try container.encode(a)
    }
}
extension RGBA: Interpolatable {
    static func linear(_ f0: RGBA, _ f1: RGBA, t: Double) -> RGBA {
        let r = Float.linear(f0.r, f1.r, t: t)
        let g = Float.linear(f0.g, f1.g, t: t)
        let b = Float.linear(f0.b, f1.b, t: t)
        let a = Float.linear(f0.a, f1.a, t: t)
        return RGBA(r, g, b, a)
    }
    static func firstSpline(_ f1: RGBA, _ f2: RGBA,
                            _ f3: RGBA, t: Double) -> RGBA {
        let r = Float.firstSpline(f1.r, f2.r, f3.r, t: t)
        let g = Float.firstSpline(f1.g, f2.g, f3.g, t: t)
        let b = Float.firstSpline(f1.b, f2.b, f3.b, t: t)
        let a = Float.firstSpline(f1.a, f2.a, f3.a, t: t)
        return RGBA(r, g, b, a)
    }
    static func spline(_ f0: RGBA, _ f1: RGBA,
                       _ f2: RGBA, _ f3: RGBA,
                       t: Double) -> RGBA {
        let r = Float.spline(f0.r, f1.r, f2.r, f3.r, t: t)
        let g = Float.spline(f0.g, f1.g, f2.g, f3.g, t: t)
        let b = Float.spline(f0.b, f1.b, f2.b, f3.b, t: t)
        let a = Float.spline(f0.a, f1.a, f2.a, f3.a, t: t)
        return RGBA(r, g, b, a)
    }
    static func lastSpline(_ f0: RGBA, _ f1: RGBA,
                           _ f2: RGBA, t: Double) -> RGBA {
        let r = Float.lastSpline(f0.r, f1.r, f2.r, t: t)
        let g = Float.lastSpline(f0.g, f1.g, f2.g, t: t)
        let b = Float.lastSpline(f0.b, f1.b, f2.b, t: t)
        let a = Float.lastSpline(f0.a, f1.a, f2.a, t: t)
        return RGBA(r, g, b, a)
    }
}

enum RGBColorSpace: Int8, Codable, Hashable {
    // Referenced definition:
    // International Color Consortium.
    // "How to interpret the sRGB color space
    // (specified in IEC 61966-2-1) for ICC profiles".
    // http://color.org/chardata/rgb/sRGB.pdf, 2015-4 (accessed 2021-01-24)
    /// CIE Illuminant D65
    case sRGB
}
extension RGBColorSpace {
    func gamma(_ x: Double) -> Double {
        switch self {
        case .sRGB:
            return x <= 0.04045 ?
                x / 12.92 :
                ((x + 0.055) / 1.055) ** 2.4
        }
    }
    func rgamma(_ x: Double) -> Double {
        switch self {
        case .sRGB:
            return x <= 0.0031308 ?
                12.92 * x :
                1.055 * (x ** (1 / 2.4)) - 0.055
        }
    }
    func rgbToLinearRGB(_ rgb: Double3) -> Double3 {
        Double3(gamma(rgb[0]),
                gamma(rgb[1]),
                gamma(rgb[2]))
    }
    func linearRGBToRGB(_ linearRGB: Double3) -> Double3 {
        Double3(rgamma(linearRGB[0]),
                rgamma(linearRGB[1]),
                rgamma(linearRGB[2]))
    }
    
    static let xyzICCD50WhitePoint = Double3(0.9642, 1.0, 0.8249)
    
    static let linearSRGBToXYZICCD50Matrix
        = Double3x3(0.436030342570117, 0.385101860087134, 0.143067806654203,
                    0.222438466210245, 0.716942745571917, 0.060618777416563,
                    0.013897440074263, 0.097076381494207, 0.713926257896652)
    static let xyzICCD50ToLinearSRGBMatrix
        = Double3x3(3.1339236463378164, -1.6169229392738516, -0.490733723087733,
                    -0.9784210516720576, 1.915842665313229, 0.0333991269959624,
                    0.07203553396859233, -0.22903203517027076, 1.4057161576769963)
    
    var linearRGBToXYZICCD50Matrix: Double3x3 {
        switch self {
        case .sRGB: return RGBColorSpace.linearSRGBToXYZICCD50Matrix
        }
    }
    func linearRGBToXYZICCD50(_ linearRGB: Double3) -> Double3 {
        linearRGBToXYZICCD50Matrix * linearRGB
    }
    var xyzICCD50ToLinearRGBMatrix: Double3x3 {
        switch self {
        case .sRGB: return RGBColorSpace.xyzICCD50ToLinearSRGBMatrix
        }
    }
    func xyzICCD50ToLinearRGB(_ xyzICCD50: Double3) -> Double3 {
        xyzICCD50ToLinearRGBMatrix * xyzICCD50
    }
    
    func labToRGB(_ lab: LAB) -> Double3 {
        let xyzICCD50 = lab.xyz(withWhitePoint: RGBColorSpace.xyzICCD50WhitePoint)
        let linearRGB = xyzICCD50ToLinearRGB(xyzICCD50)
        return linearRGBToRGB(linearRGB)
    }
    func rgbToLAB(_ rgb: Double3) -> LAB {
        let linearRGB = rgbToLinearRGB(rgb)
        let xyzICCD50 = linearRGBToXYZICCD50(linearRGB)
        return LAB(xyzICCD50, whitePoint: RGBColorSpace.xyzICCD50WhitePoint)
    }
}
extension RGBColorSpace: Protobuf {
    init(_ pb: PBRGBColorSpace) throws {
        switch pb {
        case .sRgb: self = .sRGB
        case .UNRECOGNIZED: self = .sRGB
        }
    }
    var pb: PBRGBColorSpace {
        switch self {
        case .sRGB: return .sRgb
        }
    }
}
extension RGBColorSpace: CustomStringConvertible {
    var description: String {
        switch self {
        case .sRGB: return "sRGB"
        }
    }
}

struct LAB {
    var l, a, b: Double
}
extension LAB {
    init(_ lcha: LCHA) {
        let abPoint = PolarPoint(lcha.c, lcha.h).rectangular
        l = lcha.l
        a = abPoint.x
        b = abPoint.y
    }
    
    // Referenced definition:
    // JIS Z 8781-4:2013. 測色－第４部：ＣＩＥ １９７６ Ｌ＊ａ＊ｂ＊色空間.
    init(_ xyz: Double3, whitePoint: Double3) {
        func f(_ t: Double) -> Double {
            t > 216 / 24389 ?
                t ** (1 / 3) :
                (841 / 108) * t + 4 / 29
        }
        let n = xyz / whitePoint
        let fy = f(n.y)
        l = 116 * fy - 16
        a = 500 * (f(n.x) - fy)
        b = 200 * (fy - f(n.z))
    }
    func xyz(withWhitePoint whitePoint: Double3) -> Double3 {
        func f(_ t: Double) -> Double {
            t > 6 / 29 ?
                t * t * t :
                (108 / 841) * (t - 4 / 29)
        }
        let fl = (l + 16) / 116
        return whitePoint * Double3(f(fl + a / 500),
                                    f(fl),
                                    f(fl - b / 200))
    }
}
