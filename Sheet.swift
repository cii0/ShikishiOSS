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

struct PlaneValue {
    var planes: [Plane]
    var moveIndexValues: [IndexValue<Int>]
}
extension PlaneValue: Protobuf {
    init(_ pb: PBPlaneValue) throws {
        planes = try pb.planes.map { try Plane($0) }
        moveIndexValues = try pb.moveIndexValues.map { try IndexValue<Int>($0) }
    }
    var pb: PBPlaneValue {
        PBPlaneValue.with {
            $0.planes = planes.map { $0.pb }
            $0.moveIndexValues = moveIndexValues.map { $0.pb }
        }
    }
}
extension PlaneValue: Codable {}

struct ColorValue {
    var uuColor: UUColor
    var planeIndexes: [Int], isBackground: Bool
}
extension ColorValue: Protobuf {
    init(_ pb: PBColorValue) throws {
        uuColor = try UUColor(pb.uuColor)
        planeIndexes = pb.planeIndexes.map { Int($0) }
        isBackground = pb.isBackground
    }
    var pb: PBColorValue {
        PBColorValue.with {
            $0.uuColor = uuColor.pb
            $0.planeIndexes = planeIndexes.map { Int64($0) }
            $0.isBackground = isBackground
        }
    }
}
extension ColorValue: Codable {}

struct TextValue: Hashable, Codable {
    var string: String, replacedRange: Range<Int>, origin: Point?, size: Double?
}
extension TextValue {
    var newRange: Range<Int> {
        replacedRange.lowerBound..<(replacedRange.lowerBound + string.count)
    }
}
extension TextValue: Protobuf {
    init(_ pb: PBTextValue) throws {
        string = pb.string
        replacedRange = try Range<Int>(pb.replacedRange)
        if case .origin(let origin)? = pb.originOptional {
            self.origin = try Point(origin)
        } else {
            origin = nil
        }
        if case .size(let size)? = pb.sizeOptional {
            self.size = size
        } else {
            size = nil
        }
    }
    var pb: PBTextValue {
        PBTextValue.with {
            $0.string = string
            $0.replacedRange = replacedRange.pb
            if let origin = origin {
                $0.originOptional = .origin(origin.pb)
            } else {
                $0.originOptional = nil
            }
            if let size = size {
                $0.sizeOptional = .size(size)
            } else {
                $0.sizeOptional = nil
            }
        }
    }
}

struct SheetValue {
    var lines = [Line](), planes = [Plane](), texts = [Text]()
}
extension SheetValue {
    var string: String? {
        if texts.count == 1 {
            return texts[0].string
        } else {
            return nil
        }
    }
    var allTextsString: String {
        let strings = texts
            .sorted(by: { $0.origin.y == $1.origin.y ? $0.origin.x < $1.origin.x : $0.origin.y > $1.origin.y })
            .map { $0.string }
        var str = ""
        for nstr in strings {
            str += nstr
            str += "\n\n\n\n"
        }
        return str
    }
}
extension SheetValue: Protobuf {
    init(_ pb: PBSheetValue) throws {
        lines = try pb.lines.map { try Line($0) }
        planes = try pb.planes.map { try Plane($0) }
        texts = try pb.texts.map { try Text($0) }
    }
    var pb: PBSheetValue {
        PBSheetValue.with {
            $0.lines = lines.map { $0.pb }
            $0.planes = planes.map { $0.pb }
            $0.texts = texts.map { $0.pb }
        }
    }
}
extension SheetValue: Codable {}
extension SheetValue: AppliableTransform {
    static func * (lhs: SheetValue, rhs: Transform) -> SheetValue {
        SheetValue(lines: lhs.lines.map { $0 * rhs },
                   planes: lhs.planes.map { $0 * rhs },
                   texts: lhs.texts.map { $0 * rhs })
    }
}
extension SheetValue {
    var isEmpty: Bool {
        lines.isEmpty && planes.isEmpty && texts.isEmpty
    }
    static func + (lhs: SheetValue, rhs: SheetValue) -> SheetValue {
        SheetValue(lines: lhs.lines + rhs.lines,
                   planes: lhs.planes + rhs.planes,
                   texts: lhs.texts + rhs.texts)
    }
    static func += (lhs: inout SheetValue, rhs: SheetValue) {
        lhs.lines += rhs.lines
        lhs.planes += rhs.planes
        lhs.texts += rhs.texts
    }
}

extension Array where Element == Int {
    init(_ pb: PBInt64Array) throws {
        self = pb.value.map { Int($0) }
    }
    var pb: PBInt64Array {
        PBInt64Array.with { $0.value = map { Int64($0) } }
    }
}
extension Array where Element == Line {
    init(_ pb: PBLineArray) throws {
        self = try pb.value.map { try Line($0) }
    }
    var pb: PBLineArray {
        PBLineArray.with { $0.value = map { $0.pb } }
    }
}
extension Array where Element == Plane {
    init(_ pb: PBPlaneArray) throws {
        self = try pb.value.map { try Plane($0) }
    }
    var pb: PBPlaneArray {
        PBPlaneArray.with { $0.value = map { $0.pb } }
    }
}
extension IndexValue where Value == Int {
    init(_ pb: PBIntIndexValue) throws {
        value = Int(pb.value)
        index = Int(pb.index)
    }
    var pb: PBIntIndexValue {
        PBIntIndexValue.with {
            $0.value = Int64(value)
            $0.index = Int64(index)
        }
    }
}
extension Array where Element == IndexValue<Int> {
    init(_ pb: PBIntIndexValueArray) throws {
        self = try pb.value.map { try IndexValue<Int>($0) }
    }
    var pb: PBIntIndexValueArray {
        PBIntIndexValueArray.with { $0.value = map { $0.pb } }
    }
}
extension IndexValue where Value == Line {
    init(_ pb: PBLineIndexValue) throws {
        value = try Line(pb.value)
        index = Int(pb.index)
    }
    var pb: PBLineIndexValue {
        PBLineIndexValue.with {
            $0.value = value.pb
            $0.index = Int64(index)
        }
    }
}
extension IndexValue where Value == Plane {
    init(_ pb: PBPlaneIndexValue) throws {
        value = try Plane(pb.value)
        index = Int(pb.index)
    }
    var pb: PBPlaneIndexValue {
        PBPlaneIndexValue.with {
            $0.value = value.pb
            $0.index = Int64(index)
        }
    }
}
extension IndexValue where Value == Text {
    init(_ pb: PBTextIndexValue) throws {
        value = try Text(pb.value)
        index = Int(pb.index)
    }
    var pb: PBTextIndexValue {
        PBTextIndexValue.with {
            $0.value = value.pb
            $0.index = Int64(index)
        }
    }
}
extension IndexValue where Value == Border {
    init(_ pb: PBBorderIndexValue) throws {
        value = try Border(pb.value)
        index = Int(pb.index)
    }
    var pb: PBBorderIndexValue {
        PBBorderIndexValue.with {
            $0.value = value.pb
            $0.index = Int64(index)
        }
    }
}
extension IndexValue where Value == TextValue {
    init(_ pb: PBTextValueIndexValue) throws {
        value = try TextValue(pb.value)
        index = Int(pb.index)
    }
    var pb: PBTextValueIndexValue {
        PBTextValueIndexValue.with {
            $0.value = value.pb
            $0.index = Int64(index)
        }
    }
}
extension Array where Element == IndexValue<Line> {
    init(_ pb: PBLineIndexValueArray) throws {
        self = try pb.value.map { try IndexValue<Line>($0) }
    }
    var pb: PBLineIndexValueArray {
        PBLineIndexValueArray.with { $0.value = map { $0.pb } }
    }
}
extension Array where Element == IndexValue<Plane> {
    init(_ pb: PBPlaneIndexValueArray) throws {
        self = try pb.value.map { try IndexValue<Plane>($0) }
    }
    var pb: PBPlaneIndexValueArray {
        PBPlaneIndexValueArray.with { $0.value = map { $0.pb } }
    }
}
extension Array where Element == IndexValue<Text> {
    init(_ pb: PBTextIndexValueArray) throws {
        self = try pb.value.map { try IndexValue<Text>($0) }
    }
    var pb: PBTextIndexValueArray {
        PBTextIndexValueArray.with { $0.value = map { $0.pb } }
    }
}
extension Array where Element == IndexValue<Border> {
    init(_ pb: PBBorderIndexValueArray) throws {
        self = try pb.value.map { try IndexValue<Border>($0) }
    }
    var pb: PBBorderIndexValueArray {
        PBBorderIndexValueArray.with { $0.value = map { $0.pb } }
    }
}

