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

final class Node {
    weak var owner: NodeOwner?
    private func setNeedsDisplay() {
        owner?.update()
        cacheLink?.isUpdateCache = true
    }
    
    var name = ""
    
    private(set) weak var parent: Node?
    private var backingChildren = [Node]()
    var children: [Node] {
        get { backingChildren }
        set {
            let oldChildren = backingChildren
            oldChildren.forEach { child in
                if !newValue.contains(where: { $0 === child }) {
                    child.removeFromParent()
                }
            }
            backingChildren = newValue
            newValue.forEach { child in
                if child.parent != self {
                    child.removeFromParent()
                    child.parent = self
                    child.allChildrenAndSelf { $0.owner = owner }
                    if let cacheLink = cacheLink {
                        child.allChildrenAndSelf { $0.cacheLink = cacheLink }
                    }
                    child.updateWorldTransform(worldTransform)
                }
            }
            setNeedsDisplay()
        }
    }
    func append(child: Node) {
        child.removeFromParent()
        backingChildren.append(child)
        child.parent = self
        child.allChildrenAndSelf { $0.owner = owner }
        if let cacheLink = cacheLink {
            child.allChildrenAndSelf { $0.cacheLink = cacheLink }
        }
        child.updateWorldTransform(worldTransform)
        child.setNeedsDisplay()
    }
    func insert(child: Node, at index: Array<Node>.Index) {
        var index = index
        if child.parent != nil {
            if let oldIndex = children.firstIndex(of: child), index > oldIndex {
                index -= 1
            }
            child.removeFromParent()
        }
        backingChildren.insert(child, at: index)
        child.parent = self
        child.allChildrenAndSelf { $0.owner = owner }
        if let cacheLink = cacheLink {
            child.allChildrenAndSelf { $0.cacheLink = cacheLink }
        }
        child.updateWorldTransform(worldTransform)
        child.setNeedsDisplay()
    }
    func removeFromParent() {
        guard let parent = parent else { return }
        if let index = parent.backingChildren.firstIndex(where: { $0 === self }) {
            parent.backingChildren.remove(at: index)
        }
        self.parent = nil
        updateWorldTransform(.identity)
        setNeedsDisplay()
        allChildrenAndSelf { $0.owner = nil }
        if parent.cacheLink != nil {
            allChildrenAndSelf { $0.cacheLink = nil }
        }
    }
    
    var isHidden = false {
        didSet {
            guard isHidden != oldValue else { return }
            setNeedsDisplay()
        }
    }
    
    var attitude = Attitude() {
        didSet {
            localTransform = attitude.transform
            isIdentityFromLocal = localTransform.isIdentity
            localScale = isIdentityFromLocal ? 1 : localTransform.absXScale
            updateWorldTransform(parent?.worldTransform ?? .identity)
            setNeedsDisplay()
        }
    }
    private(set) var localTransform = Transform.identity
    private(set) var isIdentityFromLocal = true, localScale = 1.0
    private(set) var worldTransform = Transform.identity
    private func updateWorldTransform(_ parentTransform: Transform) {
        if !isIdentityFromLocal {
            worldTransform = localTransform * parentTransform
            children.forEach { $0.updateWorldTransform(worldTransform) }
        } else {
            worldTransform = parentTransform
            children.forEach { $0.updateWorldTransform(parentTransform) }
        }
    }
    
    private enum BufferUpdateType {
        case none, wait, update
    }
    
