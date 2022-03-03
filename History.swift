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

typealias VersionPath = [Int]
struct Version: Hashable, Codable {
    var indexPath = VersionPath(), groupIndex = 0
}

enum UndoItemType {
    case unreversible, lazyReversible, reversible
}
protocol UndoItem: Codable, Protobuf {
    var type: UndoItemType { get }
    func reversed() -> Self?
}

struct UndoItemValue<T: UndoItem> {
    var undoItem: T
    var redoItem: T
}
extension UndoItemValue {
    init(undoItem: T, redoItem: T, isReversed: Bool) {
        if isReversed {
            self.undoItem = redoItem
            self.redoItem = undoItem
        } else {
            self.undoItem = undoItem
            self.redoItem = redoItem
        }
    }
    struct InitializeError: Error {}
    init(undoItem: T?, redoItem: T?) throws {
        var undoItem = undoItem, redoItem = redoItem
        if let undoItem = undoItem, undoItem.type == .lazyReversible {
            self.undoItem = undoItem
            self.redoItem = undoItem
        } else if let redoItem = redoItem, redoItem.type == .lazyReversible {
            self.undoItem = redoItem
            self.redoItem = redoItem
        } else {
            if let aUndoItem = redoItem?.reversed() {
                undoItem = aUndoItem
            } else if let aRedoItem = undoItem?.reversed() {
                redoItem = aRedoItem
            }
            if let undoItem = undoItem, let redoItem = redoItem {
                self.undoItem = undoItem
                self.redoItem = redoItem
            } else {
                throw InitializeError()
            }
        }
    }
    init(item: T, type: UndoType) throws {
        guard let reversedItem = item.reversed() else {
            throw InitializeError()
        }
        switch type {
        case .undo:
            self.undoItem = item
            self.redoItem = reversedItem
        case .redo:
            self.undoItem = reversedItem
            self.redoItem = item
        }
    }
    mutating func set(_ item: T, type: UndoType) {
        print("UndoItem set: \(item) \(type)")
        switch type {
        case .undo:
            undoItem = item
        case .redo:
            redoItem = item
        }
    }
    func encodeTuple() -> (undoItem: T, type: UndoType) {
        let undoType = undoItem.type, redoType = redoItem.type
        if undoType == .lazyReversible {
            return (undoItem, .undo)
        } else if redoType == .lazyReversible {
            return (redoItem, .redo)
        } else if undoType == .reversible {
            return (undoItem, .undo)
        } else {
            return (redoItem, .redo)
        }
    }
}
extension UndoItemValue: CustomStringConvertible {
    var description: String {
        "\nundo: \(undoItem),\nredo: \(redoItem)\n"
    }
}
extension UndoItemValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case undo, redo
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let undoItem = try? values.decode(T.self, forKey: .undo)
        let redoItem = try? values.decode(T.self, forKey: .redo)
        try self.init(undoItem: undoItem, redoItem: redoItem)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let (item, type) = encodeTuple()
        switch type {
        case .undo: try container.encode(item, forKey: .undo)
        case .redo: try container.encode(item, forKey: .redo)
        }
    }
}
struct UndoDataValue<T: UndoItem> {
    enum LoadType {
        case unload, loaded, error
    }
    
    var undoItemData = Data()
    var redoItemData = Data()
    var loadType = LoadType.unload
    var undoItemValue = UndoItemValue<T>?.none
    
