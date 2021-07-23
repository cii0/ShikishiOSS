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

enum CircularOrientation: String, Codable {
    case clockwise, counterClockwise
}

enum Orientation: String, Codable, Hashable {
    case horizontal, vertical
}
extension Orientation {
    func reversed() -> Orientation {
        switch self {
        case .horizontal: return .vertical
        case .vertical: return .horizontal
        }
    }
}
extension Orientation: Protobuf {
    init(_ pb: PBOrientation) throws {
        switch pb {
        case .horizontal: self = .horizontal
        case .vertical: self = .vertical
        case .UNRECOGNIZED: self = .horizontal
        }
    }
    var pb: PBOrientation {
        switch self {
        case .horizontal: return .horizontal
        case .vertical: return .vertical
        }
    }
}

enum LRBTOrientation {
    enum Horizontal {
        case leftToRight, rightToLeft
    }
    enum Vertical {
        case bottomToTop, topToBottom
    }
    case horizontal(Horizontal), vertical(Vertical)
}

enum LRTB {
    case left, right, top, bottom
}
