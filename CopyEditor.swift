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

import struct Foundation.Data

struct ColorPathValue {
    var paths: [Path], lineType: Node.LineType?, fillType: Node.FillType?
}

struct CopiedSheetsValue: Equatable {
    var deltaPoint = Point()
    var sheetIDs = [SheetPosition: SheetID]()
}
extension CopiedSheetsValue: Protobuf {
    init(_ pb: PBCopiedSheetsValue) throws {
        deltaPoint = try Point(pb.deltaPoint)
        sheetIDs = try [SheetPosition: SheetID](pb.sheetIds)
    }
    var pb: PBCopiedSheetsValue {
        PBCopiedSheetsValue.with {
            $0.deltaPoint = deltaPoint.pb
            $0.sheetIds = sheetIDs.pb
        }
    }
}
extension CopiedSheetsValue: Codable {}

struct PlanesValue: Codable {
    var planes: [Plane]
}
extension PlanesValue: Protobuf {
    init(_ pb: PBPlanesValue) throws {
        planes = try pb.planes.map { try Plane($0) }
    }
    var pb: PBPlanesValue {
        PBPlanesValue.with {
            $0.planes = planes.map { $0.pb }
        }
    }
}

enum PastableObject {
    case copiedSheetsValue(_ copiedSheetsValue: CopiedSheetsValue)
    case sheetValue(_ sheetValue: SheetValue)
    case border(_ border: Border)
    case text(_ text: Text)
    case string(_ string: String)
    case picture(_ picture: Picture)
    case planesValue(_ planesValue: PlanesValue)
    case uuColor(_ uuColor: UUColor)
}
extension PastableObject {
    static func typeName(with obj: Any) -> String {
        return System.id + "." + String(describing: type(of: obj))
    }
    static func objectTypeName(with typeName: String) -> String {
        return typeName.replacingOccurrences(of: System.id + ".", with: "")
    }
    static func objectTypeName<T>(with obj: T.Type) -> String {
        return String(describing: obj)
    }
    struct PastableError: Error {}
    var typeName: String {
        switch self {
        case .copiedSheetsValue(let copiedSheetsValue):
            return PastableObject.typeName(with: copiedSheetsValue)
        case .sheetValue(let sheetValue):
            return PastableObject.typeName(with: sheetValue)
        case .border(let border):
            return PastableObject.typeName(with: border)
        case .text(let text):
            return PastableObject.typeName(with: text)
        case .string(let string):
            return PastableObject.typeName(with: string)
        case .picture(let picture):
            return PastableObject.typeName(with: picture)
        case .planesValue(let planesValue):
            return PastableObject.typeName(with: planesValue)
        case .uuColor(let uuColor):
            return PastableObject.typeName(with: uuColor)
        }
    }
    init(data: Data, typeName: String) throws {
        let objectname = PastableObject.objectTypeName(with: typeName)
        switch objectname {
        case PastableObject.objectTypeName(with: CopiedSheetsValue.self):
            self = .copiedSheetsValue(try CopiedSheetsValue(serializedData: data))
        case PastableObject.objectTypeName(with: SheetValue.self):
            self = .sheetValue(try SheetValue(serializedData: data))
        case PastableObject.objectTypeName(with: Border.self):
            self = .border(try Border(serializedData: data))
        case PastableObject.objectTypeName(with: Text.self):
            self = .text(try Text(serializedData: data))
        case PastableObject.objectTypeName(with: String.self):
            if let string = String(data: data, encoding: .utf8) {
                self = .string(string)
            } else {
                throw PastableObject.PastableError()
            }
        case PastableObject.objectTypeName(with: Picture.self):
            self = .picture(try Picture(serializedData: data))
        case PastableObject.objectTypeName(with: PlanesValue.self):
            self = .planesValue(try PlanesValue(serializedData: data))
        case PastableObject.objectTypeName(with: UUColor.self):
            self = .uuColor(try UUColor(serializedData: data))
        default:
            throw PastableObject.PastableError()
        }
    }
    var data: Data? {
        switch self {
        case .copiedSheetsValue(let copiedSheetsValue):
            return try? copiedSheetsValue.serializedData()
        case .sheetValue(let sheetValue):
            return try? sheetValue.serializedData()
        case .border(let border):
            return try? border.serializedData()
        case .text(let text):
            return try? text.serializedData()
        case .string(let string):
            return string.data(using: .utf8)
        case .picture(let picture):
            return try? picture.serializedData()
        case .planesValue(let planesValue):
            return try? planesValue.serializedData()
        case .uuColor(let uuColor):
            return try? uuColor.serializedData()
        }
    }
}
extension PastableObject: Protobuf {
    init(_ pb: PBPastableObject) throws {
        guard let value = pb.value else {
            throw ProtobufError()
        }
        switch value {
        case .copiedSheetsValue(let copiedSheetsValue):
            self = .copiedSheetsValue(try CopiedSheetsValue(copiedSheetsValue))
        case .sheetValue(let sheetValue):
            self = .sheetValue(try SheetValue(sheetValue))
        case .border(let border):
            self = .border(try Border(border))
        case .text(let text):
            self = .text(try Text(text))
        case .string(let string):
            self = .string(string)
        case .picture(let picture):
            self = .picture(try Picture(picture))
        case .planesValue(let planesValue):
            self = .planesValue(try PlanesValue(planesValue))
        case .uuColor(let uuColor):
            self = .uuColor(try UUColor(uuColor))
        }
    }
    var pb: PBPastableObject {
        PBPastableObject.with {
            switch self {
            case .copiedSheetsValue(let copiedSheetsValue):
                $0.value = .copiedSheetsValue(copiedSheetsValue.pb)
            case .sheetValue(let sheetValue):
                $0.value = .sheetValue(sheetValue.pb)
            case .border(let border):
                $0.value = .border(border.pb)
            case .text(let text):
                $0.value = .text(text.pb)
            case .string(let string):
                $0.value = .string(string)
            case .picture(let picture):
                $0.value = .picture(picture.pb)
            case .planesValue(let planesValue):
                $0.value = .planesValue(planesValue.pb)
            case .uuColor(let uuColor):
                $0.value = .uuColor(uuColor.pb)
            }
        }
    }
}
extension PastableObject: Codable {
    private enum CodingTypeKey: String, Codable {
        case copiedSheetsValue = "0"
        case sheetValue = "1"
        case border = "2"
        case text = "3"
        case string = "4"
        case picture = "5"
        case planesValue = "6"
        case uuColor = "7"
    }
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let key = try container.decode(CodingTypeKey.self)
        switch key {
        case .copiedSheetsValue:
            self = .copiedSheetsValue(try container.decode(CopiedSheetsValue.self))
        case .sheetValue:
            self = .sheetValue(try container.decode(SheetValue.self))
        case .border:
            self = .border(try container.decode(Border.self))
        case .text:
            self = .text(try container.decode(Text.self))
        case .string:
            self = .string(try container.decode(String.self))
        case .picture:
            self = .picture(try container.decode(Picture.self))
        case .planesValue:
            self = .planesValue(try container.decode(PlanesValue.self))
        case .uuColor:
            self = .uuColor(try container.decode(UUColor.self))
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .copiedSheetsValue(let copiedSheetsValue):
            try container.encode(CodingTypeKey.copiedSheetsValue)
            try container.encode(copiedSheetsValue)
        case .sheetValue(let sheetValue):
            try container.encode(CodingTypeKey.sheetValue)
            try container.encode(sheetValue)
        case .border(let border):
            try container.encode(CodingTypeKey.border)
            try container.encode(border)
        case .text(let text):
            try container.encode(CodingTypeKey.text)
            try container.encode(text)
        case .string(let string):
            try container.encode(CodingTypeKey.string)
            try container.encode(string)
        case .picture(let picture):
            try container.encode(CodingTypeKey.picture)
            try container.encode(picture)
        case .planesValue(let planesValue):
            try container.encode(CodingTypeKey.picture)
            try container.encode(planesValue)
        case .uuColor(let uuColor):
            try container.encode(CodingTypeKey.uuColor)
            try container.encode(uuColor)
        }
    }
}
extension PastableObject {
    enum FileType: FileTypeProtocol {
        case skp
        var name: String { "Pastable Object" }
        var utType: String { "skp" }
    }
}