    var path = Path() {
        didSet {
            if lineWidth > 0 {
                if lineType != nil {
                    linePathBufferUpdateType = .update
                    if lineColorBufferUpdateType == .wait {
                        lineColorBufferUpdateType = .update
                    }
                    setNeedsDisplay()
                } else if path.isEmpty {
                    linePathBufferUpdateType = .update
                    setNeedsDisplay()
                } else {
                    linePathBufferUpdateType = .wait
                }
            }
            if fillType != nil {
                fillPathBufferUpdateType = .update
                if fillColorBufferUpdateType == .wait {
                    fillColorBufferUpdateType = .update
                }
                setNeedsDisplay()
            } else if path.isEmpty {
                fillPathBufferUpdateType = .update
                setNeedsDisplay()
            } else {
                fillPathBufferUpdateType = .wait
            }
        }
    }
    var lineWidth = 1.0 {
        didSet {
            guard lineWidth != oldValue else { return }
            if !path.isEmpty {
                if lineType != nil {
                    linePathBufferUpdateType = .update
                    if lineColorBufferUpdateType == .wait {
                        lineColorBufferUpdateType = .update
                    }
                    setNeedsDisplay()
                } else if lineWidth == 0 {
                    linePathBufferUpdateType = .update
                    setNeedsDisplay()
                } else {
                    linePathBufferUpdateType = .wait
                }
            }
        }
    }
    private var linePathBufferUpdateType = BufferUpdateType.none
    private var linePathBuffer: Buffer?
    private var linePathBufferVertexCounts = [Int]()
    private func updateLinePathBuffer() {
        let device = Renderer.shared.device
        if !path.isEmpty {
            let (pointsData, counts) = path.linePointsDataWith(lineWidth: lineWidth)
            if !pointsData.isEmpty {
                linePathBuffer = device.makeBuffer(pointsData)
                linePathBufferVertexCounts = counts
                return
            }
        }
        linePathBuffer = nil
        linePathBufferVertexCounts = []
    }
    private var fillPathBufferUpdateType = BufferUpdateType.none
    private var fillPathBuffer: Buffer?
    private var fillPathBufferVertexCounts = [Int]()
    private var fillPathBufferBezierVertexCounts = [Int]()
    private var fillPathBufferAroundVertexCounts = [Int]()
    private func updateFillPathBuffer() {
        let device = Renderer.shared.device
        if !path.isEmpty {
            if path.isPolygon {
                let (pointsData, counts) = path.fillPointsData()
                if !pointsData.isEmpty {
                    fillPathBuffer = device.makeBuffer(pointsData)
                    fillPathBufferVertexCounts = counts
                    return
                }
            } else {
                let (pointsData, counts, bezierCounts, aroundCounts)
                    = path.stencilFillData()
                if !pointsData.isEmpty {
                    fillPathBuffer = device.makeBuffer(pointsData)
                    fillPathBufferVertexCounts = counts
                    fillPathBufferBezierVertexCounts = bezierCounts
                    fillPathBufferAroundVertexCounts = aroundCounts
                    return
                }
            }
        }
        fillPathBuffer = nil
        fillPathBufferVertexCounts = []
        fillPathBufferBezierVertexCounts = []
        fillPathBufferAroundVertexCounts = []
    }
    
    enum LineType: Equatable {
        case color(Color)
        case gradient([Color])
    }
    var lineType: LineType? {
        didSet {
            if !path.isEmpty && lineWidth > 0 {
                lineColorBufferUpdateType = .update
                if linePathBufferUpdateType == .wait {
                    linePathBufferUpdateType = .update
                }
                setNeedsDisplay()
            } else if lineType == nil {
                lineColorBufferUpdateType = .update
                setNeedsDisplay()
            } else {
                lineColorBufferUpdateType = .wait
            }
        }
    }
    private var lineColorBufferUpdateType = BufferUpdateType.none
    private var lineColorBuffer: Buffer?
    private var lineColorsBuffer: Buffer?
    private func updateLineColorBuffer() {
        if let lineType = lineType {
            switch lineType {
            case .color(let color):
                lineColorBuffer = Renderer.shared.colorBuffer(with: color)
                lineColorsBuffer = nil
            case .gradient(let colors):
                let colorsData = path.lineColorsDataWith(colors,
                                                         lineWidth: lineWidth)
                lineColorBuffer = nil
                lineColorsBuffer = Renderer.shared.device.makeBuffer(colorsData)
            }
        } else {
            lineColorBuffer = nil
            lineColorsBuffer = nil
        }
    }
    