    mutating func error() {
        print("Undo error: \(loadType) \(String(describing: undoItemValue))")
        loadType = .error
        undoItemData = Data()
        redoItemData = Data()
        undoItemValue = nil
    }
    var saveUndoItemValue: UndoItemValue<T>? {
        get {
            undoItemValue
        }
        set {
            undoItemValue = newValue
            save()
        }
    }
}
extension UndoDataValue {
    init(save itemValue: UndoItemValue<T>) {
        self.undoItemValue = itemValue
        self.loadType = .loaded
        save()
    }
    mutating func loadRedoItem() -> UndoItemValue<T>? {
        if loadType == .error {
            return nil
        } else if let undoItemValue = undoItemValue {
            return undoItemValue
        } else {
            let undoItem = try? T(serializedData: undoItemData)
            let redoItem = try? T(serializedData: redoItemData)
            if let undoItem = undoItem {
                if let redoItem = redoItem {
                    undoItemValue = UndoItemValue(undoItem: undoItem,
                                                  redoItem: redoItem)
                    loadType = .loaded
                    return undoItemValue
                } else if let redoItem = undoItem.reversed() {
                    undoItemValue = UndoItemValue<T>(undoItem: undoItem,
                                                     redoItem: redoItem)
                    loadType = .loaded
                    return undoItemValue
                } else {
                    loadType = .error
                    undoItemValue = nil
                    return nil
                }
            } else if let redoItem = redoItem, let undoItem = redoItem.reversed() {
                undoItemValue = UndoItemValue<T>(undoItem: undoItem,
                                                 redoItem: redoItem)
                loadType = .loaded
                return undoItemValue
            } else {
                loadType = .error
                undoItemValue = nil
                return nil
            }
        }
    }
    func loadedRedoItem() -> UndoItemValue<T>? {
        if loadType == .error {
            return nil
        } else if let undoItemValue = undoItemValue {
            return undoItemValue
        } else {
            let undoItem = try? T(serializedData: undoItemData)
            let redoItem = try? T(serializedData: redoItemData)
            if let undoItem = undoItem {
                if let redoItem = redoItem {
                    return UndoItemValue(undoItem: undoItem, redoItem: redoItem)
                } else if let redoItem = undoItem.reversed() {
                    return UndoItemValue<T>(undoItem: undoItem, redoItem: redoItem)
                } else {
                    return nil
                }
            } else if let redoItem = redoItem, let undoItem = redoItem.reversed() {
                return UndoItemValue<T>(undoItem: undoItem, redoItem: redoItem)
            } else {
                return nil
            }
        }
    }
    mutating func save() {
        undoItemData = Data()
        redoItemData = Data()
        guard let undoItemValue = undoItemValue else { return }
        let undoType = undoItemValue.undoItem.type
        let redoType = undoItemValue.redoItem.type
        if undoType == .lazyReversible || redoType == .lazyReversible {
            if let undoItemData = try? undoItemValue.undoItem.serializedData() {
                self.undoItemData = undoItemData
            }
            if let redoItemData = try? undoItemValue.redoItem.serializedData() {
                self.redoItemData = redoItemData
            }
        } else if undoType == .reversible {
            if let undoItemData = try? undoItemValue.undoItem.serializedData() {
                self.undoItemData = undoItemData
            }
        } else {
            if let redoItemData = try? undoItemValue.redoItem.serializedData() {
                self.redoItemData = redoItemData
            }
        }
    }
}
extension UndoDataValue: Protobuf {
    typealias PB = PBUndoDataValue
    init(_ pb: PBUndoDataValue) throws {
        undoItemData = pb.undoItemData
        redoItemData = pb.redoItemData
    }
    var pb: PBUndoDataValue {
        PBUndoDataValue.with {
            $0.undoItemData = undoItemData
            $0.redoItemData = redoItemData
        }
    }
}
extension UndoDataValue: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        undoItemData = try container.decode(Data.self)
        redoItemData = try container.decode(Data.self)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(undoItemData)
        try container.encode(redoItemData)
    }
}

struct UndoGroup<T: UndoItem> {
    var values = [UndoDataValue<T>]()
}
extension UndoGroup: Protobuf {
    typealias PB = PBUndoGroup
    init(_ pb: PBUndoGroup) throws {
        values = try pb.values.map { try UndoDataValue($0) }
    }
    var pb: PBUndoGroup {
        PBUndoGroup.with {
            $0.values = values.map { $0.pb }
        }
    }
}
extension UndoGroup: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        values = try container.decode([UndoDataValue<T>].self)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(values)
    }
}

