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

import Dispatch
import struct Foundation.Data
import struct Foundation.URL

protocol Editor {
    func updateNode()
}
extension Editor {
    func updateNode() {}
}

protocol PinchEditor: Editor {
    func send(_ event: PinchEvent)
}

protocol RotateEditor: Editor {
    func send(_ event: RotateEvent)
}

protocol ScrollEditor: Editor {
    func send(_ event: ScrollEvent)
}

protocol DragEditor: Editor {
    func send(_ event: DragEvent)
}

protocol InputKeyEditor: Editor {
    func send(_ event: InputKeyEvent)
}

final class Zoomer: PinchEditor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    let correction = 3.0
    func send(_ event: PinchEvent) {
        guard event.magnification != 0 else { return }
        let oldIsEditingSheet = document.isEditingSheet
        
        var transform = document.camera.transform
        let p = event.screenPoint * document.screenToWorldTransform
        let log2Scale = transform.log2Scale
        let newLog2Scale = (log2Scale - (event.magnification * correction))
            .clipped(min: Document.minCameraLog2Scale,
                     max: Document.maxCameraLog2Scale) - log2Scale
        transform.translate(by: -p)
        transform.scale(byLog2Scale: newLog2Scale)
        transform.translate(by: p)
        document.camera = Document.clippedCamera(from: Camera(transform))
        
        if oldIsEditingSheet != document.isEditingSheet {
            document.textEditor.moveEndInputKey()
            document.updateTextCursor()
        }
        
        if document.selectedNode != nil {
            document.updateSelectedNode()
        }
        if !document.finding.isEmpty {
            document.updateFindingNodes()
        }
    }
}

final class Rotater: RotateEditor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    let correction = .pi / 40.0, clipD = .pi / 8.0
    var isClipped = false
    func send(_ event: RotateEvent) {
        switch event.phase {
        case .began: isClipped = false
        default: break
        }
        guard !isClipped && event.rotationQuantity != 0 else { return }
        var transform = document.camera.transform
        let p = event.screenPoint * document.screenToWorldTransform
        let r = transform.angle
        let rotation = r - event.rotationQuantity * correction
        let nr: Double
        if (rotation < clipD && rotation >= 0 && r < 0)
            || (rotation > -clipD && rotation <= 0 && r > 0) {
            
            nr = 0
            Feedback.performAlignment()
            isClipped = true
        } else {
            nr = rotation.clippedRotation
        }
        transform.translate(by: -p)
        transform.rotate(by: nr - r)
        transform.translate(by: p)
        var camera = Document.clippedCamera(from: Camera(transform))
        if isClipped {
            camera.rotation = 0
            document.camera = camera
        } else {
            document.camera = camera
        }
        if document.camera.rotation != 0 {
            Document.defaultCursor
                = Cursor.rotate(rotation: -document.camera.rotation + .pi / 2)
            document.cursor = Document.defaultCursor
        } else {
            Document.defaultCursor = .drawLine
            document.cursor = Document.defaultCursor
        }
    }
}

