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
import struct Foundation.URL
import class Foundation.FileManager
import SwiftProtobuf

struct ProtobufError: Error {}
protocol Serializable {
    init(serializedData: Data) throws
    func serializedData() throws -> Data
}
protocol Protobuf: Serializable {
    associatedtype PB
    init(_ pb: PB) throws
    var pb: PB { get }
}
extension Protobuf where PB: SwiftProtobuf.Message {
    init(serializedData: Data) throws {
        self = try Self(try PB(serializedData: serializedData))
    }
    func serializedData() throws -> Data {
        try pb.serializedData()
    }
}
extension Protobuf where PB: SwiftProtobuf.Enum {
    init(serializedData: Data) throws {
        if let rawValue = Int(serializedData.base64EncodedString()),
           let pb = PB(rawValue: rawValue) {
            self = try Self(pb)
        } else {
            throw ProtobufError()
        }
    }
    func serializedData() throws -> Data {
        let str = String(pb.rawValue)
        if let data = Data(base64Encoded: str) {
            return data
        } else {
            throw ProtobufError()
        }
    }
}

extension Data: Serializable {
    init(serializedData: Data) throws {
        self = serializedData
    }
    func serializedData() throws -> Data { self }
}

extension Decodable {
    static func decode<Key>(values: KeyedDecodingContainer<Key>,
                            forKey key: Key) throws -> Self where Key: CodingKey {
        try values.decode(Self.self, forKey: key)
    }
}
extension Encodable {
    func encode<CodingKeys>(forKey key: KeyedEncodingContainer<CodingKeys>.Key,
                            in container: inout KeyedEncodingContainer<CodingKeys>) throws
    where CodingKeys: CodingKey {
        try container.encode(self, forKey: key)
    }
}

protocol FileTypeProtocol {
    var name: String { get }
    var utType: String { get }
}

struct FileError: Error {}
protocol File: AnyObject {
    var url: URL { get }
    var key: String { get }
    var parent: Directory? { get set }
    func prepareToWrite()
    func write() throws
    func resetWrite()
}
extension File {
    var key: String { url.lastPathComponent }
    var size: Int? { url.fileSize }
}

final class Directory: File {
    weak var parent: Directory?
    
    var url: URL
    
    enum ChildType {
        case directory(_ directory: Directory)
        case file(_ file: File)
    }
    private(set) var children = [String: ChildType]()
    private(set) var childrenURLs: [String: URL]
    var root: Directory { parent?.root ?? self }
    
    var isWillwrite = false {
        didSet {
            notifyRootOfChanged(isWillwrite: isWillwrite)
        }
    }
    private var isStoppedWriteNotification = false
    fileprivate func notifyRootOfChanged(isWillwrite: Bool) {
        if !isStoppedWriteNotification {
            let root = self.root
            root.changedIsWillwriteByChildrenClosure?(root, isWillwrite)
        }
    }
    
    var willwriteClosure: (Directory) -> () = { _ in }
    var changedIsWillwriteByChildrenClosure: ((Directory, Bool) -> ())? = nil
    
    init(url: URL) {
        self.url = url
        guard let urls = try? FileManager.default
                .contentsOfDirectory(at: url,
                                     includingPropertiesForKeys: nil,
                                     options: []) else {
            self.childrenURLs = [:]
            return
        }
        var childrenURLs = [String: URL]()
        for url in urls {
            childrenURLs[url.lastPathComponent] = url
        }
        self.childrenURLs = childrenURLs
    }
}
extension Directory {
    func prepareToWriteAll() {
        isStoppedWriteNotification = true
        for child in children.values {
            switch child {
            case .directory(let directory):
                directory.prepareToWriteAll()
            case .file(let file):
                file.prepareToWrite()
            }
        }
        isStoppedWriteNotification = false
    }
    func writeAll() throws {
        try write()
        for child in children.values {
            switch child {
            case .directory(let directory):
                try directory.writeAll()
            case .file(let file):
                try file.write()
            }
        }
    }
    func resetWriteAll() {
        for child in children.values {
            switch child {
            case .directory(let directory):
                directory.resetWriteAll()
            case .file(let file):
                file.resetWrite()
            }
        }
    }
    
    func prepareToWrite() {
        if isWillwrite {
            willwriteClosure(self)
        }
    }
    func write() throws {
        guard isWillwrite else { return }
        try FileManager.default.createDirectory(at: url,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
        isWillwrite = false
    }
    func resetWrite() {}
    
    func makeRecord<T: Codable & Serializable>(forKey key: String) -> Record<T> {
        if let child = children[key] {
            switch child {
            case .file(let file):
                if let record = file as? Record<T> {
                    return record
                }
            case .directory(let directory):
                try? remove(directory)
            }
        }
        let url = self.url.appendingPathComponent(key)
        let record = Record<T>(url: url)
        if childrenURLs[key] == nil {
            record.isWillwrite = true
        }
        record.parent = self
        childrenURLs[key] = url
        children[key] = .file(record)
        return record
    }
    func makeDirectory(forKey key: String) -> Directory {
        if let child = children[key] {
            switch child {
            case .file(let file):
                try? remove(file)
            case .directory(let directory):
                return directory
            }
        }
        let url = self.url.appendingPathComponent(key)
        let directory = Directory(url: url)
        if childrenURLs[key] == nil {
            directory.isWillwrite = true
        }
        directory.parent = self
        childrenURLs[key] = url
        children[key] = .directory(directory)
        return directory
    }
    
    func remove(_ file: File) throws {
        childrenURLs[file.key] = nil
        children[file.key] = nil
        file.parent = nil
        try FileManager.default.removeItem(at: file.url)
    }
}

final class Record<Value: Codable & Serializable>: File {
    weak var parent: Directory?
    
    var url: URL
    var value: Value?
    var data: Data?
    
    var isWillwrite = false {
        didSet {
            parent?.notifyRootOfChanged(isWillwrite: isWillwrite)
        }
    }
    var isPreparedWrite = false
    var willwriteClosure: (Record<Value>) -> () = { _ in }
    
    init(url: URL) {
        self.url = url
    }
}
extension Record {
    func decode() throws {
        if let data = data {
            value = try Value(serializedData: data)
        } else {
            throw FileError()
        }
    }
    func encode() throws {
        if let value = value {
            data = try value.serializedData()
        }
    }
    
    var decodedValue: Value? {
        if let value = value {
            return value
        }
        let data = self.data ?? (try? Data(contentsOf: url))
        if let data = data {
            return try? Value(serializedData: data)
        } else {
            return nil
        }
    }
    var decodedData: Data? {
        self.data ?? (try? Data(contentsOf: url))
    }
    var valueDataOrDecodedData: Data? {
        if let value = value {
            return try? value.serializedData()
        } else {
            return self.data ?? (try? Data(contentsOf: url))
        }
    }
    
    func read() throws {
        data = try Data(contentsOf: url)
    }
    
    func prepareToWrite() {
        if isWillwrite {
            willwriteClosure(self)
            isWillwrite = false
            isPreparedWrite = true
        }
    }
    func write() throws {
        guard isPreparedWrite, let parentURL = parent?.url else { return }
        try encode()
        let fm = FileManager.default
        if !fm.fileExists(atPath: parentURL.path) {
            try fm.createDirectory(at: parentURL, withIntermediateDirectories: true)
        }
        try data?.write(to: url, options: .atomic)
        isPreparedWrite = false
    }
    func resetWrite() {
        value = nil
        data = nil
    }
}