struct Branch<T: UndoItem> {
    var groups = [UndoGroup<T>]()
    var children = [Branch<T>]()
    var selectedChildIndex = Int?.none
    fileprivate var childrenCount = 0
}
extension Branch: Protobuf {
    typealias PB = PBBranch
    init(_ pb: PBBranch) throws {
        groups = try pb.groups.map { try UndoGroup($0) }
        childrenCount = Int(pb.childrenCount)
        if case .selectedChildIndex(let selectedChildIndex)?
            = pb.selectedChildIndexOptional {
            
            self.selectedChildIndex = Int(selectedChildIndex)
        } else {
            selectedChildIndex = nil
        }
    }
    var pb: PBBranch {
        PBBranch.with {
            $0.groups = groups.map { $0.pb }
            $0.childrenCount = Int64(children.count)
            if let selectedChildIndex = selectedChildIndex {
                $0.selectedChildIndexOptional
                    = .selectedChildIndex(Int64(selectedChildIndex))
            } else {
                $0.selectedChildIndexOptional = nil
            }
        }
    }
}
extension Branch {
    mutating func appendInLastGroup(undo undoItem: T,
                                    redo redoItem: T) {
        let uiv = UndoItemValue(undoItem: undoItem, redoItem: redoItem)
        let udv = UndoDataValue(save: uiv)
        groups[.last].values.append(udv)
    }
    subscript(version: Version) -> UndoGroup<T> {
        get { self[version.indexPath].groups[version.groupIndex] }
        set { self[version.indexPath].groups[version.groupIndex] = newValue }
    }
    subscript(indexPath: VersionPath) -> Branch<T> {
        get {
            var branch = self
            indexPath.forEach {
                branch = branch.children[$0]
            }
            return branch
        }
        set {
            if indexPath.isEmpty {
                self = newValue
            } else if indexPath.count <= 1 {
                children[indexPath[0]] = newValue
            } else {
                var branch = self, branches = [Branch<T>]()
                indexPath.forEach {
                    branches.append(branch)
                    branch = branch.children[$0]
                }
                var n = newValue
                for (i, j) in indexPath.enumerated().reversed() {
                    var nBranch = branches[i]
                    nBranch.children[j] = n
                    n = nBranch
                }
                self = n
            }
        }
    }
    func version(atAll i: Int) -> Version? {
        guard i > 0 else { return nil }
        let i = i - 1
        var branch = self, j = 0, versionPath = VersionPath()
        while true {
            let nj = j + branch.groups.count
            if nj > i {
                return Version(indexPath: versionPath, groupIndex: i - j)
            }
            guard let sci = branch.selectedChildIndex else { break }
            versionPath.append(sci)
            j = nj
            branch = branch.children[sci]
        }
        return Version(indexPath: versionPath,
                       groupIndex: branch.groups.count - 1)
    }
    
    func all(_ handler: (VersionPath, Branch<T>) -> ()) {
        var vpbs = [(VersionPath(), self)]
        while let (versionPath, branch) = vpbs.last {
            vpbs.removeLast()
            handler(versionPath, branch)
            for (i, child) in branch.children.enumerated().reversed() {
                var versionPath = versionPath
                versionPath.append(i)
                vpbs.append((versionPath, child))
            }
        }
    }
}
extension Branch: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        groups = try container.decode([UndoGroup<T>].self)
        childrenCount = try container.decode(Int.self)
        selectedChildIndex = try container.decodeIfPresent(Int.self)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(groups)
        try container.encode(children.count)
        try container.encode(selectedChildIndex)
    }
}

struct BranchCoder<T: UndoItem> {
    var rootBranch: Branch<T>
}
extension BranchCoder: Protobuf {
    typealias PB = PBBranchCoder
    init(_ pb: PBBranchCoder) throws {
        let allBranches = try pb.allBranches.map { try Branch<T>($0) }
        rootBranch = BranchCoder.rootBranch(from: allBranches)
    }
    var pb: PBBranchCoder {
        PBBranchCoder.with {
            $0.allBranches = allBranches.map { $0.pb }
        }
    }
}
private enum BranchLoop<T: UndoItem> {
    case first(_ branch: Branch<T>)
    case next(_ children: [Branch<T>], _ branch: Branch<T>, _ j: Int)
}
extension BranchCoder {
    static func rootBranch(from allBranches: [Branch<T>]) -> Branch<T> {
        guard let root = allBranches.first else {
            return Branch<T>()
        }
        
        var i = 0, loopStack = Stack<BranchLoop<T>>()
        var returnStack = Stack<Branch<T>>()
        loopStack.push(.first(root))
        loop: while true {
            let un: Branch<T>, nj: Int
            var children: [Branch<T>]
            switch loopStack.pop()! {
            case .first(let oun):
                children = [Branch<T>]()
                children.reserveCapacity(oun.childrenCount)
                un = oun
                nj = 0
            case .next(var nchildren, let oun, let oj):
                nchildren.append(returnStack.pop()!)
                children = nchildren
                un = oun
                nj = oj
            }
            for j in nj..<un.childrenCount {
                i += 1
                
                loopStack.push(.next(children, un, j + 1))
                loopStack.push(.first(allBranches[i]))
                continue loop
            }
            
            var nun = un
            nun.children = children
            nun.children.enumerated().reversed().forEach {
                if $0.element.groups.isEmpty {
                    nun.children.remove(at: $0.offset)
                }
            }
            
            if loopStack.isEmpty {
                return nun
            } else {
                returnStack.push(nun)
                continue loop
            }
        }
    }
    var allBranches: [Branch<T>] {
        var allBranches = [Branch<T>]()
        var uns = [rootBranch]
        while let un = uns.last {
            uns.removeLast()
            allBranches.append(un)
            for child in un.children.reversed() {
                uns.append(child)
            }
        }
        return allBranches
    }
}
extension BranchCoder: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let allBranches = try container.decode([Branch<T>].self)
        rootBranch = BranchCoder.rootBranch(from: allBranches)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(allBranches)
    }
}