    enum FillType: Equatable {
        case color(Color)
        case texture(Texture)
    }
    var fillType: FillType? {
        didSet {
            if !path.isEmpty {
                fillColorBufferUpdateType = .update
                if fillPathBufferUpdateType == .wait {
                    fillPathBufferUpdateType = .update
                }
                setNeedsDisplay()
            } else if fillType == nil {
                fillColorBufferUpdateType = .update
                setNeedsDisplay()
            } else {
                fillColorBufferUpdateType = .wait
            }
        }
    }
    private var fillColorBufferUpdateType = BufferUpdateType.none
    private var fillColorBuffer: Buffer?
    private var fillTextureBuffer: Buffer?
    private var fillTexture: Texture?
    private var isOpaque = false
    private func updateFillColorBuffer() {
        if let fillType = fillType {
            switch fillType {
            case .color(let color):
                fillColorBuffer = Renderer.shared.colorBuffer(with: color)
                fillTextureBuffer = nil
                fillTexture = nil
                isOpaque = color.opacity == 1
            case .texture(let texture):
                fillColorBuffer = nil
                
                let device = Renderer.shared.device
                let pointsData = path.fillTexturePointsData()
                guard !pointsData.isEmpty else {
                    fillTextureBuffer = nil
                    fillTexture = nil
                    return
                }
                fillTextureBuffer = device.makeBuffer(pointsData)
                
                fillTexture = texture
                isOpaque = texture.isOpaque
            }
        } else {
            fillColorBuffer = nil
            fillTextureBuffer = nil
            fillTexture = nil
            isOpaque = false
        }
    }
    
    var enableCache = false {
        didSet {
            guard enableCache != oldValue else { return }
            if enableCache {
                allChildrenAndSelf { $0.cacheLink = self }
            } else {
                allChildrenAndSelf { $0.cacheLink = nil }
            }
        }
    }
    var cacheTexture: Texture? {
        didSet {
            updateWithCacheTexture()
        }
    }
    var isRenderCache = true
    private var cachePathBuffer: Buffer?
    private var cachePathBufferVertexCounts = [Int]()
    private var cacheTextureBuffer: Buffer?
    private weak var cacheLink: Node?
    private(set) var isUpdateCache = false
    func updateCache() {
        if isRenderCache && enableCache {
            if isUpdateCache || cacheTexture == nil {
                newCache()
                isUpdateCache = false
            }
        }
    }
    private func newCache() {
        guard enableCache else { return }
        guard let bounds = bounds else {
            cacheTexture = nil
            return
        }
        let color: Color
        if case .color(let aColor)? = fillType {
            color = aColor
        } else {
            color = .background
        }
        isRenderCache = false
        let texture = renderedTexture(in: bounds, to: bounds.size * 2,
                                      backgroundColor: color,
                                      sampleCount: owner?.sampleCount ?? 1,
                                      mipmapped: true)
        isRenderCache = true
        cacheTexture = texture
    }
    private func updateWithCacheTexture() {
        if cacheTexture != nil && !path.isEmpty && path.isPolygon {
            let (pointsData, counts) = path.fillPointsData()
            if !pointsData.isEmpty {
                let texturePointsData = path.fillTexturePointsData()
                if !texturePointsData.isEmpty {
                    let device = Renderer.shared.device
                    cachePathBuffer = device.makeBuffer(pointsData)
                    cachePathBufferVertexCounts = counts
                    cacheTextureBuffer = device.makeBuffer(texturePointsData)
                    return
                }
            }
        }
        cachePathBuffer = nil
        cachePathBufferVertexCounts = []
        cacheTextureBuffer = nil
        cacheTexture = nil
    }
    