enum SheetUndoItem {
    case appendLine(_ line: Line)
    case appendLines(_ lines: [Line])
    case appendPlanes(_ planes: [Plane])
    case removeLastLines(count: Int)
    case removeLastPlanes(count: Int)
    case insertLines(_ lineIndexValues: [IndexValue<Line>])
    case insertPlanes(_ planeIndexValues: [IndexValue<Plane>])
    case removeLines(lineIndexes: [Int])
    case removePlanes(planeIndexes: [Int])
    case setPlaneValue(_ planeValue: PlaneValue)
    case changeToDraft(isReverse: Bool)
    case setPicture(_ picture: Picture)
    case insertDraftLines(_ lineIndexValues: [IndexValue<Line>])
    case insertDraftPlanes(_ planeIndexValues: [IndexValue<Plane>])
    case removeDraftLines(lineIndexes: [Int])
    case removeDraftPlanes(planeIndexes: [Int])
    case setDraftPicture(_ picture: Picture)
    case insertTexts(_ textIndexValues: [IndexValue<Text>])
    case removeTexts(textIndexes: [Int])
    case replaceString(_ textIndexValue: IndexValue<TextValue>)
    case changedColors(_ colorUndoValue: ColorValue)
    case insertBorders(_ borderIndexValues: [IndexValue<Border>])
    case removeBorders(borderIndexes: [Int])
}
extension SheetUndoItem: UndoItem {
    var type: UndoItemType {
        switch self {
        case .appendLine: return .reversible
        case .appendLines: return .reversible
        case .appendPlanes: return .reversible
        case .removeLastLines: return .unreversible
        case .removeLastPlanes: return .unreversible
        case .insertLines: return .reversible
        case .insertPlanes: return .reversible
        case .removeLines: return .unreversible
        case .removePlanes: return .unreversible
        case .setPlaneValue: return .lazyReversible
        case .changeToDraft: return .reversible
        case .setPicture: return .lazyReversible
        case .insertDraftLines: return .reversible
        case .insertDraftPlanes: return .reversible
        case .removeDraftLines: return .unreversible
        case .removeDraftPlanes: return .unreversible
        case .setDraftPicture: return .lazyReversible
        case .insertTexts: return .reversible
        case .removeTexts: return .unreversible
        case .replaceString: return .lazyReversible
        case .changedColors: return .lazyReversible
        case .insertBorders: return .reversible
        case .removeBorders: return .unreversible
        }
    }
    func reversed() -> SheetUndoItem? {
        switch self {
        case .appendLine:
            return .removeLastLines(count: 1)
        case .appendLines(let lines):
            return .removeLastLines(count: lines.count)
        case .appendPlanes(let planes):
            return .removeLastPlanes(count: planes.count)
        case .removeLastLines:
            return nil
        case .removeLastPlanes:
            return nil
        case .insertLines(let livs):
            return .removeLines(lineIndexes: livs.map { $0.index })
        case .insertPlanes(let pivs):
            return .removePlanes(planeIndexes: pivs.map { $0.index })
        case .removeLines:
            return nil
        case .removePlanes:
            return nil
        case .setPlaneValue:
            return self
        case .changeToDraft(let isReverse):
            return .changeToDraft(isReverse: !isReverse)
        case .setPicture(_):
            return self
        case .insertDraftLines(let livs):
            return .removeDraftLines(lineIndexes: livs.map { $0.index })
        case .insertDraftPlanes(let pivs):
            return .removeDraftPlanes(planeIndexes: pivs.map { $0.index })
        case .removeDraftLines:
            return nil
        case .removeDraftPlanes:
            return nil
        case .setDraftPicture(_):
            return self
        case .insertTexts(let tivs):
            return .removeTexts(textIndexes: tivs.map { $0.index })
        case .removeTexts:
            return nil
        case .replaceString(_):
            return self
        case .changedColors(_):
            return self
        case .insertBorders(let bivs):
            return .removeBorders(borderIndexes: bivs.map { $0.index })
        case .removeBorders:
            return nil
        }
    }
}
extension SheetUndoItem: Protobuf {
    init(_ pb: PBSheetUndoItem) throws {
        guard let value = pb.value else {
            throw ProtobufError()
        }
        switch value {
        case .appendLine(let line):
            self = .appendLine(try Line(line))
        case .appendLines(let lines):
            self = .appendLines(try [Line](lines))
        case .appendPlanes(let planes):
            self = .appendPlanes(try [Plane](planes))
        case .removeLastLines(let lineCount):
            self = .removeLastLines(count: Int(lineCount))
        case .removeLastPlanes(let planesCount):
            self = .removeLastPlanes(count: Int(planesCount))
        case .insertLines(let lineIndexValues):
            self = .insertLines(try [IndexValue<Line>](lineIndexValues))
        case .insertPlanes(let planeIndexValues):
            self = .insertPlanes(try [IndexValue<Plane>](planeIndexValues))
        case .removeLines(let lineIndexes):
            self = .removeLines(lineIndexes: try [Int](lineIndexes))
        case .removePlanes(let planeIndexes):
            self = .removePlanes(planeIndexes: try [Int](planeIndexes))
        case .setPlaneValue(let planeValue):
            self = .setPlaneValue(try PlaneValue(planeValue))
        case .changeToDraft(let isReverse):
            self = .changeToDraft(isReverse: isReverse)
        case .setPicture(let picture):
            self = .setPicture(try Picture(picture))
        case .insertDraftLines(let lineIndexValues):
            self = .insertDraftLines(try [IndexValue<Line>](lineIndexValues))
        case .insertDraftPlanes(let planeIndexValues):
            self = .insertDraftPlanes(try [IndexValue<Plane>](planeIndexValues))
        case .removeDraftLines(let lineIndexes):
            self = .removeDraftLines(lineIndexes: try [Int](lineIndexes))
        case .removeDraftPlanes(let planeIndexes):
            self = .removeDraftPlanes(planeIndexes: try [Int](planeIndexes))
        case .setDraftPicture(let picture):
            self = .setDraftPicture(try Picture(picture))
        case .insertTexts(let texts):
            self = .insertTexts(try [IndexValue<Text>](texts))
        case .removeTexts(let textIndexes):
            self = .removeTexts(textIndexes: try [Int](textIndexes))
        case .replaceString(let textValue):
            self = .replaceString(try IndexValue<TextValue>(textValue))
        case .changedColors(let colorUndoValue):
            self = .changedColors(try ColorValue(colorUndoValue))
        case .insertBorders(let borders):
            self = .insertBorders(try [IndexValue<Border>](borders))
        case .removeBorders(let borderIndexes):
            self = .removeBorders(borderIndexes: try [Int](borderIndexes))
        }
    }
    var pb: PBSheetUndoItem {
        PBSheetUndoItem.with {
            switch self {
            case .appendLine(let line):
                $0.value = .appendLine(line.pb)
            case .appendLines(let lines):
                $0.value = .appendLines(lines.pb)
            case .appendPlanes(let planes):
                $0.value = .appendPlanes(planes.pb)
            case .removeLastLines(let lineCount):
                $0.value = .removeLastLines(Int64(lineCount))
            case .removeLastPlanes(let planesCount):
                $0.value = .removeLastPlanes(Int64(planesCount))
            case .insertLines(let lineIndexValues):
                $0.value = .insertLines(lineIndexValues.pb)
            case .insertPlanes(let planeIndexValues):
                $0.value = .insertPlanes(planeIndexValues.pb)
            case .removeLines(let lineIndexes):
                $0.value = .removeLines(lineIndexes.pb)
            case .removePlanes(let planeIndexes):
                $0.value = .removePlanes(planeIndexes.pb)
            case .setPlaneValue(let planeValue):
                $0.value = .setPlaneValue(planeValue.pb)
            case .changeToDraft(let isReverse):
                $0.value = .changeToDraft(isReverse)
            case .setPicture(let picture):
                $0.value = .setPicture(picture.pb)
            case .insertDraftLines(let lineIndexValues):
                $0.value = .insertDraftLines(lineIndexValues.pb)
            case .insertDraftPlanes(let planeIndexValues):
                $0.value = .insertDraftPlanes(planeIndexValues.pb)
            case .removeDraftLines(let lineIndexes):
                $0.value = .removeDraftLines(lineIndexes.pb)
            case .removeDraftPlanes(let planeIndexes):
                $0.value = .removeDraftPlanes(planeIndexes.pb)
            case .setDraftPicture(let picture):
                $0.value = .setDraftPicture(picture.pb)
            case .insertTexts(let texts):
                $0.value = .insertTexts(texts.pb)
            case .removeTexts(let textIndexes):
                $0.value = .removeTexts(textIndexes.pb)
            case .replaceString(let textValue):
                $0.value = .replaceString(textValue.pb)
            case .changedColors(let colorUndoValue):
                $0.value = .changedColors(colorUndoValue.pb)
            case .insertBorders(let borders):
                $0.value = .insertBorders(borders.pb)
            case .removeBorders(let borderIndexes):
                $0.value = .removeBorders(borderIndexes.pb)
            }
        }
    }
}
extension SheetUndoItem: Codable {
    private enum CodingTypeKey: String, Codable {
        case appendLine = "0"
        case appendLines = "1"
        case appendPlanes = "2"
        case removeLastLines = "3"
        case removeLastPlanes = "4"
        case insertLines = "5"
        case insertPlanes = "6"
        case removeLines = "7"
        case removePlanes = "8"
        case setPlaneValue = "9"
        case changeToDraft = "10"
        case setPicture = "11"
        case insertDraftLines = "12"
        case insertDraftPlanes = "13"
        case removeDraftLines = "14"
        case removeDraftPlanes = "15"
        case setDraftPicture = "16"
        case insertTexts = "17"
        case removeTexts = "18"
        case replaceString = "19"
        case changedColors = "20"
        case insertBorders = "21"
        case removeBorders = "22"
    }
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let key = try container.decode(CodingTypeKey.self)
        switch key {
        case .appendLine:
            self = .appendLine(try container.decode(Line.self))
        case .appendLines:
            self = .appendLines(try container.decode([Line].self))
        case .appendPlanes:
            self = .appendPlanes(try container.decode([Plane].self))
        case .removeLastLines:
            self = .removeLastLines(count: try container.decode(Int.self))
        case .removeLastPlanes:
            self = .removeLastPlanes(count: try container.decode(Int.self))
        case .insertLines:
            self = .insertLines(try container.decode([IndexValue<Line>].self))
        case .insertPlanes:
            self = .insertPlanes(try container.decode([IndexValue<Plane>].self))
        case .removeLines:
            self = .removeLines(lineIndexes: try container.decode([Int].self))
        case .removePlanes:
            self = .removePlanes(planeIndexes: try container.decode([Int].self))
        case .setPlaneValue:
            self = .setPlaneValue(try container.decode(PlaneValue.self))
        case .changeToDraft:
            self = .changeToDraft(isReverse: try container.decode(Bool.self))
        case .setPicture:
            self = .setPicture(try container.decode(Picture.self))
        case .insertDraftLines:
            self = .insertDraftLines(try container.decode([IndexValue<Line>].self))
        case .insertDraftPlanes:
            self = .insertDraftPlanes(try container.decode([IndexValue<Plane>].self))
        case .removeDraftLines:
            self = .removeDraftLines(lineIndexes: try container.decode([Int].self))
        case .removeDraftPlanes:
            self = .removeDraftPlanes(planeIndexes: try container.decode([Int].self))
        case .setDraftPicture:
            self = .setDraftPicture(try container.decode(Picture.self))
        case .insertTexts:
            self = .insertTexts(try container.decode([IndexValue<Text>].self))
        case .removeTexts:
            self = .removeTexts(textIndexes: try container.decode([Int].self))
        case .replaceString:
            self = .replaceString(try container.decode(IndexValue<TextValue>.self))
        case .changedColors:
            self = .changedColors(try container.decode(ColorValue.self))
        case .insertBorders:
            self = .insertBorders(try container.decode([IndexValue<Border>].self))
        case .removeBorders:
            self = .removeBorders(borderIndexes: try container.decode([Int].self))
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .appendLine(let line):
            try container.encode(CodingTypeKey.appendLine)
            try container.encode(line)
        case .appendLines(let lines):
            try container.encode(CodingTypeKey.appendLines)
            try container.encode(lines)
        case .appendPlanes(let planes):
            try container.encode(CodingTypeKey.appendPlanes)
            try container.encode(planes)
        case .removeLastLines(let lineCount):
            try container.encode(CodingTypeKey.removeLastLines)
            try container.encode(lineCount)
        case .removeLastPlanes(let planesCount):
            try container.encode(CodingTypeKey.removeLastPlanes)
            try container.encode(planesCount)
        case .insertLines(let lineIndexValues):
            try container.encode(CodingTypeKey.insertLines)
            try container.encode(lineIndexValues)
        case .insertPlanes(let planeIndexValues):
            try container.encode(CodingTypeKey.insertPlanes)
            try container.encode(planeIndexValues)
        case .removeLines(let lineIndexes):
            try container.encode(CodingTypeKey.removeLines)
            try container.encode(lineIndexes)
        case .removePlanes(let planeIndexes):
            try container.encode(CodingTypeKey.removePlanes)
            try container.encode(planeIndexes)
        case .setPlaneValue(let planeValue):
            try container.encode(CodingTypeKey.setPlaneValue)
            try container.encode(planeValue)
        case .changeToDraft(let isReverse):
            try container.encode(CodingTypeKey.changeToDraft)
            try container.encode(isReverse)
        case .setPicture(let picture):
            try container.encode(CodingTypeKey.setPicture)
            try container.encode(picture)
        case .insertDraftLines(let lineIndexValues):
            try container.encode(CodingTypeKey.insertDraftLines)
            try container.encode(lineIndexValues)
        case .insertDraftPlanes(let planeIndexValues):
            try container.encode(CodingTypeKey.insertDraftPlanes)
            try container.encode(planeIndexValues)
        case .removeDraftLines(let lineIndexes):
            try container.encode(CodingTypeKey.removeDraftLines)
            try container.encode(lineIndexes)
        case .removeDraftPlanes(let planeIndexes):
            try container.encode(CodingTypeKey.removeDraftPlanes)
            try container.encode(planeIndexes)
        case .setDraftPicture(let picture):
            try container.encode(CodingTypeKey.setDraftPicture)
            try container.encode(picture)
        case .insertTexts(let texts):
            try container.encode(CodingTypeKey.insertTexts)
            try container.encode(texts)
        case .removeTexts(let textIndexes):
            try container.encode(CodingTypeKey.removeTexts)
            try container.encode(textIndexes)
        case .replaceString(let textValue):
            try container.encode(CodingTypeKey.replaceString)
            try container.encode(textValue)
        case .changedColors(let colorUndoValue):
            try container.encode(CodingTypeKey.changedColors)
            try container.encode(colorUndoValue)
        case .insertBorders(let borders):
            try container.encode(CodingTypeKey.insertBorders)
            try container.encode(borders)
        case .removeBorders(let borderIndexes):
            try container.encode(CodingTypeKey.removeBorders)
            try container.encode(borderIndexes)
        }
    }
}
extension SheetUndoItem: CustomStringConvertible {
    var description: String {
        switch self {
        case .appendLine: return "appendLine"
        case .appendLines: return "appendLines"
        case .appendPlanes: return "appendPlanes"
        case .removeLastLines: return "removeLastLines"
        case .removeLastPlanes: return "removeLastPlanes"
        case .insertLines: return "insertLines"
        case .insertPlanes: return "insertPlane"
        case .removeLines: return "removeLines"
        case .removePlanes: return "removePlanes"
        case .setPlaneValue: return "setPlaneValue"
        case .changeToDraft: return "changeToDraft"
        case .setPicture: return "setPicture"
        case .insertDraftLines: return "insertDraftLines"
        case .insertDraftPlanes: return "insertDraftPlanes"
        case .removeDraftLines: return "removeDraftLines"
        case .removeDraftPlanes: return "removeDraftPlanes"
        case .setDraftPicture: return "setDraftPicture"
        case .insertTexts: return "insertTexts"
        case .removeTexts: return "removeTexts"
        case .replaceString: return "replaceString"
        case .changedColors: return "changedColors"
        case .insertBorders: return "insertBorders"
        case .removeBorders: return "removeBorders"
        }
    }
}

