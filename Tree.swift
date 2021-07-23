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

typealias IndexPath = [Int]

protocol Tree: Sequence {
    var children: [Self] { get set }
    subscript(indexPath: IndexPath) -> Self { get set }
}
extension Tree {
    typealias Index = IndexPath
    
    subscript(indexPath: IndexPath) -> Self {
        get { at(indexPath: indexPath, at: 0) }
        set { self[keyPath: Self.keyPath(with: indexPath)] = newValue }
    }
    func at(indexPath: IndexPath, at i: Int) -> Self {
        guard i < indexPath.count else { return self }
        let index = indexPath[i]
        let child = children[index]
        return child.at(indexPath: indexPath, at: i + 1)
    }
    
    static func keyPath(with indexPath: IndexPath) -> WritableKeyPath<Self, Self> {
        var indexPath = indexPath
        let keyPath: WritableKeyPath<Self, Self> = \Self.children[indexPath[0]]
        indexPath.removeFirst()
        return indexPath.reduce(keyPath) {
            $0.appending(path: \Self.children[indexPath[$1]])
        }
    }
    
    func makeIterator() -> TreeIterator<Self> {
        TreeIterator(rootTree: self)
    }
    func treeIndexEnumerated() -> TreeIndexSequence<Self> {
        TreeIndexSequence(rootTree: self)
    }
    
    func elements(at treeIndex: Index) -> [Self] {
        guard !treeIndex.isEmpty else { return [] }
        var elements = [Self]()
        elements.reserveCapacity(treeIndex.count)
        self.elements(at: treeIndex, index: 0, elements: &elements)
        return elements
    }
    private func elements(at treeIndex: Index, index: Int,
                          elements: inout [Self]) {
        elements.append(children[treeIndex[index]])
        let newIndex = index + 1
        if newIndex < treeIndex.count {
            self.elements(at: treeIndex, index: newIndex, elements: &elements)
        }
    }
    
    func sortedIndexes(_ indexes: [Index]) -> [Index] {
        var sortedIndexes = [Index]()
        for (i, _) in treeIndexEnumerated() {
            if indexes.contains(i) {
                sortedIndexes.append(i)
            }
        }
        return sortedIndexes
    }
}

struct TreeIterator<T: Tree>: IteratorProtocol {
    typealias Element = T
    
    init(rootTree: T) {
        treeValues = [(rootTree, 0)]
    }
    
    private var treeValues = [(tree: T, index: Int)]()
    mutating func next() -> T? {
        guard let lastTreeValue = treeValues.last else {
            return nil
        }
        if lastTreeValue.index >= lastTreeValue.tree.children.count {
            treeValues.removeLast()
            if !treeValues.isEmpty {
                treeValues[treeValues.count - 1].index += 1
            }
            return lastTreeValue.tree
        } else {
            let child = lastTreeValue.tree.children[lastTreeValue.index]
            if child.children.isEmpty {
                treeValues[treeValues.count - 1].index += 1
                return child
            } else {
                var aChild = child
                repeat {
                    treeValues.append((aChild, 0))
                    aChild = aChild.children[0]
                } while !aChild.children.isEmpty
                treeValues[treeValues.count - 1].index += 1
                return aChild
            }
        }
    }
}

struct TreeIndexSequence<T: Tree>: Sequence, IteratorProtocol {
    typealias Element = (T.Index, T)
    
    init(rootTree: T) {
        trees = [rootTree]
        indexPath = [0]
    }
    
    private var indexPath: IndexPath, trees: [T]
    mutating func next() -> Element? {
        guard let lastChildIndex = indexPath.last,
              let lastTree = trees.last else {
            return nil
        }
        if lastChildIndex >= lastTree.children.count {
            indexPath.removeLast()
            trees.removeLast()
            let oldIndexPath = indexPath
            if !indexPath.isEmpty {
                indexPath[indexPath.count - 1] += 1
            }
            return (oldIndexPath, lastTree)
        } else {
            let child = lastTree.children[lastChildIndex]
            if child.children.isEmpty {
                let oldIndexPath = indexPath
                indexPath[indexPath.count - 1] += 1
                return (oldIndexPath, child)
            } else {
                var aChild = child
                repeat {
                    indexPath.append(0)
                    trees.append(aChild)
                    aChild = aChild.children[0]
                } while !aChild.children.isEmpty
                let oldIndexPath = indexPath
                indexPath[indexPath.count - 1] += 1
                return (oldIndexPath, aChild)
            }
        }
    }
}

private final class BinarySearchElement<T: Comparable> {
    var value: T
    var left, right: BinarySearchElement?
    
    init(_ value: T,
         left: BinarySearchElement? = nil,
         right: BinarySearchElement? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}
extension BinarySearchElement {
    func insert(_ value: T) {
        if value < self.value {
            if let left = left {
                left.insert(value)
            } else {
                left = BinarySearchElement(value)
            }
        } else {
            if let right = right {
                right.insert(value)
            } else {
                right = BinarySearchElement(value)
            }
        }
    }
    func remove(_ value: T) -> BinarySearchElement<T>? {
        if value == self.value {
            guard left != nil else {
                return right
            }
            guard var element = right else {
                return left
            }
            while let aElement = element.left {
                element = aElement
            }
            self.value = element.value
            right = self.right?.remove(element.value)
        } else if value < self.value {
            left = self.left?.remove(value)
        } else {
            right = self.right?.remove(value)
        }
        return self
    }
    func previous(at value: T) -> T? {
        if value > self.value {
            return right?.previous(at: value) ?? self.value
        } else {
            return left?.previous(at: value)
        }
    }
    func copy() -> BinarySearchElement<T> {
        BinarySearchElement(value, left: left?.copy(), right: right?.copy())
    }
}
struct BinarySearchTree<T: Comparable> {
    private var rootElement: BinarySearchElement<T>?
}
extension BinarySearchTree {
    private mutating func copyIfShared() {
        if isKnownUniquelyReferenced(&rootElement) { return }
        rootElement = rootElement?.copy()
    }
    mutating func insert(_ value: T) {
        copyIfShared()
        if let rootElement = rootElement {
            rootElement.insert(value)
        } else {
            rootElement = BinarySearchElement(value)
        }
    }
    mutating func remove(_ value: T) {
        copyIfShared()
        rootElement = rootElement?.remove(value)
    }
}
extension BinarySearchTree {
    func previous(at value: T) -> T? {
        rootElement?.previous(at: value)
    }
}
