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

final class Finder: InputKeyEditor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    func send(_ event: InputKeyEvent) {
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            let p = document.convertScreenToWorld(event.screenPoint)
            guard let sheetView = document.sheetView(at: p) else { return }
            let inP = sheetView.convertFromWorld(p)
            if let (textView, _, i, _) = sheetView.textTuple(at: inP) {
                if document.isSelect(at: p),
                   let selection = document.selections.first {
                    
                    let nSelection = textView.convertFromWorld(selection)
                    let ranges = textView.ranges(at: nSelection)
                    if let range = ranges.first {
                        let string = String(textView.model.string[range])
                        document.finding = Finding(worldPosition: p,
                                                   string: string)
                    } else {
                        document.finding = Finding()
                    }
                } else {
                    if let range = textView.wordRange(at: i) {
                        let string = String(textView.model.string[range])
                        document.finding = Finding(worldPosition: p,
                                                   string: string)
                    }
                }
            } else {
                document.finding = Finding()
            }
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
}

final class Looker: InputKeyEditor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    func send(_ event: InputKeyEvent) {
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            let p = document.convertScreenToWorld(event.screenPoint)
//            guard let sheetView = document.sheetView(at: p) else { return }
//            let inP = sheetView.convertFromWorld(p)
            
            let isClose = !show(for: p)
//            if let (textView, _, i, _) = sheetView.textTuple(at: inP) {
//                if document.isSelect(at: p),
//                   let selection = document.selections.first {
//
//                    let nSelection = textView.convertFromWorld(selection)
//                    if let range = textView.ranges(at: nSelection).first {
//                        let string = String(textView.model.string[range])
//                        showDefinition(string: string, range: range,
//                                       in: textView, in: sheetView)
//                        isClose = false
//                    }
//                } else {
//                    let range = textView.wordRange(at: i)
//                    let string = String(textView.model.string[range])
//                    showDefinition(string: string, range: range,
//                                   in: textView, in: sheetView)
//                    isClose = false
//                }
//            }
            if isClose {
                document.closeLookingUpNode()
            }
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
    func show(for p: Point) -> Bool {
        let d = 5 / document.worldToScreenScale
        if !document.isEditingSheet {
            if let _ = document.sheetID(at: document.sheetPosition(at: p)) {
                document.show("Sheet".localized, at: p)
            } else {
                document.show("Root".localized, at: p)
            }
            return true
        } else if document.isSelect(at: p), let _ = document.selections.first?.rect {
            if let selection = document.selections.first {
                if let sheetView = document.sheetView(at: p),
                   let (textView, _, _, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)) {
                    
                    let nSelection = textView.convertFromWorld(selection)
                    if let range = textView.ranges(at: nSelection).first {
                        let string = String(textView.model.string[range])
                        showDefinition(string: string, range: range,
                                       in: textView, in: sheetView)
                        
                    }
                }
            }
            return true
        } else if let (_, _) = document.worldBorder(at: p, distance: d) {
            document.show("Border".localized, at: p)
            return true
        } else if let (_, _, _) = document.border(at: p, distance: d) {
            document.show("Border".localized, at: p)
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let _ = sheetView.lineTuple(at: sheetView.convertFromWorld(p), scale: 1 / document.worldToScreenScale)?.lineView {
            document.show("Line".localized, at: p)
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let (textView, _, i, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)) {
            
            if let range = textView.wordRange(at: i) {
                let string = String(textView.model.string[range])
                showDefinition(string: string, range: range,
                               in: textView, in: sheetView)
            } else {
                document.show("Text".localized, at: p)
            }
            return true
        } else if !document.isDefaultUUColor(at: p) {
            let colorOwners = document.readColorOwner(at: p)
            if !colorOwners.isEmpty {
                document.show("Face".localized, at: p)
                return true
            }
        }
        return false
    }
    
//    func showDefinition(string: String,
//                        range: Range<String.Index>,
//                        in textView: SheetTextView, in sheetView: SheetView) {
//        let p = textView.characterBasePosition(at: range.lowerBound)
//        let np = textView.convertToWorld(p)
//        let font = textView.model.font
//        let nFont = Font(name: font.name, cascadeNames: font.cascadeNames,
//                         isProportional: font.isProportional,
//                         size: max(1, font.size * document.worldToScreenScale))
//        document.rootNode.show(definition: string,
//                               font: nFont,
//                               orientation: textView.model.orientation,
//                               at: np)
//    }
    func showDefinition(string: String,
                        range: Range<String.Index>,
                        in textView: SheetTextView, in sheetView: SheetView) {
        let np = textView.characterPosition(at: range.lowerBound)
        if let nstr = TextDictionary.string(from: string) {
            show(string: nstr, fromSize: textView.model.size,
                 rects: textView.transformedRects(with: range),
                 at: np, in: textView, in: sheetView)
        } else {
            show(string: "?", fromSize: textView.model.size,
                 rects: textView.transformedRects(with: range),
                 at: np, in: textView, in: sheetView)
        }
    }
    func show(string: String, fromSize: Double, rects: [Rect], at p: Point,
              in textView: SheetTextView, in sheetView: SheetView) {
        document.show(string,
                      fromSize: fromSize,
                      rects: rects.map { sheetView.convertToWorld($0) },
                      textView.model.orientation)
    }
}

final class VerticalTextChanger: InputKeyEditor {
    let editor: TextOrientationEditor
    
