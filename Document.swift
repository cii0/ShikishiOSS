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
import struct Foundation.UUID

typealias Camera = Attitude
typealias SheetPosition = IntPoint
typealias Thumbnail = Image
typealias SheetID = UUID

struct CornerRectValue {
    var rect: Rect
    var rectCorner: RectCorner
}
extension CornerRectValue {
    var firstOrigin: Point {
        switch rectCorner {
        case .minXMinY: return rect.maxXMaxYPoint
        case .minXMaxY: return rect.maxXMinYPoint
        case .maxXMinY: return rect.minXMaxYPoint
        case .maxXMaxY: return rect.minXMinYPoint
        }
    }
    var lastOrigin: Point {
        switch rectCorner {
        case .minXMinY: return rect.minXMinYPoint
        case .minXMaxY: return rect.minXMaxYPoint
        case .maxXMinY: return rect.maxXMinYPoint
        case .maxXMaxY: return rect.maxXMaxYPoint
        }
    }
}
extension CornerRectValue: Protobuf {
    init(_ pb: PBCornerRectValue) throws {
        rect = try Rect(pb.rect)
        rectCorner = try RectCorner(pb.rectCorner)
    }
    var pb: PBCornerRectValue {
        PBCornerRectValue.with {
            $0.rect = rect.pb
            $0.rectCorner = rectCorner.pb
        }
    }
}
extension CornerRectValue: Codable {}

typealias Selection = CornerRectValue
extension Array: Serializable where Element == Selection {}
extension Array: Protobuf where Element == Selection {
    init(_ pb: PBCornerRectValueArray) throws {
        self = try pb.value.map { try Selection($0) }
    }
    var pb: PBCornerRectValueArray {
        PBCornerRectValueArray.with { $0.value = map { $0.pb } }
    }
}
extension Selection: AppliableTransform {
    static func * (lhs: Selection, rhs: Transform) -> Selection {
        return Selection(rect: lhs.rect * rhs, rectCorner: lhs.rectCorner)
    }
}

struct Finding {
    var worldPosition = Point()
    var string = ""
}
extension Finding {
    var isEmpty: Bool { string.isEmpty }
}
extension Finding: Protobuf {
    init(_ pb: PBFinding) throws {
        worldPosition = try Point(pb.worldPosition)
        string = pb.string
    }
    var pb: PBFinding {
        PBFinding.with {
            $0.worldPosition = worldPosition.pb
            $0.string = string
        }
    }
}
extension Finding: Codable {}

private struct Road {
    var shp0: SheetPosition, shp1: SheetPosition
}
extension Road {
    func pathlineWith(width: Double, height: Double) -> Pathline? {
        let hw = width / 2, hh = height / 2
        let dx = shp1.x - shp0.x, dy = shp1.y - shp0.y
        if abs(dx) <= 1 && abs(dy) <= 1 {
            return nil
        }
        if dx == 0 {
            let sy = dy < 0 ? shp1.y : shp0.y
            let ey = dy < 0 ? shp0.y : shp1.y
            let x = Double(shp0.x) * width + hw
            return Pathline([Point(x, Double(sy) * height + 2 * hh),
                             Point(x, Double(ey) * height)])
        } else if dy == 0 {
            let sx = dx < 0 ? shp1.x : shp0.x
            let ex = dx < 0 ? shp0.x : shp1.x
            let y = Double(shp0.y) * height + hh
            return Pathline([Point(Double(sx) * width + hw + hw, y),
                             Point(Double(ex) * width - hw + hw, y)])
        } else {
            var points = [Point]()
            let isReversed = shp0.y > shp1.y
            let sSHP = isReversed ? shp1 : shp0, eSHP = isReversed ? shp0 : shp1
            let sx = sSHP.x, sy = sSHP.y
            let ex = eSHP.x, ey = eSHP.y
            if sx < ex {
                var oldXI = sx
                for nyi in sy...ey {
                    let nxi = Int(Double(ex - sx) * Double(nyi - sy)
                                    / Double(ey - sy) + Double(sx))
                    if nyi == sy {
                        points.append(Point(Double(sx) * width + hw,
                                            Double(sy + 1) * height))
                    } else if nyi == ey {
                        let y = Double(nyi) * height + hh
                        if oldXI < nxi {
                            points.append(Point(Double(oldXI) * width + hw, y))
                        }
                        points.append(Point(Double(nxi) * width, y))
                    } else if nxi != oldXI && nxi < ex {
                        let y = Double(nyi) * height + hh
                        points.append(Point(Double(oldXI) * width + hw, y))
                        points.append(Point(Double(nxi) * width + hw, y))
                        oldXI = nxi
                    }
                }
            } else {
                var oldXI = ex
                for nyi in (sy...ey).reversed() {
                    let nxi = Int(Double(ex - sx) * Double(nyi - sy)
                                    / Double(ey - sy) + Double(sx))
                    if nyi == sy {
                        let y = Double(nyi) * height + hh
                        if oldXI < nxi {
                            points.append(Point(Double(oldXI) * width + hw, y))
                        }
                        points.append(Point(Double(nxi) * width, y))
                    } else if nyi == ey {
                        points.append(Point(Double(ex) * width + hw,
                                            Double(ey) * height))
                    } else if nxi != oldXI && nxi > sx {
                        let y = Double(nyi) * height + hh
                        points.append(Point(Double(oldXI) * width + hw, y))
                        points.append(Point(Double(nxi) * width + hw, y))
                        oldXI = nxi
                    }
                }
            }
            return Pathline(points)
        }
    }
}

enum WorldUndoItem {
    case insertSheets(_ sids: [SheetPosition: SheetID])
    case removeSheets(_ shps: [SheetPosition])
}
extension WorldUndoItem: UndoItem {
    var type: UndoItemType {
        switch self {
        case .insertSheets: return .reversible
        case .removeSheets: return .unreversible
        }
    }
    func reversed() -> WorldUndoItem? {
        switch self {
        case .insertSheets(let shps):
            return .removeSheets(shps.map { $0.key })
        case .removeSheets:
            return nil
        }
    }
}
extension WorldUndoItem: Protobuf {
    init(_ pb: PBWorldUndoItem) throws {
        guard let value = pb.value else {
            throw ProtobufError()
        }
        switch value {
        case .insertSheets(let sids):
            self = .insertSheets(try [IntPoint: SheetID](sids))
        case .removeSheets(let shps):
            self = .removeSheets(try [SheetPosition](shps))
        }
    }
    var pb: PBWorldUndoItem {
        PBWorldUndoItem.with {
            switch self {
            case .insertSheets(let sids):
                $0.value = .insertSheets(sids.pb)
            case .removeSheets(let shps):
                $0.value = .removeSheets(shps.pb)
            }
        }
    }
}
extension WorldUndoItem: Codable {
    private enum CodingTypeKey: String, Codable {
        case insertSheets = "0"
        case removeSheets = "1"
    }
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let key = try container.decode(CodingTypeKey.self)
        switch key {
        case .insertSheets:
            self = .insertSheets(try container.decode([SheetPosition: SheetID].self))
        case .removeSheets:
            self = .removeSheets(try container.decode([SheetPosition].self))
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .insertSheets(let sids):
            try container.encode(CodingTypeKey.insertSheets)
            try container.encode(sids)
        case .removeSheets(let shps):
            try container.encode(CodingTypeKey.removeSheets)
            try container.encode(shps)
        }
    }
}

extension Dictionary where Key == SheetID, Value == SheetPosition {
    init(_ pb: PBIntPointStringDic) throws {
        var shps = [SheetID: SheetPosition]()
        for e in pb.value {
            if let sid = SheetID(uuidString: e.key) {
                shps[sid] = try SheetPosition(e.value)
            }
        }
        self = shps
    }
    var pb: PBIntPointStringDic {
        var pbips = [String: PBIntPoint]()
        for (sid, shp) in self {
            pbips[sid.uuidString] = shp.pb
        }
        return PBIntPointStringDic.with {
            $0.value = pbips
        }
    }
}
extension Dictionary where Key == SheetPosition, Value == SheetID {
    init(_ pb: PBStringIntPointDic) throws {
        var sids = [SheetPosition: SheetID]()
        for e in pb.value {
            sids[try SheetPosition(e.key)] = SheetID(uuidString: e.value)
        }
        self = sids
    }
    var pb: PBStringIntPointDic {
        var pbsipdes = [PBStringIntPointDicElement]()
        for (shp, sid) in self {
            pbsipdes.append(PBStringIntPointDicElement.with {
                $0.key = shp.pb
                $0.value = sid.uuidString
            })
        }
        return PBStringIntPointDic.with {
            $0.value = pbsipdes
        }
    }
}

struct World {
    var sheetIDs = [SheetPosition: SheetID]()
    var sheetPositions = [SheetID: SheetPosition]()
}
extension World: Protobuf {
    init(_ pb: PBWorld) throws {
        let shps = try [SheetID: SheetPosition](pb.sheetPositions)
        self.sheetIDs = World.sheetIDs(with: shps)
        self.sheetPositions = shps
    }
    var pb: PBWorld {
        PBWorld.with {
            $0.sheetPositions = sheetPositions.pb
        }
    }
}
extension World: Codable {}
extension World {
    static func sheetIDs(with shps: [SheetID: SheetPosition]) -> [SheetPosition: SheetID] {
        var sids = [SheetPosition: SheetID]()
        sids.reserveCapacity(shps.count)
        for (sid, shp) in shps {
            sids[shp] = sid
        }
        return sids
    }
    static func sheetPositions(with sids: [SheetPosition: SheetID]) -> [SheetID: SheetPosition] {
        var shps = [SheetID: SheetPosition]()
        shps.reserveCapacity(sids.count)
        for (shp, sid) in sids {
            shps[sid] = shp
        }
        return shps
    }
    init(_ sids: [SheetPosition: SheetID] = [:]) {
        self.sheetIDs = sids
        self.sheetPositions = World.sheetPositions(with: sids)
    }
    init(_ shps: [SheetID: SheetPosition] = [:]) {
        self.sheetIDs = World.sheetIDs(with: shps)
        self.sheetPositions = shps
    }
}

typealias WorldHistory = History<WorldUndoItem>

final class Document {
    let url: URL
    
    let rootNode = Node()
    let sheetsNode = Node()
    let gridNode = Node(lineType: .color(.border))
    let mapNode = Node(lineType: .color(.border))
    let currentMapNode = Node(lineType: .color(.border))
    let accessoryNodeIndex = 1
    
    enum FileType: FileTypeProtocol {
        case sksdoc
        case skshdoc
        case sksdata
        
        var name: String {
            switch self {
            case .sksdoc: return String(format: "%1$@ Document".localized, System.appName)
            case .skshdoc: return String(format: "%1$@ Document with History".localized, System.appName)
            case .sksdata: return System.dataName
            }
        }
        var utType: String {
            switch self {
            case .sksdoc: return "sksdoc"
            case .skshdoc: return "skshdoc"
            case .sksdata: return "sksdata"
            }
        }
    }
    
    init(url: URL) {
        self.url = url
        
        rootDirectory = Directory(url: url)
        
        worldRecord = rootDirectory
            .makeRecord(forKey: Document.worldRecordKey)
        world = worldRecord.decodedValue ?? World()
        
        worldHistoryRecord = rootDirectory
            .makeRecord(forKey: Document.worldHistoryRecordKey)
        history = worldHistoryRecord.decodedValue ?? WorldHistory()
        
        selectionsRecord
            = rootDirectory.makeRecord(forKey: Document.selectionsRecordKey)
        selections = selectionsRecord.decodedValue ?? []
        
        cameraRecord
            = rootDirectory.makeRecord(forKey: Document.cameraRecordKey)
        let camera = cameraRecord.decodedValue ?? Document.defaultCamera
        self.camera = Document.clippedCamera(from: camera)
        
        sheetsDirectory = rootDirectory
            .makeDirectory(forKey: Document.sheetsDirectoryKey)
        sheetRecorders = Document.sheetRecorders(from: sheetsDirectory)
        
        var baseThumbnailDatas = [SheetID: Texture.BytesData]()
        sheetRecorders.forEach {
            guard let data = $0.value.thumbnail4Record.decodedData else { return }
            baseThumbnailDatas[$0.key] = Texture.bytesData(with: data)
        }
        self.baseThumbnailDatas = baseThumbnailDatas
        
        rootNode.children = [sheetsNode, gridNode, mapNode, currentMapNode]
        
        rootDirectory.changedIsWillwriteByChildrenClosure = { [weak self] (_, isWillwrite) in
            if isWillwrite {
                self?.updateAutosavingTimer()
            }
        }
        cameraRecord.willwriteClosure = { [weak self] (record) in
            if let aSelf = self {
                record.value = aSelf.camera
            }
        }
        selectionsRecord.willwriteClosure = { [weak self] (record) in
            if let aSelf = self {
                record.value = aSelf.selections
            }
        }
        worldRecord.willwriteClosure = { [weak self] (record) in
            if let aSelf = self {
                record.value = aSelf.world
                aSelf.worldHistoryRecord.value = aSelf.history
                aSelf.worldHistoryRecord.isPreparedWrite = true
            }
        }
        
        if camera.rotation != 0 {
            Document.defaultCursor
                = Cursor.rotate(rotation: -camera.rotation + .pi / 2)
            cursor = Document.defaultCursor
        }
        updateTransformsWithCamera()
        updateWithWorld()
        updateWithSelections(oldValue: [])
        backgroundColor = isEditingSheet ? .background : .disabled
    }
    deinit {
        autosavingTimer.cancel()
        sheetViewValues.forEach {
            $0.value.workItem?.cancel()
        }
        thumbnailNodeValues.forEach {
            $0.value.workItem?.cancel()
        }
        runners.forEach { $0.stop() }
    }
    
