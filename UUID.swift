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

import struct Foundation.UUID

extension UUID: Protobuf {
    init(_ pb: PBUUID) throws {
        if let v = UUID(uuidString: pb.value) {
            self = v
        } else {
            throw ProtobufError()
        }
    }
    var pb: PBUUID {
        PBUUID.with {
            $0.value = uuidString
        }
    }
}
extension UUID {
    init(index i: UInt8) {
        self.init(uuid: (i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i))
    }
    
    static let zero = UUID(index: 0)
    static let one = UUID(index: 1)
}

struct UU<Value: Codable>: Codable {
    var value: Value {
        didSet {
            id = UUID()
        }
    }
    private(set) var id: UUID
    
    init(_ value: Value, id: UUID = UUID()) {
        self.value = value
        self.id = id
    }
}
extension UU: Equatable {
    static func == (lhs: UU<Value>, rhs: UU<Value>) -> Bool {
        lhs.id == rhs.id
    }
}
extension UU: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
extension UU: Interpolatable where Value: Interpolatable {
    static func linear(_ f0: UU<Value>, _ f1: UU<Value>,
                       t: Double) -> UU<Value> {
        let value = Value.linear(f0.value, f1.value, t: t)
        return UU(value)
    }
    static func firstSpline(_ f1: UU<Value>,
                            _ f2: UU<Value>, _ f3: UU<Value>,
                            t: Double) -> UU<Value> {
        let value = Value.firstSpline(f1.value, f2.value, f3.value, t: t)
        return UU(value)
    }
    static func spline(_ f0: UU<Value>, _ f1: UU<Value>,
                       _ f2: UU<Value>, _ f3: UU<Value>,
                       t: Double) -> UU<Value> {
        let value = Value.spline(f0.value, f1.value, f2.value, f3.value, t: t)
        return UU(value)
    }
    static func lastSpline(_ f0: UU<Value>, _ f1: UU<Value>,
                           _ f2: UU<Value>,
                           t: Double) -> UU<Value> {
        let value = Value.lastSpline(f0.value, f1.value, f2.value, t: t)
        return UU(value)
    }
}
