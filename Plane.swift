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

typealias UUColor = UU<Color>
extension UU: Serializable where Value == Color {}
extension UU: Protobuf where Value == Color {
    typealias PB = PBUUColor
    init(_ pb: PBUUColor) throws {
        let value = try Color(pb.value)
        let id = try UUID(pb.id)
        self.init(value, id: id)
    }
    var pb: PBUUColor {
        PBUUColor.with {
            $0.value = value.pb
            $0.id = id.pb
        }
    }
}

struct Plane {
    var polygon = Polygon(), uuColor = UU(Color())
}
extension Plane: Protobuf {
    init(_ pb: PBPlane) throws {
        polygon = try Polygon(pb.polygon)
        uuColor = (try? UUColor(pb.uuColor)) ?? UU(Color())
    }
    var pb: PBPlane {
        PBPlane.with {
            $0.polygon = polygon.pb
            $0.uuColor = uuColor.pb
        }
    }
}
extension Plane: Hashable, Codable {}
extension Plane: AppliableTransform {
    static func * (lhs: Plane, rhs: Transform) -> Plane {
        Plane(polygon: lhs.polygon * rhs, uuColor: lhs.uuColor)
    }
}
extension Plane {
    var path: Path {
        Path(polygon)
    }
    var isEmpty: Bool {
        polygon.isEmpty
    }
    var bounds: Rect? {
        polygon.bounds
    }
    var centroid: Point? {
        polygon.centroid
    }
}
extension Array where Element == Plane {
    var bounds: Rect? {
        var rect = Rect?.none
        for element in self {
            rect = rect + element.bounds
        }
        return rect
    }
}