    init(children: [Node] = [],
         isHidden: Bool = false,
         attitude: Attitude = Attitude(),
         path: Path = Path(),
         lineWidth: Double = 0, lineType: LineType? = nil,
         fillType: FillType? = nil) {
        
        backingChildren = children
        self.isHidden = isHidden
        self.path = path
        self.attitude = attitude
        self.localTransform = attitude.transform
        self.isIdentityFromLocal = localTransform.isIdentity
        self.localScale = isIdentityFromLocal ? 1 : localTransform.absXScale
        worldTransform = localTransform
        self.lineWidth = lineWidth
        self.lineType = lineType
        self.fillType = fillType
        
        children.forEach {
            $0.removeFromParent()
            $0.parent = self
            $0.updateWorldTransform(worldTransform)
        }
        
        let isLinePath = lineWidth > 0 && !path.isEmpty
        let isLineColor = lineType != nil
        linePathBufferUpdateType = isLinePath ?
            (isLineColor ? .update : .wait) : .none
        lineColorBufferUpdateType = isLineColor ?
            (isLinePath ? .update : .wait) : .none
        let isFillColor = fillType != nil
        let isFillPath = !path.isEmpty
        fillPathBufferUpdateType = isFillPath ?
            (isFillColor ? .update : .wait) : .none
        fillColorBufferUpdateType = isFillColor ?
            (isFillPath ? .update : .wait) : .none
    }
}
extension Node {
    @discardableResult
    func updateBuffers() -> Bool {
        var isUpdate = false
        if linePathBufferUpdateType == .update {
            updateLinePathBuffer()
            linePathBufferUpdateType = .none
            isUpdate = true
        }
        if fillPathBufferUpdateType == .update {
            updateFillPathBuffer()
            fillPathBufferUpdateType = .none
            isUpdate = true
        }
        if lineColorBufferUpdateType == .update {
            updateLineColorBuffer()
            lineColorBufferUpdateType = .none
            isUpdate = true
        }
        if fillColorBufferUpdateType == .update {
            updateFillColorBuffer()
            fillColorBufferUpdateType = .none
            isUpdate = true
        }
        return isUpdate
    }
    func draw(with t: Transform, scale: Double, in ctx: Context) {
        draw(currentTransform: t,
             currentTransformBytes: nil,
             currentScale: scale,
             rootTransform: t,
             in: ctx)
    }
    func draw(with t: Transform, in ctx: Context) {
        draw(currentTransform: t,
             currentTransformBytes: nil,
             currentScale: t.absXScale,
             rootTransform: t,
             in: ctx)
    }
    fileprivate func draw(currentTransform: Transform,
                          currentTransformBytes: [Float]?,
                          currentScale: Double,
                          rootTransform: Transform,
                          in ctx: Context) {
        guard !isHidden else { return }
        
        let transform: Transform, nTransformBytes: [Float]?, tScale: Double
        if isIdentityFromLocal {
            transform = currentTransform
            nTransformBytes = currentTransformBytes
            tScale = currentScale
        } else {
            transform = worldTransform * rootTransform
            nTransformBytes = nil
            tScale = currentScale * localScale
        }
        
        guard let bounds = drawableBounds else {
            children.forEach { $0.draw(currentTransform: transform,
                                       currentTransformBytes: nTransformBytes,
                                       currentScale: tScale,
                                       rootTransform: rootTransform,
                                       in: ctx) }
            return
        }
        guard (bounds * transform)
                .intersects(Rect(x: -1, y: -1,
                                 width: 2, height: 2)) else { return }
        
        let transformBytes = nTransformBytes ?? transform.floatData4x4
        let floatSize = MemoryLayout<Float>.stride
        let transformLength = transformBytes.count * floatSize
        
        updateBuffers()
        
        if isRenderCache && enableCache && tScale < 1 {
            if isUpdateCache || cacheTexture == nil {
                newCache()
                isUpdateCache = false
            }
            if let cacheTexture = cacheTexture,
               let cacheTextureBuffer = cacheTextureBuffer {
                
                let (pointsBytes, counts) = Path(bounds).fillPointsData()
                ctx.setOpaqueTexturePipeline()
                ctx.setVertex(bytes: pointsBytes,
                              length: pointsBytes.count * floatSize,
                              at: 0)
                ctx.setVertex(cacheTextureBuffer, at: 1)
                ctx.setVertex(bytes: transformBytes,
                              length: transformLength, at: 2)
                ctx.setVertexCacheSampler(at: 3)
                ctx.setFragment(cacheTexture, at: 0)
                ctx.drawTriangleStrip(with: counts)
            }
            return
        }
        
        if let fillPathBuffer = fillPathBuffer {
            if path.isPolygon {
                if let fillColorBuffer = fillColorBuffer {
                    if isOpaque {
                        ctx.setOpaqueColorPipeline()
                    } else {
                        ctx.setAlphaColorPipeline()
                    }
                    ctx.setVertex(fillPathBuffer, at: 0)
                    ctx.setVertex(fillColorBuffer, at: 1)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 2)
                    ctx.drawTriangleStrip(with: fillPathBufferVertexCounts)
                } else if let texture = fillTexture,
                          let textureBuffer = fillTextureBuffer {
                    if isOpaque {
                        ctx.setOpaqueTexturePipeline()
                    } else {
                        ctx.setAlphaTexturePipeline()
                    }
                    ctx.setVertex(fillPathBuffer, at: 0)
                    ctx.setVertex(textureBuffer, at: 1)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 2)
                    ctx.setFragment(texture, at: 0)
                    ctx.drawTriangleStrip(with: fillPathBufferVertexCounts)
                }
            } else {
                ctx.setStencilPipeline()
                ctx.setInvertDepthStencil()
                ctx.setVertex(fillPathBuffer, at: 0)
                ctx.setVertex(bytes: transformBytes,
                              length: transformLength, at: 1)
                var i = ctx.drawTriangle(with: fillPathBufferVertexCounts)
                
                ctx.setStencilBezierPipeline()
                ctx.setVertex(fillPathBuffer, at: 0)
                ctx.setVertex(bytes: transformBytes,
                              length: transformLength, at: 1)
                i = ctx.drawTriangle(start: i,
                                     with: fillPathBufferBezierVertexCounts)
                
                if let fillColorBuffer = fillColorBuffer {
                    if isOpaque {
                        ctx.setOpaqueColorPipeline()
                    } else {
                        ctx.setAlphaColorPipeline()
                    }
                    ctx.setClippingDepthStencil()
                    ctx.setVertex(fillPathBuffer, at: 0)
                    ctx.setVertex(fillColorBuffer, at: 1)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 2)
                    ctx.drawTriangleStrip(start: i,
                                          with: fillPathBufferAroundVertexCounts)
                } else if let texture = fillTexture,
                          let textureBuffer = fillTextureBuffer {
                    if isOpaque {
                        ctx.setOpaqueTexturePipeline()
                    } else {
                        ctx.setAlphaTexturePipeline()
                    }
                    ctx.setClippingDepthStencil()
                    ctx.setVertex(fillPathBuffer, at: 0)
                    ctx.setVertex(textureBuffer, at: 1)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 2)
                    ctx.setFragment(texture, at: 0)
                    ctx.drawTriangleStrip(start: i,
                                          with: fillPathBufferAroundVertexCounts)
                }
                
                ctx.setNormalDepthStencil()
            }
        }
        
        if isRenderCache && enableCache, let owner = owner {
            ctx.clip(owner.viewportBounds(from: transform, bounds: bounds))
        }
        
        if let lineType = lineType, let linePathBuffer = linePathBuffer {
            switch lineType {
            case .color:
                if let lineColorBuffer = lineColorBuffer {
                    ctx.setOpaqueColorPipeline()
                    ctx.setVertex(linePathBuffer, at: 0)
                    ctx.setVertex(lineColorBuffer, at: 1)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 2)
                    ctx.drawTriangleStrip(with: linePathBufferVertexCounts)
                }
            case .gradient:
                if let lineColorsBuffer = lineColorsBuffer {
                    ctx.setColorsPipeline()
                    ctx.setVertex(linePathBuffer, at: 0)
                    ctx.setVertex(lineColorsBuffer, at: 1)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 2)
                    ctx.drawTriangleStrip(with: linePathBufferVertexCounts)
                }
            }
        }
        
        children.forEach { $0.draw(currentTransform: transform,
                                   currentTransformBytes: transformBytes,
                                   currentScale: tScale,
                                   rootTransform: rootTransform,
                                   in: ctx) }
        
        if isRenderCache && enableCache, let owner = owner {
            ctx.clip(owner.viewportBounds)
        }
    }
}