    let autosavingDelay = 30.0
    private var autosavingTimer = RunTimer()
    private func updateAutosavingTimer() {
        if !autosavingTimer.isWait {
            autosavingTimer.run(afterTime: autosavingDelay,
                                dispatchQueue: .main,
                                beginClosure: {}, waitClosure: {},
                                cancelClosure: {},
                                endClosure: { [weak self] in self?.asyncSave() })
        }
    }
    private var savingItem: DispatchWorkItem?
    private var savingFuncs = [() -> ()]()
    private func asyncSave() {
        rootDirectory.prepareToWriteAll()
        if let item = savingItem {
            item.wait()
        }
        
        let item = DispatchWorkItem(flags: .barrier) { [weak self] in
            do {
                try self?.rootDirectory.writeAll()
            } catch {
                DispatchQueue.main.async {
                    self?.rootNode.show(error)
                }
            }
            DispatchQueue.main.async {
                self?.savingItem = nil
                
                self?.savingFuncs.forEach { $0() }
                self?.savingFuncs = []
            }
        }
        savingItem = item
        queue.async(execute: item)
    }
    func syncSave() {
        if autosavingTimer.isWait {
            autosavingTimer.cancel()
            autosavingTimer = RunTimer()
        }
        rootDirectory.prepareToWriteAll()
        do {
            try rootDirectory.writeAll()
        } catch {
            rootNode.show(error)
        }
    }
    func endSave(completionHandler: @escaping (Document?) -> ()) {
        let message = "Saving".localized
        let progressPanel = ProgressPanel(message: message,
                                          isCancel : false,
                                          isIndeterminate: true)
        
        let timer = RunTimer()
        timer.run(afterTime: 2, dispatchQueue: .main,
                  beginClosure: {}, waitClosure: {},
                  cancelClosure: { progressPanel.close() },
                  endClosure: { progressPanel.show() })
        
        if autosavingTimer.isWait {
            autosavingTimer.cancel()
            autosavingTimer = RunTimer()
            rootDirectory.prepareToWriteAll()
            let item = DispatchWorkItem(flags: .barrier) { [weak self] in
                do {
                    try self?.rootDirectory.writeAll()
                } catch {
                    DispatchQueue.main.async {
                        self?.rootNode.show(error)
                    }
                }
                DispatchQueue.main.async {
                    timer.cancel()
                    progressPanel.close()
                    completionHandler(self)
                }
            }
            queue.async(execute: item)
        } else if let workItem = savingItem {
            workItem.notify(queue: .main, execute: {
                timer.cancel()
                progressPanel.close()
                completionHandler(self)
            })
        } else {
            timer.cancel()
            progressPanel.close()
            completionHandler(self)
        }
    }
    
    let rootDirectory: Directory
    
    static let worldRecordKey = "world.pb"
    let worldRecord: Record<World>
    
    static let worldHistoryRecordKey = "world_h.pb"
    let worldHistoryRecord: Record<WorldHistory>
    
    static let selectionsRecordKey = "selections.pb"
    var selectionsRecord: Record<[Selection]>
    
    static let cameraRecordKey = "camera.pb"
    var cameraRecord: Record<Camera>
    
    static let sheetsDirectoryKey = "sheets"
    let sheetsDirectory: Directory
    
    var world = World() {
        didSet {
            worldRecord.isWillwrite = true
        }
    }
    var history = WorldHistory()
    
    func updateWithWorld() {
        for (shp, _) in world.sheetIDs {
            let sf = sheetFrame(with: shp)
            thumbnailNode(at: shp)?.attitude.position = sf.origin
            sheetView(at: shp)?.node.attitude.position = sf.origin
        }
        updateMap()
    }
    
    func newUndoGroup() {
        history.newUndoGroup()
    }
    