struct Border {
    var location = 0.0, orientation = Orientation.horizontal
}
extension Border {
    init(location: Double, _ orientation: Orientation) {
        self.location = location
        self.orientation = orientation
    }
    init(_ orientation: Orientation) {
        location = 0
        self.orientation = orientation
    }
}
extension Border: Protobuf {
    init(_ pb: PBBorder) throws {
        location = try pb.location.notNaN().notInfinite()
        orientation = try Orientation(pb.orientation)
    }
    var pb: PBBorder {
        PBBorder.with {
            $0.location = location
            $0.orientation = orientation.pb
        }
    }
}
extension Border: Hashable, Codable {}
extension Border {
    init(position: Point, border: Border) {
        switch border.orientation {
        case .horizontal: location = position.y
        case .vertical: location = position.x
        }
        orientation = border.orientation
    }
}
extension Border {
    func edge(with bounds: Rect) -> Edge {
        switch orientation {
        case .horizontal:
            return Edge(Point(bounds.minX, location),
                        Point(bounds.maxX, location))
        case .vertical:
            return Edge(Point(location, bounds.minY),
                        Point(location, bounds.maxY))
        }
    }
    func path(with bounds: Rect) -> Path {
        Path([Pathline(edge(with: bounds))])
    }
}

extension Line {
    var node: Node {
        Node(path: Path(self),
             lineWidth: size,
             lineType: .color(.content))
    }
    func node(from color: Color) -> Node {
        Node(path: Path(self),
             lineWidth: size,
             lineType: .color(color))
    }
}
extension Plane {
    var node: Node {
        Node(path: path,
             fillType: .color(uuColor.value))
    }
    func node(from color: Color) -> Node {
        Node(path: path,
             fillType: .color(color))
    }
}
extension Text {
    var node: Node {
        Node(attitude: Attitude(position: origin),
             path: typesetter.path(),
             fillType: .color(.content))
    }
}
extension Border {
    func node(with bounds: Rect) -> Node {
        Node(path: path(with: bounds),
             lineWidth: 1, lineType: .color(.border))
    }
}

struct Sheet {
    var picture = Picture(), draftPicture = Picture()
    var texts = [Text]()
    var borders = [Border]()
    var backgroundUUColor = Sheet.defalutBackgroundUUColor
}
extension Sheet: Protobuf {
    init(_ pb: PBSheet) throws {
        picture = (try? Picture(pb.picture)) ?? Picture()
        draftPicture = (try? Picture(pb.draftPicture)) ?? Picture()
        texts = pb.texts.compactMap { try? Text($0) }
        borders = pb.borders.compactMap { try? Border($0) }
        backgroundUUColor = (try? UUColor(pb.backgroundUucolor))
            ?? Sheet.defalutBackgroundUUColor
    }
    var pb: PBSheet {
        PBSheet.with {
            $0.picture = picture.pb
            $0.draftPicture = draftPicture.pb
            $0.texts = texts.map { $0.pb }
            $0.borders = borders.map { $0.pb }
            $0.backgroundUucolor = backgroundUUColor.pb
        }
    }
}
extension Sheet: Hashable, Codable {}
extension Sheet {
    static let width = 512.0, height = 724.0
    static let defaultBounds = Rect(size: Size(width: width, height: height))
    static let defalutBackgroundUUColor = UU(Color.background, id: .zero)
    static let textPadding = Size(width: 16, height: 15)
}
extension Sheet {
    func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Sheet {
        let lines = picture.lines.map { $0.rounded(rule) }
        let texts = self.texts.map { Text(string: $0.string,
                                          orientation: $0.orientation,
                                          size: $0.size.rounded(rule),
                                          origin: $0.origin.rounded(rule)) }
        return Sheet(picture: Picture(lines: lines,
                                      planes: picture.planes),
                     draftPicture: draftPicture, texts: texts,
                     borders: borders,
                     backgroundUUColor: backgroundUUColor)
    }
    var isEmpty: Bool {
        picture.lines.isEmpty && draftPicture.lines.isEmpty
    }
    var bounds: Rect {
        Sheet.defaultBounds
    }
    func boundsTuple(at p: Point) -> (bounds: Rect, isAll: Bool) {
        let b = Sheet.defaultBounds
        guard !borders.isEmpty else { return (b, true) }
        var aabb = AABB(b)
        borders.forEach {
            switch $0.orientation {
            case .horizontal:
                if p.y > $0.location && aabb.minY < $0.location {
                    aabb.yRange.lowerBound = $0.location
                } else if p.y < $0.location && aabb.maxY > $0.location {
                    aabb.yRange.upperBound = $0.location
                }
            case .vertical:
                if p.x > $0.location && aabb.minX < $0.location {
                    aabb.xRange.lowerBound = $0.location
                } else if p.x < $0.location && aabb.maxX > $0.location {
                    aabb.xRange.upperBound = $0.location
                }
            }
        }
        return (aabb.rect, false)
    }
    var borderFrames: [Rect] {
        guard !borders.isEmpty else { return [] }
        var xs = Set<Double>(), ys = Set<Double>()
        borders.forEach {
            switch $0.orientation {
            case .horizontal:
                ys.insert($0.location)
            case .vertical:
                xs.insert($0.location)
            }
        }
        let b = Sheet.defaultBounds
        xs.insert(b.width)
        ys.insert(b.height)
        let nxs = xs.sorted(), nys = ys.sorted()
        var frames = [Rect]()
        frames.reserveCapacity(nxs.count * nys.count)
        var oldX = b.minX
        for x in nxs {
            var oldY = b.minY
            for y in nys {
                frames.append(Rect(x: oldX, y: oldY,
                                   width: x - oldX, height: y - oldY))
                oldY = y
            }
            oldX = x
        }
        return frames
    }
    
    static func clipped(_ lines: [Line], in bounds: Rect) -> [Line] {
        let lassoLine = Line(controls:
                                [Line.Control(point: bounds.minXMinYPoint),
                                 Line.Control(point: bounds.minXMinYPoint),
                                 Line.Control(point: bounds.minXMaxYPoint),
                                 Line.Control(point: bounds.minXMaxYPoint),
                                 Line.Control(point: bounds.maxXMaxYPoint),
                                 Line.Control(point: bounds.maxXMaxYPoint),
                                 Line.Control(point: bounds.maxXMinYPoint),
                                 Line.Control(point: bounds.maxXMinYPoint)])
        let lasso = Lasso(line: lassoLine)
        return lines.reduce(into: [Line]()) {
            if let splitedLine = lasso.splitedLine(with: $1) {
                switch splitedLine {
                case .around(let line):
                    $0.append(line)
                case .split(let (inLines, _)):
                    $0 += inLines
                }
            }
        }
    }
    static func clipped(_ planes: [Plane], in bounds: Rect) -> [Plane] {
        planes.filter { $0.path.intersects(bounds) }
    }
    static func clipped(_ texts: [Text], in bounds: Rect) -> [Text] {
        texts.filter { bounds.contains($0.origin) }
    }
    
    func color(at p: Point) -> UUColor {
        if let plane = picture.planes.reversed().first(where: { $0.path.contains(p) }) {
            return plane.uuColor
        } else {
            return backgroundUUColor
        }
    }
    
    var allTextsString: String {
        let strings = texts
            .sorted(by: { $0.origin.y == $1.origin.y ? $0.origin.x < $1.origin.x : $0.origin.y > $1.origin.y })
            .map { $0.string }
        var str = ""
        for nstr in strings {
            str += nstr
            str += "\n\n\n\n"
        }
        return str
    }
    
    func draftLinesColor() -> Color {
        Sheet.draftLinesColor(from: backgroundUUColor.value)
    }
    static func draftLinesColor(from fillColor: Color) -> Color {
        Color.rgbLinear(fillColor, .draft, t: 0.15)
    }
    func draftPlaneColor(from color: Color, fillColor: Color) -> Color {
        Color.rgbLinear(fillColor, color, t: 0.05)
    }
    func node(isBorder: Bool) -> Node {
        let lineNodes = picture.lines.map { $0.node }
        let planeNodes = picture.planes.map { $0.node }
        let textNodes = texts.map { $0.node }
        let borderNodes = isBorder ? borders.map { $0.node(with: bounds) } : []
        let draftLineNodes: [Node]
        if !draftPicture.lines.isEmpty {
            let lineColor = draftLinesColor()
            draftLineNodes = draftPicture.lines.map { $0.node(from: lineColor) }
        } else {
            draftLineNodes = []
        }
        let draftPlaneNodes: [Node]
        if !draftPicture.planes.isEmpty {
            let fillColor = backgroundUUColor.value
            draftPlaneNodes = draftPicture.planes.map {
                $0.node(from: draftPlaneColor(from: $0.uuColor.value,
                                              fillColor: fillColor))
            }
        } else {
            draftPlaneNodes = []
        }
        let children0 = draftPlaneNodes + draftLineNodes
        let children1 = planeNodes + lineNodes
        let children2 = textNodes + borderNodes
        return Node(children: children0 + children1 + children2,
                    path: Path(bounds),
                    fillType: .color(backgroundUUColor.value))
    }
}
extension Sheet {
    init(message: String) {
        var text = Text(string: message)
        if let bounds = text.bounds {
            text.origin = Sheet.defaultBounds.centerPoint - bounds.centerPoint
        }
        self.init(texts: [text])
    }
}

final class LineView<T: BinderProtocol>: View {
    typealias Model = Line
    typealias Binder = T
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        node = Node(path: Path(binder[keyPath: keyPath]),
                    lineWidth: binder[keyPath: keyPath].size,
                    lineType: .color(.content))
    }
    
    func updateWithModel() {
        updatePath()
        node.lineWidth = model.size
    }
    func updatePath() {
        node.path = Path(model)
    }
}
typealias SheetLineView = LineView<SheetBinder>

final class PlaneView<T: BinderProtocol>: View {
    typealias Model = Plane
    typealias Binder = T
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        node = Node(path: binder[keyPath: keyPath].path,
                    fillType: .color(binder[keyPath: keyPath].uuColor.value))
    }
    
    func updateWithModel() {
        updateColor()
        updatePath()
    }
    func updateColor() {
        node.fillType = .color(model.uuColor.value)
    }
    func updatePath() {
        node.path = model.path
    }
    var uuColor: UUColor {
        get { model.uuColor }
        set {
            binder[keyPath: keyPath].uuColor = newValue
            updateColor()
        }
    }
}
typealias SheetPlaneView = PlaneView<SheetBinder>

typealias SheetTextView = TextView<SheetBinder>

final class BorderView<T: BinderProtocol>: View {
    typealias Model = Border
    typealias Binder = T
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    
    var bounds = Sheet.defaultBounds
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        node = Node(path: binder[keyPath: keyPath].path(with: bounds),
                    lineWidth: 1, lineType: .color(.border))
    }
    
    func updateWithModel() {
        node.path = model.path(with: bounds)
    }
}
typealias SheetBorderView = BorderView<SheetBinder>

typealias SheetBinder = RecordBinder<Sheet>
typealias SheetHistory = History<SheetUndoItem>

final class SheetView: View {
    typealias Model = Sheet
    typealias Binder = SheetBinder
    let binder: Binder
    var keyPath: BinderKeyPath
    
    weak var selectedTextView: SheetTextView?
    
    var history = SheetHistory()
    
    let node: Node
    let linesView: ArrayView<SheetLineView>
    let planesView: ArrayView<SheetPlaneView>
    let draftLinesView: ArrayView<SheetLineView>
    let draftPlanesView: ArrayView<SheetPlaneView>
    let textsView: ArrayView<SheetTextView>
    let bordersView: ArrayView<SheetBorderView>
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        linesView = ArrayView(binder: binder,
                              keyPath: keyPath.appending(path: \Model.picture.lines))
        planesView = ArrayView(binder: binder,
                               keyPath: keyPath.appending(path: \Model.picture.planes))
        draftLinesView = ArrayView(binder: binder,
                                   keyPath: keyPath.appending(path: \Model.draftPicture.lines))
        draftPlanesView = ArrayView(binder: binder,
                                    keyPath: keyPath.appending(path: \Model.draftPicture.planes))
        textsView = ArrayView(binder: binder,
                              keyPath: keyPath.appending(path: \Model.texts))
        bordersView = ArrayView(binder: binder,
                                keyPath: keyPath.appending(path: \Model.borders))
        