final class Scroller: ScrollEditor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    enum SnapType {
        case began, none, x, y
    }
    let correction = 1.0
    let updateSpeed = 1000.0
    var snapType = SnapType.none, p = Point()
    private var isHighSpeed = false, oldTime = 0.0, oldDeltaPoint = Point()
    private var oldSpeedTime = 0.0, oldSpeedDistance = 0.0, oldSpeed = 0.0, fps = 0.0
    var ps = [(d: Double, t: Double, speed: Double)](),
        beganTimes = [Double]()
    func send(_ event: ScrollEvent) {
        switch event.phase {
        case .began:
            oldTime = event.time
            oldSpeedTime = oldTime
            oldDeltaPoint = Point()
            oldSpeedDistance = 0.0
            oldSpeed = 0.0
            fps = 20
            snapType = .began
            p = Point()
            beganTimes.append(event.time)
        case .changed:
            guard !event.scrollDeltaPoint.isEmpty else { return }
            let dt = event.time - oldTime
            var dp = event.scrollDeltaPoint.mid(oldDeltaPoint)
            if document.camera.rotation != 0 {
                dp = dp * Transform(rotation: document.camera.rotation)
            }
            
            let d = event.scrollDeltaPoint.distance(oldDeltaPoint)
            ps = ps.filter { event.time - $0.t < 2 }
            if d > 0 {
                ps.append((d, event.time, d / dt))
            }
            beganTimes = beganTimes.filter { event.time - $0 < 2 }
            if event.touchPhase == .began {
                beganTimes.append(event.time)
            }
            if ps.count >= 2 {
                let speed = (ps.reduce(0.0) { $0 + $1.d })
                    / (ps.last!.t - ps.first!.t)
                fps = speed > 2300 && beganTimes.count >= 8 ? 60 : 20
            }
            
            func isUnclipAngle(_ angle: Double) -> Bool {
                if document.snappedCameraType != .none {
                    return false
                }
                let a = angle * 16
                if a > .pi && a < 7 * .pi { return true }
                if a > 9 * .pi && a < 15 * .pi { return true }
                if a > -7 * .pi && a < -.pi { return true }
                if a > -15 * .pi && a < -9 * .pi { return true }
                return false
            }
            
            p += dp
            
            if event.touchPhase == .began {
                snapType = .began
                p = Point()
            }
            switch snapType {
            case .began:
                if isUnclipAngle(dp.angle()) {
                    snapType = .none
                } else {
                    if abs(dp.x) > abs(dp.y) {
                        snapType = .x
                    } else {
                        snapType = .y
                    }
                }
            case .none: break
            case .x:
                if abs(p.y) > 20 {
                    p = Point()
                    snapType = .none
                } else {
                    dp.y = 0
                }
            case .y:
                if abs(p.x) > 20 {
                    p = Point()
                    snapType = .none
                } else {
                    dp.x = 0
                }
            }
            
            oldDeltaPoint = event.scrollDeltaPoint
            
            let angle = dp.angle()
            let length = dp.length()
            let ls = document.camera.logScale
            
            let lengthDt = length / dt
            if !isUnclipAngle(angle)
                && lengthDt > updateSpeed
                && ls > -2 && ls < 2  {
                
                let s0 = document.worldToScreenScale
                let s = s0 > 0.6 ? s0 : s0.clipped(min: 0.6, max: 0.25,
                                                   newMin: 0.6, newMax: 1)
                if abs(dp.x) > abs(dp.y) {
                    let speed = abs(dp.x) / dt
                    let sv = document.snappableCameraX * fps * s
                    if speed > sv {
                        dp.x = dp.x.signValue * sv * dt
                        dp.y = 0
                        document.snappedCameraType = .x
                    } else {
                        document.snappedCameraType = .none
                    }
                } else {
                    let speed = abs(dp.y) / dt
                    let sv = document.snappableCameraY * fps * s
                    if speed > sv {
                        dp.x = 0
                        dp.y = dp.y.signValue * sv * dt
                        document.snappedCameraType = .y
                    } else {
                        document.snappedCameraType = .none
                    }
                }
            } else {
                document.snappedCameraType = .none
            }
            
            var transform = document.camera.transform
            let newPoint = dp * correction * transform.absXScale
            
            let oldPosition = transform.position
            let newP = Document.clippedCameraPosition(from: oldPosition - newPoint) - oldPosition
            
            transform.translate(by: newP)
            document.camera = Camera(transform)
            
            document.isUpdateWithCursorPosition =
                document.snappedCameraType == .none && lengthDt < updateSpeed / 2
            document.updateWithCursorPosition()
            if !document.isUpdateWithCursorPosition {
                document.textCursorNode.isHidden = true
            }
            
            oldTime = event.time
        case .ended:
            if !document.isUpdateWithCursorPosition {
                document.isUpdateWithCursorPosition = true
            }
            if let snappedCamera = document.snappedCamera {
                document.camera = snappedCamera
                document.updateWithCursorPosition()
            }
            document.snappedCameraType = .none
            break
        }
    }
}

final class DraftChanger: InputKeyEditor {
    let editor: DraftEditor
    
