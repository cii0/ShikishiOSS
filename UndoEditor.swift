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

import Dispatch

final class Undoer: InputKeyEditor {
    let editor: UndoEditor
    
    init(_ document: Document) {
        editor = UndoEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.undo(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class Redoer: InputKeyEditor {
    let editor: UndoEditor
    
    init(_ document: Document) {
        editor = UndoEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.redo(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class VersionSelector: DragEditor {
    let editor: UndoEditor
    
    init(_ document: Document) {
        editor = UndoEditor(document)
    }
    
    func send(_ event: DragEvent) {
        editor.selectVersion(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class UndoEditor: Editor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    enum UndoType {
        case x, y
    }
    
    let undoXWidth = 8.0, undoYWidth = 12.0, correction = 1.0, xd = 3.0, yd = 3.0
    let outlineNode = Node(lineWidth: 2, lineType: .color(.background))
    let lineNode = Node(lineWidth: 1, lineType: .color(.content))
    let currentKnobNode = Node(path: Path(circleRadius: 4.5), lineWidth: 1,
                               lineType: .color(.background),
                               fillType: .color(.content))
    var outlineYNodes = [Node]()
    var yNodes = [Node]()
    let rootNode = Node()
    let selectingRootNode = Node(lineWidth: 1, lineType: .color(.selected))
    let outOfBoundsNode = Node(lineWidth: 1, lineType: .color(.selected))
    
    var firstSP = Point(), fdp = Point(), ydp = Point()
    var beganVersion = Version?.none, beganXIndex = 0, beganYIndex = 0, dyIndex = 0
    var currentXIndex = 0, maxXCount = 0, currentYIndex = 0, maxYCount = 0
    var oldSP = Point(), oldTime = 0.0
    var sheetView: SheetView?
    var isEditRoot = false
    
    var type = UndoType.x
    
    func updateNode() {
        selectingRootNode.lineWidth = document.worldLineWidth
        outOfBoundsNode.lineWidth = document.worldLineWidth
    }
    
    func yPath(selectedIndex: Int,
               count: Int, x: Double) -> (path: Path, position: Point) {
        var pathlines = [Pathline]()
        pathlines.append(Pathline([Point(x, 0),
                                   Point(x, -undoYWidth * Double(count - 1))]))
        for i in 0..<count {
            let ny = -undoYWidth * Double(i)
            pathlines.append(Pathline([Point(x - xd, ny), Point(x + xd, ny)]))
        }
        return (Path(pathlines), Point(0, undoYWidth * Double(selectedIndex)))
    }
    func updateEmptyPath(at p: Point) {
        let linePath = Path([Pathline([Point(0, -yd), Point(0, yd)])])
        outlineNode.path = linePath
        lineNode.path = linePath
        
        var attitude = Attitude(document.screenToWorldTransform)
        let up = document.convertScreenToWorld(document.convertWorldToScreen(p))
        attitude.position = up
        rootNode.attitude = attitude
        
        currentKnobNode.attitude.position = Point()
        rootNode.append(child: outlineNode)
        rootNode.append(child: lineNode)
        rootNode.append(child: currentKnobNode)
        document.rootNode.append(child: rootNode)
    }
    func updatePath<T: UndoItem>(maxTopIndex: Int, rootBranch: Branch<T>) {
        var pathlines = [Pathline]()
        pathlines.append(Pathline([Point(),
                                   Point(undoXWidth * Double(maxTopIndex), 0)]))
        (0...maxTopIndex).forEach { i in
            let sx = undoXWidth * Double(i)
            pathlines.append(Pathline([Point(sx, -yd), Point(sx, yd)]))
        }
        let linePath = Path(pathlines)
        outlineNode.path = linePath
        lineNode.path = linePath
        
        rootNode.children = []
        outlineYNodes = []
        yNodes = []
        var un = rootBranch, count = 0
        while let sci = un.selectedChildIndex {
            count += un.groups.count
            let x = undoXWidth * Double(count)
            let (path, p) = yPath(selectedIndex: sci,
                                  count: un.children.count, x: x)
            let outlineYNode = Node(path: path, lineWidth: 2,
                                    lineType: .color(.background))
            let yNode = Node(path: path, lineWidth: 1,
                             lineType: .color(.content))
            outlineYNode.attitude.position = p
            yNode.attitude.position = p
            outlineYNodes.append(outlineYNode)
            yNodes.append(yNode)
            un = un.children[sci]
        }
        
        rootNode.append(child: outlineNode)
        outlineYNodes.forEach { rootNode.append(child: $0) }
        rootNode.append(child: lineNode)
        yNodes.forEach { rootNode.append(child: $0) }
        rootNode.append(child: currentKnobNode)
    }
    func undo(at p: Point, undoIndex: Int) {
        var frame: Rect?
        if let sheetView = sheetView {
            if let aFrame = sheetView.undo(to: undoIndex) {
                frame = sheetView.convertToWorld(aFrame)
            }
        } else {
            frame = document.undo(to: undoIndex)
        }
        if let frame = frame {
            let f = document.screenBounds * document.screenToWorldTransform
            if frame.width > 0 && frame.height > 0, !f.intersects(frame) {
                let fp = f.centerPoint, lp = frame.centerPoint
                let d = max(frame.width, frame.height)
                let ps = f.intersection(Edge(fp, lp).extendedLast(withDistance: d))
                if !ps.isEmpty {
                    let np = ps[0]
                    let nfp = Point.linear(fp, np, t: 0.6)
                    let nlp = Point.linear(fp, np, t: 0.95)
                    let angle = Edge(nfp, nlp).reversed().angle()
                    var pathlines = [Pathline]()
                    pathlines.append(Pathline([nfp, nlp]))
                    let l = 10 / document.worldToScreenScale
                    pathlines.append(Pathline([nlp.movedWith(distance: l,
                                                             angle: angle - .pi / 6),
                                               nlp,
                                               nlp.movedWith(distance: l,
                                                             angle: angle + .pi / 6)]))
                    outOfBoundsNode.path = Path(pathlines)
                } else {
                    outOfBoundsNode.path = Path()
                }
            } else {
                outOfBoundsNode.path = Path()
            }
            let nf = frame * document.worldToScreenTransform
            if !document.isEditingSheet || (nf.width < 6 && nf.height < 6) {
                let s = 1 / document.worldToScreenScale
                selectingRootNode.path = Path(frame.inset(by: -2 * s),
                                              cornerRadius: 4 * s)
            } else {
                selectingRootNode.path = Path()
            }
        }
    }
    
    func undo(with event: InputKeyEvent) {
        undo(with: event, isRedo: false)
    }
    func redo(with event: InputKeyEvent) {
        undo(with: event, isRedo: true)
    }
    func undo(with event: InputKeyEvent, isRedo: Bool) {
        let sp = document.lastEditedSheetScreenCenterPositionNoneSelectedNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            updateUndoOrRedo(at: p, isRedo: isRedo)
        case .changed:
            if event.isRepeat {
                updateUndoOrRedo(at: p, isRedo: isRedo)
            }
        case .ended:
            outOfBoundsNode.removeFromParent()
            selectingRootNode.removeFromParent()
            rootNode.removeFromParent()
            
            document.updateSelects()
            if let sheetView = sheetView {
                document.updateFinding(from: sheetView)
            }
            
            document.cursor = Document.defaultCursor
        }
    }
    func updateUndoOrRedo(at p: Point, isRedo: Bool) {
        func update(currentVersionIndex: Int,
                    currentMaxVersionIndex: Int) {
            func setup(firstPathline: Pathline, topIndex: Int) {
                var pathlines = [firstPathline]
                let sx = undoXWidth * Double(topIndex)
                pathlines.append(Pathline([Point(sx, -yd), Point(sx, yd)]))
                let linePath = Path(pathlines)
                outlineNode.path = linePath
                lineNode.path = linePath
                
                let rp = Point(undoXWidth * Double(topIndex), 0)
                
                var attitude = Attitude(document.screenToWorldTransform)
                let up = document.convertScreenToWorld(document.convertWorldToScreen(p) - rp)
                attitude.position = up
                rootNode.attitude = attitude
                
                currentKnobNode.attitude.position = rp
                
                rootNode.append(child: outlineNode)
                rootNode.append(child: lineNode)
                rootNode.append(child: currentKnobNode)
                document.rootNode.append(child: rootNode)
            }
            let ni = currentVersionIndex + (isRedo ? 1 : -1)
            let nsi = ni.clipped(min: 0, max: currentMaxVersionIndex)
            if nsi == 0 {
                setup(firstPathline: Pathline([Point(0, 0),
                                               Point(undoXWidth, 0)]),
                      topIndex: nsi)
            } else if nsi == currentMaxVersionIndex {
                setup(firstPathline: Pathline([Point(undoXWidth * Double(nsi - 1), 0),
                                               Point(undoXWidth * Double(nsi), 0)]),
                      topIndex: nsi)
            }
            if currentVersionIndex != nsi {
                undo(at: p, undoIndex: nsi)
                selectingRootNode.lineWidth = document.worldLineWidth
                outOfBoundsNode.lineWidth = document.worldLineWidth
                document.rootNode.append(child: selectingRootNode)
                document.rootNode.append(child: outOfBoundsNode)
            }
        }
        if !document.isEditingSheet {
            self.sheetView = nil
            isEditRoot = true
            
            update(currentVersionIndex: document.history.currentVersionIndex,
                   currentMaxVersionIndex: document.history.currentMaxVersionIndex)
        } else if let sheetView = document.sheetView(at: p) {
            self.sheetView = sheetView
            isEditRoot = false
            
            update(currentVersionIndex: sheetView.history.currentVersionIndex,
                   currentMaxVersionIndex: sheetView.history.currentMaxVersionIndex)
        } else {
            self.sheetView = nil
            isEditRoot = false
            
            updateEmptyPath(at: p)
        }
        document.updateTextCursor()
    }
    
    func selectVersion(with event: DragEvent) {
        let p = document.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            firstSP = event.screenPoint
            oldSP = event.screenPoint
            oldTime = event.time
            
            func update<T: UndoItem>(currentVersion: Version?,
                                     currentVersionIndex: Int,
                                     currentMaxVersionIndex:Int,
                                     rootBranch: Branch<T>) {
                beganVersion = currentVersion
                
                beganXIndex = currentVersionIndex
                currentXIndex = currentVersionIndex
                fdp = Point(undoXWidth * Double(currentVersionIndex), 0)
                maxXCount = currentMaxVersionIndex + 1
                
                dyIndex = 0
                let buip = beganVersion?.indexPath ?? []
                let un = rootBranch[buip]
                if let yi = un.selectedChildIndex,
                   currentVersion?.groupIndex == nil
                    || currentVersion?.groupIndex == un.groups.count - 1 {
                    
                    beganYIndex = yi
                    currentYIndex = yi
                    ydp = Point(0, -undoYWidth * Double(yi))
                    maxYCount = un.children.count
                }
                
                updatePath(maxTopIndex: currentMaxVersionIndex,
                           rootBranch: rootBranch)
                var attitude = Attitude(document.screenToWorldTransform)
                let up = document.convertScreenToWorld(document.convertWorldToScreen(p) - fdp)
                attitude.position = up
                rootNode.attitude = attitude
                currentKnobNode.attitude.position = fdp
                
                document.rootNode.append(child: rootNode)
                selectingRootNode.lineWidth = document.worldLineWidth
                outOfBoundsNode.lineWidth = document.worldLineWidth
                document.rootNode.append(child: selectingRootNode)
                document.rootNode.append(child: outOfBoundsNode)
            }
            if !document.isEditingSheet {
                self.sheetView = nil
                isEditRoot = true
                
                update(currentVersion: document.history.currentVersion,
                       currentVersionIndex: document.history.currentVersionIndex,
                       currentMaxVersionIndex: document.history.currentMaxVersionIndex,
                       rootBranch: document.history.rootBranch)
            } else if let sheetView = document.sheetView(at: p) {
                self.sheetView = sheetView
                isEditRoot = false
                
                update(currentVersion: sheetView.history.currentVersion,
                       currentVersionIndex: sheetView.history.currentVersionIndex,
                       currentMaxVersionIndex: sheetView.history.currentMaxVersionIndex,
                       rootBranch: sheetView.history.rootBranch)
            } else {
                self.sheetView = nil
                isEditRoot = false
                
                updateEmptyPath(at: p)
            }
        case .changed:
            guard (sheetView != nil || isEditRoot) && maxXCount > 0 else { return }
            
            func uip<T: UndoItem>(currentVersion: Version?,
                                  rootBranch: Branch<T>) -> VersionPath? {
                let buip = currentVersion?.indexPath ?? []
                let un = rootBranch[buip]
                if un.selectedChildIndex != nil {
                    if currentVersion?.groupIndex == nil
                        || currentVersion?.groupIndex == un.groups.count - 1 {
                        
                        return buip
                    }
                }
                return nil
            }
            let buip: VersionPath?
            if let sheetView = sheetView {
                buip = uip(currentVersion: sheetView.history.currentVersion,
                           rootBranch: sheetView.history.rootBranch)
            } else {
                buip = uip(currentVersion: document.history.currentVersion,
                           rootBranch: document.history.rootBranch)
            }
            
            let speed = (event.screenPoint - oldSP).length()
                / (event.time - oldTime)
            if buip != nil && speed < 200 {
                let dp = event.screenPoint - oldSP
                type = abs(dp.x) > abs(dp.y) ? .x : .y
            }
            oldSP = event.screenPoint
            oldTime = event.time
            
            let deltaP = event.screenPoint - firstSP
            switch type {
            case .x:
                var dp = fdp + deltaP
                dp.x = dp.x.clipped(min: 0,
                                    max: undoXWidth * Double(maxXCount - 1))
                let newIndex = Int((dp.x / undoXWidth).rounded())
                    .clipped(min: 0, max: maxXCount - 1)
                if newIndex != currentXIndex {
                    currentXIndex = newIndex
                    
                    undo(at: p, undoIndex: newIndex)
                    currentKnobNode.attitude.position.x
                        = undoXWidth * Double(newIndex)
                    
                    func updateY<T: UndoItem>(currentVersion: Version?,
                                              rootBranch: Branch<T>) {
                        let buip = currentVersion?.indexPath ?? []
                        let un = rootBranch[buip]
                        if let yi = un.selectedChildIndex,
                           currentVersion?.groupIndex == nil
                            || currentVersion?.groupIndex == un.groups.count - 1 {
                            
                            beganYIndex = yi
                            currentYIndex = yi
                            ydp = Point(0, -undoYWidth * Double(yi - dyIndex))
                            maxYCount = un.children.count
                        }
                    }
                    if let sheetView = sheetView {
                        updateY(currentVersion: sheetView.history.currentVersion,
                                rootBranch: sheetView.history.rootBranch)
                    } else {
                        updateY(currentVersion: document.history.currentVersion,
                                rootBranch: document.history.rootBranch)
                    }
                    
                    let np = document.convertScreenToWorld(firstSP)
                    let nnp = Point(undoXWidth * Double(beganXIndex),
                                    undoYWidth * Double(dyIndex))
                    let up = document.convertScreenToWorld(document.convertWorldToScreen(np) - nnp)
                    rootNode.attitude.position = up
                }
            case .y:
                if let buip = buip {
                    var dp = ydp + deltaP
                    dp.y = dp.y.clipped(min: -undoYWidth * Double(maxYCount - 1),
                                        max: 0)
                    let newIndex = Int((-dp.y / undoYWidth).rounded())
                        .clipped(min: 0, max: maxYCount - 1)
                    if newIndex != currentYIndex {
                        dyIndex += newIndex - currentYIndex
                        currentYIndex = newIndex
                        
                        if let sheetView = sheetView {
                            sheetView.history.rootBranch[buip]
                                .selectedChildIndex = newIndex
                            let maxIndex = sheetView.history.currentMaxVersionIndex
                            updatePath(maxTopIndex: maxIndex,
                                       rootBranch: sheetView.history.rootBranch)
                            maxXCount = maxIndex + 1
                        } else {
                            document.history.rootBranch[buip]
                                .selectedChildIndex = newIndex
                            let maxIndex = document.history.currentMaxVersionIndex
                            updatePath(maxTopIndex: maxIndex,
                                       rootBranch: document.history.rootBranch)
                            maxXCount = maxIndex + 1
                        }
                        
                        let np = document.convertScreenToWorld(firstSP)
                        let nnp = Point(undoXWidth * Double(beganXIndex),
                                        undoYWidth * Double(dyIndex))
                        let up = document.convertScreenToWorld(document.convertWorldToScreen(np) - nnp)
                        rootNode.attitude.position = up
                    }
                }
            }
        case .ended:
            outOfBoundsNode.removeFromParent()
            selectingRootNode.removeFromParent()
            rootNode.removeFromParent()
            
            document.updateSelects()
            if let sheetView = sheetView {
                document.updateFinding(from: sheetView)
            }
            
            document.cursor = Document.defaultCursor
        }
    }
}

final class HistoryCleaner: InputKeyEditor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    let selectingLineNode = Node(lineWidth: 1.5)
    func updateNode() {
        selectingLineNode.lineWidth = document.worldLineWidth
    }
    func end() {
        selectingLineNode.removeFromParent()
        
        document.cursor = Document.defaultCursor
        
        document.updateSelectedColor(isMain: true)
    }
    
    func send(_ event: InputKeyEvent) {
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if document.isSelectNoneCursor(at: p),
               !document.isSelectedText,
               let r = document.selections.first?.rect {
                
                let vs: [Rect] = document.world.sheetIDs.keys.compactMap { shp in
                    let frame = document.sheetFrame(with: shp)
                    if r.intersects(frame) {
                        return frame
                    } else {
                        return nil
                    }
                }
                selectingLineNode.children = vs.map {
                    Node(path: Path($0),
                         lineWidth: document.worldLineWidth,
                         lineType: .color(.selected),
                         fillType: .color(.subSelected))
                }
            } else {
                selectingLineNode.lineWidth = document.worldLineWidth
                selectingLineNode.fillType = .color(.subSelected)
                selectingLineNode.lineType = .color(.selected)
                let frame = document
                    .sheetFrame(with: document.sheetPosition(at: p))
                selectingLineNode.path = Path(frame)
                
                document.updateSelectedColor(isMain: false)
            }
            document.rootNode.append(child: selectingLineNode)
            
            document.textCursorNode.isHidden = true
        case .changed:
            break
        case .ended:
            if document.isSelectNoneCursor(at: p),
               !document.isSelectedText,
               let f = document.selections.first?.rect {
                
                let shps: [SheetPosition] = document.world.sheetIDs.keys.compactMap {
                    let frame = document.sheetFrame(with: $0)
                    if f.intersects(frame) {
                        return $0
                    } else {
                        return nil
                    }
                }
                
                let ok: () -> () = {
                    func clearHistorys(progressHandler: (Double, inout Bool) -> ()) throws {
                        var isStop = false
                        for (j, shp) in shps.enumerated() {
                            if let sheetView = self.document.sheetView(at: shp) {
                                sheetView.clearHistory()
                            } else {
                                self.document.removeUndo(at: shp)
                            }
                            progressHandler(Double(j + 1) / Double(shps.count), &isStop)
                            if isStop { break }
                        }
                    }
                    
                    let message = "Clearing Historys".localized
                    let progressPanel = ProgressPanel(message: message)
                    self.document.rootNode.show(progressPanel)
                    DispatchQueue.global().async {
                        do {
                            try clearHistorys { (progress, isStop) in
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
                    
                    self.end()
                }
                let cancel: () -> () = {
                    self.end()
                }
                let mes = shps.count == 1 ?
                    "Do you want to clear history of this sheet?".localized :
                    String(format: "Do you want to clear %d historys?".localized,
                           shps.count)
                document.rootNode
                    .show(message: mes,
                          infomation: "You can’t undo this action. History is what is used in \"Undo\", \"Redo\" or \"Select Version\", and if you clear it, you will not be able to return to the previous work.".localized,
                          okTitle: "Clear History".localized,
                          isSaftyCheck: shps.count > 1,
                          okClosure: ok, cancelClosure: cancel)
            } else {
                let shp = document.sheetPosition(at: p)
                let ok: () -> () = {
                    if let sheetView = self.document.sheetView(at: shp) {
                        sheetView.clearHistory()
                    } else {
                        self.document.removeUndo(at: shp)
                    }
                    
                    self.end()
                }
                let cancel: () -> () = {
                    self.end()
                }
                document.rootNode
                    .show(message: "Do you want to clear history of this sheet?".localized,
                          infomation: "You can’t undo this action. History is what is used in \"Undo\", \"Redo\" or \"Select Version\", and if you clear it, you will not be able to return to the previous work.".localized,
                          okTitle: "Clear History".localized,
                          okClosure: ok, cancelClosure: cancel)
            }
        }
    }
}