enum UndoType {
    case undo, redo
}

struct History<T: UndoItem> {
    var rootBranch = Branch<T>()
    var currentVersionIndex = 0, currentVersion = Version?.none
}
extension History: Protobuf {
    typealias PB = PBHistory
    init(_ pb: PBHistory) throws {
        rootBranch = try BranchCoder(pb.branchCoder).rootBranch
        currentVersionIndex = Int(pb.currentVersionIndex)
        check()
    }
    var pb: PBHistory {
        PBHistory.with {
            $0.branchCoder = BranchCoder(rootBranch: rootBranch).pb
            $0.currentVersionIndex = Int64(currentVersionIndex)
        }
    }
}
extension History: Codable {
    private enum CodingKeys: String, CodingKey {
        case rootBranch, currentVersionIndex
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        rootBranch = try values.decode(BranchCoder.self,
                                       forKey: .rootBranch).rootBranch
        currentVersionIndex = try values.decode(Int.self,
                                                forKey: .currentVersionIndex)
        check()
    }
    mutating func check() {
        guard currentVersionIndex > 0 else {
            currentVersion = nil
            return
        }
        let i = currentVersionIndex - 1
        var ug = rootBranch, j = 0, ip = VersionPath()
        while true {
            let nj = j + ug.groups.count
            if nj > i {
                currentVersion = Version(indexPath: ip, groupIndex: i - j)
                return
            }
            guard let sci = ug.selectedChildIndex else { break }
            ip.append(sci)
            j = nj
            ug = ug.children[sci]
        }
        currentVersionIndex = j + ug.groups.count - 1
        currentVersion = Version(indexPath: ip, groupIndex: ug.groups.count - 1)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(BranchCoder(rootBranch: rootBranch),
                             forKey: .rootBranch)
        try container.encode(currentVersionIndex, forKey: .currentVersionIndex)
    }
}
extension History {
    mutating func newBranch() {
        if let ui = currentVersion {
            var cuip = ui.indexPath
            var branch0 = rootBranch[cuip]
            if ui.groupIndex == branch0.groups.count - 1 {
                guard let sci = branch0.selectedChildIndex else { return }
                var un0 = Branch<T>()
                un0.groups = [UndoGroup()]
                let ni = sci + 1
                branch0.children.insert(un0, at: ni)
                branch0.selectedChildIndex = ni
                rootBranch[cuip] = branch0
                cuip.append(ni)
            } else {
                var un0 = Branch<T>(), un1 = Branch<T>()
                un0.groups = Array(branch0.groups[(ui.groupIndex + 1)...])
                un0.children = branch0.children
                un0.selectedChildIndex = branch0.selectedChildIndex
                un1.groups = [UndoGroup()]
                branch0.groups.removeLast(branch0.groups.count - ui.groupIndex - 1)
                branch0.children = [un0, un1]
                branch0.selectedChildIndex = 1
                rootBranch[cuip] = branch0
                cuip.append(1)
            }
            currentVersion = Version(indexPath: cuip, groupIndex: 0)
            currentVersionIndex += 1
        } else {
            let un0 = rootBranch
            if un0.groups.count == 0 {
                guard let sci = un0.selectedChildIndex else { return }
                var un1 = Branch<T>()
                un1.groups = [UndoGroup()]
                let ni = sci + 1
                rootBranch.groups = []
                rootBranch.children.insert(un1, at: ni)
                rootBranch.selectedChildIndex = ni
                currentVersion = Version(indexPath: [ni], groupIndex: 0)
                currentVersionIndex = 1
            } else {
                var un1 = Branch<T>()
                un1.groups = [UndoGroup()]
                rootBranch.groups = []
                rootBranch.children = [un0, un1]
                rootBranch.selectedChildIndex = 1
                currentVersion = Version(indexPath: [1], groupIndex: 0)
                currentVersionIndex = 1
            }
        }
    }
    mutating func newUndoGroup() {
        if !isLeafUndo {
            newBranch()
        } else {
            if let cui = currentVersion {
                rootBranch[cui.indexPath].groups.append(UndoGroup())
                currentVersionIndex += 1
                currentVersion!.groupIndex += 1
            } else {
                rootBranch.groups = [UndoGroup()]
                currentVersionIndex = 1
                currentVersion = Version(indexPath: VersionPath(),
                                         groupIndex: 0)
            }
        }
    }
    mutating func append(undo undoItem: T, redo redoItem: T) {
        rootBranch[currentVersion!.indexPath]
            .appendInLastGroup(undo: undoItem, redo: redoItem)
    }
    