final class Cutter: InputKeyEditor {
    let editor: CopyEditor
    
    init(_ document: Document) {
        editor = CopyEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.cut(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class Copier: InputKeyEditor {
    let editor: CopyEditor
    
    init(_ document: Document) {
        editor = CopyEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.copy(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class Paster: InputKeyEditor {
    let editor: CopyEditor
    
    init(_ document: Document) {
        editor = CopyEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.paste(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class CopyEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    enum CopiableType {
        case cut, copy, paste
    }
    var type = CopiableType.cut
    var snapLineNode = Node(fillType: .color(.subSelected))
    var selectingLineNode = Node(lineWidth: 1.5)
    var beganScale = 1.0, editingP = Point(), editingSP = Point()
    var pasteObject = PastableObject.sheetValue(SheetValue())
    var isEditingText = false
    
    func updateNode() {
        if selectingLineNode.children.isEmpty {
            selectingLineNode.lineWidth = document.worldLineWidth
        } else {
            let w = document.worldLineWidth
            for node in selectingLineNode.children {
                node.lineWidth = w
            }
            for node in pasteSheetNode.children {
                node.lineWidth = w
            }
        }
        if isEditingSheet {
            switch type {
            case .cut: updateWithCopy(for: editingP, isSendPasteboard: false,
                                      isCutColor: true)
            case .copy: updateWithCopy(for: editingP, isSendPasteboard: true,
                                       isCutColor: false)
            case .paste:
                let p = document.convertScreenToWorld(editingSP)
                updateWithPaste(at: p, atScreen: editingSP, .began)
            }
        }
    }
    
    func borderSnappedPoint(_ p: Point, with sb: Rect, distance d: Double,
                            _ orientation: Orientation) -> (isSnapped: Bool, point: Point) {
        func snapped(_ v: Double, values: [Double]) -> (Bool, Double) {
            for value in values {
                if v > value - d && v < value + d {
                    return (true, value)
                }
            }
            return (false, v)
        }
        switch orientation {
        case .horizontal:
            let (iss, y) = snapped(p.y, values: [sb.height / 4,
                                                 sb.height / 3,
                                                 sb.height / 2,
                                                 2 * sb.height / 3,
                                                 3 * sb.height / 4])
            return (iss, Point(p.x, y).rounded())
        case .vertical:
            let (iss, x) = snapped(p.x, values: [sb.width / 4,
                                                 sb.width / 3,
                                                 sb.width / 2,
                                                 2 * sb.width / 3,
                                                 3 * sb.width / 4])
            return (iss, Point(x, p.y).rounded())
        }
    }
    
    @discardableResult
    func updateWithCopy(for p: Point, isSendPasteboard: Bool, isCutColor: Bool) -> Bool {
        let d = 5 / document.worldToScreenScale
        if document.isSelectSelectedNoneCursor(at: p),
           let r = document.selections.first?.rect {
            if isSendPasteboard {
                let se = LineEditor(document)
                se.updateClipBoundsAndIndexRange(at: p)
                se.tempLine = Line(r) * Transform(translation: -se.centerOrigin)
                se.lassoCopy(isRemove: false,
                             isEnableLine: !document.isSelectedText,
                             isEnablePlane: !document.isSelectedText,
                             selections: document.selections,
                             at: p)
            }
            let rects = document.isSelectedText ?
                document.selectedFrames : [r] + document.selectedFrames
            let lw = Line.defaultLineWidth * 2 / document.worldToScreenScale
            selectingLineNode.children = rects.map {
                Node(path: Path($0),
                     lineWidth: lw,
                     lineType: .color(.selected),
                     fillType: .color(.subSelected))
            }
            return true
        } else if let (sBorder, edge) = document.worldBorder(at: p, distance: d) {
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.border(sBorder)]
            }
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = document.worldLineWidth
            selectingLineNode.path = Path([Pathline([edge.p0, edge.p1])])
            return true
        } else if let (border, _, edge) = document.border(at: p, distance: d) {
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.border(border)]
            }
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = document.worldLineWidth
            selectingLineNode.path = Path([Pathline([edge.p0, edge.p1])])
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let lineView = sheetView.lineTuple(at: sheetView.convertFromWorld(p), scale: 1 / document.worldToScreenScale)?.lineView {
            
            let t = Transform(translation: -sheetView.convertFromWorld(p))
            let ssv = SheetValue(lines: [lineView.model],
                                 planes: [], texts: []) * t
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.sheetValue(ssv)]
            }
            let lw = Line.defaultLineWidth
            let scale = 1 / document.worldToScreenScale
            selectingLineNode.children
                = [Node(path: lineView.node.path * sheetView.node.localTransform,
                        lineWidth: max(lw * 1.5, lw * 2.5 * scale, 1 * scale),
                        lineType: .color(.selected))]
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let (textView, _, _, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)) {
            
            if let result = textView.typesetter.warpCursorOffset(at: textView.convertFromWorld(p)), result.isLastWarp,
               let wcPath = textView.typesetter.warpCursorPath(at: textView.convertFromWorld(p)) {
                
                let x = result.offset +
                    (textView.textOrientation == .horizontal ?
                        textView.model.origin.x : textView.model.origin.y)
                let origin = document.sheetFrame(with: document.sheetPosition(at: p)).origin
                let path =  wcPath * Transform(translation: textView.model.origin + origin)
                selectingLineNode.fillType = .color(.subSelected)
                selectingLineNode.lineType = .color(.selected)
                selectingLineNode.lineWidth = document.worldLineWidth
                selectingLineNode.path = path
                
                let text = textView.model
                let border = Border(location: x,
                                    orientation: text.orientation.reversed())
                Pasteboard.shared.copiedObjects = [.border(border)]
                return true
            }
            
            var text = textView.model
            text.origin -= sheetView.convertFromWorld(p)
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.text(text),
                                                   .string(text.string)]
            }
            let paths = textView.typesetter.allPaddingRects()
                .map { Path(textView.convertToWorld($0)) }
            let scale = 1 / document.worldToScreenScale
            selectingLineNode.children = paths.map {
                Node(path: $0,
                     lineWidth: Line.defaultLineWidth * scale,
                     lineType: .color(.selected),
                     fillType: .color(.subSelected))
            }
            return true
        } else if !document.isDefaultUUColor(at: p) {
            let colorOwners = document.readColorOwner(at: p)
            if !colorOwners.isEmpty {
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.uuColor(document.uuColor(at: p))]
                }
                let scale = 1 / document.worldToScreenScale
                selectingLineNode.children = colorOwners.reduce(into: [Node]()) {
                    let value = $1.colorPathValue(toColor: nil, color: .selected,
                                                  subColor: .subSelected)
                    $0 += value.paths.map {
                        Node(path: $0, lineWidth: Line.defaultLineWidth * 2 * scale,
                             lineType: value.lineType, fillType: value.fillType)
                    }
                }
                return true
            }
        }
        return false
    }
    
    @discardableResult
    func cut(at p: Point) -> Bool {
        let d = 5 / document.worldToScreenScale
        
        if document.isSelectSelectedNoneCursor(at: p),
           let selection = document.selections.first {
            if document.isSelectedText {
                document.textEditor.cut(from: selection, at: p)
            } else {
                let se = LineEditor(document)
                se.updateClipBoundsAndIndexRange(at: p)
                se.tempLine = Line(selection.rect)
                    * Transform(translation: -se.centerOrigin)
                
                se.lassoCopy(isRemove: true,
                             isEnableLine: !document.isSelectedText,
                             isEnablePlane: !document.isSelectedText,
                             selections: document.selections,
                             at: p)
            }
            
            document.selections = []
            return true
        } else if let (border, i, edge) = document.border(at: p, distance: d),
                  let sheetView = document.sheetView(at: p) {
            
            Pasteboard.shared.copiedObjects = [.border(border)]
            selectingLineNode.path = Path([Pathline([edge.p0, edge.p1])])
            sheetView.newUndoGroup()
            sheetView.removeBorder(at: i)
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let (lineView, li) = sheetView
                    .lineTuple(at: sheetView.convertFromWorld(p),
                               isSmall: false,
                               scale: 1 / document.worldToScreenScale) {
            
            let t = Transform(translation: -sheetView.convertFromWorld(p))
            let ssv = SheetValue(lines: [lineView.model],
                                 planes: [], texts: []) * t
            Pasteboard.shared.copiedObjects = [.sheetValue(ssv)]
            
            sheetView.newUndoGroup()
            sheetView.removeLines(at: [li])
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let (textView, ti, _, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)) {
            if let result = textView.typesetter.warpCursorOffset(at: textView.convertFromWorld(p)), result.isLastWarp {
                let x = result.offset
                let widthCount = Typobute.maxWidthCount
                
                var text = textView.model
                if text.widthCount != widthCount {
                    text.widthCount = widthCount
                    
                    let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
                    if let textFrame = text.frame,
                       !sb.contains(textFrame) {
                       
                        let nFrame = sb.clipped(textFrame)
                        text.origin += nFrame.origin - textFrame.origin
                    }
                    let border = Border(location: x,
                                        orientation: text.orientation.reversed())
                    Pasteboard.shared.copiedObjects = [.border(border)]
                    sheetView.newUndoGroup()
                    sheetView.replace([IndexValue(value: text, index: ti)])
                }
                return true
            }
            
            var text = textView.model
            text.origin -= sheetView.convertFromWorld(p)
            
            Pasteboard.shared.copiedObjects = [.text(text),
                                               .string(text.string)]
            let tbs = textView.typesetter.allRects()
            selectingLineNode.path = Path(tbs.map { Pathline(textView.convertToWorld($0)) })
            sheetView.newUndoGroup()
            sheetView.removeText(at: ti)
            return true
        } else if !document.isDefaultUUColor(at: p) {
            let colorOwners = document.readColorOwner(at: p)
            if !colorOwners.isEmpty {
                Pasteboard.shared.copiedObjects = [.uuColor(document.uuColor(at: p))]
                colorOwners.forEach {
                    if $0.colorValue.isBackground {
                        $0.uuColor = Sheet.defalutBackgroundUUColor
                        $0.captureUUColor(isNewUndoGroup: true)
                    }
                    if !$0.colorValue.planeIndexes.isEmpty {
                        $0.sheetView.newUndoGroup()
                        $0.sheetView.removePlanes(at: $0.colorValue.planeIndexes)
                    }
                }
                return true
            }
        }
        return false
    }
    
    var isSnapped = false {
        didSet {
            guard isSnapped != oldValue else { return }
            if isSnapped {
                Feedback.performAlignment()
            }
        }
    }
    
    private var oldScale: Double?, beganRotation = 0.0,
                textNode: Node?, textFrame: Rect?, textScale = 1.0
    
    func updateWithPaste(at p: Point, atScreen sp: Point, _ phase: Phase) {
        let shp = document.sheetPosition(at: p)
        let sb = document.sheetFrame(with: shp)
        let sheetView = document.sheetView(at: shp)
        
        func updateWithValue(_ value: SheetValue) {
            let scale = beganScale * document.screenToWorldScale
            if phase == .began {
                let lineNodes = value.lines.map { $0.node }
                let planeNodes = value.planes.map { $0.node }
                let textNodes = value.texts.map { $0.node }
                let node0 = Node(children: planeNodes + lineNodes)
                let node1 = Node(children: textNodes)
                selectingLineNode.children = [node0, node1]
//                selectingLineNode.children = planeNodes + lineNodes + textNodes
            }
            selectingLineNode.path = Path()
            
            selectingLineNode.children.first?.attitude = Attitude(position: p,
                                                  scale: Size(square: 1.0 * scale),
                                                  rotation: document.camera.rotation - beganRotation)
            
            if let textChildren = selectingLineNode.children.last?.children,
               textChildren.count == value.texts.count {
                let screenScale = document.worldToScreenScale
                let t = Transform(scale: 1.0 * beganScale / screenScale)
                        .rotated(by: document.camera.rotation - beganRotation)
                let nt = t.translated(by: p - sb.minXMinYPoint)
                for (i, text) in value.texts.enumerated() {
                    textChildren[i].attitude = Attitude(position: (text.origin) * nt + sb.minXMinYPoint,
                                                        scale: Size(square: 1.0 * scale))
                }
            }
        }
        func updateWithText(_ text: Text) {
            let inP = p - sb.origin
            var isAppend = false
            
            var textView: SheetTextView?, sri: String.Index?
            if let aTextView = document.textEditor.editingTextView,
               !aTextView.isHiddenSelectedRange {
                
                if let asri = aTextView.selectedRange?.lowerBound {
                    textView = aTextView
                    sri = asri
                }
            } else if let (aTextView, _, _, asri) = sheetView?.textTuple(at: inP) {
                textView = aTextView
                sri = asri
            }
            if let textView = textView, let sri = sri {
                textNode = nil
                let cpath = textView.typesetter.cursorPath(at: sri)
                let path = textView.convertToWorld(cpath)
                selectingLineNode.fillType = .color(.subSelected)
                selectingLineNode.lineType = .color(.selected)
                selectingLineNode.path = path
                selectingLineNode.attitude = Attitude(position: Point())
                selectingLineNode.children = []
                isAppend = true
            }
            if !isAppend {
                let bScale = beganScale * document.screenToWorldScale
                let s = text.font.defaultRatio * bScale
                let os = oldScale ?? s
                func scaleIndex(_ cs: Double) -> Double {
                    if cs <= 1 || text.string.count > 50 {
                        return 1
                    } else {
                        return cs
                    }
                }
                if scaleIndex(os) == scaleIndex(s),
                   let textNode = textNode {
                    selectingLineNode.children = [textNode]
                } else {
                    var ntext = text
                    ntext.origin *= bScale
                    ntext.size *= bScale
                    let textNode = ntext.node
                    selectingLineNode.children = [textNode]
                    self.textNode = textNode
                    self.textFrame = ntext.frame
                    textScale = document.worldToScreenScale
                }
                
                let scale = textScale * document.screenToWorldScale
                let np: Point
                if let stb = textFrame {
                    let textFrame = stb
                        * Attitude(position: p,
                                   scale: Size(square: 1.0 * scale)).transform
                    let sb = sb.inset(by: Sheet.textPadding)
                    if !sb.contains(textFrame) {
                        let nFrame = sb.clipped(textFrame)
                        np = p + nFrame.origin - textFrame.origin
                    } else {
                        np = p
                    }
                } else {
                    np = p
                }
                
                var snapDP = Point(), path: Path?
                if let sheetView = sheetView {
                    let np = sheetView.convertFromWorld(np)
                    let scale = beganScale / document.worldToScreenScale
                    let nnp = text.origin * scale + np
                    let log10Scale: Double = .log10(document.worldToScreenScale)
                    let clipScale = max(0.0, log10Scale)
                    let decimalPlaces = Int(clipScale + 2)
                    let fp1 = nnp.rounded(decimalPlaces: decimalPlaces)
                    let lp1 = fp1 + (text.typesetter.typelines.last?.origin ?? Point())
                    for textView in sheetView.textsView.elementViews {
                        guard !textView.typesetter.typelines.isEmpty else { continue }
                        let fp0 = textView.model.origin
                            + (textView.typesetter
                                .firstEditReturnBounds?.centerPoint
                                ?? Point())
                        let lp0 = textView.model.origin
                            + (textView.typesetter
                                .lastEditReturnBounds?.centerPoint
                                ?? Point())
                        
                        if text.size.absRatio(textView.model.size) < 1.25 {
                            let d = 5.0 * document.screenToWorldScale
                            if fp0.distance(lp1) < d {
                                let spacing = textView.model.typelineSpacing
                                let edge = textView.typesetter.firstEdge(offset: spacing / 2)
                                path = textView.convertToWorld(Path(edge))
                                snapDP = fp0 - lp1
                                break
                            } else if lp0.distance(fp1) < d {
                                let spacing = textView.model.typelineSpacing
                                let edge = textView.typesetter.lastEdge(offset: spacing / 2)
                                path = textView.convertToWorld(Path(edge))
                                snapDP = lp0 - fp1
                                break
                            }
                        }
                    }
                }
                
                if let path = path {
                    selectingLineNode.fillType = .color(.subSelected)
                    selectingLineNode.lineType = .color(.selected)
                    selectingLineNode.path = path * Attitude(position: np + snapDP,
                                                             scale: Size(square: 1.0 * scale)).transform.inverted()
                } else {
                    selectingLineNode.path = Path()
                }
                selectingLineNode.attitude
                    = Attitude(position: np + snapDP,
                               scale: Size(square: 1.0 * scale))
                
                oldScale = s
            }
        }
        func updateBorder(with orientation: Orientation) {
            if phase == .began {
                selectingLineNode.lineType = .color(.border)
            }
            
            if let sheetView = sheetView,
               let (textView, _, _, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)),
               let x = textView.typesetter.warpCursorOffset(at: textView.convertFromWorld(p))?.offset,
               textView.textOrientation == orientation.reversed(),
               let frame = textView.model.frame {
                let f = frame + sb.origin
                let edge: Edge
                switch textView.model.orientation {
                case .horizontal:
                    edge = Edge(Point(f.minX + x, f.minY),
                                Point(f.minX + x, f.maxY))
                case .vertical:
                    edge = Edge(Point(f.minX, f.maxY - x),
                                Point(f.maxX, f.maxY - x))
                }
                snapLineNode.children = []
                selectingLineNode.path = Path([Pathline(edge)])
                return
            }
            
            var paths = [Path]()
            switch orientation {
            case .horizontal:
                func append(_ p0: Point, _ p1: Point, lw: Double = 1) {
                    paths.append(Path(Rect(x: p0.x, y: p0.y - lw / 2,
                                           width: p1.x - p0.x, height: lw)))
                }
                append(Point(sb.minX, sb.minY + sb.height / 4),
                       Point(sb.maxX, sb.minY + sb.height / 4))
                append(Point(sb.minX, sb.minY + sb.height / 3),
                       Point(sb.maxX, sb.minY + sb.height / 3))
                append(Point(sb.minX, sb.minY + sb.height / 2),
                       Point(sb.maxX, sb.minY + sb.height / 2))
                append(Point(sb.minX, sb.minY + 2 * sb.height / 3),
                       Point(sb.maxX, sb.minY + 2 * sb.height / 3))
                append(Point(sb.minX, sb.minY + 3 * sb.height / 4),
                       Point(sb.maxX, sb.minY + 3 * sb.height / 4))
            case .vertical:
                func append(_ p0: Point, _ p1: Point, lw: Double = 1) {
                    paths.append(Path(Rect(x: p0.x - lw / 2, y: p0.y,
                                           width: lw, height: p1.y - p0.y)))
                }
                append(Point(sb.minX + sb.width / 4, sb.minY),
                       Point(sb.minX + sb.width / 4, sb.maxY))
                append(Point(sb.minX + sb.width / 3, sb.minY),
                       Point(sb.minX + sb.width / 3, sb.maxY))
                append(Point(sb.minX + sb.width / 2, sb.minY),
                       Point(sb.minX + sb.width / 2, sb.maxY))
                append(Point(sb.minX + 2 * sb.width / 3, sb.minY),
                       Point(sb.minX + 2 * sb.width / 3, sb.maxY))
                append(Point(sb.minX + 3 * sb.width / 4, sb.minY),
                       Point(sb.minX + 3 * sb.width / 4, sb.maxY))
            }
            snapLineNode.children = paths.map {
                Node(path: $0, fillType: .color(.subSelected))
            }
            
            let inP = p - sb.origin
            let bnp = borderSnappedPoint(inP, with: sb,
                                         distance: 5 / document.worldToScreenScale,
                                         orientation)
            isSnapped = bnp.isSnapped
            let np = bnp.point + sb.origin
            switch orientation {
            case .horizontal:
                selectingLineNode.path = Path([Pathline([Point(sb.minX, np.y),
                                                         Point(sb.maxX, np.y)])])
            case .vertical:
                selectingLineNode.path = Path([Pathline([Point(np.x, sb.minY),
                                                         Point(np.x, sb.maxY)])])
            }
        }
        
        switch pasteObject {
        case .copiedSheetsValue: break
        case .picture:
            break
        case .sheetValue(let value):
            if value.texts.count == 1 && value.lines.isEmpty && value.planes.isEmpty {
                updateWithText(value.texts[0])
            } else {
                updateWithValue(value)
            }
        case .planesValue:
            break
        case .string(let string):
            updateWithText(Text(autoWidthCountWith: string))
        case .text(let text):
            updateWithText(text)
        case .border(let border):
            updateBorder(with: border.orientation)
        case .uuColor:
            break
        }
    }
    
    func paste(at p: Point, atScreen sp: Point) {
        let shp = document.sheetPosition(at: p)
        
        var isRootNewUndoGroup = true
        var isUpdateUndoGroupSet = Set<SheetPosition>()
        func updateUndoGroup(with nshp: SheetPosition) {
            if !isUpdateUndoGroupSet.contains(nshp),
               let sheetView = document.sheetView(at: nshp) {
                
                sheetView.newUndoGroup()
                isUpdateUndoGroupSet.insert(nshp)
            }
        }
        
        let screenScale = document.worldToScreenScale
        func firstTransform() -> Transform {
            if beganScale != screenScale
                || beganRotation != document.camera.rotation {
                let t = Transform(scale: 1.0 * beganScale / screenScale)
                    .rotated(by: document.camera.rotation - beganRotation)
                return t.translated(by: p)
            } else {
                return Transform(translation: p)
            }
        }
        func transform(in frame: Rect) -> Transform {
            if beganScale != screenScale
                || beganRotation != document.camera.rotation{
                let t = Transform(scale: 1.0 * beganScale / screenScale)
                    .rotated(by: document.camera.rotation - beganRotation)
                return t.translated(by: p - frame.minXMinYPoint)
            } else {
                return Transform(translation: p - frame.minXMinYPoint)
            }
        }
        
        func pasteLines(_ lines: [Line]) {
            let pt = firstTransform()
            let ratio = beganScale / document.worldToScreenScale
            let pLines: [Line] = lines.map {
                var l = $0 * pt
                l.size *= ratio
                return l
            }
            guard !pLines.isEmpty, let rect = pLines.bounds else { return }
            
            let minXMinYSHP = document.sheetPosition(at: rect.minXMinYPoint)
            let maxXMinYSHP = document.sheetPosition(at: rect.maxXMinYPoint)
            let minXMaxYSHP = document.sheetPosition(at: rect.minXMaxYPoint)
            let lx = max(minXMinYSHP.x, shp.x - 1)
            let rx = min(maxXMinYSHP.x, shp.x + 1)
            let by = max(minXMinYSHP.y, shp.y - 1)
            let ty = min(minXMaxYSHP.y, shp.y + 1)
            if lx <= rx && by <= ty {
                for xi in lx...rx {
                    for yi in by...ty {
                        let nshp = SheetPosition(xi, yi)
                        let frame = document.sheetFrame(with: nshp)
                        let t = transform(in: frame)
                        let oLines: [Line] = lines.map {
                            var l = $0 * t
                            l.size *= ratio
                            return l
                        }
                        let nLines = Sheet.clipped(oLines,
                                                   in: Rect(size: frame.size))
                        if !nLines.isEmpty,
                           let (sheetView, isNew) = document
                            .madeSheetViewIsNew(at: nshp,
                                                isNewUndoGroup:
                                                    isRootNewUndoGroup) {
                            if isNew {
                                isRootNewUndoGroup = false
                            }
                            updateUndoGroup(with: nshp)
                            sheetView.append(nLines)
                        }
                    }
                }
            }
        }
        func pastePlanes(_ planes: [Plane]) {
            let pt = firstTransform()
            let pPlanes = planes.map { $0 * pt }
            guard !pPlanes.isEmpty, let rect = pPlanes.bounds else { return }
            
            let minXMinYSHP = document.sheetPosition(at: rect.minXMinYPoint)
            let maxXMinYSHP = document.sheetPosition(at: rect.maxXMinYPoint)
            let minXMaxYSHP = document.sheetPosition(at: rect.minXMaxYPoint)
            let lx = max(minXMinYSHP.x, shp.x - 1)
            let rx = min(maxXMinYSHP.x, shp.x + 1)
            let by = max(minXMinYSHP.y, shp.y - 1)
            let ty = min(minXMaxYSHP.y, shp.y + 1)
            if lx <= rx && by <= ty {
                for xi in lx...rx {
                    for yi in by...ty {
                        let nshp = SheetPosition(xi, yi)
                        let frame = document.sheetFrame(with: nshp)
                        let t = transform(in: frame)
                        let nPlanes = Sheet.clipped(planes.map { $0 * t },
                                                    in: Rect(size: frame.size))
                        if !nPlanes.isEmpty,
                           let (sheetView, isNew) = document
                            .madeSheetViewIsNew(at: nshp,
                                                isNewUndoGroup:
                                                    isRootNewUndoGroup) {
                            if isNew {
                                isRootNewUndoGroup = false
                            }
                            updateUndoGroup(with: nshp)
                            sheetView.append(nPlanes)
                        }
                    }
                }
            }
        }
        func pasteTexts(_ texts: [Text]) {
            let pt = firstTransform()
            guard !texts.isEmpty else { return }
            
            for text in texts {
                let nshp = document.sheetPosition(at: (text * pt).origin)
                guard ((shp.x - 1)...(shp.x + 1)).contains(nshp.x)
                    && ((shp.y - 1)...(shp.y + 1)).contains(nshp.y) else {
                    
                    continue
                }
                let frame = document.sheetFrame(with: nshp)
                let t = transform(in: frame)
                var nText = text * t
                if let (sheetView, isNew) = document
                    .madeSheetViewIsNew(at: nshp,
                                          isNewUndoGroup:
                                            isRootNewUndoGroup) {
                    let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
                    if let textFrame = nText.frame,
                       !sb.contains(textFrame) {
                       
                        let nFrame = sb.clipped(textFrame)
                        nText.origin += nFrame.origin - textFrame.origin
                        
                        if let textFrame = nText.frame, !sb.outset(by: 1).contains(textFrame) {
                            
                            let scale = min(sb.width / textFrame.width,
                                            sb.height / textFrame.height)
                            let dp = sb.clipped(textFrame).origin - textFrame.origin
                            nText.size *= scale
                            nText.origin += dp
                        }
                    }
                    if isNew {
                        isRootNewUndoGroup = false
                    }
                    updateUndoGroup(with: nshp)
                    sheetView.append([nText])
                }
            }
        }
        func pasteText(_ text: Text) {
//            let pt = firstTransform()
            let nshp = shp
            guard ((shp.x - 1)...(shp.x + 1)).contains(nshp.x)
                    && ((shp.y - 1)...(shp.y + 1)).contains(nshp.y),
                  let sheetView = document.madeSheetView(at: nshp) else { return }
            var text = text
            var isAppend = false
            
            document.textEditor.begin(atScreen: sp)
            if let textView = document.textEditor.editingTextView,
               !textView.isHiddenSelectedRange,
               let i = sheetView.textsView.elementViews.firstIndex(of: textView) {
                
                document.textEditor.endInputKey(isUnmarkText: true,
                                                isRemoveText: false)
                if let ati = textView.selectedRange?.lowerBound {
                    var isFinding = false
                    if document.findingNodes[shp] != nil {
                        for text in sheetView.model.texts {
                            for range in text.string.ranges(of: document.finding.string) {
                                if range.contains(ati) {
                                    isFinding = true
                                    break
                                }
                            }
                            if isFinding { break }
                        }
                    }
                    if isFinding {
                        document.replaceFinding(from: text.string)
                    } else {
                        let rRange: Range<Int>
                        if let selection = document.selections.first,
                           let sRange = textView.range(from: selection),
                           sRange.contains(ati) {
                                
                            rRange = textView.model.string.intRange(from: sRange)
                            document.selections = []
                        } else {
                            let ti = textView.model.string.intIndex(from: ati)
                            rRange = ti..<ti
                        }
                        let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
                        var nText = textView.model
                        nText.replaceSubrange(text.string, from: rRange,
                                              clipFrame: sb)
                        let origin = textView.model.origin != nText.origin ?
                            nText.origin : nil
                        let size = textView.model.size != nText.size ?
                            nText.size : nil
                        let tv = TextValue(string: text.string,
                                           replacedRange: rRange,
                                           origin: origin, size: size)
                        updateUndoGroup(with: nshp)
                        sheetView.replace(IndexValue(value: tv, index: i))
                    }
                }
                isAppend = true
            }
            
            if !isAppend {
                let np = sheetView.convertFromWorld(p)
                let scale = beganScale / document.worldToScreenScale
                let nnp = text.origin * scale + np
                let log10Scale: Double = .log10(document.worldToScreenScale)
                let clipScale = max(0.0, log10Scale)
                let decimalPlaces = Int(clipScale + 2)
                let fp1 = nnp.rounded(decimalPlaces: decimalPlaces)
                let lp1 = fp1 + (text.typesetter.typelines.last?.origin ?? Point())
                for (i, textView) in sheetView.textsView.elementViews.enumerated() {
                    guard !textView.typesetter.typelines.isEmpty else { continue }
                    let fp0 = textView.model.origin
                        + (textView.typesetter
                            .firstEditReturnBounds?.centerPoint
                            ?? Point())
                    let lp0 = textView.model.origin
                        + (textView.typesetter
                            .lastEditReturnBounds?.centerPoint
                            ?? Point())
                    
                    if text.size.absRatio(textView.model.size) < 1.25 {
                        var str = text.string
                        let d = 5.0 * document.screenToWorldScale
                        var dp = Point(), rRange: Range<Int>?
                        if fp0.distance(lp1) < d {
                            str.append("\n")
                            let th = text.typesetter.height
                                + text.typelineSpacing
                            switch textView.model.orientation {
                            case .horizontal: dp = Point(0, th)
                            case .vertical: dp = Point(th, 0)
                            }
                            let si = textView.model.string
                                .intIndex(from: textView.model.string.startIndex)
                            rRange = si..<si
                        } else if lp0.distance(fp1) < d {
                            str.insert("\n", at: str.startIndex)
                            let ei = textView.model.string
                                .intIndex(from: textView.model.string.endIndex)
                            rRange = ei..<ei
                        }
                        if let rRange = rRange {
                            let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
                            var nText = textView.model
                            nText.replaceSubrange(str, from: rRange,
                                                  clipFrame: sb)
                            let origin = textView.model.origin != nText.origin + dp ?
                                nText.origin + dp : nil
                            let size = textView.model.size != nText.size ?
                                nText.size : nil
                            let tv = TextValue(string: str,
                                               replacedRange: rRange,
                                               origin: origin, size: size)
                            updateUndoGroup(with: nshp)
                            sheetView.replace(IndexValue(value: tv, index: i))
                            isAppend = true
                            break
                        }
                    }
                }
            }
            
            if !isAppend {
                let np = sheetView.convertFromWorld(p)
                let scale = beganScale / document.worldToScreenScale
                let nnp = text.origin * scale + np
                let log10Scale: Double = .log10(document.worldToScreenScale)
                let clipScale = max(0.0, log10Scale)
                let decimalPlaces = Int(clipScale + 2)
                text.origin = nnp.rounded(decimalPlaces: decimalPlaces)
                text.size = text.size * scale
                let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
                if let textFrame = text.frame, !sb.contains(textFrame) {
                    let nFrame = sb.clipped(textFrame)
                    text.origin += nFrame.origin - textFrame.origin
                    
                    if let textFrame = text.frame, !sb.outset(by: 1).contains(textFrame) {
                        
                        let scale = min(sb.width / textFrame.width,
                                        sb.height / textFrame.height)
                        let dp = sb.clipped(textFrame).origin - textFrame.origin
                        text.size *= scale
                        text.origin += dp
                    }
                }
                updateUndoGroup(with: nshp)
                sheetView.append(text)
            }
        }
        
        switch pasteObject {
        case .copiedSheetsValue: break
        case .picture(let picture):
            if let sheetView = document.madeSheetView(at: shp) {
                sheetView.newUndoGroup()
                sheetView.set(picture)
            }
        case .sheetValue(let value):
            pasteLines(value.lines)
            pastePlanes(value.planes)
            if value.texts.count == 1 && value.lines.isEmpty && value.planes.isEmpty {
                pasteText(value.texts[0])
            } else {
                pasteTexts(value.texts)
            }
        case .planesValue(let planesValue):
            guard !planesValue.planes.isEmpty else { return }
            guard let sheetView = document.madeSheetView(at: shp) else { return }
            sheetView.newUndoGroup()
            if !sheetView.model.picture.planes.isEmpty {
                let counts = Array(0..<sheetView.model.picture.planes.count)
                sheetView.removePlanes(at: counts)
            }
            sheetView.append(planesValue.planes)
        case .string(let string):
            pasteText(Text(autoWidthCountWith: string))
        case .text(let text):
            pasteText(text)
        case .border(let border):
            if let sheetView = document.madeSheetView(at: shp) {
                
                if let (textView, ti, _, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)),
                   let x = textView.typesetter.warpCursorOffset(at: textView.convertFromWorld(p))?.offset {
                    let widthCount = textView.model.size == 0 ?
                        Typobute.maxWidthCount :
                        (x / textView.model.size)
                        .clipped(min: Typobute.minWidthCount,
                                 max: Typobute.maxWidthCount)
                    
                    var text = textView.model
                    if text.widthCount != widthCount {
                        text.widthCount = widthCount
                        
                        let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
                        if let textFrame = text.frame, !sb.contains(textFrame) {
                            let nFrame = sb.clipped(textFrame)
                            text.origin += nFrame.origin - textFrame.origin
                            
                            if let textFrame = text.frame, !sb.outset(by: 1).contains(textFrame) {
                                
                                let scale = min(sb.width / textFrame.width,
                                                sb.height / textFrame.height)
                                let dp = sb.clipped(textFrame).origin - textFrame.origin
                                text.size *= scale
                                text.origin += dp
                            }
                        }
                        
                        sheetView.newUndoGroup()
                        sheetView.replace([IndexValue(value: text, index: ti)])
                    }
                    return
                }
                
                
                let sb = document.sheetFrame(with: shp)
                let inP = sheetView.convertFromWorld(p)
                let np = borderSnappedPoint(inP, with: sb,
                                            distance: 5 / document.worldToScreenScale,
                                            border.orientation).point
                sheetView.newUndoGroup()
                sheetView.append(Border(position: np, border: border))
            }
        case .uuColor(let uuColor):
            guard let _ = document.madeSheetView(at: shp) else { return }
            let colorOwners = document.madeColorOwner(at: p)
            colorOwners.forEach {
                if $0.uuColor != uuColor {
                    $0.uuColor = uuColor
                    $0.captureUUColor(isNewUndoGroup: true)
                }
            }
        }
    }
    
    var isMovePasteObject: Bool {
        switch pasteObject {
        case .copiedSheetsValue: return false
        case .picture: return false
        case .sheetValue: return true
        case .planesValue: return false
        case .string: return true
        case .text: return true
        case .border: return true
        case .uuColor: return false
        }
    }
    
    func cut(with event: InputKeyEvent) {
        let sp = document.selectedScreenPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        for runner in document.runners {
            if runner.containsStep(p) {
                Pasteboard.shared.copiedObjects
                    = [.string(runner.stepString)]
                runner.stop()
                return
            } else if runner.containsDebug(p) {
                Pasteboard.shared.copiedObjects
                    = [.string(runner.debugString)]
                runner.stop()
                return
            }
        }
        if document.containsLookingUp(at: p) {
            document.closeLookingUpNode()
            return
        }
        
        guard isEditingSheet else {
            cutSheet(with: event)
            return
        }
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            type = .cut
            editingSP = sp
            editingP = document.convertScreenToWorld(sp)
            cut(at: editingP)
            
            document.updateSelects()
            document.updateFinding(at: editingP)
            document.updateTextCursor()
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
    
    func copy(with event: InputKeyEvent) {
        guard isEditingSheet else {
            copySheet(with: event)
            return
        }
        let sp = document.selectedScreenPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            type = .copy
            beganScale = document.worldToScreenScale
            editingSP = sp
            editingP = document.convertScreenToWorld(sp)
            updateWithCopy(for: editingP,
                           isSendPasteboard: true, isCutColor: false)
            document.rootNode.append(child: selectingLineNode)
        case .changed:
            break
        case .ended:
            selectingLineNode.removeFromParent()
            
            document.cursor = Document.defaultCursor
        }
    }
    
    func paste(with event: InputKeyEvent) {
        guard isEditingSheet else {
            pasteSheet(with: event)
            return
        }
        guard !isEditingText else { return }
        
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            if let textView = document.textEditor.editingTextView,
               !textView.isHiddenSelectedRange,
               let sheetView = document.textEditor.editingSheetView,
               let i = sheetView.textsView.elementViews
                .firstIndex(of: textView),
               let o = Pasteboard.shared.copiedObjects.first {
                
                let str: String?
                switch o {
                case .string(let s): str = s
                case .text(let t): str = t.string
                default: str = nil
                }
                if let str = str {
                    document.textEditor.endInputKey(isUnmarkText: true,
                                                    isRemoveText: false)
                    guard let ti = textView.selectedRange?.lowerBound,
                          ti >= textView.model.string.startIndex else { return }
                    let text = textView.model
                    let nti = text.string.intIndex(from: ti)
                    let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
                    var nText = text
                    nText.replaceSubrange(str, from: nti..<nti,
                                          clipFrame: sb)
                    let origin = text.origin != nText.origin ?
                        nText.origin : nil
                    let size = text.size != nText.size ?
                        nText.size : nil
                    let tv = TextValue(string: str,
                                       replacedRange: nti..<nti,
                                       origin: origin, size: size)
                    sheetView.newUndoGroup()
                    sheetView.replace(IndexValue(value: tv, index: i))
                    
                    isEditingText = true
                    return
                }
            }
            
            document.cursor = .arrow
            
            type = .paste
            beganScale = document.worldToScreenScale
            beganRotation = document.camera.rotation
            textScale = beganScale
            editingSP = sp
            editingP = document.convertScreenToWorld(sp)
            guard let o = Pasteboard.shared.copiedObjects.first else { return }
            pasteObject = o
            if isMovePasteObject {
                selectingLineNode.lineWidth = document.worldLineWidth
                snapLineNode.lineWidth = selectingLineNode.lineWidth
                updateWithPaste(at: editingP, atScreen: sp,
                                event.phase)
                document.rootNode.append(child: snapLineNode)
                document.rootNode.append(child: selectingLineNode)
            } else {
                paste(at: editingP, atScreen: sp)
            }
        case .changed:
            if isMovePasteObject {
                editingSP = sp
                editingP = document.convertScreenToWorld(sp)
                updateWithPaste(at: editingP, atScreen: sp,
                                event.phase)
            }
        case .ended:
            if isMovePasteObject {
                editingSP = sp
                editingP = document.convertScreenToWorld(sp)
                paste(at: editingP, atScreen: sp)
                snapLineNode.removeFromParent()
                selectingLineNode.removeFromParent()
            }
            
            document.updateSelects()
            document.updateFinding(at: editingP)
            document.updateTextCursor()
            
            document.cursor = Document.defaultCursor
        }
    }
    
    struct Value {
        var shp: SheetPosition, frame: Rect
    }
    func values(at p: Point, isCut: Bool) -> [Value] {
        if document.isSelectSelectedNoneCursor(at: p),
           !document.isSelectedText,
           let r = document.selections.first?.rect {
            let vs: [Value] = document.world.sheetIDs.keys.compactMap { shp in
                let frame = document.sheetFrame(with: shp)
                if r.intersects(frame) {
                    return Value(shp: shp, frame: frame)
                } else {
                    return nil
                }
            }
            if isCut {
                document.selections = []
            }
            return vs
        } else {
            let shp = document.sheetPosition(at: p)
            if document.sheetID(at: shp) != nil {
                return [Value(shp: shp,
                              frame: document.sheetFrame(with: shp))]
            } else {
                return []
            }
        }
    }
    
    func updateWithCopySheet(at dp: Point, from values: [Value]) {
        var csv = CopiedSheetsValue()
        for value in values {
            if let sid = document.sheetID(at: value.shp) {
                csv.sheetIDs[value.shp] = sid
            }
        }
        if !csv.sheetIDs.isEmpty {
            csv.deltaPoint = dp
            Pasteboard.shared.copiedObjects = [.copiedSheetsValue(csv)]
        }
    }
    
    func updateWithPasteSheet(at sp: Point, phase: Phase) {
        let p = document.convertScreenToWorld(sp)
        if case .copiedSheetsValue(let csv) = pasteObject {
            if phase == .began {
                let lw = Line.defaultLineWidth / document.worldToScreenScale
                pasteSheetNode.children = csv.sheetIDs.map {
                    let fillType = document.readFillType(at: $0.value)
                        ?? .color(.disabled)
                    
                    let sf = document.sheetFrame(with: $0.key)
                    return Node(attitude: Attitude(position: sf.origin),
                                path: Path(Rect(size: sf.size)),
                                lineWidth: lw,
                                lineType: .color(.selected), fillType: fillType)
                }
            }
            
            var children = [Node]()
            for (shp, _) in csv.sheetIDs {
                var sf = document.sheetFrame(with: shp)
                sf.origin += p - csv.deltaPoint
                let nshp = document.sheetPosition(at: sf.centerPoint)
                if document.sheetID(at: nshp) == nil {
                    let sf = document.sheetFrame(with: nshp)
                    let lw = Line.defaultLineWidth / document.worldToScreenScale
                    children.append(Node(attitude: Attitude(position: sf.origin),
                                         path: Path(Rect(size: sf.size)),
                                         lineWidth: lw,
                                         lineType: selectingLineNode.lineType,
                                         fillType: selectingLineNode.fillType))
                }
            }
            selectingLineNode.children = children
            
            pasteSheetNode.attitude.position = p - csv.deltaPoint
        }
    }
    func pasteSheet(at sp: Point) {
        document.cursorPoint = sp
        let p = document.convertScreenToWorld(sp)
        if case .copiedSheetsValue(let csv) = pasteObject {
            var nIndexes = [SheetPosition: SheetID]()
            var removeIndexes = [SheetPosition]()
            for (shp, sid) in csv.sheetIDs {
                var sf = document.sheetFrame(with: shp)
                sf.origin += p - csv.deltaPoint
                let nshp = document.sheetPosition(at: sf.centerPoint)
                
                if document.sheetID(at: nshp) != nil {
                    removeIndexes.append(nshp)
                }
                if document.sheetPosition(at: sid) != nil {
                    nIndexes[nshp] = document.duplicateSheet(from: sid)
                } else {
                    nIndexes[nshp] = sid
                }
            }
            if !removeIndexes.isEmpty || !nIndexes.isEmpty {
                document.history.newUndoGroup()
                if !removeIndexes.isEmpty {
                    document.removeSheets(at: removeIndexes)
                }
                if !nIndexes.isEmpty {
                    document.append(nIndexes)
                }
                document.updateNode()
            }
        }
    }
    
    func cutSheet(with event: InputKeyEvent) {
        let sp = document.selectedScreenPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            type = .cut
            editingSP = sp
            editingP = document.convertScreenToWorld(sp)
            let p = document.convertScreenToWorld(sp)
            let values = self.values(at: p, isCut: true)
            updateWithCopySheet(at: p, from: values)
            if !values.isEmpty {
                let shps = values.map { $0.shp }
                document.cursorPoint = sp
                document.close(from: shps)
                document.newUndoGroup()
                document.removeSheets(at: shps)
            }
            
            document.updateSelects()
            document.updateFinding(at: editingP)
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
    
    func copySheet(with event: InputKeyEvent) {
        let sp = document.selectedScreenPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            type = .copy
            editingSP = sp
            editingP = document.convertScreenToWorld(sp)
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = document.worldLineWidth
            
            let p = document.convertScreenToWorld(sp)
            let values = self.values(at: p, isCut: false)
            selectingLineNode.children = values.map {
                let sf = $0.frame
                return Node(attitude: Attitude(position: sf.origin),
                            path: Path(Rect(size: sf.size)),
                            lineWidth: selectingLineNode.lineWidth,
                            lineType: selectingLineNode.lineType,
                            fillType: selectingLineNode.fillType)
            }
            updateWithCopySheet(at: p, from: values)
            
            document.rootNode.append(child: selectingLineNode)
        case .changed:
            break
        case .ended:
            selectingLineNode.removeFromParent()
            
            document.cursor = Document.defaultCursor
        }
    }
    var pasteSheetNode = Node()
    func pasteSheet(with event: InputKeyEvent) {
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            type = .paste
            beganScale = document.worldToScreenScale
            editingSP = sp
            editingP = document.convertScreenToWorld(sp)
            pasteObject = Pasteboard.shared.copiedObjects.first
                ?? .sheetValue(SheetValue())
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = document.worldLineWidth
            
            document.rootNode.append(child: selectingLineNode)
            document.rootNode.append(child: pasteSheetNode)
            
            updateWithPasteSheet(at: sp, phase: event.phase)
        case .changed:
            updateWithPasteSheet(at: sp, phase: event.phase)
        case .ended:
            pasteSheet(at: sp)
            selectingLineNode.removeFromParent()
            pasteSheetNode.removeFromParent()
            
            document.updateSelects()
            document.updateFinding(at: editingP)
            
            document.cursor = Document.defaultCursor
        }
    }
}