    init(_ document: Document) {
        editor = DraftEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.changeToDraft(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class DraftCutter: InputKeyEditor {
    let editor: DraftEditor
    
    init(_ document: Document) {
        editor = DraftEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.cutDraft(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class DraftEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    func changeToDraft(with event: InputKeyEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if document.isSelectNoneCursor(at: p),
               !document.isSelectedText,
               let f = document.selections.first?.rect,
               let line = document.selectedOutsetLine {
                
                for (shp, _) in document.sheetViewValues {
                    let ssFrame = document.sheetFrame(with: shp)
                    if ssFrame.intersects(f),
                       let sheetView = document.sheetView(at: shp) {
                        
                        let nLine = sheetView.convertFromWorld(line)
                        sheetView.changeToDraft(with: nLine)
                    }
                }
            } else {
                let (_, sheetView, frame, isAll) = document.sheetViewAndFrame(at: p)
                if let sheetView = sheetView {
                    if isAll {
                        sheetView.changeToDraft(with: nil)
                    } else {
                        sheetView.changeToDraft(with: Line(sheetView.convertFromWorld(frame.inset(by: -1))))
                    }
                }
            }
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
    func cutDraft(with event: InputKeyEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if document.isSelectNoneCursor(at: p),
               !document.isSelectedText,
               let f = document.selections.first?.rect,
               let line = document.selectedOutsetLine {
                
                var value = SheetValue()
                for (shp, _) in document.sheetViewValues {
                    let ssFrame = document.sheetFrame(with: shp)
                    if ssFrame.intersects(f),
                       let sheetView = document.sheetView(at: shp) {
                       
                        let nLine = sheetView.convertFromWorld(line)
                        if let v = sheetView.removeDraft(with: nLine, at: p) {
                            value += v
                       }
                    }
                }
                Pasteboard.shared.copiedObjects = [.sheetValue(value)]
                
                document.selections = []
            } else {
                let (_, sheetView, frame, isAll) = document.sheetViewAndFrame(at: p)
                if let sheetView = sheetView {
                    if isAll {
                        sheetView.cutDraft(with: nil, at: p)
                    } else {
                        sheetView.cutDraft(with: Line(sheetView.convertFromWorld(frame.inset(by: -1))), at: p)
                    }
                }
            }
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
}

final class FacesMaker: InputKeyEditor {
    let editor: FaceEditor
    
    init(_ document: Document) {
        editor = FaceEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.makeFaces(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class FacesCutter: InputKeyEditor {
    let editor: FaceEditor
    
    init(_ document: Document) {
        editor = FaceEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.cutFaces(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class FaceEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    func makeFaces(with event: InputKeyEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if document.isSelectNoneCursor(at: p),
               !document.isSelectedText,
               let f = document.selections.first?.rect {
                for (shp, _) in document.sheetViewValues {
                    let ssFrame = document.sheetFrame(with: shp)
                    if ssFrame.intersects(f),
                       let sheetView = document.sheetView(at: shp) {
                        
                        let f = sheetView.convertFromWorld(f).inset(by: 1)
                        sheetView.makeFaces(with: Path(f))
                    }
                }
            } else {
                let (_, sheetView, frame, isAll) = document.sheetViewAndFrame(at: p)
                if let sheetView = sheetView {
                    if isAll {
                        sheetView.makeFaces(with: nil)
                    } else {
                        let f = sheetView.convertFromWorld(frame).inset(by: 1)
                        sheetView.makeFaces(with: Path(f))
                    }
                }
            }
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
    func cutFaces(with event: InputKeyEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if document.isSelectNoneCursor(at: p),
               !document.isSelectedText,
               let f = document.selections.first?.rect {
                var value = SheetValue()
                for (shp, _) in document.sheetViewValues {
                    let ssFrame = document.sheetFrame(with: shp)
                    if ssFrame.intersects(f),
                       let sheetView = document.sheetView(at: shp) {
                        
                        let f = sheetView.convertFromWorld(f).inset(by: 1)
                        if let v = sheetView.removeFilledFaces(with: Path(f),
                                                                   at: p) {
                            value += v
                        }
                    }
                }
                Pasteboard.shared.copiedObjects = [.sheetValue(value)]
                
                document.selections = []
            } else {
                let (_, sheetView, frame, isAll) = document.sheetViewAndFrame(at: p)
                if let sheetView = sheetView {
                    if isAll {
                        sheetView.cutFaces(with: nil)
                    } else {
                        let f = sheetView.convertFromWorld(frame).inset(by: 1)
                        sheetView.cutFaces(with: Path(f))
                    }
                }
            }
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
}

final class Importer: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.import(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class Exporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.export(with: event, .png)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class PNGExporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.export(with: event, .png)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class PDFExporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.export(with: event, .pdf)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class DocumentExporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.export(with: event, .documentWithHistory)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class DocumentWithoutHistoryExporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.export(with: event, .document)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class IOEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    var fp = Point()
    
    let pngMaxWidth = 2048.0, pdfMaxWidth = 512.0
    
    let selectingLineNode = Node(lineWidth: 1.5)
    func updateNode() {
        selectingLineNode.lineWidth = document.worldLineWidth
    }
    func end(isUpdateSelect: Bool = false, isUpdateCursor: Bool = true) {
        selectingLineNode.removeFromParent()
        
        if isUpdateSelect {
            document.updateSelects()
        }
        if isUpdateCursor {
            document.cursor = Document.defaultCursor
        }
        document.updateSelectedColor(isMain: true)
    }
    func name(from shp: SheetPosition) -> String {
        return "\(shp.x)_\(shp.y)"
    }
    func name(from shps: [SheetPosition]) -> String {
        if shps.isEmpty {
            return "Empty"
        } else if shps.count == 1 {
            return name(from: shps[0])
        } else {
            return "\(name(from: shps[.first]))__"
        }
    }
    
    func sorted(_ vs: [SelectingValue],
                with rectCorner: RectCorner) -> [SelectingValue] {
        switch rectCorner {
        case .minXMinY:
            return vs.sorted {
                $0.shp.y != $1.shp.y ?
                    $0.shp.y > $1.shp.y :
                    $0.shp.x > $1.shp.x
            }
        case .minXMaxY:
            return vs.sorted {
                $0.shp.y != $1.shp.y ?
                    $0.shp.y < $1.shp.y :
                    $0.shp.x > $1.shp.x
            }
        case .maxXMinY:
            return vs.sorted {
                $0.shp.y != $1.shp.y ?
                    $0.shp.y > $1.shp.y :
                    $0.shp.x < $1.shp.x
            }
        case .maxXMaxY:
            return vs.sorted {
                $0.shp.y != $1.shp.y ?
                    $0.shp.y < $1.shp.y :
                    $0.shp.x < $1.shp.x
            }
        }
    }
    
    @discardableResult
    func beginImport(at sp: Point) -> SheetPosition {
        fp = document.convertScreenToWorld(sp)
        selectingLineNode.lineWidth = document.worldLineWidth
        selectingLineNode.fillType = .color(.subSelected)
        selectingLineNode.lineType = .color(.selected)
        let shp = document.sheetPosition(at: fp)
        let frame = document.sheetFrame(with: shp)
        selectingLineNode.path = Path(frame)
        document.rootNode.append(child: selectingLineNode)
        
        document.textCursorNode.isHidden = true
        
        document.updateSelectedColor(isMain: false)
        
        return shp
    }
    func `import`(from urls: [URL], at shp: SheetPosition) {
        var mshp = shp
        var nSHPs = [SheetPosition](), willremoveSHPs = [SheetPosition]()
        for url in urls {
            let importedDocument = Document(url: url)
            
            var maxX = mshp.x
            for (osid, _) in importedDocument.sheetRecorders {
                guard let oshp = importedDocument.sheetPosition(at: osid) else {
                    continue
                }
                let nshp = oshp + mshp
                if document.sheetID(at: nshp) != nil {
                    willremoveSHPs.append(nshp)
                }
                
                nSHPs.append(nshp)
                
                if nshp.x > maxX {
                    maxX = nshp.x
                }
            }
            mshp.x = maxX + 2
        }
        
        var oldP: Point?
        let viewSHPs = sorted(nSHPs.map { SelectingValue(shp: $0, bounds: Rect()) }, with: .maxXMinY)
            .map { $0.shp }
        selectingLineNode.children = viewSHPs.map {
            let frame = document.sheetFrame(with: $0)
            if let op = oldP {
                let cp = frame.centerPoint
                let path = Path([Pathline([op, cp])])
                let arrowNode = Node(path: path,
                                     lineWidth: selectingLineNode.lineWidth,
                                     lineType: selectingLineNode.lineType)
                oldP = frame.centerPoint
                return Node(children: [arrowNode],
                            path: Path(frame),
                            lineWidth: selectingLineNode.lineWidth,
                            lineType: selectingLineNode.lineType,
                            fillType: selectingLineNode.fillType)
            } else {
                oldP = frame.centerPoint
                return Node(path: Path(frame),
                            lineWidth: selectingLineNode.lineWidth,
                            lineType: selectingLineNode.lineType,
                            fillType: selectingLineNode.fillType)
            }
        } + willremoveSHPs.map {
            Node(path: Path(document.sheetFrame(with: $0)),
                 lineWidth: selectingLineNode.lineWidth * 2,
                 lineType: selectingLineNode.lineType,
                 fillType: selectingLineNode.fillType)
        }
        
        let length = urls.reduce(0) { $0 + ($1.fileSize ?? 0) }
        
        let ok: () -> () = {
            self.load(from: urls, at: shp)
            
            self.end(isUpdateSelect: true)
        }
        let cancel: () -> () = {
            self.end(isUpdateSelect: true)
        }
        let message: String
        if willremoveSHPs.isEmpty {
            if urls.count >= 2 {
                message = String(format: "Do you want to import a total of %2$d sheets from %1$d documents?".localized, urls.count, nSHPs.count)
            } else {
                message = String(format: "Do you want to import %1$d sheets?".localized, nSHPs.count)
            }
        } else {
            if urls.count >= 2 {
                message = String(format: "Do you want to import a total of $2$d sheets from %1$d documents, replacing %3$d existing sheets?".localized, urls.count, nSHPs.count, willremoveSHPs.count)
            } else {
                message = String(format: "Do you want to import $1$d sheets and replace the %2$d existing sheets?".localized, nSHPs.count, willremoveSHPs.count)
            }
        }
        document.rootNode
            .show(message: message,
                  infomation: "This operation can be undone when in root mode, but the data will remain until the root history is cleared.".localized,
                  okTitle: "Import".localized,
                  isSaftyCheck: nSHPs.count > 100 || length > 20*1024*1024,
                  okClosure: ok, cancelClosure: cancel)
    }
    func load(from urls: [URL], at shp: SheetPosition) {
        var mshp = shp
        var nSIDs = [SheetPosition: SheetID](), willremoveSHPs = [SheetPosition]()
        var resetSIDs = Set<SheetID>()
        for url in urls {
            let importedDocument = Document(url: url)
            
            var maxX = mshp.x
            for (osid, osrr) in importedDocument.sheetRecorders {
                guard let oshp = importedDocument.sheetPosition(at: osid) else {
                    let nsid = document.appendSheet(from: osrr)
                    resetSIDs.insert(nsid)
                    continue
                }
                let nshp = oshp + mshp
                if document.sheetID(at: nshp) != nil {
                    willremoveSHPs.append(nshp)
                }
                nSIDs[nshp] = document.appendSheet(from: osrr)
                
                if nshp.x > maxX {
                    maxX = nshp.x
                }
            }
            mshp.x = maxX + 2
        }
        if !willremoveSHPs.isEmpty || !nSIDs.isEmpty || !resetSIDs.isEmpty {
            document.history.newUndoGroup()
            if !willremoveSHPs.isEmpty {
                document.removeSheets(at: willremoveSHPs)
            }
            if !nSIDs.isEmpty {
                document.append(nSIDs)
            }
            if !resetSIDs.isEmpty {
                document.moveSheetsToUpperRightCorner(with: Array(resetSIDs),
                                                      isNewUndoGroup: false)
            }
            document.updateNode()
        }
    }
    func `import`(with event: InputKeyEvent) {
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            let sp = document.lastEditedSheetScreenCenterPositionNoneSelectedNoneCursor
                ?? event.screenPoint
            beginImport(at: sp)
        case .changed:
            break
        case .ended:
            let shp = document.sheetPosition(at: fp)
            let complete: (IOResult) -> () = { ioResult in
                self.import(from: [ioResult.url], at: shp)
            }
            let cancel: () -> () = {
                self.end(isUpdateSelect: true)
            }
            URL.load(prompt: "Import".localized,
                     fileTypes: [Document.FileType.sksdoc, Document.FileType.skshdoc],
                     completionClosure: complete, cancelClosure: cancel)
        }
    }
    
    struct SelectingValue {
        var shp: SheetPosition, bounds: Rect
    }
    
    enum ExportType {
        case png, pdf, documentWithHistory, document
        var isDocument: Bool {
            self == .document || self == .documentWithHistory
        }
    }
    
    func export(with event: InputKeyEvent, _ type: ExportType) {
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
                ?? event.screenPoint
            fp = document.convertScreenToWorld(sp)
            if document.isSelectNoneCursor(at: fp),
               !document.isSelectedText,
               let r = document.selections.first?.rect {
                
                let vs: [SelectingValue] = document.world.sheetIDs.keys.compactMap { shp in
                    let frame = document.sheetFrame(with: shp)
                    if let rf = r.intersection(frame) {
                        if document.isEditingSheet {
                            let nf = rf - frame.origin
                            return SelectingValue(shp: shp,
                                                  bounds: nf)
                        } else {
                            return SelectingValue(shp: shp,
                                                  bounds: Sheet.defaultBounds)
                        }
                    } else {
                        return nil
                    }
                }
                let nvs = sorted(vs, with: document.selections.first?.rectCorner ?? .minXMinY)
                
                if let unionFrame = document.isEditingSheet
                    && vs.count > 1 && !type.isDocument ? document.selections.first?.rect : nil {
                    
                    selectingLineNode.lineWidth = document.worldLineWidth
                    selectingLineNode.fillType = .color(.subSelected)
                    selectingLineNode.lineType = .color(.selected)
                    selectingLineNode.path = Path(unionFrame)
                } else {
                    var oldP: Point?
                    selectingLineNode.children = nvs.map {
                        let frame = !type.isDocument ?
                        ($0.bounds + document.sheetFrame(with: $0.shp).origin) :
                        document.sheetFrame(with: $0.shp)
                        
                        if !type.isDocument, let op = oldP {
                            let cp = frame.centerPoint
                            let a = op.angle(cp) - .pi
                            let d = min(frame.width, frame.height) / 4
                            let p0 = cp.movedWith(distance: d, angle: a + .pi / 6)
                            let p1 = cp.movedWith(distance: d, angle: a - .pi / 6)
                            let path = Path([Pathline([op, cp]),
                                             Pathline([p0, cp, p1])])
                            let arrowNode = Node(path: path,
                                                 lineWidth: document.worldLineWidth,
                                                 lineType: .color(.selected))
                            oldP = frame.centerPoint
                            return Node(children: [arrowNode],
                                        path: Path(frame),
                                        lineWidth: document.worldLineWidth,
                                        lineType: .color(.selected),
                                        fillType: .color(.subSelected))
                        } else {
                            oldP = frame.centerPoint
                            return Node(path: Path(frame),
                                        lineWidth: document.worldLineWidth,
                                        lineType: .color(.selected),
                                        fillType: .color(.subSelected))
                        }
                    }
                }
            } else {
                selectingLineNode.lineWidth = document.worldLineWidth
                selectingLineNode.fillType = .color(.subSelected)
                selectingLineNode.lineType = .color(.selected)
                if !type.isDocument {
                    let (_, _, frame, _) = document.sheetViewAndFrame(at: fp)
                    selectingLineNode.path = Path(frame)
                } else {
                    let frame = document.sheetFrame(with: document.sheetPosition(at: fp))
                    selectingLineNode.path = Path(frame)
                }
                
                document.updateSelectedColor(isMain: false)
            }
            document.rootNode.append(child: selectingLineNode)
            
            document.textCursorNode.isHidden = true
        case .changed:
            break
        case .ended:
            beginExport(type, at: fp)
        }
    }
    func beginExport(_ type: ExportType, at p: Point) {
        var vs = [SelectingValue]()
        
        let unionFrame: Rect?
        if document.isSelectNoneCursor(at: p),
           !document.isSelectedText,
           let r = document.selections.first?.rect {
            vs = document.world.sheetIDs.keys.compactMap { shp in
                let frame = document.sheetFrame(with: shp)
                if let rf = r.intersection(frame) {
                    if document.isEditingSheet {
                        let nf = rf - frame.origin
                        return SelectingValue(shp: shp,
                                              bounds: nf)
                    } else {
                        return SelectingValue(shp: shp,
                                              bounds: Sheet.defaultBounds)
                    }
                } else {
                    return nil
                }
            }
            vs = sorted(vs, with: document.selections.first?.rectCorner ?? .minXMinY)
            
            unionFrame = document.isEditingSheet && vs.count > 1 ? document.selections.first?.rect : nil
        } else {
            unionFrame = nil
            let (shp, sheetView, frame, _) = document.sheetViewAndFrame(at: p)
            if let sheetView = sheetView {
                let bounds = sheetView.model.boundsTuple(at: sheetView.convertFromWorld(p)).bounds.integral
                vs.append(SelectingValue(shp: shp, bounds: bounds))
            } else {
                let bounds = Rect(size: frame.size)
                vs.append(SelectingValue(shp: shp, bounds: bounds))
            }
        }
        
        guard let fv = vs.first else {
            end()
            return
        }
        let size = unionFrame?.size ?? fv.bounds.size
        guard size.width > 0 && size.height > 0 else {
            end()
            return
        }
        
        let complete: (IOResult) -> () = { (ioResult) in
            self.document.syncSave()
            switch type {
            case .png:
                self.exportImage(from: vs, unionFrame: unionFrame,
                                 size: size * 4, at: ioResult)
            case .pdf:
                self.exportPDF(from: vs, unionFrame: unionFrame,
                               size: size, at: ioResult)
            case .document:
                self.exportDocument(from: vs, isHistory: false, at: ioResult)
            case .documentWithHistory:
                self.exportDocument(from: vs, isHistory: true, at: ioResult)
            }
            self.end()
        }
        let cancel: () -> () = {
            self.end()
        }
        let fileSize: () -> (Int?) = {
            switch type {
            case .png:
                if vs.count == 1 {
                    let v = vs[0]
                    if let sid = self.document.sheetID(at: v.shp),
                       let node = self.document.renderableSheetNode(at: sid) {
                        let image = node.image(in: v.bounds, to: size * 4)
                        return image?.data(.png)?.count ?? 0
                    } else {
                        let node = Node(path: Path(v.bounds),
                                        fillType: .color(.background))
                        let image = node.image(in: v.bounds, to: size * 4,
                                               backgroundColor: .background)
                        return image?.data(.png)?.count ?? 0
                    }
                }
            case .pdf:
                if vs.count == 1 {
                    let v = vs[0]
                    if let pdf = try? PDF(mediaBox: Rect(size: size)) {
                        if let sid = self.document.sheetID(at: v.shp),
                           let node = self.document.renderableSheetNode(at: sid) {
                            node.render(in: v.bounds, to: size,
                                        in: pdf)
                        } else {
                            let node = Node(path: Path(v.bounds),
                                            fillType: .color(.background))
                            node.render(in: v.bounds, to: size,
                                        backgroundColor: .background,
                                        in: pdf)
                        }
                        pdf.finish()
                        return pdf.dataSize
                    }
                }
            case .document:
                let sids = vs.reduce(into: [SheetPosition: SheetID]()) {
                    $0[$1.shp] = self.document.sheetID(at: $1.shp)
                }
                let csv = CopiedSheetsValue(deltaPoint: Point(), sheetIDs: sids)
                
                var fileSize = 0
                csv.sheetIDs.forEach {
                    if let v = self.document.sheetRecorders[$0.value] {
                        fileSize += v.fileSizeWithoutHistory
                    }
                }
                return fileSize
            case .documentWithHistory:
                let sids = vs.reduce(into: [SheetPosition: SheetID]()) {
                    $0[$1.shp] = self.document.sheetID(at: $1.shp)
                }
                let csv = CopiedSheetsValue(deltaPoint: Point(), sheetIDs: sids)
                
                var fileSize = 0
                csv.sheetIDs.forEach {
                    if let v = self.document.sheetRecorders[$0.value] {
                        fileSize += v.fileSize
                    }
                }
                return fileSize
            }
            return nil
        }
        let fType: FileTypeProtocol
        switch type {
        case .png:
            fType = vs.count > 1 && unionFrame == nil ?
                Image.FileType.pngs : Image.FileType.png
        case .pdf:
            fType = PDF.FileType.pdf
        case .document:
            fType = Document.FileType.sksdoc
        case .documentWithHistory:
            fType = Document.FileType.skshdoc
        }
        
        URL.export(name: name(from: vs.map { $0.shp }),
                   fileType: fType,
                   fileSizeHandler: fileSize,
                   completionClosure: complete, cancelClosure: cancel)
    }
    
    func exportImage(from vs: [SelectingValue], unionFrame: Rect?,
                     size: Size, at ioResult: IOResult) {
        if vs.isEmpty {
            return
        } else if vs.count == 1 || unionFrame != nil {
            do {
                try ioResult.remove()
                
                if let unionFrame = unionFrame {
                    var nImage = Image(size: unionFrame.size * 4,
                                       color: .background)
                    for v in vs {
                        let origin = document.sheetFrame(with: v.shp).origin - unionFrame.origin
                        
                        if let sid = self.document.sheetID(at: v.shp),
                           let node = self.document.renderableSheetNode(at: sid) {
                            if let image = node.image(in: v.bounds, to: size) {
                                nImage = nImage?.drawn(image, in: (v.bounds + origin) * Transform(scale: 4))
                            }
                        } else {
                            let node = Node(path: Path(v.bounds),
                                            fillType: .color(.background))
                            if let image = node.image(in: v.bounds, to: size, backgroundColor: .background) {
                                nImage = nImage?.drawn(image, in: (v.bounds + origin) * Transform(scale: 4))
                            }
                        }
                    }
                    try nImage?.write(.png, to: ioResult.url)
                } else {
                    let v = vs[0]
                    if let sid = self.document.sheetID(at: v.shp),
                       let node = self.document.renderableSheetNode(at: sid) {
                        let image = node.image(in: v.bounds, to: size)
                        try image?.write(.png, to: ioResult.url)
                    } else {
                        let node = Node(path: Path(v.bounds),
                                        fillType: .color(.background))
                        let image = node.image(in: v.bounds, to: size, backgroundColor: .background)
                        try image?.write(.png, to: ioResult.url)
                    }
                }
                
                try ioResult.setAttributes()
            } catch {
                self.document.rootNode.show(error)
            }
        } else {
            let message = "Exporting Images".localized
            let progressPanel = ProgressPanel(message: message)
            self.document.rootNode.show(progressPanel)
            do {
                try ioResult.remove()
                try ioResult.makeDirectory()
                
                func export(progressHandler: (Double, inout Bool) -> ()) throws {
                    var isStop = false
                    for (j, v) in vs.enumerated() {
                        if let sid = self.document.sheetID(at: v.shp),
                           let node = self.document.renderableSheetNode(at: sid) {
                            let image = node.image(in: v.bounds, to: size)
                            let subIOResult = ioResult.sub(name: "\(j)__" +  self.name(from: v.shp) + ".png")
                            try image?.write(.png, to: subIOResult.url)
                            
                            try subIOResult.setAttributes()
                        } else {
                            let node = Node(path: Path(v.bounds),
                                            fillType: .color(.background))
                            let image = node.image(in: v.bounds, to: size, backgroundColor: .background)
                            let subIOResult = ioResult.sub(name: "\(j)__" +  self.name(from: v.shp) + ".png")
                            try image?.write(.png, to: subIOResult.url)
                            
                            try subIOResult.setAttributes()
                        }
                        progressHandler(Double(j + 1) / Double(vs.count), &isStop)
                        if isStop { break }
                    }
                }
                
                DispatchQueue.global().async {
                    do {
                        try export { (progress, isStop) in
                            if progressPanel.isCancel {
                                isStop = true
                            } else {
                                DispatchQueue.main.async {
                                    progressPanel.progress = progress
                                }
                            }
                        }
                        DispatchQueue.main.async {
                            progressPanel.closePanel()
                            self.end()
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.document.rootNode.show(error)
                            progressPanel.closePanel()
                            self.end()
                        }
                    }
                }
            } catch {
                self.document.rootNode.show(error)
                progressPanel.closePanel()
                self.end()
            }
        }
    }
    
    func exportPDF(from vs: [SelectingValue],  unionFrame: Rect?,
                   size: Size, at ioResult: IOResult) {
        func export(progressHandler: (Double, inout Bool) -> ()) throws {
            var isStop = false
            let pdf = try PDF(url: ioResult.url, mediaBox: Rect(size: size))
            
            if let unionFrame = unionFrame {
                pdf.newPage { pdf in
                    for v in vs {
                        let origin = document.sheetFrame(with: v.shp).origin - unionFrame.origin
                        
                        if let sid = self.document.sheetID(at: v.shp),
                           let node = self.document.renderableSheetNode(at: sid) {
                            node.render(in: v.bounds, to: v.bounds + origin,
                                        in: pdf)
                        } else {
                            let node = Node(path: Path(v.bounds),
                                            fillType: .color(.background))
                            node.render(in: v.bounds, to: v.bounds + origin,
                                        backgroundColor: .background,
                                        in: pdf)
                        }
                    }
                }
            } else {
                for (i, v) in vs.enumerated() {
                    if let sid = self.document.sheetID(at: v.shp),
                       let node = self.document.renderableSheetNode(at: sid) {
                        node.render(in: v.bounds, to: size,
                                    in: pdf)
                    } else {
                        let node = Node(path: Path(v.bounds),
                                        fillType: .color(.background))
                        node.render(in: v.bounds, to: size,
                                    backgroundColor: .background,
                                    in: pdf)
                    }
                    
                    progressHandler(Double(i + 1) / Double(vs.count), &isStop)
                    if isStop { break }
                }
            }
            
            pdf.finish()
            
            try ioResult.setAttributes()
        }
        
        if vs.count == 1 {
            do {
                try export { (_, isStop) in }
                self.end()
            } catch {
                self.document.rootNode.show(error)
                self.end()
            }
        } else {
            let message = "Exporting PDF".localized
            let progressPanel = ProgressPanel(message: message)
            self.document.rootNode.show(progressPanel)
            do {
                try ioResult.remove()
                
                DispatchQueue.global().async {
                    do {
                        try export { (progress, isStop) in
                            if progressPanel.isCancel {
                                isStop = true
                            } else {
                                DispatchQueue.main.async {
                                    progressPanel.progress = progress
                                }
                            }
                        }
                        DispatchQueue.main.async {
                            progressPanel.closePanel()
                            self.end()
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.document.rootNode.show(error)
                            progressPanel.closePanel()
                            self.end()
                        }
                    }
                }
            } catch {
                self.document.rootNode.show(error)
                progressPanel.closePanel()
                self.end()
            }
        }
    }
    
    func exportDocument(from vs: [SelectingValue],
                        isHistory: Bool,
                        at ioResult: IOResult) {
        guard let shp0 = vs.first?.shp else { return }
        
        func export(progressHandler: (Double, inout Bool) -> ()) throws {
            try ioResult.remove()
            
            let sids = vs.reduce(into: [SheetPosition: SheetID]()) {
                $0[$1.shp - shp0] = document.sheetID(at: $1.shp)
            }
            let csv = CopiedSheetsValue(deltaPoint: Point(), sheetIDs: sids)
            
            var isStop = false
            let nDocument = Document(url: ioResult.url)
            for (i, v) in csv.sheetIDs.enumerated() {
                let (shp, osid) = v
                guard let osrr = document.sheetRecorders[osid] else { continue }
                let nsid = SheetID()
                let nsrr = nDocument.makeSheetRecorder(at: nsid)
                if let oldSID = nDocument.world.sheetIDs[shp] {
                    nDocument.world.sheetPositions[oldSID] = nil
                }
                nDocument.world.sheetIDs[shp] = nsid
                nDocument.world.sheetPositions[nsid] = shp
                
                nsrr.sheetRecord.data
                    = osrr.sheetRecord.decodedData
                nsrr.thumbnail4Record.data
                    = osrr.thumbnail4Record.decodedData
                nsrr.thumbnail16Record.data
                    = osrr.thumbnail16Record.decodedData
                nsrr.thumbnail64Record.data
                    = osrr.thumbnail64Record.decodedData
                nsrr.thumbnail256Record.data
                    = osrr.thumbnail256Record.decodedData
                nsrr.thumbnail1024Record.data
                    = osrr.thumbnail1024Record.decodedData
                nsrr.sheetRecord.isWillwrite = true
                nsrr.thumbnail4Record.isWillwrite = true
                nsrr.thumbnail16Record.isWillwrite = true
                nsrr.thumbnail64Record.isWillwrite = true
                nsrr.thumbnail256Record.isWillwrite = true
                nsrr.thumbnail1024Record.isWillwrite = true
                
                if isHistory {
                    nsrr.sheetHistoryRecord.data
                        = osrr.sheetHistoryRecord.decodedData
                    nsrr.sheetHistoryRecord.isWillwrite = true
                }
                
                progressHandler(Double(i + 1) / Double(csv.sheetIDs.count + 1), &isStop)
                if isStop { break }
            }
            nDocument.camera = document.camera
            nDocument.syncSave()
            
            try ioResult.setAttributes()
        }
        
        if vs.count == 1 {
            do {
                try export { (_, isStop) in }
                self.end()
            } catch {
                self.document.rootNode.show(error)
                self.end()
            }
        } else {
            let message = "Exporting Document".localized
            let progressPanel = ProgressPanel(message: message)
            self.document.rootNode.show(progressPanel)
            DispatchQueue.global().async {
                do {
                    try export { (progress, isStop) in
                        if progressPanel.isCancel {
                            isStop = true
                        } else {
                            DispatchQueue.main.async {
                                progressPanel.progress = progress
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        progressPanel.closePanel()
                        self.end()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.document.rootNode.show(error)
                        progressPanel.closePanel()
                        self.end()
                    }
                }
            }
        }
    }
}
