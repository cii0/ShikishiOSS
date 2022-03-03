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

protocol Interpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self
    static func firstSpline(_ f1: Self,
                            _ f2: Self, _ f3: Self, t: Double) -> Self
    static func spline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, t: Double) -> Self
    static func lastSpline(_ f0: Self, _ f1: Self,
                           _ f2: Self, t: Double) -> Self
}

extension Array: Interpolatable where Element: Interpolatable {
    static func linear(_ f0: [Element], _ f1: [Element],
                       t: Double) -> [Element] {
        if f0.isEmpty {
            return f0
        }
        return f0.enumerated().map { i, e0 in
            if i >= f1.count {
                return e0
            }
            let e1 = f1[i]
            return Element.linear(e0, e1, t: t)
        }
    }
    static func firstSpline(_ f1: [Element],
                            _ f2: [Element], _ f3: [Element],
                            t: Double) -> [Element] {
        if f1.isEmpty {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            if i >= f2.count {
                return e1
            }
            let e2 = f2[i]
            let e3 = i >= f3.count ? e2 : f3[i]
            return Element.firstSpline(e1, e2, e3, t: t)
        }
    }
    static func spline(_ f0: [Element], _ f1: [Element],
                       _ f2: [Element], _ f3: [Element],
                       t: Double) -> [Element] {
        if f1.isEmpty {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            if i >= f2.count {
                return e1
            }
            let e0 = i >= f0.count ? e1 : f0[i]
            let e2 = f2[i]
            let e3 = i >= f3.count ? e2 : f3[i]
            return Element.spline(e0, e1, e2, e3, t: t)
        }
    }
    static func lastSpline(_ f0: [Element], _ f1: [Element],
                           _ f2: [Element],
                           t: Double) -> [Element] {
        if f1.isEmpty {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            if i >= f2.count {
                return e1
            }
            let e0 = i >= f0.count ? e1 : f0[i]
            let e2 = f2[i]
            return Element.lastSpline(e0, e1, e2, t: t)
        }
    }
}

extension Optional: Interpolatable where Wrapped: Interpolatable {
    static func linear(_ f0: Optional, _ f1: Optional,
                       t: Double) -> Optional {
        if let f0 = f0 {
            if let f1 = f1 {
                return Wrapped.linear(f0, f1, t: t)
            } else {
                return f0
            }
        } else {
            return nil
        }
    }
    static func firstSpline(_ f1: Optional,
                            _ f2: Optional, _ f3: Optional,
                            t: Double) -> Optional {
        if let f1 = f1 {
            if let f2 = f2 {
                if let f3 = f3 {
                    return Wrapped.firstSpline(f1, f2, f3, t: t)
                } else {
                    return Wrapped.linear(f1, f2, t: t)
                }
            } else {
                return f1
            }
        } else {
            return nil
        }
    }
    static func spline(_ f0: Optional, _ f1: Optional,
                       _ f2: Optional, _ f3: Optional,
                       t: Double) -> Optional {
        if let f1 = f1 {
            if let f2 = f2 {
                if let f0 = f0 {
                    if let f3 = f3 {
                        return Wrapped.spline(f0, f1, f2, f3, t: t)
                    } else {
                        return Wrapped.lastSpline(f0, f1, f2, t: t)
                    }
                } else {
                    if let f3 = f3 {
                        return Wrapped.firstSpline(f1, f2, f3, t: t)
                    } else {
                        return Wrapped.linear(f1, f2, t: t)
                    }
                }
            } else {
                return f1
            }
        } else {
            return nil
        }
    }
    static func lastSpline(_ f0: Optional, _ f1: Optional,
                           _ f2: Optional,
                           t: Double) -> Optional {
        if let f1 = f1 {
            if let f2 = f2 {
                if let f0 = f0 {
                    return Wrapped.lastSpline(f0, f1, f2, t: t)
                } else {
                    return Wrapped.linear(f1, f2, t: t)
                }
            } else {
                return f1
            }
        } else {
            return nil
        }
    }
}
