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

enum FirstOrLast: String, Codable {
    case first, last
}
extension FirstOrLast {
    var reversed: FirstOrLast {
        switch self {
        case .first: return .last
        case .last: return .first
        }
    }
}
extension Array {
    var removedFirst: [Element] {
        var array = self
        _ = array.removeFirst()
        return array
    }
    var removedLast: [Element] {
        var array = self
        _ = array.removeLast()
        return array
    }
    
    mutating func remove(at indexes: [Int]) {
        for i in indexes.reversed() {
            remove(at: i)
        }
    }
    mutating func insert(_ ivs: [IndexValue<Element>]) {
        for iv in ivs {
            insert(iv.value, at: iv.index)
        }
    }
    subscript(firstOrLast: FirstOrLast) -> Element {
        get {
            switch firstOrLast {
            case .first: return self[0]
            case .last: return self[count - 1]
            }
        }
        set {
            switch firstOrLast {
            case .first: self[0] = newValue
            case .last: self[count - 1] = newValue
            }
        }
    }
}
extension RangeReplaceableCollection where Element: Equatable {
    static func - (lhs: Self, rhs: Self) -> Self {
        var lhs = lhs
        for element in rhs {
            if let i = lhs.firstIndex(of: element) {
                lhs.remove(at: i)
            }
        }
        return lhs
    }
}

struct Stack<Element> {
    private(set) var elements = [Element]()
}
extension Stack {
    init(minimumCapacity: Int) {
        elements.reserveCapacity(minimumCapacity)
    }
    mutating func push(_ e: Element) {
        elements.append(e)
    }
    mutating func pop() -> Element? {
        elements.popLast()
    }
    var isEmpty: Bool {
        elements.isEmpty
    }
    mutating func removeAll() {
        elements.removeAll()
    }
}

final class ArrayView<T: View>: View {
    typealias Binder = T.Binder
    typealias Model = [T.Model]
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    
    typealias ElementView = T
    typealias ModelElement = T.Model
    private(set) var elementViews: [ElementView]
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        elementViews = ArrayView.elementViewsWith(model: binder[keyPath: keyPath],
                                                  binder: binder,
                                                  keyPath: keyPath)
        
