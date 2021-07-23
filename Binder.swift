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

protocol BinderProtocol: class {
    associatedtype Value
    var value: Value { get set }
}
final class RecordBinder<Value: Codable & Serializable>: BinderProtocol {
    var record: Record<Value> {
        didSet {
            record.willwriteClosure = { [weak self] (record) in
                if let aSelf = self {
                    record.value = aSelf.value
                }
            }
        }
    }
    var value: Value {
        didSet { record.isWillwrite = true }
    }
    func enableWrite() {
        record.isWillwrite = true
    }
    init?(record: Record<Value>) {
        guard let value = record.value else {
            return nil
        }
        self.value = value
        self.record = record
        record.willwriteClosure = { [weak self] (record) in
            if let aSelf = self {
                record.value = aSelf.value
            }
        }
    }
    init(value: Value, record: Record<Value>) {
        self.value = value
        self.record = record
        record.willwriteClosure = { [weak self] (record) in
            if let aSelf = self {
                record.value = aSelf.value
            }
        }
    }
}

protocol View: class, Hashable {
    associatedtype Binder: BinderProtocol
    associatedtype Model
    var model: Model { get set }
    var node: Node { get }
    func updateWithModel()
    var binder: Binder { get }
    var keyPath: ReferenceWritableKeyPath<Binder, Model> { get set }
    init(binder: Binder, keyPath: ReferenceWritableKeyPath<Binder, Model>)
}
extension View {
    typealias BinderKeyPath = ReferenceWritableKeyPath<Binder, Model>
    var model: Model {
        get { binder[keyPath: keyPath] }
        set {
            binder[keyPath: keyPath] = newValue
            updateWithModel()
        }
    }
    func convertFromWorld<T: AppliableTransform>(_ value: T) -> T {
        node.convertFromWorld(value)
    }
    func convertToWorld<T: AppliableTransform>(_ value: T) -> T {
        node.convertToWorld(value)
    }
    func convert<T: AppliableTransform>(_ value: T, from fromNode: Node) -> T {
        node.convert(value, from: fromNode)
    }
    func convert<T: AppliableTransform>(_ value: T, to toNode: Node) -> T {
        node.convert(value, to: toNode)
    }
}
extension View {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs === rhs
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
