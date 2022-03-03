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

struct Animation<Value: Interpolatable> {
    var keyframes = [Keyframe<Value>]()
}
extension Animation: Codable where Value: Codable {}
extension Animation {
    mutating func insert(_ keyframe: Keyframe<Value>) {
        for (i, aKeyframe) in keyframes.enumerated() {
            if keyframe.time < aKeyframe.time {
                keyframes.insert(keyframe, at: i)
                return
            }
        }
        keyframes.append(keyframe)
    }
    func value(withTime t: Rational) -> Value? {
        if let result = timeResult(withTime: t) {
            return value(with: result)
        } else {
            return nil
        }
    }
    func value(with timeResult: TimeResult) -> Value? {
        guard !keyframes.isEmpty else {
            return nil
        }
        let i1 = timeResult.index, it = timeResult.internalTime
        let k1 = keyframes[i1]
        if k1.type == .step {
            return k1.value
        }
        guard it > 0 && i1 + 1 < keyframes.count,
              let st = timeResult.sectionTime else { return k1.value }
        let k2 = keyframes[i1 + 1]
        if keyframes.count <= 2 || k1.type == .linear {
            let t = Double(it / st)
            return Value.linear(k1.value, k2.value, t: t)
        } else {
            let t = Double(it / st)
            let isUseFirstIndex = i1 - 1 >= 0
            let isUseLastIndex = i1 + 2 < keyframes.count
            if isUseFirstIndex {
                if isUseLastIndex {
                    let k0 = keyframes[i1 - 1], k3 = keyframes[i1 + 2]
                    return Value.spline(k0.value, k1.value,
                                        k2.value, k3.value, t: t)
                } else {
                    let k0 = keyframes[i1 - 1]
                    return Value.lastSpline(k0.value, k1.value, k2.value, t: t)
                }
            } else if isUseLastIndex {
                let k3 = keyframes[i1 + 2]
                return Value.firstSpline(k1.value, k2.value, k3.value, t: t)
            } else {
                let t = Double(it / st)
                return Value.linear(k1.value, k2.value, t: t)
            }
        }
    }
    
    struct TimeResult {
        var index: Int, internalTime: Rational
        var sectionTime: Rational?, time: Rational
    }
    func timeResult(withTime t: Rational) -> TimeResult? {
        guard !keyframes.isEmpty else {
            return nil
        }
        var oldT: Rational?
        for i in (0..<keyframes.count).reversed() {
            let ki = keyframes[i]
            let kt = ki.time
            if t >= kt {
                if let oldT = oldT {
                    return TimeResult(index: i,
                                      internalTime: t - kt,
                                      sectionTime: oldT - kt, time: t)
                } else {
                    return TimeResult(index: i,
                                      internalTime: t - kt,
                                      sectionTime: nil, time: t)
                }
            }
            oldT = kt
        }
        if let oldT = oldT {
            return TimeResult(index: 0,
                              internalTime: t - keyframes.first!.time,
                              sectionTime: oldT - keyframes.first!.time,
                              time: t)
        } else {
            return TimeResult(index: 0,
                              internalTime: 0,
                              sectionTime: nil,
                              time: t)
        }
    }
}

struct Keyframe<Value: Interpolatable> {
    enum KeyframeType: Int8, Codable {
        case step, linear, spline
    }
    var value: Value
    var type = KeyframeType.spline
    var time = Rational(0)
}
extension Keyframe: Codable where Value: Codable {}