        node = Node(children: [draftPlanesView.node, draftLinesView.node,
                               planesView.node, linesView.node, textsView.node,
                               bordersView.node])
        
        updateDraft()
        updateBackground()
    }
    
    func updateWithModel() {
        linesView.updateWithModel()
        planesView.updateWithModel()
        draftLinesView.updateWithModel()
        draftPlanesView.updateWithModel()
        textsView.updateWithModel()
        bordersView.updateWithModel()
        
        updateDraft()
        updateBackground()
    }
    func updateDraft() {
        if !draftLinesView.model.isEmpty {
            let lineColor = model.draftLinesColor()
            draftLinesView.elementViews.forEach {
                $0.node.lineType = .color(lineColor)
            }
        }
        if !draftPlanesView.model.isEmpty {
            let fillColor = model.backgroundUUColor.value
            draftPlanesView.elementViews.forEach {
                $0.node.fillType = .color(model.draftPlaneColor(from: $0.model.uuColor.value,
                                                           fillColor: fillColor))
            }
        }
    }
    var backgroundUUColor: UUColor {
        get { model.backgroundUUColor }
        set {
            binder.value.backgroundUUColor = newValue
            
            updateBackground()
            updateDraft()
        }
    }
    private func updateBackground() {
        if model.backgroundUUColor != Sheet.defalutBackgroundUUColor {
            node.fillType = .color(model.backgroundUUColor.value)
        } else {
            node.fillType = nil
        }
    }
    
    func clearHistory() {
        history.reset()
        binder.enableWrite()
    }
    
    func set(_ colorValue: ColorValue) {
        if !colorValue.planeIndexes.isEmpty {
            var picture = model.picture
            for pi in colorValue.planeIndexes {
                picture.planes[pi].uuColor = colorValue.uuColor
            }
            binder.value.picture = picture
            for pi in colorValue.planeIndexes {
                planesView.elementViews[pi].updateColor()
            }
        }
        if colorValue.isBackground {
            backgroundUUColor = colorValue.uuColor
        }
    }
    func colorPathValue(with colorValue: ColorValue,
                        toColor: Color?,
                        color: Color, subColor: Color) -> ColorPathValue {
        if !colorValue.planeIndexes.isEmpty {
            let paths = colorValue.planeIndexes.map {
                planesView.elementViews[$0].node.path * node.localTransform
            }
            if let toColor = toColor {
                return ColorPathValue(paths: paths,
                                      lineType: .color(color),
                                      fillType: .color(subColor + toColor))
            } else {
                return ColorPathValue(paths: paths,
                                      lineType: .color(color),
                                      fillType: .color(subColor))
            }
        } else if colorValue.isBackground, let b = node.bounds {
            let path = Path([Pathline(b)]) * node.localTransform
            if let toColor = toColor {
                return ColorPathValue(paths: [path],
                                      lineType: .color(color),
                                      fillType: .color(subColor + toColor))
            } else {
                return ColorPathValue(paths: [path],
                                      lineType: .color(color),
                                      fillType: .color(subColor))
            }
        } else {
            return ColorPathValue(paths: [], lineType: nil, fillType: nil)
        }
    }
    
    func removeAll() {
        guard !model.picture.isEmpty
                || !model.draftPicture.isEmpty
                || !model.texts.isEmpty else { return }
        newUndoGroup()
        if !model.picture.isEmpty {
            set(Picture())
        }
        if !model.draftPicture.isEmpty {
            removeDraft()
        }
        if !model.texts.isEmpty {
            removeText(at: Array(0..<model.texts.count))
        }
    }
    
    func sheetColorOwner(at p: Point) -> SheetColorOwner {
        if let pi = planesView.firstIndex(at: p) {
            let cv = ColorValue(uuColor: model.picture.planes[pi].uuColor,
                                planeIndexes: [pi], isBackground: false)
            return SheetColorOwner(sheetView: self, colorValue: cv)
        } else {
            let cv = ColorValue(uuColor: model.backgroundUUColor,
                                planeIndexes: [], isBackground: true)
            return SheetColorOwner(sheetView: self, colorValue: cv)
        }
    }
    func sheetColorOwner(at r: Rect) -> [SheetColorOwner] {
        let piDic = planesView.elementViews.enumerated().reduce(into: [UUColor: [Int]]()) {
            if $1.element.node.path.intersects(r) {
                let uuColor = $1.element.model.uuColor
                if $0[uuColor] != nil {
                    $0[uuColor]?.append($1.offset)
                } else {
                    $0[uuColor] = [$1.offset]
                }
            }
        }
        return piDic.map {
            let cv = ColorValue(uuColor: $0.key,
                                planeIndexes: $0.value, isBackground: false)
            return SheetColorOwner(sheetView: self, colorValue: cv)
        }
    }
    func sheetColorOwner(with uuColor: UUColor) -> SheetColorOwner? {
        let planeIndexes = model.picture.planes.enumerated().compactMap {
            $0.element.uuColor == uuColor ? $0.offset : nil
        }
        let isBackground = model.backgroundUUColor == uuColor
        guard !planeIndexes.isEmpty || isBackground else {
            return nil
        }
        let cv = ColorValue(uuColor: uuColor,
                            planeIndexes: planeIndexes,
                            isBackground: isBackground)
        return SheetColorOwner(sheetView: self, colorValue: cv)
    }
    
    func newUndoGroup() {
        history.newUndoGroup()
    }
    
    private func append(undo undoItem: SheetUndoItem,
                        redo redoItem: SheetUndoItem) {
        history.append(undo: undoItem, redo: redoItem)
    }
    @discardableResult
    func set(_ item: SheetUndoItem, isMakeRect: Bool = false) -> Rect? {
        selectedTextView = nil
        switch item {
        case .appendLine(let line):
            let lineNode = appendNode(line)
            if isMakeRect {
                return lineNode.bounds
            }
        case .appendLines(let lines):
            appendNode(lines)
            if isMakeRect {
                return linesView.elementViews[(linesView.elementViews.count - lines.count)...]
                    .reduce(into: Rect?.none) { $0 += $1.node.bounds }
            }
        case .appendPlanes(let planes):
            appendNode(planes)
            if isMakeRect {
                return planesView.elementViews[(planesView.elementViews.count - planes.count)...]
                    .reduce(into: Rect?.none) { $0 += $1.node.bounds }
            }
        case .removeLastLines(let count):
            if isMakeRect {
                let frame = linesView.elementViews[(linesView.elementViews.count - count)...]
                    .reduce(into: Rect?.none) { $0 += $1.node.bounds }
                removeLastsLineNode(count: count)
                return frame
            } else {
                removeLastsLineNode(count: count)
            }
        case .removeLastPlanes(let count):
            if isMakeRect {
                let frame = planesView.elementViews[(planesView.elementViews.count - count)...]
                    .reduce(into: Rect?.none) { $0 += $1.node.bounds }
                removeLastsPlaneNode(count: count)
                return frame
            } else {
                removeLastsPlaneNode(count: count)
            }
        case .insertLines(let livs):
            insertNode(livs)
            if isMakeRect {
                return livs.reduce(into: Rect?.none) {
                    $0 += linesView.elementViews[$1.index].node.bounds
                }
            }
        case .insertPlanes(let pivs):
            insertNode(pivs)
            if isMakeRect {
                return pivs.reduce(into: Rect?.none) {
                    $0 += planesView.elementViews[$1.index].node.bounds
                }
            }
        case .removeLines(let lineIndexes):
            if isMakeRect {
                let frame = lineIndexes.reduce(into: Rect?.none) {
                    $0 += linesView.elementViews[$1].node.bounds
                }
                removeLinesNode(at: lineIndexes)
                return frame
            } else {
                removeLinesNode(at: lineIndexes)
            }
        case .removePlanes(let planeIndexes):
            if isMakeRect {
                let frame = planeIndexes.reduce(into: Rect?.none) {
                    $0 += planesView.elementViews[$1].node.bounds
                }
                removePlanesNode(at: planeIndexes)
                return frame
            } else {
                removePlanesNode(at: planeIndexes)
            }
        case .setPlaneValue(let planeValue):
            let planeIndexes = planeValue.moveIndexValues.map {
                IndexValue(value: planesView.elementViews[$0.value].model, index: $0.index)
            }
            setNode(planeValue.planes)
            if isMakeRect {
                let frame = planesView.elementViews
                    .reduce(into: Rect?.none) { $0 += $1.node.bounds }
                insertNode(planeIndexes)
                return frame
            } else {
                insertNode(planeIndexes)
            }
        case .changeToDraft(let isReverse):
            if isReverse {
                if linesView.model.isEmpty && planesView.model.isEmpty {
                    setNode(draftLinesView.model)
                    setDraftNode([Line]())
                    setNode(draftPlanesView.model)
                    setDraftNode([Plane]())
                }
            } else {
                if draftLinesView.model.isEmpty && draftPlanesView.model.isEmpty {
                    setDraftNode(linesView.model)
                    setNode([Line]())
                    setDraftNode(planesView.model)
                    setNode([Plane]())
                }
            }
            if isMakeRect {
                return node.bounds
            }
        case .setPicture(let picture):
            setNode(picture.lines)
            setNode(picture.planes)
            if isMakeRect {
                return node.bounds
            }
        case .insertDraftLines(let livs):
            insertDraftNode(livs)
            if isMakeRect {
                return livs.reduce(into: Rect?.none) {
                    $0 += draftLinesView.elementViews[$1.index].node.bounds
                }
            }
        case .insertDraftPlanes(let pivs):
            insertDraftNode(pivs)
            if isMakeRect {
                return pivs.reduce(into: Rect?.none) {
                    $0 += draftPlanesView.elementViews[$1.index].node.bounds
                }
            }
        case .removeDraftLines(let lineIndexes):
            if isMakeRect {
                let frame = lineIndexes.reduce(into: Rect?.none) {
                    $0 += draftLinesView.elementViews[$1].node.bounds
                }
                removeDraftLinesNode(at: lineIndexes)
                return frame
            } else {
                removeDraftLinesNode(at: lineIndexes)
            }
        case .removeDraftPlanes(let planeIndexes):
            if isMakeRect {
                let frame = planeIndexes.reduce(into: Rect?.none) {
                    $0 += draftPlanesView.elementViews[$1].node.bounds
                }
                removeDraftPlanesNode(at: planeIndexes)
                return frame
            } else {
                removeDraftPlanesNode(at: planeIndexes)
            }
        case .setDraftPicture(let picture):
            setDraftNode(picture.lines)
            setDraftNode(picture.planes)
            if isMakeRect {
                return node.bounds
            }
        case .insertTexts(let tivs):
            insertNode(tivs)
            if isMakeRect {
                return tivs.reduce(into: Rect?.none) {
                    $0 += textsView.elementViews[$1.index].transformedBounds
                }
            }
        case .removeTexts(let textIndexes):
            if isMakeRect {
                let frame = textIndexes.reduce(into: Rect?.none) {
                    $0 += textsView.elementViews[$1].transformedBounds
                }
                removeTextsNode(at: textIndexes)
                return frame
            } else {
                removeTextsNode(at: textIndexes)
            }
        case .replaceString(let ituv):
            if isMakeRect {
                let textView = textsView.elementViews[ituv.index]
                let firstRect: Rect?
                if ituv.value.origin != nil || ituv.value.size != nil {
                    firstRect = textView.transformedBounds
                } else {
                    let fRange = textView.model.string
                        .range(fromInt: ituv.value.replacedRange)
                    firstRect = textView
                        .transformedTypoBounds(with: fRange)
                }
                setNode(ituv)
                let lastRect: Rect?
                if ituv.value.origin != nil || ituv.value.size != nil {
                    lastRect = textView.transformedBounds
                } else {
                    let nRange = textView.model.string
                        .range(fromInt: ituv.value.newRange)
                    lastRect = textView
                        .transformedTypoBounds(with: nRange)
                }
                selectedTextView = textView
                return firstRect + lastRect
            } else {
                setNode(ituv)
                selectedTextView = textsView.elementViews[ituv.index]
            }
        case .changedColors(let colorUndoValue):
            changeColorsNode(colorUndoValue)
            if isMakeRect {
                return colorUndoValue.planeIndexes.reduce(into: Rect?.none) {
                    $0 += planesView.elementViews[$1].node.bounds
                }
            }
        case .insertBorders(let bivs):
            insertNode(bivs)
            if isMakeRect {
                return bivs.reduce(into: Rect?.none) {
                    let borderView = bordersView.elementViews[$1.index]
                    $0 += borderView.node.bounds?.inset(by: -borderView.node.lineWidth)
                }
            }
        case .removeBorders(let borderIndexes):
            if isMakeRect {
                let frame = borderIndexes.reduce(into: Rect?.none) {
                    let borderView = bordersView.elementViews[$1]
                    $0 += borderView.node.bounds?.inset(by: -borderView.node.lineWidth)
                }
                removeBordersNode(at: borderIndexes)
                return frame
            } else {
                removeBordersNode(at: borderIndexes)
            }
        }
        return nil
    }
    @discardableResult
    private func appendNode(_ line: Line) -> Node {
        linesView.append(line).node
    }
    private func appendNode(_ lines: [Line]) {
        linesView.append(lines)
    }
    private func appendNode(_ planes: [Plane]) {
        planesView.append(planes)
    }
    private func removeLastsLineNode(count: Int) {
        linesView.removeLasts(count: count)
    }
    private func removeLastsPlaneNode(count: Int) {
        planesView.removeLasts(count: count)
    }
    private func insertNode(_ livs: [IndexValue<Line>]) {
        linesView.insert(livs)
    }
    private func insertNode(_ pivs: [IndexValue<Plane>]) {
        planesView.insert(pivs)
    }
    private func removeLinesNode(at lineIndexes: [Int]) {
        linesView.remove(at: lineIndexes)
    }
    private func removePlanesNode(at planeIndexes: [Int]) {
        planesView.remove(at: planeIndexes)
    }
    private func setNode(_ lines: [Line]) {
        linesView.model = lines
    }
    private func setNode(_ planes: [Plane]) {
        planesView.model = planes
    }
    private func setDraftNode(_ lines: [Line]) {
        draftLinesView.model = lines
        
        if !lines.isEmpty {
            let lineColor = model.draftLinesColor()
            draftLinesView.elementViews.forEach {
                $0.node.lineType = .color(lineColor)
            }
        }
    }
    private func setDraftNode(_ planes: [Plane]) {
        draftPlanesView.model = planes
        
        if !planes.isEmpty {
            let fillColor = model.backgroundUUColor.value
            draftPlanesView.elementViews.forEach {
                $0.node.fillType = .color(model.draftPlaneColor(from: $0.model.uuColor.value,
                                                           fillColor: fillColor))
            }
        }
    }
    private func insertDraftNode(_ livs: [IndexValue<Line>]) {
        draftLinesView.insert(livs)
        
        if !livs.isEmpty {
            let lineColor = model.draftLinesColor()
            livs.forEach {
                draftLinesView.elementViews[$0.index].node.lineType = .color(lineColor)
            }
        }
    }
    private func insertDraftNode(_ pivs: [IndexValue<Plane>]) {
        draftPlanesView.insert(pivs)
        
        if !pivs.isEmpty {
            let fillColor = model.backgroundUUColor.value
            pivs.forEach {
                let planeView = draftPlanesView.elementViews[$0.index]
                planeView.node.fillType = .color(model.draftPlaneColor(from: planeView.model.uuColor.value,
                                                             fillColor: fillColor))
            }
        }
    }
    private func removeDraftLinesNode(at lineIndexes: [Int]) {
        draftLinesView.remove(at: lineIndexes)
    }
    private func removeDraftPlanesNode(at planeIndexes: [Int]) {
        draftPlanesView.remove(at: planeIndexes)
    }
    private func insertNode(_ tivs: [IndexValue<Text>]) {
        textsView.insert(tivs)
    }
    private func removeTextsNode(at textIndexes: [Int]) {
        textsView.remove(at: textIndexes)
    }
    private func setNode(_ ituv: IndexValue<TextValue>) {
        textsView.elementViews[ituv.index].set(ituv.value)
    }
    private func changeColorsNode(_ colorValue: ColorValue) {
        colorValue.planeIndexes.forEach {
            planesView.elementViews[$0].uuColor = colorValue.uuColor
        }
        if colorValue.isBackground {
            backgroundUUColor = colorValue.uuColor
        }
    }
    private func insertNode(_ bivs: [IndexValue<Border>]) {
        bordersView.insert(bivs)
    }
    private func removeBordersNode(at borderIndexes: [Int]) {
        bordersView.remove(at: borderIndexes)
    }
    
    func append(_ line: Line) {
        let undoItem = SheetUndoItem.removeLastLines(count: 1)
        let redoItem = SheetUndoItem.appendLine(line)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func append(_ lines: [Line]) {
        if lines.count == 1 {
            append(lines[0])
        } else {
            let undoItem = SheetUndoItem.removeLastLines(count: lines.count)
            let redoItem = SheetUndoItem.appendLines(lines)
            append(undo: undoItem, redo: redoItem)
            set(redoItem)
        }
    }
    func append(_ planes: [Plane]) {
        let undoItem = SheetUndoItem.removeLastPlanes(count: planes.count)
        let redoItem = SheetUndoItem.appendPlanes(planes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func insert(_ livs: [IndexValue<Line>]) {
        let undoItem = SheetUndoItem.removeLines(lineIndexes: livs.map { $0.index })
        let redoItem = SheetUndoItem.insertLines(livs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func insert(_ pivs: [IndexValue<Plane>]) {
        let undoItem = SheetUndoItem.removePlanes(planeIndexes: pivs.map { $0.index })
        let redoItem = SheetUndoItem.insertPlanes(pivs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeLines(at lineIndexes: [Int]) {
        let livs = lineIndexes.map {
            IndexValue(value: model.picture.lines[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertLines(livs)
        let redoItem = SheetUndoItem.removeLines(lineIndexes: lineIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removePlanes(at planeIndexes: [Int]) {
        let pivs = planeIndexes.map {
            IndexValue(value: model.picture.planes[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertPlanes(pivs)
        let redoItem = SheetUndoItem.removePlanes(planeIndexes: planeIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func set(_ picture: Picture) {
        let undoItem = SheetUndoItem.setPicture(model.picture)
        let redoItem = SheetUndoItem.setPicture(picture)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func set(_ planeValue: PlaneValue) {
        var isArray = Array(repeating: false, count: model.picture.planes.count)
        for v in planeValue.moveIndexValues {
            isArray[v.value] = true
        }
        let oldPlanes = model.picture.planes.enumerated().compactMap {
            isArray[$0.offset] ? nil : $0.element
        }
        let oldVs = planeValue.moveIndexValues
            .map { IndexValue(value: $0.index, index: $0.value) }
            .sorted { $0.index < $1.index }
        let oldPlaneValue = PlaneValue(planes: oldPlanes, moveIndexValues: oldVs)
        let undoItem = SheetUndoItem.setPlaneValue(oldPlaneValue)
        let redoItem = SheetUndoItem.setPlaneValue(planeValue)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func insertDraft(_ livs: [IndexValue<Line>]) {
        let undoItem = SheetUndoItem.removeDraftLines(lineIndexes: livs.map { $0.index })
        let redoItem = SheetUndoItem.insertDraftLines(livs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func insertDraft(_ pivs: [IndexValue<Plane>]) {
        let undoItem = SheetUndoItem.removeDraftPlanes(planeIndexes: pivs.map { $0.index })
        let redoItem = SheetUndoItem.insertDraftPlanes(pivs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeDraftLines(at lineIndexes: [Int]) {
        let livs = lineIndexes.map {
            IndexValue(value: model.draftPicture.lines[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertDraftLines(livs)
        let redoItem = SheetUndoItem.removeDraftLines(lineIndexes: lineIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeDraftPlanes(at planeIndexes: [Int]) {
        let pivs = planeIndexes.map {
            IndexValue(value: model.draftPicture.planes[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertDraftPlanes(pivs)
        let redoItem = SheetUndoItem.removeDraftPlanes(planeIndexes: planeIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func setDraft(_ draftPicture: Picture) {
        let undoItem = SheetUndoItem.setDraftPicture(model.draftPicture)
        let redoItem = SheetUndoItem.setDraftPicture(draftPicture)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func changeToDraft() {
        if !model.draftPicture.isEmpty {
            removeDraft()
        }
        let undoItem = SheetUndoItem.changeToDraft(isReverse: true)
        let redoItem = SheetUndoItem.changeToDraft(isReverse: false)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeDraft() {
        setDraft(Picture())
    }
    func append(_ text: Text) {
        let undoItem = SheetUndoItem.removeTexts(textIndexes: [model.texts.count])
        let redoItem = SheetUndoItem.insertTexts([IndexValue(value: text,
                                                             index: model.texts.count)])
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func append(_ texts: [Text]) {
        let undoItem = SheetUndoItem.removeTexts(textIndexes: Array(model.texts.count..<(model.texts.count + texts.count)))
        let redoItem = SheetUndoItem.insertTexts(texts.enumerated().map {
            IndexValue(value: $0.element, index: model.texts.count + $0.offset)
        })
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func insert(_ tivs: [IndexValue<Text>]) {
        let undoItem = SheetUndoItem.removeTexts(textIndexes: tivs.map { $0.index })
        let redoItem = SheetUndoItem.insertTexts(tivs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeText(at i: Int) {
        let undoItem = SheetUndoItem.insertTexts([IndexValue(value: model.texts[i],
                                                             index: i)])
        let redoItem = SheetUndoItem.removeTexts(textIndexes: [i])
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func replace(_ tivs: [IndexValue<Text>]) {
        let ivs = tivs.map { $0.index }
        let otivs = tivs
            .map { IndexValue(value: model.texts[$0.index], index: $0.index) }
        let undoItem0 = SheetUndoItem.insertTexts(otivs)
        let redoItem0 = SheetUndoItem.removeTexts(textIndexes: ivs)
        append(undo: undoItem0, redo: redoItem0)
        
        let undoItem1 = SheetUndoItem.removeTexts(textIndexes: ivs)
        let redoItem1 = SheetUndoItem.insertTexts(tivs)
        append(undo: undoItem1, redo: redoItem1)
        
        tivs.forEach { textsView.elementViews[$0.index].model = $0.value }
    }
    func removeText(at textIndexes: [Int]) {
        let tivs = textIndexes.map {
            IndexValue(value: model.texts[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertTexts(tivs)
        let redoItem = SheetUndoItem.removeTexts(textIndexes: textIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func capture(_ ituv: IndexValue<TextValue>,
                 old oituv: IndexValue<TextValue>) {
        let undoItem = SheetUndoItem.replaceString(oituv)
        let redoItem = SheetUndoItem.replaceString(ituv)
        append(undo: undoItem, redo: redoItem)
    }
    func replace(_ ituv: IndexValue<TextValue>) {
        let oldText = textsView.elementViews[ituv.index].model
        let string = oldText.string
        let intRange = ituv.value.replacedRange
        let oldRange = intRange.lowerBound..<(intRange.lowerBound + ituv.value.string.count)
        let oldOrigin = ituv.value.origin != nil ? oldText.origin : nil
        let oldSize = ituv.value.size != nil ? oldText.size : nil
        let sRange = string.range(fromInt: intRange)
        let oituv = TextValue(string: String(string[sRange]),
                              replacedRange: oldRange,
                              origin: oldOrigin, size: oldSize)
        let undoItem = SheetUndoItem.replaceString(IndexValue(value: oituv,
                                                              index: ituv.index))
        let redoItem = SheetUndoItem.replaceString(ituv)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func capture(_ colorUndoValue: ColorValue, oldColorValue: ColorValue) {
        let undoItem = SheetUndoItem.changedColors(oldColorValue)
        let redoItem = SheetUndoItem.changedColors(colorUndoValue)
        append(undo: undoItem, redo: redoItem)
    }
    func append(_ border: Border) {
        let undoItem = SheetUndoItem.removeBorders(borderIndexes: [model.borders.count])
        let redoItem = SheetUndoItem.insertBorders([IndexValue(value: border,
                                                               index: model.borders.count)])
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeBorder(at i: Int) {
        let undoItem = SheetUndoItem.insertBorders([IndexValue(value: model.borders[i],
                                                               index: i)])
        let redoItem = SheetUndoItem.removeBorders(borderIndexes: [i])
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    @discardableResult
    func undo(to toTopIndex: Int) -> Rect? {
        var frame = Rect?.none
        let results = history.undoAndResults(to: toTopIndex)
        for result in results {
            let item: UndoItemValue<SheetUndoItem>?
            if result.item.loadType == .unload {
                _ = history[result.version].values[result.valueIndex].loadRedoItem()
                loadCheck(with: result)
                item = history[result.version].values[result.valueIndex].undoItemValue
            } else {
                item = result.item.undoItemValue
            }
            switch result.type {
            case .undo:
                if let undoItem = item?.undoItem {
                    if let aFrame = set(undoItem, isMakeRect: true) {
                        frame += aFrame
                    }
                }
            case .redo:
                if let redoItem = item?.redoItem {
                    if let aFrame = set(redoItem, isMakeRect: true) {
                        frame += aFrame
                    }
                }
            }
        }
        return frame
    }
    func loadCheck(with result: SheetHistory.UndoResult) {
        guard let uiv = history[result.version].values[result.valueIndex]
                .undoItemValue else { return }
        
        let isUndo = result.type == .undo
        let reversedType: UndoType = isUndo ? .redo : .undo
        
        switch isUndo ? uiv.redoItem : uiv.undoItem {
        case .appendLine(let line):
            if let lastLine = model.picture.lines.last {
                if lastLine != line {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.appendLine(lastLine), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .appendLines(let lines):
            let di = model.picture.lines.count - lines.count
            if di >= 0 {
                let lastLines = Array(model.picture.lines[di...])
                if lastLines != lines {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.appendLines(lastLines), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .appendPlanes(let planes):
            let di = model.picture.planes.count - planes.count
            if di >= 0 {
                let lastPlanes = Array(model.picture.planes[di...])
                if lastPlanes != planes {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.appendPlanes(lastPlanes),
                                                type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .removeLastLines: break
        case .removeLastPlanes: break
        case .insertLines(let livs):
            let maxI = livs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.picture.lines.count {
                let oldLIVS = livs.map { IndexValue(value: model.picture.lines[$0.index],
                                                    index: $0.index) }
                if oldLIVS != livs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertLines(oldLIVS), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .insertPlanes(let pivs):
            let maxI = pivs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.picture.planes.count {
                let oldPIVS = pivs.map { IndexValue(value: model.picture.planes[$0.index],
                                                    index: $0.index) }
                if oldPIVS != pivs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertPlanes(oldPIVS), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .removeLines(let lineIndexes):
            let oldLIS = lineIndexes.filter { $0 < model.picture.lines.count + lineIndexes.count }.sorted()
            if oldLIS != lineIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removeLines(lineIndexes: oldLIS), type: reversedType)
            }
        case .removePlanes(let planeIndexes):
            let oldPIS = planeIndexes.filter { $0 < model.picture.planes.count + planeIndexes.count }.sorted()
            if oldPIS != planeIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removePlanes(planeIndexes: oldPIS), type: reversedType)
            }
        case .setPlaneValue(let planeValue):
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            if planeValue.planes.count + planeValue.moveIndexValues.count
                == model.picture.planes.count {
                
                var isArray = Array(repeating: false,
                                    count: model.picture.planes.count)
                for v in planeValue.moveIndexValues {
                    if v.index < isArray.count {
                        isArray[v.index] = true
                    } else {
                        error()
                    }
                }
                var i = 0
                for (j, isMoved) in isArray.enumerated() {
                    if !isMoved {
                        if i < planeValue.planes.count
                            && planeValue.planes[i] != model.picture.planes[j] {
                            
                            error()
                            break
                        }
                        i += 1
                    }
                }
            } else {
                error()
            }
        case .changeToDraft: break
        case .setPicture(let picture):
            if model.picture != picture {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.setPicture(model.picture), type: reversedType)
            }
        case .insertDraftLines(let livs):
            let maxI = livs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.draftPicture.lines.count {
                let oldLIVS = livs.map { IndexValue(value: model.draftPicture.lines[$0.index],
                                                    index: $0.index) }
                if oldLIVS != livs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertDraftLines(oldLIVS), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .insertDraftPlanes(let pivs):
            let maxI = pivs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.draftPicture.planes.count {
                let oldPIVS = pivs.map { IndexValue(value: model.draftPicture.planes[$0.index],
                                                    index: $0.index) }
                if oldPIVS != pivs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertDraftPlanes(oldPIVS), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .removeDraftLines(let lineIndexes):
            let oldLIS = lineIndexes.filter { $0 < model.draftPicture.lines.count + lineIndexes.count }.sorted()
            if oldLIS != lineIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removeDraftLines(lineIndexes: oldLIS), type: reversedType)
            }
        case .removeDraftPlanes(let planeIndexes):
            let oldPIS = planeIndexes.filter { $0 < model.draftPicture.planes.count + planeIndexes.count }.sorted()
            if oldPIS != planeIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removeDraftPlanes(planeIndexes: oldPIS), type: reversedType)
            }
        case .setDraftPicture(let draftPicture):
            if model.draftPicture != draftPicture {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.setDraftPicture(model.draftPicture),
                                            type: reversedType)
            }
        case .insertTexts(let tivs):
            let maxI = tivs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.texts.count {
                let oldTIVS = tivs.map { IndexValue(value: model.texts[$0.index],
                                                    index: $0.index) }
                if oldTIVS != tivs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertTexts(oldTIVS), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .removeTexts(let textIndexes):
            let oldTIS = textIndexes.filter { $0 < model.texts.count + textIndexes.count }.sorted()
            if oldTIS != textIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removeTexts(textIndexes: oldTIS), type: reversedType)
            }
        case .replaceString(let tuiv):
            guard tuiv.index < model.texts.count else {
                history[result.version]
                    .values[result.valueIndex].error()
                break
            }
            let text = model.texts[tuiv.index]
            let intRange = tuiv.value.newRange
            if intRange.lowerBound >= 0
                && intRange.upperBound <= text.string.count {
                
                let range = text.string.range(fromInt: intRange)
                let oldString = text.string[range]
                let oldOrigin = tuiv.value.origin != nil ? text.origin : nil
                let oldSize = tuiv.value.size != nil ? text.size : nil
                if oldString != tuiv.value.string
                    || oldOrigin != tuiv.value.origin
                    || oldSize != tuiv.value.size {
                    
                    let nOrigin = oldOrigin != tuiv.value.origin ?
                        oldOrigin : tuiv.value.origin
                    let nSize = oldSize != tuiv.value.size ?
                        oldSize : tuiv.value.size
                    let tv = TextValue(string: String(oldString),
                                       replacedRange: tuiv.value.replacedRange,
                                       origin: nOrigin, size: nSize)
                    let nTUIV = IndexValue(value: tv, index: tuiv.index)
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.replaceString(nTUIV), type: reversedType)
                }
            } else {
                history[result.version]
                    .values[result.valueIndex].error()
            }
        case .changedColors(let colorUndoValue):
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            if !colorUndoValue.planeIndexes.isEmpty {
                let maxPISI = colorUndoValue.planeIndexes.max { $0 < $1 }
                if let maxPISI = maxPISI, maxPISI < model.picture.planes.count {
                    for i in colorUndoValue.planeIndexes {
                        if model.picture.planes[i].uuColor != colorUndoValue.uuColor {
                            error()
                            break
                        }
                    }
                } else {
                    error()
                }
            }
            if colorUndoValue.isBackground && model.backgroundUUColor != colorUndoValue.uuColor {
                error()
            }
        case .insertBorders(let bivs):
            let maxI = bivs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.borders.count {
                let oldBIVS = bivs.map { IndexValue(value: model.borders[$0.index],
                                                    index: $0.index) }
                if oldBIVS != bivs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertBorders(oldBIVS), type: reversedType)
                }
            } else {
                history[result.version]
                    .values[result.valueIndex].error()
            }
        case .removeBorders(let borderIndexes):
            let oldBIS = borderIndexes.filter { $0 < model.borders.count + borderIndexes.count }.sorted()
            if oldBIS != borderIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removeBorders(borderIndexes: oldBIS), type: reversedType)
            }
        }
        
        guard let nuiv = history[result.version].values[result.valueIndex]
                .undoItemValue else { return }
        switch isUndo ? nuiv.undoItem : nuiv.redoItem {
        case .appendLine(_): break
        case .appendLines(_): break
        case .appendPlanes(_): break
        case .removeLastLines(let count):
            if count > model.picture.lines.count {
                history[result.version]
                    .values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .appendLines(model.picture.lines),
                                    redoItem: .removeLastLines(count: model.picture.lines.count),
                                    isReversed: isUndo)
            }
        case .removeLastPlanes(let count):
            if count > model.picture.planes.count {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .appendPlanes(model.picture.planes),
                                    redoItem: .removeLastPlanes(count: model.picture.planes.count),
                                    isReversed: isUndo)
            }
        case .insertLines(var livs):
            var isChanged = false, linesCount = model.picture.lines.count
            livs.enumerated().forEach { (k, iv) in
                if iv.index > linesCount {
                    livs[k].index = linesCount
                    isChanged = true
                }
                linesCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removeLines(lineIndexes: livs.map { $0.index }),
                                    redoItem: .insertLines(livs),
                                    isReversed: isUndo)
            }
        case .insertPlanes(var pivs):
            var isChanged = false, planesCount = model.picture.planes.count
            pivs.enumerated().forEach { (k, iv) in
                if iv.index > planesCount {
                    pivs[k].index = planesCount
                    isChanged = true
                }
                planesCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removePlanes(planeIndexes: pivs.map { $0.index }),
                                    redoItem: .insertPlanes(pivs),
                                    isReversed: isUndo)
            }
        case .removeLines(var lineIndexes):
            let lis = lineIndexes.filter { $0 < model.picture.lines.count }.sorted()
            if lineIndexes != lis {
                lineIndexes = lis
                let livs = lineIndexes.map {
                    IndexValue(value: model.picture.lines[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertLines(livs),
                                    redoItem: .removeLines(lineIndexes: lis),
                                    isReversed: isUndo)
            }
        case .removePlanes(var planeIndexes):
            let pis = planeIndexes.filter { $0 < model.picture.planes.count }.sorted()
            if planeIndexes != pis {
                planeIndexes = pis
                let pivs = planeIndexes.map {
                    IndexValue(value: model.picture.planes[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertPlanes(pivs),
                                    redoItem: .removePlanes(planeIndexes: pis),
                                    isReversed: isUndo)
            }
        case .setPlaneValue(var planeValue):
            var isChanged = false
            let oldPlanesCount = model.picture.planes.count
            if oldPlanesCount > 0 {
                for (i, v) in planeValue.moveIndexValues.enumerated() {
                    if v.value >= oldPlanesCount {
                        planeValue.moveIndexValues[i].value = oldPlanesCount - 1
                        isChanged = true
                    }
                }
            } else {
                planeValue.moveIndexValues = []
            }
            
            var planesCount = planeValue.planes.count
            planeValue.moveIndexValues.enumerated().forEach { (k, iv) in
                if iv.index > planesCount {
                    planeValue.moveIndexValues[k].index = planesCount
                    isChanged = true
                }
                planesCount += 1
            }
            
            var isArray = Array(repeating: false,
                                count: model.picture.planes.count)
            for v in planeValue.moveIndexValues {
                isArray[v.value] = true
            }
            let oldPlanes = model.picture.planes.enumerated().compactMap {
                isArray[$0.offset] ? nil : $0.element
            }
            let oldVs = planeValue.moveIndexValues
                .map { IndexValue(value: $0.index, index: $0.value) }
                .sorted { $0.index < $1.index }
            let oldPlaneValue = PlaneValue(planes: oldPlanes,
                                           moveIndexValues: oldVs)
            
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .setPlaneValue(oldPlaneValue),
                                    redoItem: .setPlaneValue(planeValue),
                                    isReversed: isUndo)
            } else {
                switch result.type {
                case .undo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.redoItem = .setPlaneValue(oldPlaneValue)
                case .redo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.undoItem = .setPlaneValue(oldPlaneValue)
                }
            }
        case .changeToDraft(_):
            break
        case .setPicture(_):
            switch result.type {
            case .undo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.redoItem = .setPicture(model.picture)
            case .redo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.undoItem = .setPicture(model.picture)
            }
        case .insertDraftLines(var livs):
            var isChanged = false, linesCount = model.draftPicture.lines.count
            livs.enumerated().forEach { (k, iv) in
                if iv.index > linesCount {
                    livs[k].index = linesCount
                    isChanged = true
                }
                linesCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removeDraftLines(lineIndexes: livs.map { $0.index }),
                                    redoItem: .insertDraftLines(livs),
                                    isReversed: isUndo)
            }
        case .insertDraftPlanes(var pivs):
            var isChanged = false, planesCount = model.draftPicture.planes.count
            pivs.enumerated().forEach { (k, iv) in
                if iv.index > planesCount {
                    pivs[k].index = planesCount
                    isChanged = true
                }
                planesCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removeDraftPlanes(planeIndexes: pivs.map { $0.index }),
                                    redoItem: .insertDraftPlanes(pivs),
                                    isReversed: isUndo)
            }
        case .removeDraftLines(var lineIndexes):
            let lis = lineIndexes.filter { $0 < model.draftPicture.lines.count }.sorted()
            if lineIndexes != lis {
                lineIndexes = lis
                let livs = lineIndexes.map {
                    IndexValue(value: model.draftPicture.lines[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertDraftLines(livs),
                                    redoItem: .removeDraftLines(lineIndexes: lis),
                                    isReversed: isUndo)
            }
        case .removeDraftPlanes(var planeIndexes):
            let pis = planeIndexes.filter { $0 < model.draftPicture.planes.count }.sorted()
            if planeIndexes != pis {
                planeIndexes = pis
                let pivs = planeIndexes.map {
                    IndexValue(value: model.draftPicture.planes[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertDraftPlanes(pivs),
                                    redoItem: .removeDraftPlanes(planeIndexes: pis),
                                    isReversed: isUndo)
            }
        case .setDraftPicture(_):
            switch result.type {
            case .undo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.redoItem = .setDraftPicture(model.draftPicture)
            case .redo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.undoItem = .setDraftPicture(model.draftPicture)
            }
        case .insertTexts(var tivs):
            var isChanged = false, textsCount = model.texts.count
            tivs.enumerated().forEach { (k, iv) in
                if iv.index > textsCount {
                    tivs[k].index = textsCount
                    isChanged = true
                }
                textsCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removeTexts(textIndexes: tivs.map { $0.index }),
                                    redoItem: .insertTexts(tivs),
                                    isReversed: isUndo)
            }
        case .removeTexts(var textIndexes):
            let tis = textIndexes.filter { $0 < model.texts.count }.sorted()
            if textIndexes != tis {
                textIndexes = tis
                let tivs = textIndexes.map {
                    IndexValue(value: model.texts[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertTexts(tivs),
                                    redoItem: .removeTexts(textIndexes: tis),
                                    isReversed: isUndo)
            }
        case .replaceString(var tuiv):
            guard !model.texts.isEmpty else {
                history[result.version]
                    .values[result.valueIndex].error()
                break
            }
            var isChanged = false
            if tuiv.index >= model.texts.count {
                tuiv.index = model.texts.count - 1
                isChanged = true
            }
            let oldString = model.texts[tuiv.index].string
            if tuiv.value.replacedRange.lowerBound < 0 {
                tuiv.value.replacedRange
                    = 0..<tuiv.value.replacedRange.upperBound
                isChanged = true
            }
            if tuiv.value.replacedRange.lowerBound > oldString.count {
                tuiv.value.replacedRange
                    = oldString.count..<oldString.count
                isChanged = true
            }
            if tuiv.value.replacedRange.upperBound > oldString.count {
                tuiv.value.replacedRange
                    = tuiv.value.replacedRange.lowerBound..<oldString.count
                isChanged = true
            }
            let oldRange = tuiv.value.newRange
            let oldOrigin = tuiv.value.origin != nil ?
                model.texts[tuiv.index].origin : nil
            let oldSize = tuiv.value.size != nil ?
                model.texts[tuiv.index].size : nil
            let nRange = oldString.range(fromInt: tuiv.value.replacedRange)
            let nString = String(oldString[nRange])
            let tv = TextValue(string: nString,
                               replacedRange: oldRange,
                               origin: oldOrigin, size: oldSize)
            let tiv = IndexValue(value: tv, index: tuiv.index)
            if isChanged {
                history[result.version]
                    .values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .replaceString(tiv),
                                    redoItem: .replaceString(tuiv),
                                    isReversed: isUndo)
            } else {
                switch result.type {
                case .undo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.redoItem = .replaceString(tiv)
                case .redo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.undoItem = .replaceString(tiv)
                }
            }
        case .changedColors(var colorUndoValue):
            let pis = colorUndoValue.planeIndexes.filter {
                $0 < model.picture.planes.count
            }
            var isChanged = false
            if colorUndoValue.planeIndexes != pis {
                colorUndoValue.planeIndexes = pis
                isChanged = true
            }
            var oColorUndoValue = colorUndoValue
            if let pi = oColorUndoValue.planeIndexes.first {
                oColorUndoValue.uuColor = model.picture.planes[pi].uuColor
            } else {
                oColorUndoValue.uuColor = model.backgroundUUColor
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .changedColors(oColorUndoValue),
                                    redoItem: .changedColors(colorUndoValue),
                                    isReversed: isUndo)
            } else {
                switch result.type {
                case .undo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.redoItem = .changedColors(oColorUndoValue)
                case .redo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.undoItem = .changedColors(oColorUndoValue)
                }
            }
        case .insertBorders(var bivs):
            var isChanged = false, bordersCount = model.borders.count
            bivs.enumerated().forEach { (k, iv) in
                if iv.index > bordersCount {
                    bivs[k].index = bordersCount
                    isChanged = true
                }
                bordersCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removeBorders(borderIndexes: bivs.map { $0.index }),
                                    redoItem: .insertBorders(bivs),
                                    isReversed: isUndo)
            }
        case .removeBorders(var borderIndexes):
            let bis = borderIndexes.filter { $0 < model.borders.count }.sorted()
            if borderIndexes != bis {
                borderIndexes = bis
                let bivs = borderIndexes.map {
                    IndexValue(value: model.borders[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertBorders(bivs),
                                    redoItem: .removeBorders(borderIndexes: bis),
                                    isReversed: isUndo)
            }
        }
    }
    
    func textTuple(at p: Point) -> (textView: SheetTextView,
                                    textIndex: Int,
                                    stringIndex: String.Index,
                                    cursorIndex: String.Index)? {
        var n: (textView: SheetTextView,
                textIndex: Int,
                stringIndex: String.Index,
                cursorIndex: String.Index)?
        var minD = Double.infinity
        for (ti, textView) in textsView.elementViews.enumerated() {
            if textView.transformedBounds?.contains(p) ?? false {
                let inP = textView.convert(p, from: node)
                if let i = textView.characterIndex(for: inP),
                   let cr = textView.characterRatio(for: inP) {
                    
                    let sri = cr > 0.5 ?
                        textView.typesetter.index(after: i) : i
                    
                    let np = textView.typesetter.characterPosition(at: sri)
                    let d = p.distanceSquared(textView.convert(np, to: node))
                    if d < minD {
                        minD = d
                        n = (textView, ti, i, sri)
                    }
                }
            }
        }
        return n
    }
    func lineTuple(at p: Point, isSmall ois: Bool? = nil,
                   scale: Double) -> (lineView: SheetLineView,
                                      lineIndex: Int)? {
        let isSmall = ois ??
            (sheetColorOwner(at: p).uuColor != Sheet.defalutBackgroundUUColor)
        let ds = Line.defaultLineWidth * 3 * scale
        
        var minI: Int?, minDSquared = Double.infinity
        for (i, line) in model.picture.lines.enumerated() {
            let nd = isSmall ? (line.size / 2 + ds) / 4 : line.size / 2 + ds
            let ldSquared = nd * nd
            let dSquared = line.minDistanceSquared(at: p)
            if dSquared < minDSquared && dSquared < ldSquared {
                minI = i
                minDSquared = dSquared
            }
        }
        if let i = minI {
            return (linesView.elementViews[i], i)
        } else {
            return nil
        }
    }
    
    func autoUUColor(with uuColors: [UUColor],
                     baseUUColor: UUColor = UU(Color(lightness: 85)),
                     lRanges: [ClosedRange<Double>] = [0.78...0.8,
                                                       0.82...0.84,
                                                       0.86...0.88,
                                                       0.9...0.92]) -> UUColor {
        var vs = Array(repeating: false, count: lRanges.count)
        uuColors.forEach {
            for (i, lRange) in lRanges.enumerated() {
                if lRange.contains($0.value.lightness) {
                    vs[i] = true
                }
            }
        }
        var uuColor = baseUUColor
        uuColor.value.lightness = Double.random(in: lRanges[vs.firstIndex(of: false) ?? 0])
        return uuColor
    }
    
    var soundNode: Node?
    var isSound = false {
        didSet {
            if let soundNode = self.soundNode {
                soundNode.removeFromParent()
                self.soundNode = nil
            }
            if let waveTrack = waveTrack {
                let soundNode = Node()
                soundNode.children = waveTrack.lineNodes(bounds: model.bounds,
                                                         from: .horizontal,
                                                         bpm: 120)
                node.insert(child: soundNode, at: 0)
                self.soundNode = soundNode
            }
        }
    }
    var waveTrack: WaveTrack? {
        guard isSound else { return nil }
        var wt = WaveTrack()
        wt.lineWaves = model.picture.lines.map {
            LineWave(line: wt.waveLine(from: $0,
                                       bounds: Sheet.defaultBounds,
                                       orientation: .horizontal))
        }
        return wt
    }
    
    func capture(intRange: Range<Int>, subString: String,
                 captureString: String, captureOrigin: Point?,
                 captureSize: Double?,
                 at i: Int, in textView: SheetTextView) {
        let oldIntRange = intRange.lowerBound..<(intRange.lowerBound + subString.count)
        let range = captureString.range(fromInt: intRange)
        
        let newOrigin, oldOrigin: Point?
        if let captureOrigin = captureOrigin,
           captureOrigin != textView.model.origin {
            newOrigin = textView.model.origin
            oldOrigin = captureOrigin
        } else {
            newOrigin = nil
            oldOrigin = nil
        }
        
        let newSize, oldSize: Double?
        if let captureSize = captureSize,
           captureSize != textView.model.size {
            newSize = textView.model.size
            oldSize = captureSize
        } else {
            newSize = nil
            oldSize = nil
        }
        
        let otv = TextValue(string: String(captureString[range]),
                            replacedRange: oldIntRange,
                            origin: oldOrigin, size: oldSize)
        let tv = TextValue(string: subString,
                           replacedRange: intRange,
                           origin: newOrigin, size: newSize)
        capture(IndexValue(value: tv, index: i),
                old: IndexValue(value: otv, index: i))
    }
    func capture(captureOrigin: Point,
                 at i: Int, in textView: SheetTextView) {
        let newOrigin = textView.model.origin
        guard newOrigin != captureOrigin else { return }
        let oldOrigin = captureOrigin
        
        let otv = TextValue(string: "", replacedRange: 0..<0,
                            origin: oldOrigin, size: nil)
        let tv = TextValue(string: "", replacedRange: 0..<0,
                           origin: newOrigin, size: nil)
        capture(IndexValue(value: tv, index: i),
                old: IndexValue(value: otv, index: i))
    }
    
    func lassoErase(with lasso: Lasso,
                    distance d: Double = 0,
                    isStraight: Bool = false,
                    isRemove: Bool,
                    isEnableLine: Bool = true,
                    isEnablePlane: Bool = true,
                    isEnableText: Bool = true,
                    selections: [Selection] = [],
                    isDraft: Bool = false,
                    isUpdateUndoGroup: Bool = false) -> SheetValue? {
        guard let nlb = lasso.bounds else { return nil }
        guard node.bounds?.intersects(nlb) ?? false else { return nil }
        
        var isUpdateUndoGroup = isUpdateUndoGroup
        func updateUndoGroup() {
            if !isUpdateUndoGroup {
                newUndoGroup()
                isUpdateUndoGroup = true
            }
        }
        
        var ssValue = SheetValue()
        
        if isEnableLine {
            var removeLines = [Line](), splitedLines = [Line]()
            var removeLineIndexes = [Int]()
            let linesView = isDraft ? self.draftLinesView : self.linesView
            if isStraight {
                let p = lasso.line.firstPoint
                var minLineIndex: Int?, minDSquared = Double.infinity
                for (i, aLine) in linesView.model.enumerated() {
                    let dSquared = aLine.minDistanceSquared(at: p)
                    if dSquared < minDSquared {
                        minDSquared = dSquared
                        minLineIndex = i
                    }
                }
                if let i = minLineIndex {
                    removeLineIndexes.append(i)
                    removeLines.append(linesView.model[i])
                }
            } else {
                let nSplitLines: [Line], nd: Double
                if d > 0 {
                    let snlb = nlb.outset(by: d + 0.0001)
                    let splitLines = linesView.model.filter {
                        $0.bounds?.outset(by: $0.size / 2).intersects(snlb) ?? false
                    }
                    if splitLines.count < 50 {
                        let count = splitLines.reduce(0) {
                            lasso.intersects($1) ? $0 + 1 : $0
                        }
                        nd = count <= 3 ? d * 2 : d
                        nSplitLines = splitLines
                    } else {
                        nd = d
                        nSplitLines = []
                    }
                } else {
                    nd = d
                    nSplitLines = []
                }
                for (i, aLine) in linesView.model.enumerated() {
                    if let splitedLine = lasso
                        .splitedLine(with: aLine,
                                     splitLines: nSplitLines,
                                     distance: nd) {
                        switch splitedLine {
                        case .around(let line):
                            removeLineIndexes.append(i)
                            removeLines.append(line)
                        case .split(let (aRemoveLines, aSplitLines)):
                            removeLineIndexes.append(i)
                            removeLines += aRemoveLines
                            splitedLines += aSplitLines
                        }
                    }
                }
            }
            if isRemove && (!removeLineIndexes.isEmpty || !splitedLines.isEmpty) {
                updateUndoGroup()
                if !removeLineIndexes.isEmpty {
                    if isDraft {
                        self.removeDraftLines(at: removeLineIndexes)
                    } else {
                        self.removeLines(at: removeLineIndexes)
                    }
                }
                if isDraft {
                    insertDraft(splitedLines.enumerated().map {
                        IndexValue(value: $0.element, index: $0.offset)
                    })
                } else {
                    append(splitedLines)
                }
            }
            ssValue.lines = removeLines
        }
        
        let nPath = lasso.line.path(isClosed: true, isPolygon: false)
        
        if isEnablePlane {
            let planesView = isDraft ? self.draftPlanesView : self.planesView
            let indexValues = planesView.elementViews.enumerated().compactMap {
                nPath.contains($0.element.node.path) ?
                    IndexValue(value: $0.element.model, index: $0.offset) : nil
            }
            if !indexValues.isEmpty {
                if isRemove {
                    updateUndoGroup()
                    if isDraft {
                        removeDraftPlanes(at: indexValues.map { $0.index })
                    } else {
                        removePlanes(at: indexValues.map { $0.index })
                    }
                }
                ssValue.planes += indexValues.map { $0.value }
            }
        }
        
        if isEnableText {
            for (ti, textView) in textsView.elementViews.enumerated().reversed() {
                
                guard textView.transformedBounds
                        .intersects(nlb) else { continue }
                var ranges = [Range<String.Index>]()
                if let selection = selections.first {
                    let nRect = textView.convertFromWorld(selection.rect)
                    let tfp = textView.convertFromWorld(selection.firstOrigin)
                    let tlp = textView.convertFromWorld(selection.lastOrigin)
                    if textView.intersects(nRect),
                       let fi = textView.characterIndexWithOutOfBounds(for: tfp),
                       let li = textView.characterIndexWithOutOfBounds(for: tlp) {
                        
                        ranges.append(fi < li ? fi..<li : li..<fi)
                    }
                } else {
                    for typeline in textView.typesetter.typelines {
                        let tlRange = typeline.range
                        var oldI: String.Index?
                        var isRemoveAll = true
                        
                        let range: Range<String.Index>
                        if !typeline.isReturnEnd {
                            range = tlRange
                        } else if tlRange.lowerBound < tlRange.upperBound {
                            range = tlRange.lowerBound..<tlRange.upperBound
                        } else { continue }
                        
                        for i in textView.model.string[range].indices {
                            let tb = textView.typesetter
                                .characterBounds(at: i)!
                                .outset(by: textView.lassoPadding)
                                + textView.model.origin
                            if nPath.intersects(tb) {
                                if oldI == nil {
                                    oldI = i
                                }
                            } else {
                                isRemoveAll = false
                                if let oldI = oldI {
                                    ranges.append(oldI..<i)
                                }
                                oldI = nil
                            }
                        }
                        if isRemoveAll {
                            ranges.append(tlRange)
                        } else if let oldI = oldI, oldI < range.upperBound {
                            ranges.append(oldI..<range.upperBound)
                        }
                        oldI = nil
                    }
                }
                
                guard !ranges.isEmpty else { continue }
                
                var minP = textView.typesetter
                    .characterPosition(at: textView.model.string.startIndex)
                var minI = textView.model.string.endIndex
                for range in ranges {
                    let i = range.lowerBound
                    if i < minI {
                        minI = i
                        minP = textView.typesetter
                            .characterPosition(at: i)
                    }
                }
                let oldText = textView.model
                var text = textView.model
                var removedText = text
                removedText.string = ""
                for range in ranges {
                    removedText.string += text.string[range]
                }
                for range in ranges.reversed() {
                    text.string.removeSubrange(range)
                }
                removedText.origin += minP
                
                if isRemove {
                    if text.string.isEmpty {
                        updateUndoGroup()
                        removeText(at: ti)
                    } else {
                        let os = oldText.string
                        let range = os
                            .intRange(from: os.startIndex..<os.endIndex)
                        
                        let sb = model.bounds.inset(by: Sheet.textPadding)
                        let origin: Point?
                        if let textFrame = text.frame,
                           !sb.contains(textFrame) {
                           
                            let nFrame = sb.clipped(textFrame)
                            origin = text.origin + nFrame.origin - textFrame.origin
                        } else {
                            origin = nil
                        }
                        
                        let tuv = TextValue(string: text.string,
                                            replacedRange: range,
                                            origin: origin, size: nil)
                        updateUndoGroup()
                        replace(IndexValue(value: tuv, index: ti))
                    }
                }
                
                ssValue.texts.append(removedText)
            }
        }
        
        return ssValue.isEmpty ? nil : ssValue
    }
    
    func copy(with line: Line?, at p: Point, isRemove: Bool = false) {
        if let line = line {
            if let value = lassoErase(with: Lasso(line: line),
                                      isRemove: isRemove) {
                let t = Transform(translation: -convertFromWorld(p))
                Pasteboard.shared.copiedObjects = [.sheetValue(value * t)]
            } else {
                Pasteboard.shared.copiedObjects = []
            }
        } else {
            let ssv = SheetValue(lines: model.picture.lines,
                                 planes: model.picture.planes,
                                 texts: model.texts)
            if !ssv.isEmpty {
                if isRemove {
                    newUndoGroup()
                    if !model.picture.isEmpty {
                        set(Picture())
                    }
                    if !model.texts.isEmpty {
                        removeText(at: Array(0..<model.texts.count))
                    }
                }
                let t = Transform(translation: -convertFromWorld(p))
                Pasteboard.shared.copiedObjects = [.sheetValue(ssv * t)]
            } else {
                Pasteboard.shared.copiedObjects = []
            }
        }
    }
    func changeToDraft(with line: Line?) {
        if let line = line {
            if let value = lassoErase(with: Lasso(line: line),
                                      isRemove: true, isEnableText: false) {
                if !value.lines.isEmpty {
                    let li = model.draftPicture.lines.count
                    insertDraft(value.lines.enumerated().map {
                        IndexValue(value: $0.element, index: li + $0.offset)
                    })
                }
                if !value.planes.isEmpty {
                    let pi = model.draftPicture.planes.count
                    insertDraft(value.planes.enumerated().map {
                        IndexValue(value: $0.element, index: pi + $0.offset)
                    })
                }
            }
        } else {
            if !model.picture.isEmpty {
                if model.draftPicture.isEmpty {
                    newUndoGroup()
                    
                    changeToDraft()
                } else {
                    newUndoGroup()
                    if !model.picture.lines.isEmpty {
                        let li = model.draftPicture.lines.count
                        insertDraft(model.picture.lines.enumerated().map {
                            IndexValue(value: $0.element, index: li + $0.offset)
                        })
                    }
                    if !model.picture.planes.isEmpty {
                        let pi = model.draftPicture.planes.count
                        insertDraft(model.picture.planes.enumerated().map {
                            IndexValue(value: $0.element, index: pi + $0.offset)
                        })
                    }
                    set(Picture())
                }
            }
        }
    }
    func removeDraft(with line: Line, at p: Point) -> SheetValue? {
        if let value = lassoErase(with: Lasso(line: line),
                                  isRemove: true,
                                  isEnableText: false,
                                  isDraft: true) {
            let t = Transform(translation: -convertFromWorld(p))
            return value * t
        }
        return nil
    }
    func cutDraft(with line: Line?, at p: Point) {
        if let line = line {
            if let value = lassoErase(with: Lasso(line: line),
                                      isRemove: true,
                                      isEnableText: false,
                                      isDraft: true) {
                let t = Transform(translation: -convertFromWorld(p))
                Pasteboard.shared.copiedObjects = [.sheetValue(value * t)]
            }
        } else {
            let object = PastableObject.picture(model.draftPicture)
            if !model.draftPicture.isEmpty {
                newUndoGroup()
                removeDraft()
                Pasteboard.shared.copiedObjects = [object]
            }
        }
    }
    
    func makeFaces(with path: Path?) {
        let b = model.bounds
        let result = model.picture
            .autoFill(inFrame: b,
                      clipingPath: path, borders: model.borders)
        switch result {
        case .planes(let planes):
            newUndoGroup()
            append(planes)
        case .planeValue(let planeValue):
            newUndoGroup()
            set(planeValue)
        case .none: break
        }
    }
    func removeFilledFaces(with path: Path?, at p: Point) -> SheetValue? {
        var removePlaneValues = Array(planesView.elementViews.enumerated())
        if let path = path {
            removePlaneValues = removePlaneValues.filter {
                path.intersects($0.element.node.path)
            }
        }
        if !removePlaneValues.isEmpty {
            newUndoGroup()
            let planes = removePlaneValues.map { $0.element.model }
            let t = Transform(translation: -convertFromWorld(p))
            removePlanes(at: removePlaneValues.map { $0.offset })
            return SheetValue(lines: [], planes: planes, texts: []) * t
        } else {
            return nil
        }
    }
    func cutFaces(with path: Path?) {
        var removePlaneValues = Array(planesView.elementViews.enumerated())
        if let path = path {
            removePlaneValues = removePlaneValues.filter {
                path.intersects($0.element.node.path)
            }
        }
        let isRemoveBackground
            = model.backgroundUUColor != Sheet.defalutBackgroundUUColor
            && path == nil
        
        if isRemoveBackground || !removePlaneValues.isEmpty {
            newUndoGroup()
            if !removePlaneValues.isEmpty {
                let planes = removePlaneValues.map { $0.element.model }
                Pasteboard.shared.copiedObjects
                    = [.planesValue(PlanesValue(planes: planes))]
                removePlanes(at: removePlaneValues.map { $0.offset })
            }
            if isRemoveBackground {
                let ncv = ColorValue(uuColor: Sheet.defalutBackgroundUUColor,
                                     planeIndexes: [],
                                     isBackground: true)
                let ocv = ColorValue(uuColor: model.backgroundUUColor,
                                     planeIndexes: [],
                                     isBackground: true)
                backgroundUUColor = ncv.uuColor
                capture(ncv, oldColorValue: ocv)
            }
        }
    }
}

final class SheetColorOwner {
    let sheetView: SheetView
    private(set) var colorValue: ColorValue
    let oldColorValue: ColorValue
    var uuColor: UUColor {
        get { colorValue.uuColor }
        set {
            colorValue.uuColor = newValue
            sheetView.set(colorValue)
        }
    }
    
    init(sheetView: SheetView, colorValue: ColorValue) {
        self.sheetView = sheetView
        self.colorValue = colorValue
        oldColorValue = colorValue
    }
    
    func captureUUColor(isNewUndoGroup: Bool = true) {
        if isNewUndoGroup {
            sheetView.history.newUndoGroup()
        }
        sheetView.capture(colorValue, oldColorValue: oldColorValue)
    }
    func colorPathValue(toColor: Color?,
                        color: Color, subColor: Color) -> ColorPathValue {
        sheetView.colorPathValue(with: colorValue,
                                 toColor: toColor,
                                 color: color, subColor: subColor)
    }
}