extension Node {
    func allChildrenAndSelf(_ closure: (Node) -> ()) {
        func allChildrenRecursion(_ child: Node, _ closure: (Node) -> Void) {
            child.backingChildren.forEach { allChildrenRecursion($0, closure) }
            closure(child)
        }
        allChildrenRecursion(self, closure)
    }
    func allChildren(_ closure: (Node) -> ()) {
        func allChildrenRecursion(_ child: Node, _ closure: (Node) -> Void) {
            child.backingChildren.forEach { allChildrenRecursion($0, closure) }
            closure(child)
        }
    }
    func allParents(closure: (Node, inout Bool) -> ()) {
        guard let parent = parent else { return }
        var stop = false
        closure(parent, &stop)
        guard !stop else { return }
        parent.allParents(closure: closure)
    }
    func selfAndAllParents(closure: (Node, inout Bool) -> ()) {
        var stop = false
        closure(self, &stop)
        guard !stop else { return }
        parent?.selfAndAllParents(closure: closure)
    }
    var root: Node {
        parent?.root ?? self
    }
    
    var isEmpty: Bool {
        path.isEmpty
    }
    var bounds: Rect? {
        path.bounds
    }
    var transformedBounds: Rect? {
        if let bounds = bounds {
            return bounds * localTransform
        } else {
            return nil
        }
    }
    var drawableBounds: Rect? {
        lineWidth > 0 && lineType != nil ?
            path.bounds?.inset(by: -lineWidth) : path.bounds
    }
    