        node = Node(children: elementViews.map { $0.node })
    }
    
    func updateWithModel() {
        updateChildren()
    }
    func updateChildren() {
        elementViews = ArrayView.elementViewsWith(model: model,
                                                  binder: binder,
                                                  keyPath: keyPath)
        node.children = elementViews.map { $0.node }
    }
    private static func elementViewsWith(model: Model,
                                         binder: Binder,
                                         keyPath: BinderKeyPath) -> [ElementView] {
        return model.enumerated().map { (i, _) in
            ElementView(binder: binder,
                        keyPath: keyPath.appending(path: \Model[i]))
        }
    }
    
    @discardableResult
    func append(_ modelElement: ModelElement) -> ElementView {
        binder[keyPath: keyPath].append(modelElement)
        let elementView
            = ElementView(binder: binder,
                          keyPath: keyPath
                            .appending(path: \Model[model.count - 1]))
        elementViews.append(elementView)
        node.append(child: elementView.node)
        return elementView
    }
    @discardableResult
    func insert(_ modelElement: ModelElement, at index: Int) -> ElementView {
        binder[keyPath: keyPath].insert(modelElement, at: index)
        let elementView
            = ElementView(binder: binder,
                          keyPath: keyPath.appending(path: \Model[index]))
        elementViews.insert(elementView, at: index)
        node.insert(child: elementView.node, at: index)
        
        elementViews[(index + 1)...].enumerated().forEach { (i, aElementView) in
            aElementView.keyPath = keyPath.appending(path: \Model[index + 1 + i])
        }
        return elementView
    }
    func insert(_ elementView: ElementView, _ modelElement: ModelElement,
                at index: Int) {
        binder[keyPath: keyPath].insert(modelElement, at: index)
        elementViews.insert(elementView, at: index)
        node.insert(child: elementView.node, at: index)
        
        elementViews[(index + 1)...].enumerated().forEach { (i, aElementView) in
            aElementView.keyPath = keyPath.appending(path: \Model[index + 1 + i])
        }
    }
    func remove(at index: Int) {
        binder[keyPath: keyPath].remove(at: index)
        elementViews.remove(at: index)
        node.children[index].removeFromParent()
        
        elementViews[index...].enumerated().forEach { (i, elementView) in
            elementView.keyPath = keyPath.appending(path: \Model[index + i])
        }
    }
    func append(_ modelElements: [ModelElement]) {
        binder[keyPath: keyPath] += modelElements
        
        for i in 0..<modelElements.count {
            let j = model.count - modelElements.count + i
            let elementView
                = ElementView(binder: binder,
                              keyPath: keyPath.appending(path: \Model[j]))
            elementViews.append(elementView)
            node.append(child: elementView.node)
        }
    }
    func insert(_ ivs: [IndexValue<ModelElement>]) {
        var model = self.model
        for iv in ivs {
            model.insert(iv.value, at: iv.index)
        }
        binder[keyPath: keyPath] = model
        
        let nElementViews: [ElementView] = ivs.map { iv in
            ElementView(binder: binder,
                        keyPath: keyPath.appending(path: \Model[iv.index]))
        }
        for (i, elementView) in nElementViews.enumerated() {
            let iv = ivs[i]
            elementViews.insert(elementView, at: iv.index)
            node.insert(child: elementView.node, at: iv.index)
        }
        
        elementViews.enumerated().forEach { (i, elementView) in
            elementView.keyPath = keyPath.appending(path: \Model[i])
        }
    }
    func insert(_ ivs: [IndexValue<ElementView>]) {
        var model = self.model
        for iv in ivs {
            model.insert(iv.value.model, at: iv.index)
        }
        binder[keyPath: keyPath] = model
        
        for iv in ivs {
            elementViews.insert(iv.value, at: iv.index)
            node.insert(child: iv.value.node, at: iv.index)
        }
        
        elementViews.enumerated().forEach { (i, elementView) in
            elementView.keyPath = keyPath.appending(path: \Model[i])
        }
    }
    func append(_ elementViews: [ElementView], _ modelElements: [ModelElement]) {
        binder[keyPath: keyPath] += modelElements
        self.elementViews += elementViews
        elementViews.forEach { node.append(child: $0.node) }
    }
    func removeLasts(count: Int) {
        let range = (model.count - count)..<model.count
        binder[keyPath: keyPath].removeLast(count)
        elementViews.removeLast(count)
        range.reversed().forEach { node.children[$0].removeFromParent() }
    }
    func remove(at indexes: [Int]) {
        var model = self.model
        for index in indexes.reversed() {
            model.remove(at: index)
            elementViews.remove(at: index)
            node.children[index].removeFromParent()
        }
        binder[keyPath: keyPath] = model
        
        elementViews.enumerated().forEach { (i, elementView) in
            elementView.keyPath = keyPath.appending(path: \Model[i])
        }
    }
    
    func firstIndex(at p: Point) -> Int? {
        guard (node.isEmpty || node.containsPath(p)) && !node.isHidden else {
            return nil
        }
        for (i, child) in elementViews.enumerated().reversed() {
            let inP = p * child.node.localTransform.inverted()
            if  child.node.contains(inP) {
                return i
            }
        }
        return nil
    }
    func at(_ p: Point) -> ElementView? {
        guard (node.isEmpty || node.containsPath(p)) && !node.isHidden else {
            return nil
        }
        for child in elementViews.reversed() {
            let inP = p * child.node.localTransform.inverted()
            if  child.node.contains(inP) {
                return child
            }
        }
        return nil
    }
}