    init(_ document: Document) {
        editor = TextOrientationEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.changeToVerticalText(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class HorizontalTextChanger: InputKeyEditor {
    let editor: TextOrientationEditor
    
    init(_ document: Document) {
        editor = TextOrientationEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.changeToHorizontalText(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class TextOrientationEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    func changeToVerticalText(with event: InputKeyEvent) {
        changeTextOrientation(.vertical, with: event)
    }
    func changeToHorizontalText(with event: InputKeyEvent) {
        changeTextOrientation(.horizontal, with: event)
    }
    func changeTextOrientation(_ orientation: Orientation, with event: InputKeyEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        switch event.phase {
        case .began:
            defer {
                document.updateTextCursor()
            }
            document.cursor = .arrow
            
            let p = document.convertScreenToWorld(event.screenPoint)
            
            if document.isSelectNoneCursor(at: p),
               let f = document.selections.first?.rect {
                
                for (shp, _) in document.sheetViewValues {
                    let ssFrame = document.sheetFrame(with: shp)
                    if ssFrame.intersects(f),
                       let sheetView = document.sheetView(at: shp) {
                        
                        let b = sheetView.convertFromWorld(f)
                        var tivs = [IndexValue<Text>]()
                        for (i, textView) in sheetView.textsView.elementViews.enumerated() {
                            if textView.transformedBounds?.intersects(b) ?? false {
                                
                                var text = textView.model
                                text.orientation = orientation
                                tivs.append(IndexValue(value: text, index: i))
                            }
                            
                        }
                        if !tivs.isEmpty {
                            sheetView.newUndoGroup()
                            sheetView.replace(tivs)
                        }
                    }
                }
            } else if !document.isNoneCursor {
                document.textEditor.begin(atScreen: event.screenPoint)
                
                guard let sheetView = document.sheetView(at: p) else { return }
                if let aTextView = document.textEditor.editingTextView,
                   !aTextView.isHiddenSelectedRange,
                   let i = sheetView.textsView.elementViews
                    .firstIndex(of: aTextView) {
                    
                    document.textEditor.endInputKey(isUnmarkText: true,
                                                    isRemoveText: false)
                    let textView = aTextView
                    var text = textView.model
                    if text.orientation != orientation {
                        text.orientation = orientation
                        
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
                        sheetView.replace([IndexValue(value: text, index: i)])
                    }
                } else {
                    let inP = sheetView.convertFromWorld(p)
                    document.textEditor
                        .appendEmptyText(screenPoint: event.screenPoint,
                                         at: inP,
                                         orientation: orientation,
                                         in: sheetView)
                }
            }
            
            document.updateSelects()
            document.updateFinding(at: p)
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
}

final class SuperscriptChanger: InputKeyEditor {
    let editor: TextScriptEditor
    
    init(_ document: Document) {
        editor = TextScriptEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.changeScripst(true, with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class SubscriptChanger: InputKeyEditor {
    let editor: TextScriptEditor
    
    init(_ document: Document) {
        editor = TextScriptEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.changeScripst(false, with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class TextScriptEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    func changeScripst(_ isSuper: Bool, with event: InputKeyEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        func moveCharacter(isSuper: Bool, from c: Character) -> Character? {
            if isSuper {
                if c.isSuperscript {
                    return nil
                } else if c.isSubscript {
                    return c.fromSubscript
                } else {
                    return c.toSuperscript
                }
            } else {
                if c.isSuperscript {
                    return c.fromSuperscript
                } else if c.isSubscript {
                    return nil
                } else {
                    return c.toSubscript
                }
            }
        }
        
        switch event.phase {
        case .began:
            defer {
                document.updateTextCursor()
            }
            document.cursor = .arrow
            
            let p = document.convertScreenToWorld(event.screenPoint)
            
            if document.isSelect(at: p),
               let selection = document.selections.first {
                
                for (shp, _) in document.sheetViewValues {
                    let ssFrame = document.sheetFrame(with: shp)
                    if ssFrame.intersects(selection.rect),
                       let sheetView = document.sheetView(at: shp) {
                        
                        var isNewUndoGroup = true
                        for (j, textView) in sheetView.textsView.elementViews.enumerated() {
                            let nSelection = textView.convertFromWorld(selection)
                            let ranges = textView.ranges(at: nSelection)
                            let string = textView.model.string
                            for range in ranges {
                                let str = string[range]
                                var nstr = "", isChange = false
                                for c in str {
                                    if let nc = moveCharacter(isSuper: isSuper, from: c) {
                                        nstr.append(nc)
                                        isChange = true
                                    } else {
                                        nstr.append(c)
                                    }
                                }
                                if isChange {
                                    let tv = TextValue(string: nstr,
                                                       replacedRange: string.intRange(from: range),
                                                       origin: nil, size: nil)
                                    if isNewUndoGroup {
                                        sheetView.newUndoGroup()
                                        isNewUndoGroup = false
                                    }
                                    sheetView.replace(IndexValue(value: tv, index: j))
                                }
                            }
                        }
                    }
                }
            } else {
                document.textEditor.begin(atScreen: event.screenPoint)
                
                guard let sheetView = document.sheetView(at: p) else { return }
                if let aTextView = document.textEditor.editingTextView,
                   !aTextView.isHiddenSelectedRange,
                   let ai = sheetView.textsView.elementViews
                    .firstIndex(of: aTextView) {
                    
                    document.textEditor.endInputKey(isUnmarkText: true,
                                                    isRemoveText: true)
                    guard let ati = aTextView.selectedRange?.lowerBound,
                          ati > aTextView.model.string.startIndex else { return }
                    let textView = aTextView
                    let i = ai
                    let ti = aTextView.model.string.index(before: ati)
                    
                    let text = textView.model
                    if !text.string.isEmpty {
                        let ti = ti >= text.string.endIndex ?
                            text.string.index(before: text.string.endIndex) : ti
                        let c = text.string[ti]
                        if let nc = moveCharacter(isSuper: isSuper, from: c) {
                            let nti = text.string.intIndex(from: ti)
                            let tv = TextValue(string: String(nc),
                                               replacedRange: nti..<(nti + 1),
                                               origin: nil, size: nil)
                            sheetView.newUndoGroup()
                            sheetView.replace(IndexValue(value: tv, index: i))
                        }
                    }
                }
            }
            
            document.updateSelects()
            document.updateFinding(at: p)
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
}

final class TextEditor: Editor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    deinit {
        inputKeyTimer.cancel()
    }
    
    weak var editingSheetView: SheetView?
    weak var editingTextView: SheetTextView? {
        didSet {
            if editingTextView !== oldValue {
                editingTextView?.editor = self
                oldValue?.unmark()
                TextInputContext.update()
                oldValue?.isHiddenSelectedRange = true
            }
            editingTextView?.isHiddenSelectedRange = false
            if editingTextView == nil && Cursor.isHidden {
                Cursor.isHidden = false
            }
        }
    }
    
    var isMovedCursor = true
    
    enum InputKeyEditType {
        case insert, remove, moveCursor, none
    }
    private(set) var inputType = InputKeyEditType.none
    private var inputKeyTimer = RunTimer(), isInputtingKey = false
    private var captureString = "", captureOrigin: Point?, captureSize: Double?,
                captureOrigins = [Point](),
                isFirstInputKey = false
    
    func begin(atScreen sp: Point) {
        guard document.isEditingSheet else { return }
        let p = document.convertScreenToWorld(sp)
        
        document.textCursorNode.isHidden = true
        
        guard let sheetView = document.madeSheetView(at: p) else { return }
        let inP = sheetView.convertFromWorld(p)
        if !isMovedCursor, let eTextView = editingTextView,
           sheetView.textsView.elementViews.contains(eTextView) {
            
        } else if let (textView, _, _, sri) = sheetView.textTuple(at: inP) {
            if isMovedCursor {
                if textView.editor == nil {
                    textView.editor = self
                }
                textView.selectedRange = sri..<sri
                textView.updateCursor()
                textView.updateSelectedLineLocation()
            }
            self.editingSheetView = sheetView
            self.editingTextView = textView
            Cursor.isHidden = true
            isMovedCursor = false
        }
    }
    
    func send(_ event: InputTextEvent) {
        switch event.phase {
        case .began:
            beginInputKey(event)
        case .changed:
            beginInputKey(event)
        case .ended:
            sendEnd()
        }
    }
    func sendEnd() {
        if document.oldInputTextKeys.isEmpty && !Cursor.isHidden {
            document.cursor = Document.defaultCursor
        }
    }
    func stopInputKey(isEndEdit: Bool = true) {
        sendEnd()
        cancelInputKey(isEndEdit: isEndEdit)
        endInputKey(isUnmarkText: true, isRemoveText: true)
    }
    func beginInputKey(_ event: InputTextEvent) {
        guard document.isEditingSheet else {
            document.stop(with: event)
            return
        }
        
        if !document.finding.isEmpty,
           document.editingFindingSheetView == nil {
            let sp = event.screenPoint
            let p = document.convertScreenToWorld(sp)
            guard let sheetView = document.madeSheetView(at: p) else { return }
            let shp = document.sheetPosition(from: sheetView)
            let inP = sheetView.convertFromWorld(p)
            if let (textView, _, _, _) = sheetView.textTuple(at: inP) {
                loop: for (nshp, node) in document.findingNodes {
                    guard nshp == shp else { continue }
                    for child in node.children {
                        if child.contains(p) {
                            document.isEditingFinding = true
                            if let b = child.transformedBounds,
                               let range = textView.range(from: Selection(rect: b, rectCorner: .maxXMaxY)) {
                                document.editingFindingSheetView = sheetView
                                document.editingFindingTextView = textView
                                document.editingFindingRange
                                    = textView.model.string.intRange(from: range)
                                var str = textView.model.string
                                str.removeSubrange(range)
                                document.editingFindingOldString = str
                            }
                            break loop
                        }
                    }
                }
            }
        }
        
//        print(isMovedCursor, editingSheetView, editingTextView, editingTextView?.selectedRange)
        document.textCursorNode.isHidden = true
        
        if !isMovedCursor,
           let eSheetView = editingSheetView,
           let eTextView = editingTextView,
           eSheetView.textsView.elementViews.contains(eTextView) {
            
            inputKey(with: event, in: eTextView, in: eSheetView)
        } else {
            let sp = event.screenPoint
            let p = document.convertScreenToWorld(sp)
            guard let sheetView = document.madeSheetView(at: p) else { return }
            let inP = sheetView.convertFromWorld(p)
            if let (textView, _, _, sri) = sheetView.textTuple(at: inP) {
                if isMovedCursor {
                    if textView.editor == nil {
                        textView.editor = self
                    }
                    textView.selectedRange = sri..<sri
                    textView.updateCursor()
                    textView.updateSelectedLineLocation()
                }
                self.editingSheetView = sheetView
                self.editingTextView = textView
                Cursor.isHidden = true
                inputKey(with: event, in: textView, in: sheetView)
                isMovedCursor = false
            } else if event.inputKeyType.isInputText {
                appendEmptyText(event, at: inP, in: sheetView)
            }
        }
    }
    func appendEmptyText(_ event: InputTextEvent, at inP: Point,
                         orientation: Orientation = .horizontal,
                         in sheetView: SheetView) {
        let text = Text(string: "", orientation: orientation,
                        size: document.sheetTextSize, origin: inP)
        sheetView.newUndoGroup()
        sheetView.append(text)
        
        self.isFirstInputKey = true
        
        let editingTextView = sheetView.textsView.elementViews.last!
        let si = editingTextView.model.string.startIndex
        editingTextView.selectedRange = si..<si
        editingTextView.updateCursor()
        
        self.editingSheetView = sheetView
        self.editingTextView = editingTextView
        
        Cursor.isHidden = true
        
        inputKey(with: event, in: editingTextView, in: sheetView,
                 isNewUndoGroup: false)
        
        isMovedCursor = false
    }
    func appendEmptyText(screenPoint: Point, at inP: Point,
                         orientation: Orientation = .horizontal,
                         in sheetView: SheetView) {
        let text = Text(string: "", orientation: orientation,
                        size: document.sheetTextSize, origin: inP)
        sheetView.newUndoGroup()
        sheetView.append(text)
        
        self.isFirstInputKey = true
        
        let editingTextView = sheetView.textsView.elementViews.last!
        let si = editingTextView.model.string.startIndex
        editingTextView.selectedRange = si..<si
        editingTextView.updateCursor()
        
        self.editingSheetView = sheetView
        self.editingTextView = editingTextView
        
        Cursor.isHidden = true
        
        isMovedCursor = false
    }
    
    func cancelInputKey(isEndEdit: Bool = true) {
        if let editingTextView = editingTextView {
            inputKeyTimer.cancel()
            editingTextView.unmark()
            let oldEditingSheetView = editingSheetView
            if isEndEdit {
                editingTextView.isHiddenSelectedRange = true
                editingSheetView = nil
                self.editingTextView = nil
                Cursor.isHidden = false
            }
            
            document.updateSelects()
            if let oldEditingSheetView = oldEditingSheetView {
                document.updateFinding(from: oldEditingSheetView)
            }
        }
    }
    func endInputKey(isUnmarkText: Bool = false, isRemoveText: Bool = false) {
        if let editingTextView = editingTextView,
           inputKeyTimer.isWait || editingTextView.isMarked {
            
            if isUnmarkText {
                editingTextView.unmark()
            }
            inputKeyTimer.cancel()
            if isRemoveText, let sheetView = editingSheetView {
                removeText(in: editingTextView, in: sheetView)
            }
            
            document.updateSelects()
            if let editingSheetView = editingSheetView {
                document.updateFinding(from: editingSheetView)
            }
        }
    }
    func inputKey(with event: InputTextEvent,
                  in textView: SheetTextView,
                  in sheetView: SheetView,
                  isNewUndoGroup: Bool = true) {
        inputKey(with: { event.send() }, in: textView, in: sheetView,
                 isNewUndoGroup: isNewUndoGroup)
    }
    var isCapturing = false
    func inputKey(with handler: () -> (),
                  in textView: SheetTextView,
                  in sheetView: SheetView,
                  isNewUndoGroup: Bool = true,
                  isUpdateCursor: Bool = true) {
        guard !isCapturing else {
            handler()
            return
        }
        isCapturing = true
        if !inputKeyTimer.isWait {
            self.captureString = textView.model.string
            self.captureOrigin = textView.model.origin
            self.captureSize = textView.model.size
            self.captureOrigins = sheetView.textsView.elementViews
                .map { $0.model.origin }
        }
        
        let oldString = textView.model.string
        let oldTypelineOrigins = textView.typesetter.typelines.map { $0.origin }
        let oldI = textView.selectedTypelineIndex
        let oldSpacing = textView.typesetter.typelineSpacing
        let oldBoundsArray = textView.typesetter.typelines.map { $0.frame }
        
        handler()
        
        update(oldString: oldString, oldSpacing: oldSpacing,
               oldTypelineOrigins: oldTypelineOrigins, oldTypelineIndex: oldI,
               oldBoundsArray: oldBoundsArray,
               in: textView, in: sheetView,
               isUpdateCursor: isUpdateCursor)
        
        let beginClosure: () -> () = { [weak self] in
            guard let aSelf = self else { return }
            aSelf.beginInputKey()
        }
        let waitClosure: () -> () = {}
        let cancelClosure: () -> () = { [weak self,
                                         weak textView,
                                         weak sheetView] in
            guard let aSelf = self,
                  let textView = textView,
                  let sheetView = sheetView else { return }
            aSelf.endInputKey(in: textView, in: sheetView,
                              isNewUndoGroup: isNewUndoGroup)
        }
        let endClosure: () -> () = { [weak self,
                                      weak textView,
                                      weak sheetView] in
            guard let aSelf = self,
                  let textView = textView,
                  let sheetView = sheetView else { return }
            aSelf.endInputKey(in: textView, in: sheetView,
                              isNewUndoGroup: isNewUndoGroup)
        }
        inputKeyTimer.run(afterTime: 0.5, dispatchQueue: .main,
                          beginClosure: beginClosure,
                          waitClosure: waitClosure,
                          cancelClosure: cancelClosure,
                          endClosure: endClosure)
        isCapturing = false
    }
    func beginInputKey() {
        if !isInputtingKey {
        } else {
            isInputtingKey = true
        }
    }
    func moveEndInputKey(isStopFromMarkedText: Bool = false) {
        func updateFinding() {
            if !document.finding.isEmpty {
                if let sheetView = editingSheetView,
                   let textView = editingTextView,
                   sheetView == document.editingFindingSheetView
                    && textView == document.editingFindingTextView,
                   let oldString = document.editingFindingOldString,
                   let (_, substring)
                    = oldString.difference(to: textView.model.string),
                   substring != document.finding.string {
                    
                    
//                    textView.model.string = oldString
                    document.replaceFinding(from: substring)
                }
                
                document.isEditingFinding = false
            }
        }
        if let editingTextView = editingTextView,
           let editingSheetView = editingSheetView {
            
            if isStopFromMarkedText ? !editingTextView.isMarked : true {
                inputKeyTimer.cancel()
                editingTextView.unmark()
                editingTextView.isHiddenSelectedRange = true
                updateFinding()
                self.editingSheetView = nil
                self.editingTextView = nil
                removeText(in: editingTextView, in: editingSheetView)
            } else {
                updateFinding()
            }
        } else {
            updateFinding()
        }
        if Cursor.isHidden {
            Cursor.isHidden = false
        }
    }
    func endInputKey(in textView: SheetTextView,
                     in sheetView: SheetView,
                     isNewUndoGroup: Bool = true) {
        isInputtingKey = false
        guard let i = sheetView.textsView.elementViews
                .firstIndex(of: textView) else { return }
        let value = captureString.difference(to: textView.model.string)
        
//        if let str = value?.subString {
//            let dic = O.defaultDictionary(with: Sheet(), ssDic: [:],
//                                cursorP: Point(), printP: Point())
//            dic.keys.forEach { (key) in
//                if key.baseString == str {
//                    print(key.baseString)
//                }
//            }
//            print("SS:", str)
//        }
        
        // Spell Check (Version 2.0)
        
        if isFirstInputKey {
            isFirstInputKey = false
        } else if isNewUndoGroup && value != nil {
            sheetView.newUndoGroup()
        }
        
        if let value = value {
            sheetView.capture(intRange: value.intRange,
                              subString: value.subString,
                              captureString: captureString,
                              captureOrigin: captureOrigin,
                              captureSize: captureSize,
                              at: i, in: textView)
            for (j, aTextView) in sheetView.textsView.elementViews.enumerated() {
                if j < captureOrigins.count && textView != aTextView {
                    let origin = captureOrigins[j]
                    sheetView.capture(captureOrigin: origin,
                                      at: j, in: aTextView)
                }
            }
            captureString = textView.model.string
            document.updateSelects()
            document.updateFinding(from: sheetView)
        }
    }
    func removeText(in textView: SheetTextView,
                    in sheetView: SheetView) {
        guard let i = sheetView.textsView.elementViews
                .firstIndex(of: textView) else { return }
        if textView.model.string.isEmpty {
            sheetView.removeText(at: i)
            if editingTextView != nil {
                editingSheetView = nil
                editingTextView = nil
            }
            document.updateSelects()
            document.updateFinding(from: sheetView)
        }
    }
    
    func cut(from selection: Selection, at p: Point) {
        guard let sheetView = document.madeSheetView(at: p) else { return }
        let inP = sheetView.convertFromWorld(p)
        guard let (textView, ti, _, _) = sheetView.textTuple(at: inP) else { return }
        
        guard let range = textView.range(from: selection) else { return }
        
        let minP = textView.typesetter
            .characterPosition(at: range.lowerBound)
        var removedText = textView.model
        removedText.string = String(removedText.string[range])
        removedText.origin += minP
        let ssValue = SheetValue(texts: [removedText])
        
        let removeRange: Range<String.Index>
        if textView.typesetter.isFirst(at: range.lowerBound) && textView.typesetter.isLast(at: range.upperBound) {
            
            let str = textView.typesetter.string
            if  str.startIndex < range.lowerBound {
                removeRange = str.index(before: range.lowerBound)..<range.upperBound
            } else if range.upperBound < str.endIndex {
                removeRange = range.lowerBound..<str.index(after: range.upperBound)
            } else {
                removeRange = range
            }
        } else {
            removeRange = range
        }
        
        let captureString = textView.model.string
        let captureOrigin = textView.model.origin
        let captureSize = textView.model.size
        editingTextView = textView
        editingSheetView = sheetView
        textView.removeCharacters(in: removeRange)
        textView.unmark()
        let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
        if let textFrame = textView.model.frame,
           !sb.contains(textFrame) {
           
            let nFrame = sb.clipped(textFrame)
            textView.model.origin += nFrame.origin - textFrame.origin
        }
        if let value = captureString.difference(to: textView.model.string) {
            sheetView.newUndoGroup()
            sheetView.capture(intRange: value.intRange,
                              subString: value.subString,
                              captureString: captureString,
                              captureOrigin: captureOrigin,
                              captureSize: captureSize,
                              at: ti, in: textView)
        }
        
        Cursor.isHidden = true
        
        isMovedCursor = false
        
        let t = Transform(translation: -sheetView.convertFromWorld(p))
        let nValue = ssValue * t
        if let s = nValue.string {
            Pasteboard.shared.copiedObjects
                = [.sheetValue(nValue), .string(s)]
        } else {
            Pasteboard.shared.copiedObjects
                = [.sheetValue(nValue)]
        }
    }
    
    func update(oldString: String, oldSpacing: Double,
                oldTypelineOrigins: [Point], oldTypelineIndex: Int?,
                oldBoundsArray: [Rect],
                in textView: SheetTextView,
                in sheetView: SheetView,
                isUpdateCursor: Bool = true) {
        guard let p = textView.cursorPositon else { return }
        guard textView.model.string != oldString else {
            if isUpdateCursor {
                let osp = textView.convertToWorld(p)
                let sp = document.convertWorldToScreen(osp)
                if sp != document.cursorPoint {
                    textView.node.moveCursor(to: sp)
                    document.isUpdateWithCursorPosition = false
                    document.cursorPoint = sp
                    document.isUpdateWithCursorPosition = true
                }
            }
            return
        }
        let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
        if let textFrame = textView.model.frame,
           !sb.contains(textFrame) {
           
            let nFrame = sb.clipped(textFrame)
            let oldTP = textView.model.origin
            textView.model.origin += nFrame.origin - textFrame.origin
            let nTP = textView.model.origin
            if oldTP != nTP
                && !oldString.isEmpty && nTP.distance(oldTP) < 50 {
                document.camera.position += nTP - oldTP
            }
        }
        
        if oldSpacing != textView.typesetter.typelineSpacing,
           let oldI = oldTypelineIndex {
            
            let ti: Int?
            if let newI = textView.selectedTypelineIndex,
               newI < oldTypelineOrigins.count {
                if oldI <= newI {
                    ti = oldI < textView.typesetter.typelines.count ? oldI : nil
                } else {
                    ti = newI
                }
            } else {
                ti = oldI < textView.typesetter.typelines.count ? oldI : nil
            }
            if let ti = ti {
                let oldP = oldTypelineOrigins[ti]
                let np = textView.typesetter.typelines[ti].origin
                switch textView.textOrientation {
                case .horizontal:
                    if oldP.y != np.y && abs(np.y - oldP.y) < 50 {
                        document.camera.position.y += np.y - oldP.y
                    }
                case .vertical:
                    if oldP.x != np.x && abs(np.x - oldP.x) < 50 {
                        document.camera.position.x += np.x - oldP.x
                    }
                }
            }
        }
        
        if let textFrame = textView.model.frame,
           !textFrame.isEmpty,
           !sb.contains(textFrame) {
            let wp = textView.convertToWorld(p)
            let osp = textView.convertToWorld(p)
            let sp = document.convertWorldToScreen(osp)

            let tp0 = textView.cursorPositon
            
            let nFrame = sb.clipped(textFrame)
            var ndp = nFrame.origin - textFrame.origin
            textView.model.origin += ndp
            if let nTextFrame = textView.model.frame, !sb.outset(by: 1).contains(nTextFrame) {
                let scale = min(sb.width / nTextFrame.width,
                                sb.height / nTextFrame.height)
                let dp = sb.clipped(nTextFrame).origin - nTextFrame.origin
                textView.model.size = (textView.model.size * scale)
                    .clipped(min: 0, max: Font.maxSize)
                textView.model.origin += dp
                ndp += dp
                document.camera.scale *= scale
            }
            
            let mp: Point
            if let tp0 = tp0, let tp1 = textView.cursorPositon {
                mp = tp1 - tp0
            } else {
                mp = Point()
            }
            let np = wp - document.convertScreenToWorld(sp)
            document.camera.position += np + mp + ndp
        }
        
        let clippedCamera = Document.clippedCamera(from: document.camera)
        if document.camera != clippedCamera {
            document.camera = clippedCamera
        }
        
        let newBoundsArray = textView.typesetter.typelines.map { $0.frame }
        if textView.model.string.count > oldString.count,
           newBoundsArray != oldBoundsArray,
           var b = textView.typesetter.spacingTypoBounds,
           let ti = sheetView.textsView.elementViews.firstIndex(of: textView) {
            
            let forigin = textView.model.origin
            var tbs = textView.typesetter.typelines.map {
                $0.frame.outset(by: $0.spacing / 2) + forigin
            }
            var movedIndexes
                = (0..<sheetView.textsView.elementViews.count).filter { $0 != ti }
            
            while !movedIndexes.isEmpty {
                var nmis = [Int](), nbs = [Rect](), isMoved = false
                for k in movedIndexes {
                    let textView1 = sheetView.textsView.elementViews[k]
                    guard let nb = textView1.typesetter.spacingTypoBounds,
                          nb.intersects(b) else { continue }
                    let origin1 = textView1.model.origin
                    var dp = Point(), isUp, isRight: Bool?
                    for t0b in tbs {
                        for t1 in textView1.typesetter.typelines {
                            let t1b = t1.frame.outset(by: t1.spacing / 2)
                                + origin1 + dp
                            let nb = t0b.moveOut(t1b,
                                                 textView1.model.orientation)
                            var ndp = nb.origin - t1b.origin
                            if !ndp.isEmpty {
                                if let isUp = isUp {
                                    if (isUp && ndp.y < 0)
                                        || (!isUp && ndp.y > 0) {
                                        ndp.y = -ndp.y
                                    }
                                } else {
                                    isUp = ndp.y > 0
                                }
                                if let isRight = isRight {
                                    if (isRight && ndp.x < 0)
                                        || (!isRight && ndp.x > 0) {
                                        ndp.x = -ndp.x
                                    }
                                } else {
                                    isRight = ndp.x > 0
                                }
                                dp += ndp
                            }
                        }
                    }
                    let newOrigin = origin1 + dp
                    if newOrigin != origin1 {
                        textView1.model.origin = newOrigin
                        
                        let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
                        if let textFrame = textView1.model.frame,
                           !sb.contains(textFrame) {
                            let nFrame = sb.clipped(textFrame)
                            textView1.model.origin += nFrame.origin - textFrame.origin
                        }
                        
                        let origin1 = textView1.model.origin
                        nbs += textView1.typesetter.typelines.map {
                            $0.frame.outset(by: $0.spacing / 2) + origin1
                        }
                        isMoved = true
                    } else {
                        nmis.append(k)
                    }
                }
                if !isMoved { break }
                movedIndexes = nmis
                tbs += nbs
                if let nb = nbs.union() {
                    b += nb
                }
            }
        }
        
        if isUpdateCursor {
            let osp = textView.convertToWorld(p)
            let sp = document.convertWorldToScreen(osp)
            textView.node.moveCursor(to: sp)
            document.isUpdateWithCursorPosition = false
            document.cursorPoint = sp
            document.isUpdateWithCursorPosition = true
        }
    }
    
    func characterIndex(for point: Point) -> String.Index? {
        guard let textView = editingTextView else { return nil }
        let sp = document.convertScreenToWorld(point)
        let p = textView.convertFromWorld(sp)
        return textView.characterIndex(for: p)
    }
    func characterRatio(for point: Point) -> Double? {
        guard let textView = editingTextView else { return nil }
        let sp = document.convertScreenToWorld(point)
        let p = textView.convertFromWorld(sp)
        return textView.characterRatio(for: p)
    }
    func characterPosition(at i: String.Index) -> Point? {
        guard let textView = editingTextView else { return nil }
        let p = textView.characterPosition(at: i)
        let sp = textView.convertToWorld(p)
        return document.convertWorldToScreen(sp)
    }
    func characterBasePosition(at i: String.Index) -> Point? {
        guard let textView = editingTextView else { return nil }
        let p = textView.characterBasePosition(at: i)
        let sp = textView.convertToWorld(p)
        return document.convertWorldToScreen(sp)
    }
    func characterBounds(at i: String.Index) -> Rect? {
        guard let textView = editingTextView,
              let rect = textView.characterBounds(at: i) else { return nil }
        let sRect = textView.convertToWorld(rect)
        return document.convertWorldToScreen(sRect)
    }
    func baselineDelta(at i: String.Index) -> Double? {
        guard let textView = editingTextView else { return nil }
        return textView.baselineDelta(at: i)
    }
    func firstRect(for range: Range<String.Index>) -> Rect? {
        guard let textView = editingTextView,
              let rect = textView.firstRect(for: range) else { return nil }
        let sRect = textView.convertToWorld(rect)
        return document.convertWorldToScreen(sRect)
    }
    
    func unmark() {
        editingTextView?.unmark()
    }
    func mark(_ string: String,
              markingRange: Range<String.Index>,
              at replacedRange: Range<String.Index>? = nil) {
        if let textView = editingTextView,
           let sheetView = editingSheetView {
           
            inputKey(with: { textView.mark(string,
                                           markingRange: markingRange,
                                           at: replacedRange) },
                     in: textView, in: sheetView,
                     isUpdateCursor: false)
        }
    }
    func insert(_ string: String,
                at replacedRange: Range<String.Index>? = nil) {
        if inputType != .insert {
            endInputKey()
            inputType = .insert
        }
        editingTextView?.insert(string, at: replacedRange)
    }
    func insertNewline() {
        if inputType != .insert {
            endInputKey()
            inputType = .insert
        }
        editingTextView?.insertNewline()
    }
    func insertTab() {
        if inputType != .insert {
            endInputKey()
            inputType = .insert
        }
        editingTextView?.insertTab()
    }
    func deleteBackward() {
        if inputType != .remove {
            endInputKey()
            inputType = .remove
        }
        editingTextView?.deleteBackward()
    }
    func deleteForward() {
        if inputType != .remove {
            endInputKey()
            inputType = .remove
        }
        editingTextView?.deleteForward()
    }
    func moveLeft() {
        if inputType != .moveCursor {
            endInputKey()
            inputType = .moveCursor
        }
        editingTextView?.moveLeft()
    }
    func moveRight() {
        if inputType != .moveCursor {
            endInputKey()
            inputType = .moveCursor
        }
        editingTextView?.moveRight()
    }
    func moveUp() {
        if inputType != .moveCursor {
            endInputKey()
            inputType = .moveCursor
        }
        editingTextView?.moveUp()
    }
    func moveDown() {
        if inputType != .moveCursor {
            endInputKey()
            inputType = .moveCursor
        }
        editingTextView?.moveDown()
    }
}

final class TextView<T: BinderProtocol>: View {
    typealias Model = Text
    typealias Binder = T
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    
    weak var editor: TextEditor?
    private(set) var typesetter: Typesetter
    
    var markedRange: Range<String.Index>?
    var replacedRange: Range<String.Index>?
    var selectedRange: Range<String.Index>?
    var selectedLineLocation = 0.0
    
    var intSelectedLowerBound: Int? {
        if let i = selectedRange?.lowerBound {
            return model.string.intIndex(from: i)
        } else {
            return nil
        }
    }
    var intSelectedUpperBound: Int? {
        if let i = selectedRange?.upperBound {
            return model.string.intIndex(from: i)
        } else {
            return nil
        }
    }
    var selectedTypelineIndex: Int? {
        if let i = selectedRange?.lowerBound,
           let ti = typesetter.typelineIndex(at: i) {
            return ti
        } else {
            return typesetter.typelines.isEmpty ? nil :
                typesetter.typelines.count - 1
        }
    }
    var selectedTypeline: Typeline? {
        if let i = selectedRange?.lowerBound,
           let ti = typesetter.typelineIndex(at: i) {
            return typesetter.typelines[ti]
        } else {
            return typesetter.typelines.last
        }
    }
    
    let markedRangeNode = Node(lineWidth: 1, lineType: .color(.content))
    let replacedRangeNode = Node(lineWidth: 2, lineType: .color(.content))
    let cursorNode = Node(isHidden: true,
                          lineWidth: 0.5, lineType: .color(.background),
                          fillType: .color(.content))
    let borderNode = Node(isHidden: true,
                          lineWidth: 0.5, lineType: .color(.border))
    var isHiddenSelectedRange = true {
        didSet {
            cursorNode.isHidden = isHiddenSelectedRange
//            borderNode.isHidden = isHiddenSelectedRange
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        typesetter = binder[keyPath: keyPath].typesetter
        
        node = Node(children: [markedRangeNode, replacedRangeNode,
                               cursorNode, borderNode],
                    attitude: Attitude(position: binder[keyPath: keyPath].origin),
                    fillType: .color(.content))
        updateLineWidth()
        updatePath()
        
        updateCursor()
    }
}
extension TextView {
    func updateWithModel() {
        node.attitude.position = model.origin
        updateLineWidth()
        updateTypesetter()
    }
    func updateLineWidth() {
        let ratio = model.size / Font.defaultSize
        cursorNode.lineWidth = 0.5 * ratio
        borderNode.lineWidth = cursorNode.lineWidth
        markedRangeNode.lineWidth = Line.defaultLineWidth * ratio
        replacedRangeNode.lineWidth = Line.defaultLineWidth * 1.5 * ratio
    }
    func updateTypesetter() {
        typesetter = model.typesetter
        updatePath()
        
        updateMarkedRange()
        updateCursor()
    }
    func updatePath() {
        node.path = typesetter.path()
        borderNode.path = typesetter.maxTypelineWidthPath
    }
    
    private func updateMarkedRange() {
        if let markedRange = markedRange {
            var mPathlines = [Pathline]()
            let delta = markedRangeNode.lineWidth
            for edge in typesetter.underlineEdges(for: markedRange,
                                                  delta: delta) {
                mPathlines.append(Pathline(edge))
            }
            markedRangeNode.path = Path(mPathlines)
        } else {
            markedRangeNode.path = Path()
        }
        if let replacedRange = replacedRange {
            var rPathlines = [Pathline]()
            let delta = markedRangeNode.lineWidth
            for edge in typesetter.underlineEdges(for: replacedRange,
                                                  delta: delta) {
                rPathlines.append(Pathline(edge))
            }
            replacedRangeNode.path = Path(rPathlines)
        } else {
            replacedRangeNode.path = Path()
        }
    }
    fileprivate func updateCursor() {
        if let selectedRange = selectedRange {
            cursorNode.path = typesetter.cursorPath(at: selectedRange.lowerBound)
        } else {
            cursorNode.path = Path()
        }
    }
    fileprivate func updateSelectedLineLocation() {
        if let range = selectedRange {
            if let li = typesetter.typelineIndex(at: range.lowerBound) {
             selectedLineLocation = typesetter.typelines[li]
                 .characterOffset(at: range.lowerBound)
            } else {
             if let typeline = typesetter.typelines.last,
                range.lowerBound == typeline.range.upperBound {
                 if !typeline.isLastReturnEnd {
                    selectedLineLocation = typeline.width
                 } else {
                     selectedLineLocation = 0
                 }
             } else {
                selectedLineLocation = 0
             }
            }
        } else {
            selectedLineLocation = 0
        }
    }
    
    var bounds: Rect? {
        typesetter.spacingTypoBounds
    }
    var transformedBounds: Rect? {
        if let bounds = bounds {
            return bounds * node.localTransform
        } else {
            return nil
        }
    }
    func typoBounds(with textValue: TextValue) -> Rect? {
        let sRange = model.string.range(fromInt: textValue.newRange)
        return typesetter.typoBounds(for: sRange)
    }
    func transformedTypoBounds(with range: Range<String.Index>) -> Rect? {
        let b = typesetter.typoBounds(for: range)
        if let b = b {
            return b * node.localTransform
        } else {
            return nil
        }
    }
    func transformedRects(with range: Range<String.Index>) -> [Rect] {
        typesetter.rects(for: range).map { $0 * node.localTransform }
    }
    func transformedPaddingRects(with range: Range<String.Index>) -> [Rect] {
        typesetter.paddingRects(for: range).map { $0 * node.localTransform }
    }
    
    var cursorPositon: Point? {
        guard let selectedRange = selectedRange else { return nil }
        return typesetter.characterPosition(at: selectedRange.lowerBound)
    }

    var isMarked: Bool {
        markedRange != nil
    }
    
    func characterIndexWithOutOfBounds(for p: Point) -> String.Index? {
        typesetter.characterIndexWithOutOfBounds(for: p)
    }
    func characterIndex(for p: Point) -> String.Index? {
        typesetter.characterIndex(for: p)
    }
    func characterRatio(for p: Point) -> Double? {
        typesetter.characterRatio(for: p)
    }
    func characterPosition(at i: String.Index) -> Point {
        typesetter.characterPosition(at: i)
    }
    func characterBasePosition(at i: String.Index) -> Point {
        typesetter.characterBasePosition(at: i)
    }
    func characterBounds(at i: String.Index) -> Rect? {
        typesetter.characterBounds(at: i)
    }
    func baselineDelta(at i: String.Index) -> Double {
        typesetter.baselineDelta(at: i)
    }
    func firstRect(for range: Range<String.Index>) -> Rect? {
        typesetter.firstRect(for: range)
    }
    
    var textOrientation: Orientation {
        model.orientation
    }
    
    func wordRange(at i: String.Index) -> Range<String.Index>? {
        let string = model.string
        var range: Range<String.Index>?
        string.enumerateSubstrings(in: string.startIndex..<string.endIndex,
                                   options: .byWords) { (str, sRange, eRange, isStop) in
            if sRange.contains(i) {
                range = sRange
                isStop = true
            }
        }
        if i == string.endIndex {
            return nil
        }
        if let range = range, string[range] == "\n" {
            return nil
        }
        return range ?? i..<string.index(after: i)
    }
    
    func intersects(_ rect: Rect) -> Bool {
        typesetter.intersects(rect)
    }
    func intersectsHalf(_ rect: Rect) -> Bool {
        typesetter.intersectsHalf(rect)
    }
    
    func ranges(at selection: Selection) -> [Range<String.Index>] {
        guard let fi = characterIndexWithOutOfBounds(for: selection.firstOrigin),
              let li = characterIndexWithOutOfBounds(for: selection.lastOrigin) else { return [] }
        return [fi < li ? fi..<li : li..<fi]
    }
    
    var copyPadding: Double {
        1 * model.size / Font.defaultSize
    }
    
    var lassoPadding: Double {
        -2 * typesetter.typobute.font.size / Font.defaultSize
    }
    func lassoRanges(at nPath: Path) -> [Range<String.Index>] {
        var ranges = [Range<String.Index>](), oldI: String.Index?
        for i in model.string.indices {
            guard let otb = typesetter.characterBounds(at: i) else { continue }
            let tb = otb.outset(by: lassoPadding) + model.origin
            if nPath.intersects(tb) {
                if oldI == nil {
                    oldI = i
                }
            } else {
                if let oldI = oldI {
                    ranges.append(oldI..<i)
                }
                oldI = nil
            }
        }
        if let oldI = oldI {
            ranges.append(oldI..<model.string.endIndex)
        }
        return ranges
    }
    
    func set(_ textValue: TextValue) {
        unmark()
        
        let oldRange = model.string.range(fromInt: textValue.replacedRange)
        binder[keyPath: keyPath].string
            .replaceSubrange(oldRange, with: textValue.string)
        let nri = model.string.range(fromInt: textValue.newRange).upperBound
        selectedRange = nri..<nri
        
        if let origin = textValue.origin {
            binder[keyPath: keyPath].origin = origin
            node.attitude.position = origin
        }
        if let size = textValue.size {
            binder[keyPath: keyPath].size = size
        }
        
        updateTypesetter()
        updateSelectedLineLocation()
    }
    
    func insertNewline() {
        guard let rRange = isMarked ?
                markedRange : selectedRange else { return }
        
        let string = model.string
        var str = "\n"
        loop: for (li, typeline) in typesetter.typelines.enumerated() {
            guard (typeline.range.contains(rRange.lowerBound)
                    || (li == typesetter.typelines.count - 1
                            && !typeline.isLastReturnEnd
                            && rRange.lowerBound == typeline.range.upperBound))
                    && !typeline.range.isEmpty else { continue }
            var i = typeline.range.lowerBound
            while i < typeline.range.upperBound {
                let c = string[i]
                if c != "\t" {
                    if rRange.lowerBound > typeline.range.lowerBound {
                        let i1 = string.index(before: rRange.lowerBound)
                        let c1 = string[i1]
                        if c1 == ":" {
                            str.append("\t")
                        } else {
                            if i1 > typeline.range.lowerBound {
                                let i2 = string.index(before: i1)
                                let c2 = string[i2]
                                
                                if i2 > typeline.range.lowerBound {
                                    let i3 = string.index(before: i2)
                                    if string[i3].isWhitespace
                                        && c2 == "-" && (c1 == ">" || c1 == "!") {
                                    
                                        str.append("\t")
                                    }
                                }
                            }
                        }
                    }
                    break loop
                } else {
                    if i < rRange.lowerBound {
                        str.append(c)
                    }
                }
                i = string.index(after: i)
            }
            break
        }
        insert(str)
    }
    func insertTab() {
        insert("\t")
    }
    
    func deleteBackward(from range: Range<String.Index>? = nil) {
        if let range = range {
            removeCharacters(in: range)
            return
        }
        guard let deleteRange = selectedRange else { return }
        
        if let document = editor?.document,
           !document.selectedFrames.isEmpty,
           let selection = document.selections.first {
            if delete(from: selection) {
                document.selections = []
                return
            }
        }
        
        if deleteRange.isEmpty {
            let string = model.string
            guard deleteRange.lowerBound > string.startIndex else { return }
            let nsi = typesetter.index(before: deleteRange.lowerBound)
            let nRange = nsi..<deleteRange.lowerBound
            let nnRange = string.rangeOfComposedCharacterSequences(for: nRange)
            removeCharacters(in: nnRange)
        } else {
            removeCharacters(in: deleteRange)
        }
    }
    func deleteForward(from range: Range<String.Index>? = nil) {
        if let range = range {
            removeCharacters(in: range)
            return
        }
        guard let deleteRange = selectedRange else { return }
        
        if let document = editor?.document,
           !document.selectedFrames.isEmpty,
           let selection = document.selections.first {
            if delete(from: selection) {
                document.selections = []
                return
            }
        }
        
        if deleteRange.isEmpty {
            let string = model.string
            guard deleteRange.lowerBound < string.endIndex else { return }
            let nei = typesetter.index(after: deleteRange.lowerBound)
            let nRange = deleteRange.lowerBound..<nei
            let nnRange = string.rangeOfComposedCharacterSequences(for: nRange)
            removeCharacters(in: nnRange)
        } else {
            removeCharacters(in: deleteRange)
        }
    }
    func range(from selection: Selection) -> Range<String.Index>? {
        let nRect = convertFromWorld(selection.rect)
        let tfp = convertFromWorld(selection.firstOrigin)
        let tlp = convertFromWorld(selection.lastOrigin)
        if intersects(nRect),
           let fi = characterIndexWithOutOfBounds(for: tfp),
           let li = characterIndexWithOutOfBounds(for: tlp) {
            
            return fi < li ? fi..<li : li..<fi
        } else {
            return nil
        }
    }
    @discardableResult func delete(from selection: Selection) -> Bool {
        guard let deleteRange = selectedRange else { return false }
        if let nRange = range(from: selection) {
            if nRange.contains(deleteRange.lowerBound)
                || nRange.lowerBound == deleteRange.lowerBound
                || nRange.upperBound == deleteRange.lowerBound {
                removeCharacters(in: nRange)
                return true
            }
        }
        return false
    }
    
    func moveLeft() {
        guard let range = selectedRange else { return }
        if !range.isEmpty {
            selectedRange = range.lowerBound..<range.lowerBound
        } else {
            let string = model.string
            guard range.lowerBound > string.startIndex else { return }
            let ni = typesetter.index(before: range.lowerBound)
            selectedRange = ni..<ni
        }
        updateCursor()
        updateSelectedLineLocation()
    }
    func moveRight() {
        guard let range = selectedRange else { return }
        if !range.isEmpty {
            selectedRange = range.upperBound..<range.upperBound
        } else {
            let string = model.string
            guard range.lowerBound < string.endIndex else { return }
            let ni = typesetter.index(after: range.lowerBound)
            selectedRange = ni..<ni
        }
        updateCursor()
        updateSelectedLineLocation()
    }
    func moveUp() {
        guard let range = selectedRange else { return }
        guard let tli = typesetter
                .typelineIndex(at: range.lowerBound) else {
            if var typeline = typesetter.typelines.last,
               range.lowerBound == typeline.range.upperBound {
                let string = model.string
                let d = selectedLineLocation
                if !typeline.isLastReturnEnd {
                    let tli = typesetter.typelines.count - 1
                    if tli == 0 && d == typesetter.typelines[tli].width {
                        let si = model.string.startIndex
                        selectedRange = si..<si
                        updateCursor()
                        return
                    }
                    let i = d < typesetter.typelines[tli].width ?
                        tli : tli - 1
                    typeline = typesetter.typelines[i]
                }
                let ni = typeline.characterIndex(forOffset: d, padding: 0)
                    ?? string.index(before: typeline.range.upperBound)
                selectedRange = ni..<ni
                updateCursor()
            }
            return
        }
        if !range.isEmpty {
            selectedRange = range.lowerBound..<range.lowerBound
        } else {
            let string = model.string
            let d = selectedLineLocation
            let isFirst = tli == 0
            let isSelectedLast = range.lowerBound == string.endIndex
                && d < typesetter.typelines[tli].width
            if !isSelectedLast, isFirst {
                let si = model.string.startIndex
                selectedRange = si..<si
            } else {
                let i = isSelectedLast || isFirst ? tli : tli - 1
                let typeline = typesetter.typelines[i]
                let ni = typeline.characterMainIndex(forOffset: d, padding: 0,
                                                     from: typesetter)
                    ?? string.index(before: typeline.range.upperBound)
                selectedRange = ni..<ni
            }
        }
        updateCursor()
    }
    func moveDown() {
        guard let range = selectedRange else { return }
        guard let li = typesetter
                .typelineIndex(at: range.lowerBound) else { return }
        if !range.isEmpty {
            selectedRange = range.upperBound..<range.upperBound
        } else {
            let string = model.string
            let isSelectedFirst = range.lowerBound == string.startIndex
                && selectedLineLocation > 0
            let isLast = li == typesetter.typelines.count - 1
            if !isSelectedFirst, isLast {
               let ni = string.endIndex
               selectedRange = ni..<ni
            } else {
                let i = isSelectedFirst || isLast ? li : li + 1
                let typeline = typesetter.typelines[i]
                let d = selectedLineLocation
                if let ni = typeline.characterMainIndex(forOffset: d, padding: 0,
                                                        from: typesetter) {
                    selectedRange = ni..<ni
                } else {
                    let ni = i == typesetter.typelines.count - 1
                        && !typeline.isLastReturnEnd
                        ?
                        typeline.range.upperBound :
                        string.index(before: typeline.range.upperBound)
                    selectedRange = ni..<ni
                }
            }
        }
        updateCursor()
    }
    
    func removeCharacters(in range: Range<String.Index>) {
        isHiddenSelectedRange = false
        
        if let markedRange = markedRange {
            let nRange: Range<String.Index>
            let string = model.string
            let d = string.count(from: range)
            if markedRange.contains(range.upperBound) {
                let nei = string.index(markedRange.upperBound, offsetBy: -d)
                nRange = range.lowerBound..<nei
            } else {
                nRange = string.range(markedRange, offsetBy: -d)
            }
            if nRange.isEmpty {
                unmark()
            } else {
                self.markedRange = nRange
            }
        }
        
        let iMarkedRange: Range<Int>? = markedRange != nil ?
            model.string.intRange(from: markedRange!) : nil
        let iReplacedRange: Range<Int>? = replacedRange != nil ?
            model.string.intRange(from: replacedRange!) : nil
        let i = model.string.intIndex(from: range.lowerBound)
        binder[keyPath: keyPath].string.removeSubrange(range)
        let ni = model.string.index(fromInt: i)
        if let iMarkedRange = iMarkedRange {
            markedRange = model.string.range(fromInt: iMarkedRange)
        }
        if let iReplacedRange = iReplacedRange {
            replacedRange = model.string.range(fromInt: iReplacedRange)
        }
        selectedRange = ni..<ni
        
        TextInputContext.update()
        updateTypesetter()
        updateSelectedLineLocation()
    }
    
    func unmark() {
        if isMarked {
            markedRange = nil
            replacedRange = nil
            TextInputContext.unmark()
            updateMarkedRange()
        }
    }
    func mark(_ str: String,
              markingRange: Range<String.Index>,
              at range: Range<String.Index>? = nil) {
        isHiddenSelectedRange = false
        
        let rRange: Range<String.Index>
        if let range = range {
            rRange = range
        } else if let markedRange = markedRange {
            rRange = markedRange
        } else if let selectedRange = selectedRange {
            rRange = selectedRange
        } else {
            return
        }
        
        if str.isEmpty {
            let i = model.string.intIndex(from: rRange.lowerBound)
            binder[keyPath: keyPath].string.removeSubrange(rRange)
            let ni = model.string.index(fromInt: i)
            markedRange = nil
            replacedRange = nil
            selectedRange = ni..<ni
        } else {
            let i = model.string.intIndex(from: rRange.lowerBound)
            let iMarkingRange = str.intRange(from: markingRange)
            binder[keyPath: keyPath].string.replaceSubrange(rRange, with: str)
            let ni = model.string.index(fromInt: i)
            let di = model.string.index(ni, offsetBy: str.count)
            let imsi = model.string.index(fromInt: iMarkingRange.lowerBound + i)
            let imei = model.string.index(fromInt: iMarkingRange.upperBound + i)
            markedRange = ni..<di
            replacedRange = imsi..<imei
            selectedRange = di..<di
        }
        TextInputContext.update()
        updateTypesetter()
        updateSelectedLineLocation()
    }
    func insert(_ str: String,
                at range: Range<String.Index>? = nil) {
        isHiddenSelectedRange = false
        
        let rRange: Range<String.Index>
        if let range = range {
            rRange = range
        } else if let markedRange = markedRange {
            rRange = markedRange
        } else if let selectedRange = selectedRange {
            rRange = selectedRange
        } else {
            return
        }
        
        unmark()
        TextInputContext.update()
        
        let irRange = model.string.intRange(from: rRange)
        binder[keyPath: keyPath].string.replaceSubrange(rRange, with: str)
        let ei = model.string.index(model.string.startIndex,
                                    offsetBy: irRange.lowerBound + str.count)
        selectedRange = ei..<ei
        
        updateTypesetter()
        updateSelectedLineLocation()
    }
}