    func contains(_ p: Point) -> Bool {
        !isHidden && containsPath(p)
    }
    func containsPath(_ p: Point) -> Bool {
        if fillType != nil && path.contains(p) {
            return true
        }
        if lineType != nil && path.containsLine(p, lineWidth: lineWidth) {
            return true
        }
        return false
    }
    func containsFromAllParents(_ parent: Node) -> Bool {
        var isParent = false
        allParents { (node, stop) in
            if node == parent {
                isParent = true
                stop = true
            }
        }
        return isParent
    }
    
    func at(_ p: Point) -> Node? {
        guard (isEmpty || containsPath(p)) && !isHidden else {
            return nil
        }
        for child in backingChildren.reversed() {
            let inPoint = p * child.localTransform.inverted()
            if let hitChild = child.at(inPoint) {
                return hitChild
            }
        }
        return isEmpty ? nil : self
    }
    
    func convert<T: AppliableTransform>(_ value: T,
                                        from node: Node) -> T {
        guard self != node else {
            return value
        }
        if containsFromAllParents(node) {
            return convert(value, fromParent: node)
        } else if node.containsFromAllParents(self) {
            return node.convert(value, toParent: self)
        } else {
            let rootValue = node.convertToWorld(value)
            return convertFromWorld(rootValue)
        }
    }
    private func convert<T: AppliableTransform>(_ value: T,
                                                fromParent: Node) -> T {
        var transform = Transform.identity
        selfAndAllParents { (node, stop) in
            if node == fromParent {
                stop = true
            } else {
                transform *= node.localTransform
            }
        }
        return value * transform.inverted()
    }
    func convertFromWorld<T: AppliableTransform>(_ value: T) -> T {
        var transform = Transform.identity
        selfAndAllParents { (node, _) in
            if node.parent != nil {
                transform *= node.localTransform
            }
        }
        return value * transform.inverted()
    }
    
    func convert<T: AppliableTransform>(_ value: T,
                                        to node: Node) -> T {
        guard self != node else {
            return value
        }
        if containsFromAllParents(node) {
            return convert(value, toParent: node)
        } else if node.containsFromAllParents(self) {
            return node.convert(value, fromParent: self)
        } else {
            let rootValue = convertToWorld(value)
            return node.convertFromWorld(rootValue)
        }
    }
    private func convert<T: AppliableTransform>(_ value: T,
                                                toParent: Node) -> T {
        guard let parent = parent else {
            return value
        }
        if parent == toParent {
            return value * localTransform
        } else {
            return parent.convert(value * localTransform,
                                  toParent: toParent)
        }
    }
    func convertToWorld<T: AppliableTransform>(_ value: T) -> T {
        parent?.convertToWorld(value * localTransform) ?? value
    }
}
extension Node: Equatable {
    static func == (lhs: Node, rhs: Node) -> Bool {
        lhs === rhs
    }
}
extension Node: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