    struct UndoResult {
        var item: UndoDataValue<T>, type: UndoType
        var version: Version, valueIndex: Int
    }
    mutating func undoAndResults(to toTopIndex: Int) -> [UndoResult] {
        let fromTopIndex = currentVersionIndex
        guard fromTopIndex != toTopIndex else { return [] }
        func enumerated(minI: Int, maxI: Int, _ handler: (Version) -> ()) {
            var minI = minI
            if minI == 0 {
                minI = 1
                handler(Version(indexPath: VersionPath(), groupIndex: -1))
            }
            guard minI <= maxI else { return }
            for i in minI...maxI {
                let ui = rootBranch.version(atAll: i)!
                handler(ui)
            }
        }
        var results = [UndoResult]()
        if fromTopIndex < toTopIndex {
            enumerated(minI: fromTopIndex + 1, maxI: toTopIndex) { (ui) in
                rootBranch[ui].values.enumerated().forEach {
                    results.append(UndoResult(item: $0.element,
                                              type: .redo,
                                              version: ui,
                                              valueIndex: $0.offset))
                }
            }
        } else {
            var values = [(Version)]()
            values.reserveCapacity(fromTopIndex - toTopIndex)
            enumerated(minI: toTopIndex, maxI: fromTopIndex - 1) { (ui) in
                values.append((ui))
            }
            values.reversed().forEach { (ui) in
                let un = rootBranch[ui.indexPath]
                if ui.groupIndex + 1 >= un.groups.count {
                    var nui = ui
                    nui.groupIndex = 0
                    nui.indexPath.append(un.selectedChildIndex!)
                    un.children[un.selectedChildIndex!]
                        .groups[0].values.enumerated().reversed().forEach {
                            results.append(UndoResult(item: $0.element,
                                                      type: .undo,
                                                      version: nui,
                                                      valueIndex: $0.offset))
                        }
                } else {
                    var nui = ui
                    nui.groupIndex = ui.groupIndex + 1
                    rootBranch[nui].values.enumerated().reversed().forEach {
                        results.append(UndoResult(item: $0.element,
                                                  type: .undo,
                                                  version: nui,
                                                  valueIndex: $0.offset))
                    }
                }
            }
        }
        currentVersion = rootBranch.version(atAll: toTopIndex)
        currentVersionIndex = toTopIndex
        return results
    }
    
    mutating func reset() {
        rootBranch = Branch()
        currentVersionIndex = 0
        currentVersion = nil
    }
    var isEmpty: Bool {
        rootBranch.groups.isEmpty && rootBranch.children.isEmpty
    }
    
    subscript(ui: Version) -> UndoGroup<T> {
        get { rootBranch[ui.indexPath].groups[ui.groupIndex] }
        set { rootBranch[ui.indexPath].groups[ui.groupIndex] = newValue }
    }
    
    var currentMaxVersionIndex: Int {
        var un = rootBranch, i = un.groups.count
        while let sci = un.selectedChildIndex {
            un = un.children[sci]
            i += un.groups.count
        }
        return i
    }
    var isLeafUndo: Bool {
        currentVersionIndex == currentMaxVersionIndex
    }
    var isCanUndo: Bool {
        currentVersionIndex > 0
    }
    var isCanRedo: Bool {
        currentVersionIndex < currentMaxVersionIndex
    }
}