    private func append(undo undoItem: WorldUndoItem,
                        redo redoItem: WorldUndoItem) {
        history.append(undo: undoItem, redo: redoItem)
    }
    @discardableResult
    private func set(_ item: WorldUndoItem, enableNode: Bool = true,
                     isMakeRect: Bool = false) -> Rect? {
        if enableNode {
            switch item {
            case .insertSheets(let sids):
                var rect = Rect?.none
                sids.forEach { (shp, sid) in
                    let sheetFrame = self.sheetFrame(with: shp)
                    let fillType = readFillType(at: sid) ?? .color(.disabled)
                    let node = Node(path: Path(sheetFrame), fillType: fillType)
                    thumbnailNodeValues[shp]?.workItem?.cancel()
                    sheetViewValues[shp]?.workItem?.cancel()
                    thumbnailNode(at: shp)?.removeFromParent()
                    sheetView(at: shp)?.node.removeFromParent()
                    sheetsNode.append(child: node)
                    thumbnailNodeValues[shp] = ThumbnailNodeValue(type: thumbnailType,
                                                                  sheetID: sid, node: node, workItem: nil)
                    
                    if let oldSID = world.sheetIDs[shp] {
                        world.sheetPositions[oldSID] = nil
                    }
                    world.sheetIDs[shp] = sid
                    world.sheetPositions[sid] = shp
                    
                    if isMakeRect {
                        rect += sheetFrame
                    }
                }
                updateMap()
                updateWithCursorPosition()
                return rect
            case .removeSheets(let shps):
                var rect = Rect?.none
                shps.forEach { shp in
                    if let sid = sheetID(at: shp) {
                        if isMakeRect {
                            rect += sheetFrame(with: shp)
                        }
                        
                        readAndClose(.none, at: sid, shp)
                        
                        thumbnailNode(at: shp)?.removeFromParent()
                        let tv = thumbnailNodeValues[shp]
                        thumbnailNodeValues[shp] = nil
                        tv?.workItem?.cancel()
                        
                        world.sheetPositions[sid] = nil
                    }
                    world.sheetIDs[shp] = nil
                }
                updateMap()
                updateWithCursorPosition()
                return rect
            }
        } else {
            switch item {
            case .insertSheets(let sids):
                var rect = Rect?.none
                sids.forEach { (shp, sid) in
                    let sheetFrame = self.sheetFrame(with: shp)
                    
                    if let oldSID = world.sheetIDs[shp] {
                        world.sheetPositions[oldSID] = nil
                    }
                    world.sheetIDs[shp] = sid
                    world.sheetPositions[sid] = shp
                    
                    if isMakeRect {
                        rect += sheetFrame
                    }
                }
                return rect
            case .removeSheets(let shps):
                var rect = Rect?.none
                shps.forEach { shp in
                    if let sid = sheetID(at: shp) {
                        if isMakeRect {
                            rect += sheetFrame(with: shp)
                        }
                        world.sheetPositions[sid] = nil
                    }
                    world.sheetIDs[shp] = nil
                }
                return rect
            }
        }
    }
    func append(_ sids: [SheetPosition: SheetID], enableNode: Bool = true) {
        let undoItem = WorldUndoItem.removeSheets(sids.map { $0.key })
        let redoItem = WorldUndoItem.insertSheets(sids)
        append(undo: undoItem, redo: redoItem)
        set(redoItem, enableNode: enableNode)
    }
    func removeSheets(at shps: [SheetPosition]) {
        var sids = [SheetPosition: SheetID]()
        shps.forEach {
            sids[$0] = world.sheetIDs[$0]
        }
        let undoItem = WorldUndoItem.insertSheets(sids)
        let redoItem = WorldUndoItem.removeSheets(shps)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    @discardableResult
    func undo(to toTopIndex: Int) -> Rect? {
        var frame = Rect?.none
        let results = history.undoAndResults(to: toTopIndex)
        for result in results {
            let item: UndoItemValue<WorldUndoItem>?
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
    func loadCheck(with result: WorldHistory.UndoResult) {
        guard let uiv = history[result.version].values[result.valueIndex]
                .undoItemValue else { return }
        
        let isReversed = result.type == .undo
        
        switch !isReversed ? uiv.undoItem : uiv.redoItem {
        case .insertSheets(let sids):
            for (shp, sid) in sids {
                if world.sheetIDs[shp] != sid {
                    history[result.version].values[result.valueIndex].error()
                    break
                }
            }
        default: break
        }
        
        switch isReversed ? uiv.undoItem : uiv.redoItem {
        case .insertSheets(_): break
        case .removeSheets(_): break
        }
    }
    
    func restoreDatabase() {
        var resetSIDs = Set<SheetID>()
        for sid in sheetRecorders.keys {
            if world.sheetPositions[sid] == nil {
                resetSIDs.insert(sid)
            }
        }
        history.rootBranch.all { (_, branch) in
            for group in branch.groups {
                for udv in group.values {
                    if let item = udv.loadedRedoItem() {
                        if case .insertSheets(let sids) = item.undoItem {
                            for sid in sids.values {
                                resetSIDs.remove(sid)
                            }
                        }
                        if case .insertSheets(let sids) = item.redoItem {
                            for sid in sids.values {
                                resetSIDs.remove(sid)
                            }
                        }
                    }
                }
            }
        }
        if !resetSIDs.isEmpty {
            moveSheetsToUpperRightCorner(with: Array(resetSIDs))
        }
    }
    func moveSheetsToUpperRightCorner(with sids: [SheetID],
                                      isNewUndoGroup: Bool = true) {
        let xCount = Int(Double(sids.count).squareRoot())
        let fxi = (world.sheetPositions.values.max { $0.x < $1.x }?.x ?? 0) + 2
        var dxi = 0
        var yi = (world.sheetPositions.values.max { $0.y < $1.y }?.y ?? 0) + 2
        var newSIDs = [SheetPosition: SheetID]()
        for sid in sids {
            let shp = SheetPosition(fxi + dxi, yi)
            newSIDs[shp] = sid
            dxi += 1
            if dxi >= xCount {
                dxi = 0
                yi += 1
            }
        }
        if isNewUndoGroup {
            newUndoGroup()
        }
        append(newSIDs)
        rootNode.show(message: "There are sheets added in the upper right corner because the positions data is not found.".localized)
    }
    
    func resetAllThumbnails(_ handler: (String) -> (Bool)) {
        for (i, v) in sheetRecorders.enumerated() {
            let (sheetID, sheetRecorder) = v
            guard handler("\(i) / \(sheetRecorders.count - 1)") else { return }
            autoreleasepool {
                let record = sheetRecorder.sheetRecord
                guard let sheet = record.decodedValue else { return }
                let sheetBinder = RecordBinder(value: sheet,
                                               record: record)
                let sheetView = SheetView(binder: sheetBinder,
                                            keyPath: \SheetBinder.value)
                sheetView.node.path = Path(Sheet.defaultBounds)
                sheetView.node.allChildrenAndSelf { $0.updateBuffers() }
                
                makeThumbnailRecord(at: sheetID, with: sheetView)
                syncSave()
            }
        }
    }
    func resetAllSheets(_ handler: (String) -> (Bool)) {
        for (i, v) in sheetRecorders.enumerated() {
            let (_, sheetRecorder) = v
            guard handler("\(i) / \(sheetRecorders.count - 1)") else { return }
            autoreleasepool {
                let record = sheetRecorder.sheetRecord
                guard let sheet = record.decodedValue else { return }
                record.value = sheet
                record.isWillwrite = true
                syncSave()
            }
        }
    }
    func resetAllStrings(_ handler: (String) -> (Bool)) {
        for (i, v) in sheetRecorders.enumerated() {
            let (_, sheetRecorder) = v
            guard handler("\(i) / \(sheetRecorders.count - 1)") else { return }
            autoreleasepool {
                let record = sheetRecorder.sheetRecord
                guard let sheet = record.decodedValue else { return }
                sheetRecorder.stringRecord.value = sheet.allTextsString
                sheetRecorder.stringRecord.isWillwrite = true
                syncSave()
            }
        }
    }
    
    func clearHistory(progressHandler: (Double, inout Bool) -> ()) {
        syncSave()
        
        var resetSRRs = [SheetID: SheetRecorder]()
        for (sid, srr) in sheetRecorders {
            if world.sheetPositions[sid] == nil {
                resetSRRs[sid] = srr
            }
        }
        var isStop = false
        if !resetSRRs.isEmpty {
            for (i, v) in resetSRRs.enumerated() {
                remove(v.value)
                sheetRecorders[v.key] = nil
                progressHandler(Double(i + 1) / Double(resetSRRs.count), &isStop)
                if isStop { break }
            }
        }
        history.reset()
        worldHistoryRecord.value = history
        worldHistoryRecord.isWillwrite = true
    }
    
    static var defaultCursor = Cursor.drawLine
    var cursorNotifications = [((Document, Cursor) -> ())]()
    var cursor = Document.defaultCursor {
        didSet {
            guard cursor != oldValue else { return }
            cursorNotifications.forEach { $0(self, cursor) }
        }
    }
    
    static let defaultBackgroundColor = Color.background
    var backgroundColorNotifications = [((Document, Color) -> ())]()
    var backgroundColor = Document.defaultBackgroundColor {
        didSet {
            guard backgroundColor != oldValue else { return }
            backgroundColorNotifications.forEach { $0(self, backgroundColor) }
        }
    }
    
    static let maxSheetCount = 10000
    static let maxSheetAABB = AABB(maxValueX: Double(maxSheetCount) * Sheet.width,
                                   maxValueY: Double(maxSheetCount) * Sheet.height)
    static let minCameraLog2Scale = -12.0, maxCameraLog2Scale = 8.0
    static func clippedCameraPosition(from p: Point) -> Point {
        var p = p
        if p.x < maxSheetAABB.minX {
            p.x = maxSheetAABB.minX
        } else if p.x > maxSheetAABB.maxX {
            p.x = maxSheetAABB.maxX
        }
        if p.y < maxSheetAABB.minY {
            p.y = maxSheetAABB.minY
        } else if p.y > maxSheetAABB.maxY {
            p.y = maxSheetAABB.maxY
        }
        return p
    }
    static func clippedCamera(from camera: Camera) -> Camera {
        var camera = camera
        camera.position = clippedCameraPosition(from: camera.position)
        let s = camera.scale.width
        if s != camera.scale.height {
            camera.scale = Size(square: s)
        }
        
        let logScale = camera.logScale
        if logScale.isNaN {
            camera.logScale = 0
        } else if logScale < minCameraLog2Scale {
            camera.logScale = minCameraLog2Scale
        } else if logScale > maxCameraLog2Scale {
            camera.logScale = maxCameraLog2Scale
        }
        return camera
    }
    static let defaultCamera
        = Camera(position: Sheet.defaultBounds.centerPoint,
                 scale: Size(width: 1.25, height: 1.25))
    var cameraNotifications = [((Document, Camera) -> ())]()
    var camera = Document.defaultCamera {
        didSet {
            if snappedCameraType != .none {
                snapCamera()
            } else {
                updateTransformsWithCamera()
            }
            cameraRecord.isWillwrite = true
            cameraNotifications.forEach { $0(self, camera) }
        }
    }
    enum SnappedCameraType {
        case x, y, none
    }
    var snappedCameraType = SnappedCameraType.none {
        didSet {
            guard snappedCameraType != oldValue else { return }
            if snappedCameraType != .none {
                snapCamera()
            } else {
                snappedCamera = nil
            }
        }
    }
    var snappableCameraX = Sheet.defaultBounds.width / 3
    var snappableCameraY = Sheet.defaultBounds.height / 4
    func snapCamera() {
        var camera = self.camera
        if snappedCameraType == .x {
            camera.position.x = camera.position.x.interval(scale: snappableCameraX)
        }
        if snappedCameraType == .y {
            camera.position.y = camera.position.y.interval(scale: snappableCameraY)
        }
        snappedCamera = camera
    }
    private(set) var snappedCamera: Camera? {
        didSet {
            if snappedCamera != oldValue {
                updateTransformsWithCamera()
            }
        }
    }
    var drawableSize = Size() {
        didSet {
            updateNode()
        }
    }
    var screenBounds = Rect() {
        didSet {
            centeringCameraTransform = Transform(translation: -screenBounds.centerPoint)
            viewportToScreenTransform = Transform(viewportSize: screenBounds.size)
            screenToViewportTransform = Transform(invertedViewportSize: screenBounds.size)
            updateTransformsWithCamera()
        }
    }
    var worldBounds: Rect { screenBounds * screenToWorldTransform }
    private(set) var screenToWorldTransform = Transform.identity
    var screenToWorldScale: Double { screenToWorldTransform.absXScale }
    private(set) var worldToScreenTransform = Transform.identity
    private(set) var worldToScreenScale = 1.0
    private(set) var centeringCameraTransform = Transform.identity
    private(set) var viewportToScreenTransform = Transform.identity
    private(set) var screenToViewportTransform = Transform.identity
    private(set) var worldToViewportTransform = Transform.identity
    private func updateTransformsWithCamera() {
        let camera = snappedCamera ?? self.camera
        screenToWorldTransform = centeringCameraTransform * camera.transform
        worldToScreenTransform = screenToWorldTransform.inverted()
        worldToScreenScale = worldToScreenTransform.absXScale
        worldToViewportTransform = worldToScreenTransform * screenToViewportTransform
        updateNode()
    }
    func updateNode() {
        guard !drawableSize.isEmpty else { return }
        thumbnailType = self.thumbnailType(withScale: worldToScreenScale)
        readAndClose(with: screenBounds, screenToWorldTransform)
        updateMapWith(worldToScreenTransform: worldToScreenTransform,
                      screenToWorldTransform: screenToWorldTransform,
                      camera: camera,
                      in: screenBounds)
        updateGrid(with: screenToWorldTransform, in: screenBounds)
        updateEditorNode()
        updateRunnerNodesPosition()
    }
    let editableMapScale = 2.0 ** -4
    var isEditingSheet: Bool {
        worldToScreenScale > editableMapScale
    }
    var worldLineWidth: Double {
        Line.defaultLineWidth * screenToWorldScale
    }
    func convertScreenToWorld<T: AppliableTransform>(_ v: T) -> T {
        v * screenToWorldTransform
    }
    func convertWorldToScreen<T: AppliableTransform>(_ v: T) -> T {
        v * worldToScreenTransform
    }
    
    var sheetLineWidth: Double { Line.defaultLineWidth }
    var sheetTextSize: Double { Font.defaultSize }
    
    var selections = [Selection]() {
        didSet {
            selectionsRecord.isWillwrite = true
            updateWithSelections(oldValue: oldValue)
        }
    }
    private(set) var selectedNode: Node?, selectedOrientationNode: Node?
    private(set) var selectedFrames = [Rect](), selectedFramesNode: Node?
    private(set) var selectedClippedFrame: Rect?, selectedClippedNode: Node?
    private(set) var isOldSelectedSheet = false, isSelectedText = false
    func updateWithSelections(oldValue: [Selection]) {
        if !selections.isEmpty {
            if oldValue.isEmpty {
                let oNode = Node(path: Path(circleRadius: 3),
                                 fillType: .color(.selected))
                selectedOrientationNode = oNode
                
                let node = Node(lineWidth: Line.defaultLineWidth,
                                lineType: .color(.selected),
                                fillType: .color(.subSelected))
                rootNode.append(child: oNode)
                selectedNode = node
                rootNode.append(child: node)
                
                let soNode = Node()
                selectedFramesNode = soNode
                rootNode.append(child: soNode)
                
                let ssNode = Node(lineWidth: Line.defaultLineWidth,
                                  lineType: .color(.selected),
                                  fillType: .color(.subSelected))
                selectedClippedNode = ssNode
                rootNode.append(child: ssNode)
                
                isOldSelectedSheet = isEditingSheet
            }
            updateSelects()
            updateSelectedNode()
        } else {
            selectedFrames = []
            if !oldValue.isEmpty {
                selectedNode?.removeFromParent()
                selectedOrientationNode?.removeFromParent()
                selectedFramesNode?.removeFromParent()
                selectedClippedNode?.removeFromParent()
                selectedNode = nil
                selectedOrientationNode = nil
                selectedFramesNode = nil
                selectedClippedNode = nil
            }
        }
    }
    func updateSelects() {
        guard let selection = selections.first else { return }
        let centerSHPs = Set(self.centerSHPs)
        let rect = selection.rect
        var rects = [Rect](), isSelectedText = false, selectedCount = 0
        var firstOrientation = Orientation.horizontal, lineNodes = [Node]()
        if isEditingSheet {
            var cr: Rect?
            sheetViewValues.forEach {
                guard let shp = sheetPosition(at: $0.value.sheetID),
                      centerSHPs.contains(shp) else { return }
                let frame = sheetFrame(with: shp)
                guard let inFrame = rect.intersection(frame) else { return }
                guard let sheetView = $0.value.view else { return }
                cr = cr == nil ? inFrame : cr!.union(inFrame)
                for textView in sheetView.textsView.elementViews {
                    let nRect = textView.convertFromWorld(rect)
                    guard textView.intersects(nRect) else { continue }
                    let tfp = textView.convertFromWorld(selection.firstOrigin)
                    let tlp = textView.convertFromWorld(selection.lastOrigin)
                    if textView.characterIndex(for: tfp) != nil {
                        isSelectedText = true
                    }
                    
                    guard let fi = textView.characterIndexWithOutOfBounds(for: tfp),
                          let li = textView.characterIndexWithOutOfBounds(for: tlp) else { continue }
                    let range = fi < li ? fi..<li : li..<fi
                    for nf in textView.transformedPaddingRects(with: range) {
                        rects.append(sheetView.convertToWorld(nf))
                    }
                    if selectedCount == 0 {
                        firstOrientation = textView.model.orientation
                    }
                    selectedCount += 1
                }
            }
            if selectedCount == 1 && rects.count >= 2 {
                let r0 = rects[0], r1 = rects[1]
                switch firstOrientation {
                case .horizontal:
                    let w = r0.minX - r1.maxX
                    if w > 0 {
                        lineNodes.append(Node(path: Path(Edge(r0.minXMinYPoint,
                                                              r1.maxXMaxYPoint)),
                                              lineWidth: worldLineWidth,
                                              lineType: .color(.selected)))
                    }
                case .vertical:
                    let h = r1.minY - r0.maxY
                    if h > 0 {
                        lineNodes.append(Node(path: Path(Edge(r0.minXMaxYPoint,
                                                              r1.maxXMinYPoint)),
                                              lineWidth: worldLineWidth,
                                              lineType: .color(.selected)))
                    }
                }
            }
            if let cr = cr, cr != rect, isEditingSheet {
                selectedClippedNode?.lineWidth = worldLineWidth
                selectedClippedNode?.path = Path(cr)
            } else {
                selectedClippedNode?.path = Path()
            }
            selectedClippedFrame = cr
        } else {
            world.sheetIDs.keys.forEach {
                let frame = sheetFrame(with: $0)
                guard rect.intersects(frame) else { return }
                rects.append(frame)
            }
        }
        selectedFramesNode?.children = rects.map {
            Node(path: Path($0),
                 lineWidth: worldLineWidth,
                 lineType: .color(.selected),
                 fillType: .color(.subSelected))
        } + lineNodes
        selectedFrames = rects
        self.isSelectedText = isSelectedText && selectedCount == 1
    }
    func updateSelectedNode() {
        guard let crv = selections.first else { return }
        let rect = crv.rect, rectCorner = crv.rectCorner
        let l = worldLineWidth
        
        if let cr = selectedClippedFrame, cr != rect, isEditingSheet {
            selectedClippedNode?.lineWidth = l
            selectedClippedNode?.path = Path(cr)
        } else {
            selectedClippedNode?.path = Path()
        }
        selectedNode?.isHidden = isSelectedText
        selectedNode?.lineWidth = l
        selectedNode?.path = Path(rect)
        
        let attitude = Attitude(screenToWorldTransform)
        var nAttitude = attitude
        switch rectCorner {
        case .minXMinY: nAttitude.position = rect.minXMinYPoint
        case .minXMaxY: nAttitude.position = rect.minXMaxYPoint
        case .maxXMinY: nAttitude.position = rect.maxXMinYPoint
        case .maxXMaxY: nAttitude.position = rect.maxXMaxYPoint
        }
        selectedOrientationNode?.isHidden = isSelectedText
        selectedOrientationNode?.attitude = nAttitude
        
        selectedFramesNode?.children.forEach { $0.lineWidth = l }
        
        let isS = isEditingSheet
        if isS != isOldSelectedSheet {
            isOldSelectedSheet = isS
            updateSelects()
        }
    }
    func isSelect(at p: Point) -> Bool {
        if isSelectedText {
            return selectedFrames.contains(where: { $0.contains(p) })
        } else {
            if let r = selections.first?.rect {
                if r.contains(p) {
                    return true
                }
                return selectedFrames.contains(where: { $0.contains(p) })
            }
            return false
        }
    }
    var selectedLine: Line? {
        if let rect = selections.first?.rect {
            return Line(rect)
        } else {
            return nil
        }
    }
    var selectedOutsetLine: Line? {
        if let rect = selections.first?.rect.inset(by: -0.5) {
            return Line(rect)
        } else {
            return nil
        }
    }
    func updateSelectedColor(isMain: Bool) {
        if !selections.isEmpty {
            let selectedColor = isMain ? Color.selected : Color.diselected
            let subSelectedColor = isMain ? Color.subSelected : Color.subDiselected
            selectedNode?.fillType = .color(subSelectedColor)
            selectedNode?.lineType = .color(selectedColor)
            selectedClippedNode?.fillType = .color(subSelectedColor)
            selectedClippedNode?.lineType = .color(selectedColor)
            selectedFramesNode?.children.forEach {
                $0.fillType = .color(subSelectedColor)
                $0.lineType = .color(selectedColor)
            }
            selectedOrientationNode?.fillType = .color(selectedColor)
        }
    }
    
    var finding = Finding() {
        didSet {
            updateWithFinding()
        }
    }
    private var findingNode: Node?
    private(set) var findingNodes = [SheetPosition: Node]()
    let findingSplittedWidth
        = (Double.hypot(Sheet.width / 2, Sheet.height / 2) * 1.25).rounded()
    private func updateWithFinding() {
        guard !finding.isEmpty else {
            if findingNode != nil {
                findingNodes = [:]
                findingNode?.removeFromParent()
                findingNode = nil
            }
            return
        }
        
        var nodes = [Node]()
        var findingNodes = [SheetPosition: Node]()
        for sr in sheetRecorders {
            guard let shp = sheetPosition(at: sr.key) else { continue }
            let string = sheetViewValues[shp]?.view?.model.allTextsString
                ?? sr.value.stringRecord.decodedValue
            if string?.contains(finding.string) ?? false {
                let node = Node()
                findingNodes[shp] = node
                nodes.append(node)
            }
        }
        
        self.findingNodes = findingNodes
        findingNode?.removeFromParent()
        let node = Node(children: nodes)
        rootNode.append(child: node)
        findingNode = node
        findingNodes.forEach { updateFindingNodes(at: $0.key) }
    }
    private func updateFindingNodes(at shp: SheetPosition) {
        guard let node = findingNodes[shp] else { return }
        
        let sf = sheetFrame(with: shp)
        let l = worldLineWidth, p: Point
        var nodes = [Node]()
        if finding.worldPosition.distance(sf.centerPoint) < findingSplittedWidth {
            p = finding.worldPosition
        } else {
            let angle = sf.centerPoint.angle(finding.worldPosition)
            p = sf.centerPoint.movedWith(distance: findingSplittedWidth,
                                         angle: angle)
            let node = Node(path: Path([Pathline([finding.worldPosition, p])]),
                            lineWidth: l,
                            lineType: .color(.selected))
            nodes.append(node)
        }
        if let nSheetView = sheetView(at: shp) {
            for text in nSheetView.model.texts {
                for range in text.string.ranges(of: finding.string) {
                    if let rect = text.typesetter.typoBounds(for: range) {
                        let nr = nSheetView.convertToWorld(rect + text.origin)
                        nodes.append(Node(path: Path(nr),
                                          lineWidth: l,
                                          lineType: .color(.selected),
                                          fillType: .color(.subSelected)))
                        nodes.append(Node(path: Path([Pathline([p,
                                                                nr.centerPoint])]),
                                          lineWidth: l,
                                          lineType: .color(.selected)))
                    }
                }
            }
        } else {
            nodes.append(Node(path: Path(sf),
                              lineWidth: l,
                              lineType: .color(.selected),
                              fillType: .color(.subSelected)))
            nodes.append(Node(path: Path([Pathline([p,
                                                    sf.centerPoint])]),
                              lineWidth: l,
                              lineType: .color(.selected)))
        }
        node.children = nodes
    }
    func updateFindingNodes() {
        if !findingNodes.isEmpty {
            let l = worldLineWidth
            findingNodes.values.forEach {
                $0.children.forEach { $0.lineWidth = l }
            }
        }
    }
    func replaceFinding(from toStr: String) {
        let fromStr = finding.string
        func make(isRecord: Bool = false) {
            func make(_ sheetView: SheetView) -> Bool {
                var isNewUndoGroup = true
                func updateUndoGroup() {
                    if isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = false
                    }
                }
                let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
                for (i, textView) in sheetView.textsView.elementViews.enumerated() {
                    var text = textView.model
                    if text.string.contains(fromStr) {
                        let rRange = 0..<text.string.count
                        let ns = text.string.replacingOccurrences(of: fromStr,
                                                                  with: toStr)
                        text.replaceSubrange(ns, from: rRange, clipFrame: sb)
                        let origin = textView.model.origin != text.origin ?
                            text.origin : nil
                        let size = textView.model.size != text.size ?
                            text.size : nil
                        let tv = TextValue(string: ns,
                                           replacedRange: rRange,
                                           origin: origin, size: size)
                        updateUndoGroup()
                        sheetView.replace(IndexValue(value: tv, index: i))
                    }
                }
                return !isNewUndoGroup
            }
            
            if isRecord {
                func replaceSheets(progressHandler: (Double, inout Bool) -> ()) throws {
                    var isStop = false
                    for (j, v) in findingNodes.enumerated() {
                        let shp = v.key
                        if let sheetView = sheetViewValues[shp]?.view {
                            _ = make(sheetView)
                        } else if let sid = sheetID(at: shp),
                                  let sheetRecorder = sheetRecorders[sid] {
                            let record = sheetRecorder.sheetRecord
                            guard let sheet = record.decodedValue else { return }
                            
                            let sheetBinder = RecordBinder(value: sheet,
                                                           record: record)
                            let sheetView = SheetView(binder: sheetBinder,
                                                        keyPath: \SheetBinder.value)
                            sheetView.node.path = Path(Sheet.defaultBounds)
                            sheetView.node.allChildrenAndSelf { $0.updateBuffers() }
                            
                            if make(sheetView) {
                                if savingItem != nil {
                                    savingFuncs.append { [model = sheetView.model, um = sheetView.history,
                                                          tm = thumbnailMipmap(from: sheetView), weak self] in
                                        
                                        sheetRecorder.sheetRecord.value = model
                                        sheetRecorder.sheetRecord.isWillwrite = true
                                        sheetRecorder.sheetHistoryRecord.value = um
                                        sheetRecorder.sheetHistoryRecord.isWillwrite = true
                                        self?.updateStringRecord(at: sid, with: sheetView)
                                        if let tm = tm {
                                            self?.saveThumbnailRecord(tm, in: sheetRecorder)
                                            self?.baseThumbnailDatas[sid] = Texture.bytesData(with: tm.thumbnail4Data)
                                        }
                                    }
                                } else {
                                    sheetRecorder.sheetRecord.value = sheetView.model
                                    sheetRecorder.sheetHistoryRecord.value = sheetView.history
                                    sheetRecorder.sheetHistoryRecord.isWillwrite = true
                                    makeThumbnailRecord(at: sid, with: sheetView)
                                    sheetRecorder.sheetRecord.willwriteClosure = { (_) in }
                                }
                            }
                        }
                        progressHandler(Double(j + 1) / Double(findingNodes.count), &isStop)
                        if isStop { break }
                    }
                }
                
                let message = "Replacing sheets".localized
                let progressPanel = ProgressPanel(message: message)
                rootNode.show(progressPanel)
//                DispatchQueue.global().async {
                    do {
                        try replaceSheets { (progress, isStop) in
                            if progressPanel.isCancel {
                                isStop = true
                            } else {
//                                DispatchQueue.main.async {
                                    progressPanel.progress = progress
//                                }
                            }
                        }
//                        DispatchQueue.main.async {
                            progressPanel.closePanel()
                            self.finding.string = toStr
//                        }
                    } catch {
//                        DispatchQueue.main.async {
                            self.rootNode.show(error)
                            progressPanel.closePanel()
                            self.finding.string = toStr
//                        }
                    }
//                }
            } else {
                for (shp, _) in findingNodes {
                    if let sheetView = sheetViewValues[shp]?.view {
                        _ = make(sheetView)
                    }
                }
                finding.string = toStr
            }
        }
        
        var recordCount = 0
        for (shp, _) in findingNodes {
            if sheetViewValues[shp]?.view == nil,
               let sid = sheetID(at: shp),
               sheetRecorders[sid] != nil {
                recordCount += 1
            }
        }
        if recordCount > 0 {
            rootNode.show(message: "\(recordCount)",
                          infomation: "",
                          okTitle: "Replace".localized) {
                make(isRecord: true)
            } cancelClosure: {}
        } else {
            make()
        }
    }
    
    func string(at p: Point) -> String? {
        if isSelect(at: p), let r = selections.first?.rect {
            let se = LineEditor(self)
            se.updateClipBoundsAndIndexRange(at: p)
            se.tempLine = Line(r) * Transform(translation: -se.centerOrigin)
            let value = se.sheetValue(isRemove: false,
                                      isEnableLine: !isSelectedText,
                                      isEnablePlane: !isSelectedText,
                                      selections: selections,
                                      at: p)
            if !value.isEmpty {
                return value.allTextsString
            }
        } else if let sheetView = sheetView(at: p),
                  let textView = sheetView.textTuple(at: sheetView.convertFromWorld(p))?.textView {
            
            return textView.model.string
        }
        return nil
    }
    
    func containsLookingUp(at wp: Point) -> Bool {
        lookingUpBoundsNode?.path
            .contains(lookingUpNode.convertFromWorld(wp)) ?? false
    }
    private(set) var isShownLookingUp = false
    private var lookingUpNode = Node(), lookingUpBoundsNode: Node?
    func show(_ string: String, at origin: Point) {
        show(string,
             fromSize: isEditingSheet ? Font.defaultSize : 400,
             rects: [Rect(origin, distance: 2)],
             .horizontal,
             clipRatio: isEditingSheet ? 1 : nil)
    }
    func show(_ string: String, fromSize: Double, toSize: Double = 8,
              rects: [Rect], _ orientation: Orientation,
              clipRatio: Double? = 1,
              padding: Double = 3,
              textPadding: Double = 3,
              cornerRadius: Double = 4) {
        closeLookingUpNode()
        guard !rects.isEmpty else { return }
        let ratio = clipRatio != nil ?
            min(fromSize / Font.defaultSize, clipRatio!) :
            fromSize / Font.defaultSize
        let origin: Point
        let pd = (padding + 3.75 + textPadding + toSize / 2 + 1) * ratio
        let lpd = padding * ratio
        var backNodes = [Node](), lineNodes = [Node]()
        func backNode(from path: Path) -> Node {
            return Node(path: path,
                        lineWidth: 1 * ratio,
                        lineType: .color(.subBorder),
                        fillType: .color(Color.disabled.with(opacity: 0.95)))
        }
        func lineNode(from path: Path) -> Node {
            return Node(path: path,
                        lineWidth: 1 * ratio,
                        lineType: .color(.subBorder),
                        fillType: .color(Color.disabled.with(opacity: 0.95)))
        }
        switch orientation {
        case .horizontal:
            origin = rects[0].minXMinYPoint + Point(0, -pd)
            backNodes = rects.map {
                let rect = Rect(Edge($0.minXMinYPoint + Point(0, -lpd),
                                     $0.maxXMinYPoint + Point(0, -lpd)))
                return backNode(from: Path(rect.inset(by: -2 * ratio),
                                           cornerRadius: 1 * ratio))
            }
            lineNodes = rects.map {
                Node(path: Path(Edge($0.minXMinYPoint + Point(0, -lpd),
                                     $0.maxXMinYPoint + Point(0, -lpd))),
                     lineWidth: 1 * ratio, lineType: .color(.content))
            }
        case .vertical:
            origin = rects[0].minXMaxYPoint + Point(-pd, 0)
            backNodes = rects.map {
                let rect = Rect(Edge($0.minXMaxYPoint + Point(-lpd, 0),
                                     $0.minXMinYPoint + Point(-lpd, 0)))
                return backNode(from: Path(rect.inset(by: -2 * ratio),
                                           cornerRadius: 1 * ratio))
            }
            lineNodes = rects.map {
                Node(path: Path(Edge($0.minXMaxYPoint + Point(-lpd, 0),
                                     $0.minXMinYPoint + Point(-lpd, 0))),
                     lineWidth: 1 * ratio, lineType: .color(.content))
            }
        }
        let text = Text(string: string, orientation: orientation,
                        size: toSize * ratio, widthCount: 20, origin: origin)
        let typesetter = text.typesetter
        guard let b = typesetter.typoBounds?
                .outset(by: (toSize / 2 + 1) * ratio) else { return }
        let textNode = Node(attitude: Attitude(position: text.origin),
                            path: typesetter.path(), fillType: .color(.content))
        let boundsNode = Node(path: Path(b + text.origin,
                                         cornerRadius: cornerRadius * ratio),
                              lineWidth: 1 * ratio,
                              lineType: .color(.subBorder),
                              fillType: .color(Color.disabled.with(opacity: 0.95)))
        lookingUpNode.children = backNodes + lineNodes + [boundsNode, textNode]
        lookingUpBoundsNode = boundsNode
        if lookingUpNode.parent == nil {
            rootNode.append(child: lookingUpNode)
        }
        isShownLookingUp = true
    }
    func closeLookingUpNode() {
        lookingUpBoundsNode = nil
        lookingUpNode.children = []
        lookingUpNode.path = Path()
        lookingUpNode.removeFromParent()
    }
    func closeLookingUp() {
        if isShownLookingUp {
            closeLookingUpNode()
            isShownLookingUp = false
        }
    }
    
    func closeAllPanels(at p: Point) {
        if isShownLookingUp,
           let b = lookingUpBoundsNode?.transformedBounds,
           !b.contains(p) {
            
            closeLookingUp()
        }
        selections = []
    }
    
    private var menuNode: Node?
    
    var textCursorWidthNode = Node(lineWidth: 2, lineType: .color(.border))
    var textCursorNode = Node(lineWidth: 0.5, lineType: .color(.background),
                              fillType: .color(.content))
    func updateTextCursor(isMove: Bool = false) {
        func close() {
            if textCursorNode.parent != nil {
                textCursorNode.removeFromParent()
            }
            if textCursorWidthNode.parent != nil {
                textCursorWidthNode.removeFromParent()
            }
        }
        if isEditingSheet && textEditor.editingTextView == nil,
           let sheetView = sheetView(at: cursorSHP) {
            
            if isMove {
                sheetView.selectedTextView = nil
            }
            
            if !sheetView.model.texts.isEmpty {
                let cp = convertScreenToWorld(cursorPoint)
                let vp = sheetView.convertFromWorld(cp)
                if let textView = sheetView.selectedTextView,
                   let i = textView.selectedRange?.lowerBound {
                    
                    if textCursorWidthNode.parent == nil {
                        rootNode.append(child: textCursorWidthNode)
                    }
                    if textCursorNode.parent == nil {
                        rootNode.append(child: textCursorNode)
                    }
                    if textCursorWidthNode.isHidden {
                        textCursorWidthNode.isHidden = false
                    }
                    if textCursorNode.isHidden {
                        textCursorNode.isHidden = false
                    }
                    let path = textView.typesetter.cursorPath(at: i)
                    textCursorNode.path = textView.convertToWorld(path)
                    textCursorWidthNode.path = textCursorNode.path
                } else if let (textView, _, _, cursorIndex) = sheetView.textTuple(at: vp) {
                    
                    if textCursorWidthNode.parent == nil {
                        rootNode.append(child: textCursorWidthNode)
                    }
                    if textCursorNode.parent == nil {
                        rootNode.append(child: textCursorNode)
                    }
                    if textCursorNode.isHidden {
                        textCursorNode.isHidden = false
                    }
                    let ratio = textView.model.size / Font.defaultSize
                    textCursorWidthNode.lineWidth = 1 * ratio
                    textCursorNode.lineWidth = 0.5 * ratio
                    
                    if let wcpath = textView.typesetter.warpCursorPath(at: textView.convertFromWorld(cp)) {
                        
                        textCursorWidthNode.path = textView.convertToWorld(wcpath)
                        textCursorWidthNode.isHidden = false
                    } else {
                        textCursorWidthNode.isHidden = true
                    }
                    let path = textView.typesetter
                        .cursorPath(at: cursorIndex,
                                    halfWidth: 0.75, heightRatio: 0.3)
                    textCursorNode.path = textView.convertToWorld(path)
                } else {
                    close()
                }
            } else {
                close()
            }
        } else {
            close()
        }
    }
    
    enum ThumbnailType: Int {
        case w4 = 4, w16 = 16, w64 = 64, w256 = 256, w1024 = 1024
    }
    let thumbnail4Scale = 2.0 ** -8
    let thumbnail16Scale = 2.0 ** -6
    let thumbnail64Scale = 2.0 ** -4
    let thumbnail256Scale = 2.0 ** -2
    let thumbnail1024Scale = 2.0 ** 0
    var thumbnailType = ThumbnailType.w4
    func thumbnailType(withScale scale: Double) -> ThumbnailType {
        if scale < thumbnail4Scale {
            return .w4
        } else if scale < thumbnail16Scale {
            return .w16
        } else if scale < thumbnail64Scale {
            return .w64
        } else if scale < thumbnail256Scale {
            return .w256
        } else {
            return .w1024
        }
    }
    
    struct SheetRecorder {
        let directory: Directory
        
        static let sheetKey = "sheet.pb"
        let sheetRecord: Record<Sheet>
        
        static let sheetHistoryKey = "sheet_h.pb"
        let sheetHistoryRecord: Record<SheetHistory>
        
        static let thumbnail4Key = "t4.jpg"
        let thumbnail4Record: Record<Thumbnail>
        static let thumbnail16Key = "t16.jpg"
        let thumbnail16Record: Record<Thumbnail>
        static let thumbnail64Key = "t64.jpg"
        let thumbnail64Record: Record<Thumbnail>
        static let thumbnail256Key = "t256.jpg"
        let thumbnail256Record: Record<Thumbnail>
        static let thumbnail1024Key = "t1024.jpg"
        let thumbnail1024Record: Record<Thumbnail>
        
        static let stringKey = "string.txt"
        let stringRecord: Record<String>
        
        var fileSize: Int {
            var size = 0
            size += sheetRecord.size ?? 0
            size += sheetHistoryRecord.size ?? 0
            size += thumbnail4Record.size ?? 0
            size += thumbnail16Record.size ?? 0
            size += thumbnail64Record.size ?? 0
            size += thumbnail256Record.size ?? 0
            size += thumbnail1024Record.size ?? 0
            size += stringRecord.size ?? 0
            return size
        }
        var fileSizeWithoutHistory: Int {
            var size = 0
            size += sheetRecord.size ?? 0
            size += thumbnail4Record.size ?? 0
            size += thumbnail16Record.size ?? 0
            size += thumbnail64Record.size ?? 0
            size += thumbnail256Record.size ?? 0
            size += thumbnail1024Record.size ?? 0
            size += stringRecord.size ?? 0
            return size
        }
        
        init(_ directory: Directory) {
            self.directory = directory
            sheetRecord = directory.makeRecord(forKey: SheetRecorder.sheetKey)
            sheetHistoryRecord = directory.makeRecord(forKey: SheetRecorder.sheetHistoryKey)
            thumbnail4Record = directory.makeRecord(forKey: SheetRecorder.thumbnail4Key)
            thumbnail16Record = directory.makeRecord(forKey: SheetRecorder.thumbnail16Key)
            thumbnail64Record = directory.makeRecord(forKey: SheetRecorder.thumbnail64Key)
            thumbnail256Record = directory.makeRecord(forKey: SheetRecorder.thumbnail256Key)
            thumbnail1024Record = directory.makeRecord(forKey: SheetRecorder.thumbnail1024Key)
            stringRecord = directory.makeRecord(forKey: SheetRecorder.stringKey)
        }
    }
    
    struct SheetViewValue {
        let sheetID: SheetID
        var view: SheetView?
        weak var workItem: DispatchWorkItem?
    }
    struct ThumbnailNodeValue {
        var type: ThumbnailType?
        let sheetID: SheetID
        var node: Node?
        weak var workItem: DispatchWorkItem?
    }
    private(set) var sheetRecorders: [SheetID: SheetRecorder]
    private(set) var baseThumbnailDatas: [SheetID: Texture.BytesData]
    private(set) var sheetViewValues = [SheetPosition: SheetViewValue]()
    private(set) var thumbnailNodeValues = [SheetPosition: ThumbnailNodeValue]()
    
    let queue = DispatchQueue(label: System.id + ".queue",
                              qos: .userInteractive)
    
    static func sheetRecorders(from sheetsDirectory: Directory) -> [SheetID: SheetRecorder] {
        var srrs = [SheetID: SheetRecorder]()
        srrs.reserveCapacity(sheetsDirectory.childrenURLs.count)
        for (key, _) in sheetsDirectory.childrenURLs {
            guard let sid = sheetID(forKey: key) else { continue }
            let directory = sheetsDirectory.makeDirectory(forKey: sheetIDKey(at: sid))
            srrs[sid] = SheetRecorder(directory)
        }
        return srrs
    }
    
    func makeSheetRecorder(at sid: SheetID) -> SheetRecorder {
        SheetRecorder(sheetsDirectory.makeDirectory(forKey: Document.sheetIDKey(at: sid)))
    }
    func append(_ srr: SheetRecorder, at sid: SheetID) {
        sheetRecorders[sid] = srr
        if let data = srr.thumbnail4Record.decodedData {
            baseThumbnailDatas[sid] = Texture.bytesData(with: data)
        }
    }
    func remove(_ srr: SheetRecorder) {
        try? sheetsDirectory.remove(srr.directory)
    }
    func removeUndo(at shp: SheetPosition) {
        if let sid = sheetID(at: shp), let srr = sheetRecorders[sid] {
            try? srr.directory.remove(srr.sheetHistoryRecord)
        }
    }
    func contains(at sid: SheetID) -> Bool {
        sheetsDirectory.childrenURLs[Document.sheetIDKey(at: sid)] != nil
    }
    
    static func sheetID(forKey key: String) -> SheetID? { SheetID(uuidString: key) }
    static func sheetIDKey(at sid: SheetID) -> String { sid.uuidString }
    
    func thumbnailRecord(at sid: SheetID,
                         with type: ThumbnailType) -> Record<Thumbnail>? {
        switch type {
        case .w4: return sheetRecorders[sid]?.thumbnail4Record
        case .w16: return sheetRecorders[sid]?.thumbnail16Record
        case .w64: return sheetRecorders[sid]?.thumbnail64Record
        case .w256: return sheetRecorders[sid]?.thumbnail256Record
        case .w1024: return sheetRecorders[sid]?.thumbnail1024Record
        }
    }
    
    @discardableResult
    func readThumbnailNode(at sid: SheetID) -> Node? {
        guard let shp = sheetPosition(at: sid) else { return nil }
        if let tv = thumbnailNodeValues[shp]?.node { return tv }
        let ssFrame = sheetFrame(with: shp)
        return Node(attitude: Attitude(position: ssFrame.origin),
                    path: Path(Rect(size: ssFrame.size)),
                    fillType: readFillType(at: sid) ?? .color(.disabled))
    }
    func readThumbnail(at sid: SheetID) -> Texture? {
        if let shp = sheetPosition(at: sid) {
            if let fillType = thumbnailNode(at: shp)?.fillType,
               case .texture(let thumbnailTexture) = fillType {
                
                if Int(thumbnailTexture.size.width) != thumbnailType.rawValue {
                    guard let data = readThumbnailData(at: sid),
                          let nThumbnailTexture = Texture(data: data, isOpaque: true) else { return nil }
                    return nThumbnailTexture
                }
                return thumbnailTexture
            }
        }
        
        guard let data = readThumbnailData(at: sid),
              let thumbnailTexture = Texture(data: data, isOpaque: true) else {
            return thumbnailRecord(at: sid, with: thumbnailType)?.decodedValue?.texture
        }
        return thumbnailTexture
    }
    func readFillType(at sid: SheetID) -> Node.FillType? {
        if let shp = sheetPosition(at: sid) {
            if let fillType = thumbnailNode(at: shp)?.fillType {
                return fillType
            }
        }
        
        guard let data = readThumbnailData(at: sid),
              let thumbnailTexture = Texture(data: data, isOpaque: true) else {
            guard let thumbnailTexture = thumbnailRecord(at: sid, with: thumbnailType)?.decodedValue?.texture else {
                return nil
            }
            return .texture(thumbnailTexture)
        }
        return .texture(thumbnailTexture)
    }
    func readThumbnailData(at sid: SheetID) -> Data? {
        return thumbnailRecord(at: sid, with: thumbnailType)?.decodedData
    }
    func readSheet(at sid: SheetID) -> Sheet? {
        if let shp = sheetPosition(at: sid), let sheet = sheetView(at: shp)?.model {
            return sheet
        }
        if let sheetRecorder = sheetRecorders[sid] {
            return sheetRecorder.sheetRecord.decodedValue
        } else {
            return nil
        }
    }
    func readSheetHistory(at sid: SheetID) -> SheetHistory? {
        if let shp = sheetPosition(at: sid), let history = sheetView(at: shp)?.history {
            return history
        }
        if let sheetRecorder = sheetRecorders[sid] {
            return sheetRecorder.sheetHistoryRecord.decodedValue
        } else {
            return nil
        }
    }
    
    func updateStringRecord(at sid: SheetID, with sheetView: SheetView) {
        guard let sheetRecorder = sheetRecorders[sid] else { return }
        sheetRecorder.stringRecord.value = sheetView.model.allTextsString
        sheetRecorder.stringRecord.isWillwrite = true
    }
    
    struct ThumbnailMipmap {
        var thumbnail4Data: Data
        var thumbnail4: Thumbnail?
        var thumbnail16: Thumbnail?
        var thumbnail64: Thumbnail?
        var thumbnail256: Thumbnail?
        var thumbnail1024: Thumbnail?
    }
    func hideSelectedRange(_ handler: () -> ()) {
        var isHiddenSelectedRange = false
        if let textView = textEditor.editingTextView, !textView.isHiddenSelectedRange {
            
            textView.isHiddenSelectedRange = true
            isHiddenSelectedRange = true
        }
        
        handler()
        
        if isHiddenSelectedRange, let textView = textEditor.editingTextView {
            textView.isHiddenSelectedRange = false
        }
    }
    func makeThumbnailRecord(at sid: SheetID, with sheetView: SheetView) {
        hideSelectedRange {
            if let tm = thumbnailMipmap(from: sheetView),
               let sheetRecorder = sheetRecorders[sid] {
                
                saveThumbnailRecord(tm, in: sheetRecorder)
                baseThumbnailDatas[sid] = Texture.bytesData(with: tm.thumbnail4Data)
            }
        }
        updateStringRecord(at: sid, with: sheetView)
    }
    func thumbnailMipmap(from sheetView: SheetView) -> ThumbnailMipmap? {
        var size = Sheet.defaultBounds.size * (2.0 ** 1)
        let bColor = sheetView.model.backgroundUUColor.value
        let baseImage = sheetView.node.image(with: size, backgroundColor: bColor)
        guard let thumbnail1024 = baseImage else { return nil }
        size = size / 4
        let thumbnail256 = thumbnail1024.resize(with: size)
        size = size / 4
        let thumbnail64 = thumbnail256?.resize(with: size)
        size = size / 4
        let thumbnail16 = thumbnail64?.resize(with: size)
        size = size / 4
        let thumbnail4 = thumbnail16?.resize(with: size)
        guard let thumbnail4Data = thumbnail4?.data(.jpeg) else { return nil }
        return ThumbnailMipmap(thumbnail4Data: thumbnail4Data,
                               thumbnail4: thumbnail4,
                               thumbnail16: thumbnail16,
                               thumbnail64: thumbnail64,
                               thumbnail256: thumbnail256,
                               thumbnail1024: thumbnail1024)
    }
    func saveThumbnailRecord(_ tm: ThumbnailMipmap,
                             in srr: SheetRecorder) {
        srr.thumbnail4Record.value = tm.thumbnail4
        srr.thumbnail16Record.value = tm.thumbnail16
        srr.thumbnail64Record.value = tm.thumbnail64
        srr.thumbnail256Record.value = tm.thumbnail256
        srr.thumbnail1024Record.value = tm.thumbnail1024
        srr.thumbnail4Record.isWillwrite = true
        srr.thumbnail16Record.isWillwrite = true
        srr.thumbnail64Record.isWillwrite = true
        srr.thumbnail256Record.isWillwrite = true
        srr.thumbnail1024Record.isWillwrite = true
    }
    func emptyNode(at shp: SheetPosition) -> Node {
        let ssFrame = sheetFrame(with: shp)
        return Node(path: Path(ssFrame), fillType: baseFillType(at: shp))
    }
    func baseFillType(at shp: SheetPosition) -> Node.FillType {
        guard let sid = sheetID(at: shp), let bytesData = baseThumbnailDatas[sid] else {
            return .color(.disabled)
        }
        guard let texture = Texture(bytesData: bytesData, isOpaque: true) else {
            return .color(.disabled)
        }
        return .texture(texture)
    }
    
    var isUpdateWithCursorPosition = true
    var cursorPoint = Point() {
        didSet {
            updateWithCursorPosition()
        }
    }
    var cursorSHP = SheetPosition()
    var centerSHPs = [SheetPosition]()
    func updateWithCursorPosition() {
        if isUpdateWithCursorPosition {
            updateWithCursorPositionAlways()
        }
    }
    private func updateWithCursorPositionAlways() {
        var shps = [SheetPosition]()
        let shp = sheetPosition(at: convertScreenToWorld(cursorPoint))
        cursorSHP = shp
        shps.append(shp)
        shps.append(SheetPosition(shp.x + 1, shp.y))
        shps.append(SheetPosition(shp.x - 1, shp.y))
        shps.append(SheetPosition(shp.x, shp.y + 1))
        shps.append(SheetPosition(shp.x, shp.y - 1))
        shps.append(SheetPosition(shp.x + 1, shp.y + 1))
        shps.append(SheetPosition(shp.x + 1, shp.y - 1))
        shps.append(SheetPosition(shp.x - 1, shp.y - 1))
        shps.append(SheetPosition(shp.x - 1, shp.y + 1))
        centerSHPs = shps
        if let leshp = lastEditedSheetPosition {
            shps.append(leshp)
        }
        
        var nshps = sheetViewValues
        let oshps = nshps
        for shp in shps {
            nshps[shp] = nil
        }
        nshps.forEach { readAndClose(.none, qos: .default, at: $0.value.sheetID, $0.key) }
        for nshp in shps {
            if oshps[nshp] == nil, let sid = sheetID(at: nshp) {
                readAndClose(.sheet,
                             qos: nshp == shp ? .userInteractive : .default,
                             at: sid, nshp)
            }
        }
        
        updateTextCursor(isMove: true)
    }
    
    private enum NodeType {
        case none, sheet
    }
    func readAndClose(with aBounds: Rect, _ transform: Transform) {
        readAndClose(with: aBounds, transform, sheetRecorders)
    }
    func readAndClose(with aBounds: Rect, _ transform: Transform,
                      _ sheetRecorders: [SheetID: SheetRecorder]) {
        let bounds = aBounds * transform
        let d = transform.log2Scale.clipped(min: 0, max: 4, newMin: 1440, newMax: 360)
        let thumbnailsBounds = bounds.inset(by: -d)
        let minXIndex = Int((thumbnailsBounds.minX / Sheet.width).rounded(.down))
        let maxXIndex = Int((thumbnailsBounds.maxX / Sheet.width).rounded(.up))
        let minYIndex = Int((thumbnailsBounds.minY / Sheet.height).rounded(.down))
        let maxYIndex = Int((thumbnailsBounds.maxY / Sheet.height).rounded(.up))
        
        for (sid, _) in sheetRecorders {
            guard let shp = sheetPosition(at: sid) else { continue }
            let type: ThumbnailType?
            if shp.x >= minXIndex && shp.x <= maxXIndex
                && shp.y >= minYIndex && shp.y <= maxYIndex {
                
                type = thumbnailType
            } else {
                type = nil
            }
            let tv = thumbnailNodeValues[shp]
                ?? ThumbnailNodeValue(type: .none, sheetID: sid, node: nil, workItem: nil)
            if tv.type != type {
                set(type, in: tv, at: sid, shp)
            }
        }
    }
    private func set(_ type: ThumbnailType?, in tv: ThumbnailNodeValue,
                     at sid: SheetID, _ shp: SheetPosition) {
        if sheetViewValues[shp]?.view != nil { return }
        if let type = type {
            if let oldType = tv.type {
                if type != oldType {
                    tv.workItem?.cancel()
                    openThumbnail(at: shp, sid, tv.node, type)
                }
            } else {
                openThumbnail(at: shp, sid, tv.node, type)
            }
        } else {
            if tv.type != nil {
                tv.workItem?.cancel()
                tv.node?.removeFromParent()
                thumbnailNodeValues[shp]?.node?.removeFromParent()
                thumbnailNodeValues[shp] = ThumbnailNodeValue(type: type, sheetID: sid, node: nil,
                                                              workItem: nil)
            }
        }
    }
    func openThumbnail(at shp: SheetPosition, _ sid: SheetID, _ node: Node?,
                       _ type: ThumbnailType) {
        let node = node ?? emptyNode(at: shp)
        guard type != .w4 else {
            node.fillType = baseFillType(at: shp)
            thumbnailNodeValues[shp]?.node?.removeFromParent()
            thumbnailNodeValues[shp] = ThumbnailNodeValue(type: type, sheetID: sid, node: node,
                                                          workItem: nil)
            sheetsNode.append(child: node)
            return
        }
        let thumbnailRecord = self.thumbnailRecord(at: sid, with: type)
        var item: DispatchWorkItem!
        item = DispatchWorkItem() { [weak thumbnailRecord, weak node] in
            defer {
                item = nil
            }
            guard !item.isCancelled else { return }
            if let thumbnail = thumbnailRecord?.value {
                try? Texture.texture(mipmapImage: thumbnail) { thumbnailTexture in
                    node?.fillType = .texture(thumbnailTexture)//
                } cancelHandler: { _ in }
            } else {
                guard let data = thumbnailRecord?.decodedData else { return }
                try? Texture.texture(mipmapData: data) { thumbnailTexture in
                    node?.fillType = .texture(thumbnailTexture)
                } cancelHandler: { _ in }
            }
        }
        queue.async(execute: item)
        thumbnailNodeValues[shp]?.node?.removeFromParent()
        thumbnailNodeValues[shp] = ThumbnailNodeValue(type: type, sheetID: sid, node: node,
                                                      workItem: item)
        sheetsNode.append(child: node)
    }
    
    func close(from shps: [SheetPosition]) {
        shps.forEach {
            if let sid = sheetID(at: $0) {
                readAndClose(.none, qos: .default, at: sid, $0)
            }
        }
    }
    func close(from sids: [SheetID]) {
        sids.forEach {
            if let shp = sheetPosition(at: $0) {
                readAndClose(.none, qos: .default, at: $0, shp)
            }
        }
    }
    private func updateThumbnail(_ sheetViewValue: SheetViewValue,
                                 at shp: SheetPosition, _ sid: SheetID) {
        if let sheetView = sheetViewValue.view {
            if let texture = sheetView.node.cacheTexture {
                if let tv = thumbnailNodeValues[shp], let tNode = tv.node {
                    tNode.fillType = .texture(texture)
                    if tNode.parent == nil {
                        sheetsNode.append(child: tNode)
                    }
                } else if sheetViewValues[shp] != nil {
                    let ssFrame = sheetFrame(with: shp)
                    let tNode = Node(path: Path(ssFrame),
                                     fillType: .color(.disabled))
                    tNode.fillType = .texture(texture)
                    thumbnailNodeValues[shp]?.node?.removeFromParent()
                    thumbnailNodeValues[shp] = ThumbnailNodeValue(type: thumbnailType,
                                                                  sheetID: sid, node: tNode,
                                                                  workItem: nil)
                    sheetsNode.append(child: tNode)
                }
            } else if let tv = thumbnailNodeValues[shp] {
                openThumbnail(at: shp, sid, tv.node, thumbnailType)
            }
        }
    }
    private func readAndClose(_ type: NodeType, qos: DispatchQoS = .default,
                              at sid: SheetID, _ shp: SheetPosition) {
        switch type {
        case .none:
            if let sheetViewValue = sheetViewValues[shp] {
                sheetViewValue.workItem?.cancel()
                
                if let sheetView = sheetViewValue.view {
                    sheetView.node.updateCache()
                }
                if let sheetView = sheetViewValue.view,
                   let sheetRecorder = sheetRecorders[sheetViewValue.sheetID],
                   sheetRecorder.sheetRecord.isWillwrite {
                    
                    if savingItem != nil {
                        savingFuncs.append { [sid = sheetViewValue.sheetID,
                                              model = sheetView.model, um = sheetView.history,
                                              tm = thumbnailMipmap(from: sheetView), weak self] in
                            
                            sheetRecorder.sheetRecord.value = model
                            sheetRecorder.sheetRecord.isWillwrite = true
                            sheetRecorder.sheetHistoryRecord.value = um
                            sheetRecorder.sheetHistoryRecord.isWillwrite = true
                            self?.updateStringRecord(at: sid, with: sheetView)
                            if let tm = tm {
                                self?.saveThumbnailRecord(tm, in: sheetRecorder)
                                self?.baseThumbnailDatas[sid] = Texture.bytesData(with: tm.thumbnail4Data)
                            }
                        }
                    } else {
                        sheetRecorder.sheetRecord.value = sheetView.model
                        sheetRecorder.sheetHistoryRecord.value = sheetView.history
                        sheetRecorder.sheetHistoryRecord.isWillwrite = true
                        makeThumbnailRecord(at: sheetViewValue.sheetID, with: sheetView)
                        sheetRecorder.sheetRecord.willwriteClosure = { (_) in }
                    }
                }
                
                updateThumbnail(sheetViewValue, at: shp, sid)
                sheetViewValues[shp]?.view?.node.removeFromParent()
                sheetViewValues[shp] = nil
                sheetViewValue.view?.node.removeFromParent()
                updateFindingNodes(at: shp)
            }
            updateSelects()
        case .sheet:
            var item: DispatchWorkItem!
            item = DispatchWorkItem(qos: qos) { [weak self] in
                defer { item = nil }
                guard let aSelf = self,
                      !item.isCancelled,
                      let sheetRecorder = aSelf.sheetRecorders[sid] else { return }
                let sheetRecord = sheetRecorder.sheetRecord
                let historyRecord = sheetRecorder.sheetHistoryRecord
                
                let sheet = sheetRecord.decodedValue ?? Sheet(message: "Failed to load".localized)
                let sheetBinder = RecordBinder(value: sheet, record: sheetRecord)
                let sheetView = SheetView(binder: sheetBinder, keyPath: \SheetBinder.value)
                if let history = historyRecord.decodedValue {
                    sheetView.history = history
                }
                let frame = aSelf.sheetFrame(with: shp)
                sheetView.node.path = Path(Rect(size: frame.size))
                sheetView.node.attitude.position = frame.origin
                sheetView.node.allChildrenAndSelf { $0.updateBuffers() }
                if let thumbnail = sheetRecorder.thumbnail1024Record.decodedValue {
                    do {
                        try Texture.texture(mipmapImage: thumbnail, completionHandler: { texture in
                            sheetView.node.cacheTexture = texture
                            
                        }, cancelHandler: { _ in
//                            sheetView.enableCache = true
                        })
                    } catch {
//                        sheetView.enableCache = true
                    }
                } else {
//                    sheetView.enableCache = true
                }
                
                DispatchQueue.main.async {
                    guard aSelf.sheetID(at: shp) == sid,
                          aSelf.sheetViewValues[shp] != nil else { return }
                    sheetRecord.willwriteClosure = { [weak sheetView, weak self, weak historyRecord] (record) in
                        if let sheetView = sheetView {
                            record.value = sheetView.model
                            historyRecord?.value = sheetView.history
                            historyRecord?.isPreparedWrite = true
                            self?.makeThumbnailRecord(at: sid, with: sheetView)
                        }
                    }
                    
                    aSelf.sheetView(at: shp)?.node.removeFromParent()
                    aSelf.sheetViewValues[shp] = SheetViewValue(sheetID: sid, view: sheetView,
                                                                workItem: nil)
                    if sheetView.node.parent == nil {
                        aSelf.sheetsNode.append(child: sheetView.node)
                        sheetView.node.enableCache = true
                    }
                    aSelf.thumbnailNodeValues[shp]?.node?.removeFromParent()
                    
                    aSelf.updateSelects()
                    aSelf.updateFindingNodes(at: shp)
                    if shp == aSelf.sheetPosition(at: aSelf.convertScreenToWorld(aSelf.cursorPoint)) {
                        aSelf.updateTextCursor()
                    }
                }
            }
            sheetViewValues[shp]?.view?.node.removeFromParent()
            sheetViewValues[shp] = SheetViewValue(sheetID: sid, view: nil,
                                                  workItem: item)
            queue.async(execute: item)
        }
    }
    
    func renderableSheetNode(at sid: SheetID) -> Node? {
        guard let shp = sheetPosition(at: sid) else { return nil }
        guard let sheet = sheetRecorders[sid]?
                .sheetRecord.decodedValue else { return nil }
        let node = sheet.node(isBorder: false)
        node.attitude.position = sheetFrame(with: shp).origin
        return node
    }
    
    func readSheetView(at sid: SheetID) -> SheetView? {
        guard let shp = sheetPosition(at: sid) else { return nil }
        return sheetView(at: shp) ?? readSheetView(at: sid, shp)
    }
    func readSheetView(at shp: SheetPosition) -> SheetView? {
        if let sheetView = sheetView(at: shp) {
            return sheetView
        } else if let sid = sheetID(at: shp) {
            return readSheetView(at: sid, shp)
        } else {
            return nil
        }
    }
    func readSheetView(at p: Point) -> SheetView? {
        readSheetView(at: sheetPosition(at: p))
    }
    func readSheetView(at sid: SheetID, _ shp: SheetPosition,
                       isUpdateNode: Bool = false) -> SheetView? {
        guard let sheetRecorder = sheetRecorders[sid] else { return nil }
        let sheetRecord = sheetRecorder.sheetRecord
        let sheetHistoryRecord = sheetRecorder.sheetHistoryRecord
        
        guard let sheet = sheetRecord.decodedValue else { return nil }
        let sheetBinder = RecordBinder(value: sheet, record: sheetRecord)
        let sheetView = SheetView(binder: sheetBinder, keyPath: \SheetBinder.value)
        if let history = sheetHistoryRecord.decodedValue {
            sheetView.history = history
        }
        let frame = sheetFrame(with: shp)
        sheetView.node.path = Path(Rect(size: frame.size))
        sheetView.node.attitude.position = frame.origin
        sheetView.node.allChildrenAndSelf { $0.updateBuffers() }
        sheetView.node.enableCache = true
        
        sheetRecord.willwriteClosure = { [weak sheetView, weak sheetHistoryRecord, weak self] (record) in
            if let sheetView = sheetView {
                record.value = sheetView.model
                sheetHistoryRecord?.value = sheetView.history
                sheetHistoryRecord?.isPreparedWrite = true
                self?.makeThumbnailRecord(at: sid, with: sheetView)
            }
        }
        
        if isUpdateNode {
            self.sheetView(at: shp)?.node.removeFromParent()
            sheetViewValues[shp] = SheetViewValue(sheetID: sid, view: sheetView, workItem: nil)
            if sheetView.node.parent == nil {
                sheetsNode.append(child: sheetView.node)
            }
            thumbnailNodeValues[shp]?.node?.removeFromParent()
        }
        
        return sheetView
    }
    
    func sheetPosition(at sid: SheetID) -> SheetPosition? {
        world.sheetPositions[sid]
    }
    func sheetID(at shp: SheetPosition) -> SheetID? {
        world.sheetIDs[shp]
    }
    func sheetPosition(at p: Point) -> SheetPosition {
        let p = Document.maxSheetAABB.clippedPoint(with: p)
        return SheetPosition(Int((p.x / Sheet.width).rounded(.down)),
                             Int((p.y / Sheet.height).rounded(.down)))
    }
    func sheetFrame(with shp: SheetPosition) -> Rect {
        Rect(x: Double(shp.x) * Sheet.width,
             y: Double(shp.y) * Sheet.height,
             width: Sheet.width,
             height: Sheet.height)
    }
    func sheetView(at p: Point) -> SheetView? {
        sheetViewValues[sheetPosition(at: p)]?.view
    }
    func sheetViewValue(at shp: SheetPosition) -> SheetViewValue? {
        sheetViewValues[shp]
    }
    func sheetView(at shp: SheetPosition) -> SheetView? {
        sheetViewValues[shp]?.view
    }
    func thumbnailNode(at shp: SheetPosition) -> Node? {
        thumbnailNodeValues[shp]?.node
    }
    
    func madeReadSheetView(at p: Point,
                           isNewUndoGroup: Bool = true) -> SheetView? {
        let shp = sheetPosition(at: p)
        if let ssv = madeSheetView(at: shp,
                                   isNewUndoGroup: isNewUndoGroup) {
            return ssv
        } else if let sid = sheetID(at: shp) {
            return readSheetView(at: sid, shp, isUpdateNode: true)
        } else {
            return nil
        }
    }
    
    @discardableResult
    func madeSheetView(at p: Point,
                       isNewUndoGroup: Bool = true) -> SheetView? {
        madeSheetView(at: sheetPosition(at: p), isNewUndoGroup: isNewUndoGroup)
    }
    @discardableResult
    func madeSheetView(at shp: SheetPosition,
                       isNewUndoGroup: Bool = true) -> SheetView? {
        if let sheetView = sheetView(at: shp) { return sheetView }
        if sheetID(at: shp) != nil { return nil }
        let newSID = SheetID()
        guard !contains(at: newSID) else { return nil }
        return append(Sheet(), history: nil, at: newSID, at: shp,
                      isNewUndoGroup: isNewUndoGroup)
    }
    @discardableResult
    func madeSheetViewIsNew(at shp: SheetPosition,
                            isNewUndoGroup: Bool = true) -> (SheetView,
                                                             isNew: Bool)? {
        if let sheetView = sheetView(at: shp) { return (sheetView, false) }
        if sheetID(at: shp) != nil { return nil }
        let newSID = SheetID()
        guard !contains(at: newSID) else { return nil }
        return (append(Sheet(), history: nil, at: newSID, at: shp,
                       isNewUndoGroup: isNewUndoGroup), true)
    }
    @discardableResult
    func madeSheetView(with sheet: Sheet,
                       history: SheetHistory?,
                       at shp: SheetPosition,
                       isNewUndoGroup: Bool = true) -> SheetView? {
        if let sheetView = sheetView(at: shp) {
            sheetView.node.removeFromParent()
        }
        let newSID = SheetID()
        guard !contains(at: newSID) else { return nil }
        return append(sheet, history: history,
                      at: newSID, at: shp,
                      isNewUndoGroup: isNewUndoGroup)
    }
    @discardableResult
    func append(_ sheet: Sheet, history: SheetHistory?,
                at sid: SheetID, at shp: SheetPosition,
                isNewUndoGroup: Bool = true) -> SheetView {
        if isNewUndoGroup {
            newUndoGroup()
        }
        append([shp: sid], enableNode: false)
        
        let sheetRecorder = makeSheetRecorder(at: sid)
        let sheetRecord = sheetRecorder.sheetRecord
        let sheetHistoryRecord = sheetRecorder.sheetHistoryRecord
        
        let sheetBinder = RecordBinder(value: sheet, record: sheetRecord)
        let sheetView = SheetView(binder: sheetBinder, keyPath: \SheetBinder.value)
        if let history = history {
            sheetView.history = history
        }
        let frame = sheetFrame(with: shp)
        sheetView.node.path = Path(Rect(size: frame.size))
        sheetView.node.attitude.position = frame.origin
        sheetView.node.allChildrenAndSelf { $0.updateBuffers() }
        sheetView.node.enableCache = true
        
        sheetRecord.willwriteClosure = { [weak sheetView, weak sheetHistoryRecord, weak self] (record) in
            if let sheetView = sheetView {
                record.value = sheetView.model
                sheetHistoryRecord?.value = sheetView.history
                sheetHistoryRecord?.isPreparedWrite = true
                self?.makeThumbnailRecord(at: sid, with: sheetView)
            }
        }
        
        self.sheetView(at: shp)?.node.removeFromParent()
        sheetRecorders[sid] = sheetRecorder
        sheetViewValues[shp]?.view?.node.removeFromParent()
        sheetViewValues[shp] = SheetViewValue(sheetID: sid, view: sheetView, workItem: nil)
        sheetsNode.append(child: sheetView.node)
        updateMap()
        
        return sheetView
    }
    @discardableResult
    func duplicateSheet(from sid: SheetID) -> SheetID {
        let nsid = SheetID()
        let nsrr = makeSheetRecorder(at: nsid)
        if let shp = sheetPosition(at: sid),
           let sheetView = sheetView(at: shp) {
            nsrr.sheetRecord.value = sheetView.model
            nsrr.sheetHistoryRecord.value = sheetView.history
            hideSelectedRange {
                if let t = thumbnailMipmap(from: sheetView) {
                    saveThumbnailRecord(t, in: nsrr)
                }
            }
        } else if let osrr = sheetRecorders[sid] {
            nsrr.sheetRecord.data
                = osrr.sheetRecord.valueDataOrDecodedData
            nsrr.thumbnail4Record.data
                = osrr.thumbnail4Record.valueDataOrDecodedData
            nsrr.thumbnail16Record.data
                = osrr.thumbnail16Record.valueDataOrDecodedData
            nsrr.thumbnail64Record.data
                = osrr.thumbnail64Record.valueDataOrDecodedData
            nsrr.thumbnail256Record.data
                = osrr.thumbnail256Record.valueDataOrDecodedData
            nsrr.thumbnail1024Record.data
                = osrr.thumbnail1024Record.valueDataOrDecodedData
            nsrr.sheetHistoryRecord.data
                = osrr.sheetHistoryRecord.valueDataOrDecodedData
            nsrr.stringRecord.data
                = osrr.stringRecord.valueDataOrDecodedData
        }
        nsrr.sheetRecord.isWillwrite = true
        nsrr.thumbnail4Record.isWillwrite = true
        nsrr.thumbnail16Record.isWillwrite = true
        nsrr.thumbnail64Record.isWillwrite = true
        nsrr.thumbnail256Record.isWillwrite = true
        nsrr.thumbnail1024Record.isWillwrite = true
        nsrr.sheetHistoryRecord.isWillwrite = true
        nsrr.stringRecord.isWillwrite = true
        append(nsrr, at: nsid)
        return nsid
    }
    func appendSheet(from osrr: SheetRecorder) -> SheetID {
        let nsid = SheetID()
        let nsrr = makeSheetRecorder(at: nsid)
        nsrr.sheetRecord.data
            = osrr.sheetRecord.valueDataOrDecodedData
        nsrr.thumbnail4Record.data
            = osrr.thumbnail4Record.valueDataOrDecodedData
        nsrr.thumbnail16Record.data
            = osrr.thumbnail16Record.valueDataOrDecodedData
        nsrr.thumbnail64Record.data
            = osrr.thumbnail64Record.valueDataOrDecodedData
        nsrr.thumbnail256Record.data
            = osrr.thumbnail256Record.valueDataOrDecodedData
        nsrr.thumbnail1024Record.data
            = osrr.thumbnail1024Record.valueDataOrDecodedData
        nsrr.sheetHistoryRecord.data
            = osrr.sheetHistoryRecord.valueDataOrDecodedData
        nsrr.stringRecord.data
            = osrr.stringRecord.valueDataOrDecodedData
        nsrr.sheetRecord.isWillwrite = true
        nsrr.thumbnail4Record.isWillwrite = true
        nsrr.thumbnail16Record.isWillwrite = true
        nsrr.thumbnail64Record.isWillwrite = true
        nsrr.thumbnail256Record.isWillwrite = true
        nsrr.thumbnail1024Record.isWillwrite = true
        nsrr.sheetHistoryRecord.isWillwrite = true
        nsrr.stringRecord.isWillwrite = true
        append(nsrr, at: nsid)
        return nsid
    }
    func removeSheet(at sid: SheetID, for shp: SheetPosition) {
        if let sheetRecorder = sheetRecorders[sid] {
            remove(sheetRecorder)
            sheetRecorders[sid] = nil
        }
        if let sheetViewValue = sheetViewValues[shp] {
            sheetViewValue.view?.node.removeFromParent()
            sheetViewValues[shp] = nil
        }
        updateMap()
    }
    
    private(set) var lastEditedSheetPosition: SheetPosition?
    private var lastEditedSheetNode: Node?
    func updateLastEditedSheetPosition(from event: Event) {
        lastEditedSheetPosition
            = sheetPosition(at: convertScreenToWorld(event.screenPoint))
    }
    var isShownLastEditedSheet = false {
        didSet {
            updateSelectedColor(isMain: true)
            lastEditedSheetNode?.removeFromParent()
            lastEditedSheetNode = nil
            if isShownLastEditedSheet {
                if let shp = lastEditedSheetPosition {
                    let f = sheetFrame(with: shp)
                    if let r = selections.first?.rect,
                       worldBounds.intersects(r) && !r.intersects(f)
                        && worldBounds.intersects(f) {
                        
                        updateSelectedColor(isMain: false)
                    }
                    let selectedSheetNode = Node(path: Path(f),
                                                 lineWidth: worldLineWidth,
                                                 lineType: .color(.selected),
                                                 fillType: .color(.subSelected))
                    rootNode.append(child: selectedSheetNode)
                    self.lastEditedSheetNode = selectedSheetNode
                }
            }
        }
    }
    var isNoneCursor = false
    private var lastEditedSheetPositionInView: SheetPosition? {
        if let shp = lastEditedSheetPosition {
            let f = sheetFrame(with: shp)
            if worldBounds.intersects(f) {
                if let r = selections.first?.rect {
                    if !f.contains(r)
                        && (!worldBounds.intersects(r) || !r.intersects(f)) {
                        return shp
                    }
                } else {
                    return shp
                }
            }
        }
        return nil
    }
    var lastEditedSheetPositionNoneCursor: SheetPosition? {
        guard isNoneCursor else { return nil }
        return lastEditedSheetPositionInView
    }
    func isSelectNoneCursor(at p: Point) -> Bool {
        (isNoneCursor && lastEditedSheetPositionNoneCursor == nil)
            || isSelect(at: p)
    }
    var lastEditedSheetWorldCenterPositionNoneCursor: Point? {
        if let shp = lastEditedSheetPositionNoneCursor {
            return sheetFrame(with: shp).centerPoint
        } else {
            return nil
        }
    }
    var lastEditedSheetScreenCenterPositionNoneCursor: Point? {
        if let p = lastEditedSheetWorldCenterPositionNoneCursor {
            return convertWorldToScreen(p)
        } else {
            return nil
        }
    }
    var selectedScreenPositionNoneCursor: Point? {
        guard isNoneCursor else { return nil }
        if let r = selections.first?.rect {
            if let shp = lastEditedSheetPosition {
                let f = sheetFrame(with: shp)
                if worldBounds.intersects(f), r.intersects(f) {
                    return convertWorldToScreen(r.centerPoint)
                }
            }
        }
        return lastEditedSheetScreenCenterPositionNoneCursor
    }
    func isSelectSelectedNoneCursor(at p: Point) -> Bool {
        (isNoneCursor && selectedScreenPositionNoneCursor == nil)
            || isSelect(at: p)
    }
    var selectedSheetViewNoneCursor: SheetView? {
        guard isNoneCursor else { return nil }
        if let shp = lastEditedSheetPosition {
            return readSheetView(at: shp)
        } else {
            return nil
        }
    }
    var lastEditedSheetWorldCenterPositionNoneSelectedNoneCursor: Point? {
        guard isNoneCursor else { return nil }
        if let shp = lastEditedSheetPosition {
            let f = sheetFrame(with: shp)
            if worldBounds.intersects(f) {
                return f.centerPoint
            }
        }
        return nil
    }
    var lastEditedSheetScreenCenterPositionNoneSelectedNoneCursor: Point? {
        if let p = lastEditedSheetWorldCenterPositionNoneSelectedNoneCursor {
            return convertWorldToScreen(p)
        } else {
            return nil
        }
    }
    var isSelectedNoneCursor: Bool {
        guard isNoneCursor else { return false }
        if lastEditedSheetPositionInView != nil {
            return true
        } else if let r = selections.first?.rect {
            var isIntersects = false
            for shp in world.sheetIDs.keys {
                let frame = sheetFrame(with: shp)
                if r.intersects(frame) && worldBounds.intersects(frame) {
                    isIntersects = true
                }
            }
            return isIntersects
        } else {
            return false
        }
    }
    var isSelectedOnlyNoneCursor: Bool {
        guard isNoneCursor else { return false }
        if let r = selections.first?.rect {
            if let shp = lastEditedSheetPosition {
                let f = sheetFrame(with: shp)
                if worldBounds.intersects(f), r.intersects(f) {
                    return true
                }
            }
        }
        return false
    }
    
    func sheetViewAndFrame(at p: Point) -> (shp: SheetPosition,
                                              sheetView: SheetView?,
                                              frame: Rect,
                                              isAll: Bool) {
        let shp = sheetPosition(at: p)
        let frame = sheetFrame(with: shp)
        if let sheetView = sheetView(at: p) {
            if !isEditingSheet {
                return (shp, sheetView, frame, true)
            } else {
                let (bounds, isAll) = sheetView.model.boundsTuple(at: sheetView.convertFromWorld(p))
                return (shp, sheetView, bounds + frame.origin, isAll)
            }
        } else {
            return (shp, nil, frame, false)
        }
    }
    
    func worldBorder(at p: Point,
                     distance d: Double) -> (border: Border, edge: Edge)? {
        let shp = sheetPosition(at: p)
        let b = sheetFrame(with: shp)
        let topEdge = b.topEdge
        if topEdge.distance(from: p) < d {
            return (Border(.horizontal), topEdge)
        }
        let bottomEdge = b.bottomEdge
        if bottomEdge.distance(from: p) < d {
            return (Border(.horizontal), bottomEdge)
        }
        let leftEdge = b.leftEdge
        if leftEdge.distance(from: p) < d {
            return (Border(.vertical), leftEdge)
        }
        let rightEdge = b.rightEdge
        if rightEdge.distance(from: p) < d {
            return (Border(.vertical), rightEdge)
        }
        return nil
    }
    func border(at p: Point,
                distance d: Double) -> (border: Border, index: Int, edge: Edge)? {
        let shp = sheetPosition(at: p)
        guard let sheetView = sheetView(at: shp) else { return nil }
        let b = sheetFrame(with: shp)
        let inP = sheetView.convertFromWorld(p)
        for (i, border) in sheetView.model.borders.enumerated() {
            switch border.orientation {
            case .horizontal:
                if abs(inP.y - border.location) < d {
                    return (border, i,
                            Edge(Point(0, border.location) + b.origin,
                                 Point(b.width, border.location) + b.origin))
                }
            case .vertical:
                if abs(inP.x - border.location) < d {
                    return (border, i,
                            Edge(Point(border.location, 0) + b.origin,
                                 Point(border.location, b.height) + b.origin))
                }
            }
        }
        return nil
    }
    
    func colorPathValue(at p: Point, toColor: Color?,
                        color: Color, subColor: Color) -> ColorPathValue {
        if let sheetView = sheetView(at: p) {
            let inP = sheetView.convertFromWorld(p)
            return sheetView.sheetColorOwner(at: inP)
                .colorPathValue(toColor: toColor, color: color, subColor: subColor)
        } else {
            let shp = sheetPosition(at: p)
            return ColorPathValue(paths: [Path(sheetFrame(with: shp))],
                                  lineType: .color(color),
                                  fillType: .color(subColor))
        }
    }
    func uuColor(at p: Point) -> UUColor {
        if let sheetView = sheetView(at: p) {
            let inP = sheetView.convertFromWorld(p)
            return sheetView.sheetColorOwner(at: inP).uuColor
        } else {
            return Sheet.defalutBackgroundUUColor
        }
    }
    func madeColorOwner(at p: Point) -> [SheetColorOwner] {
        guard let sheetView = madeSheetView(at: p) else {
            return []
        }
        let inP = sheetView.convertFromWorld(p)
        return [sheetView.sheetColorOwner(at: inP)]
    }
    func readColorOwner(at p: Point) -> [SheetColorOwner] {
        guard let sheetView = readSheetView(at: p) else {
            return []
        }
        let inP = sheetView.convertFromWorld(p)
        return [sheetView.sheetColorOwner(at: inP)]
    }
    func isDefaultUUColor(at p: Point) -> Bool {
        if let sheetView = sheetView(at: p) {
            let inP = sheetView.convertFromWorld(p)
            return sheetView.sheetColorOwner(at: inP).uuColor
                == Sheet.defalutBackgroundUUColor
        } else {
            return true
        }
    }
    
    let mapWidth = Sheet.width * 10, mapHeight = Sheet.height * 10
    private var mapSheetPositions = Set<SheetPosition>()
    func mapSheetPosition(at shp: SheetPosition) -> SheetPosition {
        let x = (Rational(shp.x) / 10).rounded(.down).integralPart
        let y = (Rational(shp.y) / 10).rounded(.down).integralPart
        return SheetPosition(x, y)
    }
    func mapPosition(at shp: SheetPosition) -> Point {
        Point(Double(shp.x) * mapWidth + mapWidth / 2,
              Double(shp.y) * mapHeight + mapHeight / 2)
    }
    func mapFrame(at shp: SheetPosition) -> Rect {
        Rect(x: Double(shp.x) * mapWidth,
             y: Double(shp.y) * mapHeight,
             width: mapWidth, height: mapHeight)
    }
    private var roads = [Road]()
    func updateMap() {
        mapSheetPositions = Set(sheetRecorders.keys.compactMap {
            if let shp = sheetPosition(at: $0) {
                return mapSheetPosition(at: shp)
            } else {
                return nil
            }
        })
        var roads = [Road]()
        
        var xSHPs = [Int: [SheetPosition]]()
        for mSHP in mapSheetPositions {
            if xSHPs[mSHP.y] != nil {
                xSHPs[mSHP.y]?.append(mSHP)
            } else {
                xSHPs[mSHP.y] = [mSHP]
            }
        }
        let sortedSHPs = xSHPs.sorted { $0.key < $1.key }
        var previousSHPs = [SheetPosition]()
        for shpV in sortedSHPs {
            let sortedXSHPs = shpV.value.sorted { $0.x < $1.x }
            if sortedXSHPs.count > 1 {
                for i in 1..<sortedXSHPs.count {
                    roads.append(Road(shp0: sortedXSHPs[i - 1],
                                                        shp1: sortedXSHPs[i]))
                }
            }
            if !previousSHPs.isEmpty {
                roads.append(Road(shp0: previousSHPs[0],
                                                    shp1: sortedXSHPs[0]))
            }
            previousSHPs = sortedXSHPs
        }
        
        self.roads = roads
        
        let pathlines = roads.compactMap {
            $0.pathlineWith(width: mapWidth, height: mapHeight)
        }
        mapNode.path = Path(pathlines, isCap: false)
    }
    func updateMapWith(worldToScreenTransform: Transform,
                       screenToWorldTransform: Transform,
                       camera: Camera,
                       in screenBounds: Rect) {
        let worldBounds = screenBounds * screenToWorldTransform
        for road in roads {
            if worldBounds.intersects(Edge(mapPosition(at: road.shp0),
                                           mapPosition(at: road.shp1))) {
                currentMapNode.isHidden = true
                currentMapNode.path = Path()
                return
            }
        }
        if currentMapNode.isHidden {
            currentMapNode.isHidden = false
        }
        
        let worldCP = screenBounds.centerPoint * screenToWorldTransform
        
        let currentSHP = sheetPosition(at: worldCP)
        let mapSHP = mapSheetPosition(at: currentSHP)
        var minMSHP: SheetPosition?, minDSquared = Int.max
        for mshp in mapSheetPositions {
            let dSquared = mshp.distanceSquared(mapSHP)
            if dSquared < minDSquared {
                minDSquared = dSquared
                minMSHP = mshp
            }
        }
        if let minMSHP = minMSHP {
            let road = Road(shp0: minMSHP, shp1: mapSHP)
            if let pathline = road.pathlineWith(width: mapWidth,
                                                height: mapHeight) {
                currentMapNode.path = Path([pathline])
            } else {
                currentMapNode.path = Path()
            }
        } else {
            currentMapNode.path = Path()
        }
    }
    func updateGrid(with transform: Transform, in bounds: Rect) {
        let bounds = bounds * transform, lw = gridNode.lineWidth
        let w = Sheet.width, h = Sheet.height
        let cp = Point()
        var pathlines = [Pathline]()
        let minXIndex = Int(((bounds.minX - cp.x - lw) / w).rounded(.down))
        let maxXIndex = Int(((bounds.maxX - cp.x + lw) / w).rounded(.up))
        if maxXIndex - minXIndex > 0 {
            let minY = bounds.minY, maxY = bounds.maxY
            for i in minXIndex..<maxXIndex {
                let x = Double(i) * w + cp.x
                pathlines.append(Pathline(Edge(Point(x: x, y: minY),
                                               Point(x: x, y: maxY))))
            }
        }
        let minYIndex = Int(((bounds.minY - cp.y - lw) / h).rounded(.down))
        let maxYIndex = Int(((bounds.maxY - cp.y + lw) / h).rounded(.up))
        if maxYIndex - minYIndex > 0 {
            let minX = bounds.minX, maxX = bounds.maxX
            for i in minYIndex..<maxYIndex {
                let y = Double(i) * h + cp.y
                pathlines.append(Pathline(Edge(Point(x: minX, y: y),
                                               Point(x: maxX, y: y))))
            }
        }
        gridNode.path = Path(pathlines, isCap: false)
        gridNode.lineWidth = transform.absXScale
        
        updateMapColor(with: transform)
    }
    private enum MapType {
        case hidden, shown
    }
    private var oldMapType = MapType.hidden
    func updateMapColor(with transform: Transform) {
        let mapType: MapType = isEditingSheet ? .hidden : .shown
        switch mapType {
        case .hidden:
            if oldMapType != .hidden {
                mapNode.isHidden = true
                backgroundColor = .background
                gridNode.lineType = .color(.border)
                mapNode.lineType = .color(.border)
                currentMapNode.lineType = .color(.border)
            }
        case .shown:
            let scale = transform.absXScale
            mapNode.lineWidth = 3 * scale
            currentMapNode.lineWidth = 3 * scale
            if oldMapType != .shown {
                if oldMapType == .hidden {
                    mapNode.isHidden = false
                    backgroundColor = .disabled
                    gridNode.lineType = .color(.subBorder)
                    mapNode.lineType = .color(.subBorder)
                    currentMapNode.lineType = .color(.subBorder)
                }
            }
        }
        oldMapType = mapType
    }
    
    var modifierKeys = ModifierKeys()
    
    func indicate(with event: DragEvent) {
        cursorPoint = event.screenPoint
        textEditor.isMovedCursor = true
        textEditor.moveEndInputKey(isStopFromMarkedText: true)
    }
    
    private(set) var oldPinchEvent: PinchEvent?, zoomer: Zoomer?
    func pinch(_ event: PinchEvent) {
        switch event.phase {
        case .began:
            zoomer = Zoomer(self)
            zoomer?.send(event)
            oldPinchEvent = event
        case .changed:
            zoomer?.send(event)
            oldPinchEvent = event
        case .ended:
            oldPinchEvent = nil
            zoomer?.send(event)
            zoomer = nil
        }
    }
    
    private(set) var oldScrollEvent: ScrollEvent?, scroller: Scroller?
    func scroll(_ event: ScrollEvent) {
        textEditor.moveEndInputKey()
        switch event.phase {
        case .began:
            scroller = Scroller(self)
            scroller?.send(event)
            oldScrollEvent = event
        case .changed:
            scroller?.send(event)
            oldScrollEvent = event
        case .ended:
            oldScrollEvent = nil
            scroller?.send(event)
            scroller = nil
        }
    }
    
    private(set) var oldRotateEvent: RotateEvent?, rotater: Rotater?
    func rotate(_ event: RotateEvent) {
        switch event.phase {
        case .began:
            rotater = Rotater(self)
            rotater?.send(event)
            oldRotateEvent = event
        case .changed:
            rotater?.send(event)
            oldRotateEvent = event
        case .ended:
            oldRotateEvent = nil
            rotater?.send(event)
            rotater = nil
        }
    }
    
    private func dragEditor(with quasimode: Quasimode) -> DragEditor? {
        switch quasimode {
        case .drawLine: return LineDrawer(self)
        case .drawStraightLine: return StraightLineDrawer(self)
        case .lassoCut: return LassoCutter(self)
        case .select: return Selector(self)
        case .changeLightness: return LightnessChanger(self)
        case .changeTint: return TintChanger(self)
        case .selectVersion: return VersionSelector(self)
        default: return nil
        }
    }
    private(set) var oldDragEvent: DragEvent?, dragEditor: DragEditor?
    func drag(_ event: DragEvent) {
        switch event.phase {
        case .began:
            updateLastEditedSheetPosition(from: event)
            stopInputTextEvent()
            stopInputKeyEvent()
            let quasimode = Quasimode(modifier: modifierKeys, .drag)
            dragEditor = self.dragEditor(with: quasimode)
            dragEditor?.send(event)
            oldDragEvent = event
            textCursorNode.isHidden = true
        case .changed:
            dragEditor?.send(event)
            oldDragEvent = event
        case .ended:
            oldDragEvent = nil
            dragEditor?.send(event)
            dragEditor = nil
            cursorPoint = event.screenPoint
        }
    }
    
    private(set) var oldInputTextKeys = Set<InputKeyType>()
    lazy private(set) var textEditor: TextEditor = { TextEditor(self) } ()
    func inputText(_ event: InputTextEvent) {
        switch event.phase {
        case .began:
            updateLastEditedSheetPosition(from: event)
            oldInputTextKeys.insert(event.inputKeyType)
            textEditor.send(event)
        case .changed:
            textEditor.send(event)
        case .ended:
            oldInputTextKeys.remove(event.inputKeyType)
            textEditor.send(event)
        }
    }
    
    var runners = Set<RunEditor>() {
        didSet {
            updateRunners()
        }
    }
    var runnerNodes = [(origin: Point, node: Node)]()
    var runnersNode: Node?
    func updateRunners() {
        runnerNodes.forEach { $0.node.removeFromParent() }
        runnerNodes = runners.map {
            let text = Text(string: "Calculating".localized)
            let textNode = text.node
            let node = Node(children: [textNode], isHidden: true,
                            path: Path(textNode.bounds?
                                        .inset(by: -10) ?? Rect(),
                                       cornerRadius: 8),
                            lineWidth: 1, lineType: .color(.border),
                            fillType: .color(.background))
            return ($0.printOrigin, node)
        }
        runnerNodes.forEach { rootNode.append(child: $0.node) }
        
        updateRunnerNodesPosition()
    }
    func updateRunnerNodesPosition() {
        guard !runnerNodes.isEmpty else { return }
        let b = screenBounds.inset(by: 5)
        for (p, node) in runnerNodes {
            let sp = convertWorldToScreen(p)
            if !b.contains(sp) || worldToScreenScale < 0.25 {
                node.isHidden = false
                
                let fp = b.centerPoint
                let ps = b.intersection(Edge(fp, sp))
                if !ps.isEmpty, let cvb = node.bounds {
                    let np = ps[0]
                    let cvf = Rect(x: np.x - cvb.width / 2,
                                   y: np.y - cvb.height / 2,
                                   width: cvb.width, height: cvb.height)
                    let nf = screenBounds.inset(by: 5).clipped(cvf)
                    node.attitude.position
                        = convertScreenToWorld(nf.origin - cvb.origin)
                } else {
                    node.attitude.position = p
                }
                node.attitude.scale = Size(square: 1 / worldToScreenScale)
                if camera.rotation != 0 {
                    node.attitude.rotation = camera.rotation
                }
            } else {
                node.isHidden = true
            }
        }
    }
    
    private func inputKeyEditor(with quasimode: Quasimode) -> InputKeyEditor? {
        switch quasimode {
        case .cut: return Cutter(self)
        case .copy: return Copier(self)
        case .paste: return Paster(self)
        case .undo: return Undoer(self)
        case .redo: return Redoer(self)
        case .find:
            return System.isVersion2 ? Finder(self) : nil
        case .lookUp: return Looker(self)
//        case .unselect: return Unselector(self)
        case .changeToVerticalText: return VerticalTextChanger(self)
        case .changeToHorizontalText: return HorizontalTextChanger(self)
        case .changeToSuperscript:
            return System.isVersion2 ? SuperscriptChanger(self) : nil
        case .changeToSubscript:
            return System.isVersion2 ? SubscriptChanger(self) : nil
        case .run: return Runner(self)
        case .changeToDraft: return DraftChanger(self)
        case .cutDraft: return DraftCutter(self)
        case .makeFaces: return FacesMaker(self)
        case .cutFaces: return FacesCutter(self)
        default: return nil
        }
    }
    private(set) var oldInputKeyEvent: InputKeyEvent?
    private(set) var inputKeyEditor: InputKeyEditor?
//    var inputKeyEditorNotification: ((Document, InputKeyEditor?,
//                                      InputKeyEvent) -> ())?
    func inputKey(_ event: InputKeyEvent) {
        switch event.phase {
        case .began:
            updateLastEditedSheetPosition(from: event)
            guard inputKeyEditor == nil else { return }
            let quasimode = Quasimode(modifier: modifierKeys,
                                      event.inputKeyType)
            if System.isVersion2 {
                if textEditor.editingTextView != nil
                    && quasimode != .changeToSuperscript
                    && quasimode != .changeToSubscript
                    && quasimode != .changeToHorizontalText
                    && quasimode != .changeToVerticalText
                    && quasimode != .paste {
                    
                    stopInputTextEvent(isEndEdit: quasimode != .undo
                                        && quasimode != .redo)
                }
                if quasimode == .run {
                    textEditor.moveEndInputKey()
                }
            } else {
                if textEditor.editingTextView != nil
                    && quasimode != .changeToHorizontalText
                    && quasimode != .changeToVerticalText
                    && quasimode != .paste {
                    
                    stopInputTextEvent(isEndEdit: quasimode != .undo
                                        && quasimode != .redo)
                }
            }
            stopDragEvent()
            inputKeyEditor = self.inputKeyEditor(with: quasimode)
//            inputKeyEditorNotification?(self, inputKeyEditor, event)
            inputKeyEditor?.send(event)
            oldInputKeyEvent = event
        case .changed:
//            inputKeyEditorNotification?(self, inputKeyEditor, event)
            inputKeyEditor?.send(event)
            oldInputKeyEvent = event
        case .ended:
            oldInputKeyEvent = nil
//            inputKeyEditorNotification?(self, inputKeyEditor, event)
            inputKeyEditor?.send(event)
            inputKeyEditor = nil
        }
    }
    
    func stop(with event: Event) {
        switch event.phase {
        case .began:
            cursor = .block
        case .changed:
            break
        case .ended:
            cursor = Document.defaultCursor
        }
    }
    
    func stopAllEvents(isEnableText: Bool = true) {
        stopPinchEvent()
        stopScrollEvent()
        stopDragEvent()
        if isEnableText {
            stopInputTextEvent()
        }
        stopInputKeyEvent()
        if isEnableText {
            textEditor.moveEndInputKey()
        }
        modifierKeys = []
    }
    func stopPinchEvent() {
        if var event = oldPinchEvent, let pinchEditor = zoomer {
            event.phase = .ended
            self.zoomer = nil
            oldPinchEvent = nil
            pinchEditor.send(event)
        }
    }
    func stopScrollEvent() {
        if var event = oldScrollEvent, let scrollEditor = scroller {
            event.phase = .ended
            self.scroller = nil
            oldScrollEvent = nil
            scrollEditor.send(event)
        }
    }
    func stopDragEvent() {
        if var event = oldDragEvent, let dragEditor = dragEditor {
            event.phase = .ended
            self.dragEditor = nil
            oldDragEvent = nil
            dragEditor.send(event)
        }
    }
    func stopInputTextEvent(isEndEdit: Bool = true) {
        oldInputTextKeys.removeAll()
        textEditor.stopInputKey(isEndEdit: isEndEdit)
    }
    func stopInputKeyEvent() {
        if var event = oldInputKeyEvent, let inputKeyEditor = inputKeyEditor {
            event.phase = .ended
            self.inputKeyEditor = nil
            oldInputKeyEvent = nil
            inputKeyEditor.send(event)
        }
    }
    func updateEditorNode() {
        zoomer?.updateNode()
        scroller?.updateNode()
        dragEditor?.updateNode()
        inputKeyEditor?.updateNode()
    }
}
