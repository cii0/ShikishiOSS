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

final class LightnessChanger: DragEditor {
    let editor: ColorEditor
    
    init(_ document: Document) {
        editor = ColorEditor(document)
    }
    
    func send(_ event: DragEvent) {
        editor.changeLightness(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class TintChanger: DragEditor {
    let editor: ColorEditor
    
    init(_ document: Document) {
        editor = ColorEditor(document)
    }
    
    func send(_ event: DragEvent) {
        editor.changeTint(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class ColorEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    var colorOwners = [SheetColorOwner]()
    var fp = Point()
    var firstUUColor = UU(Color())
    var editingUUColor = UU(Color())
    
    func updateNode() {
        let attitude = Attitude(document.screenToWorldTransform)
        var lightnessAttitude = attitude
        lightnessAttitude.position = lightnessWorldPosition
        lightnessNode.attitude = lightnessAttitude
        var tintAttitude = attitude
        tintAttitude.position = tintWorldPosition
        tintBorderNode.attitude = tintAttitude
        tintNode.attitude = tintAttitude
    }
    
    let colorPointNode = Node(path: Path(circleRadius: 4.5), lineWidth: 1,
                              lineType: .color(.background),
                              fillType: .color(.content))
    
    var lightnessHeight = 140.0
    private func lightnessPointsWith(splitCount count: Int = 140) -> [Point] {
        let rCount = 1 / Double(count)
        return (0...count).map {
            let t = Double($0) * rCount
            return Point(0, lightnessHeight * t)
        }
    }
    private func lightnessGradientWith(chroma: Double, hue: Double,
                                       splitCount count: Int = 140) -> [Color] {
        let rCount = 1 / Double(count)
        return (0...count).map {
            let t = Double.linear(Color.minLightness, Color.whiteLightness,
                                  t: Double($0) * rCount)
            return Color(lightness: t, unsafetyChroma: chroma, hue: hue)
        }
    }
    let lightnessNode = Node(lineWidth: 2)
    var isEditingLightness = false {
        didSet {
            guard isEditingLightness != oldValue else { return }
            if isEditingLightness {
                let color = firstUUColor.value
                let gradient = lightnessGradientWith(chroma: color.chroma,
                                                     hue: color.hue)
                lightnessNode.lineType = .gradient(gradient)
                document.rootNode.append(child: lightnessNode)
                lightnessNode.append(child: colorPointNode)
            } else {
                lightnessNode.removeFromParent()
                colorPointNode.removeFromParent()
            }
        }
    }
    var beganLightnessPosition = Point() {
        didSet {
            lightnessNode.attitude.position = lightnessWorldPosition
        }
    }
    var lightnessWorldPosition: Point {
        let sfp = document.convertWorldToScreen(beganLightnessPosition)
        let t = oldEditingLightness.clipped(min: Color.minLightness,
                                            max: Color.whiteLightness,
                                            newMin: 0, newMax: 1)
        let dp = Point(0, lightnessHeight * t)
        return document.convertScreenToWorld(sfp - dp)
    }
    var oldEditingLightness = 0.0
    var editingLightness = 0.0 {
        didSet {
            let t = editingLightness.clipped(min: Color.minLightness,
                                             max: Color.whiteLightness,
                                             newMin: 0, newMax: 1)
            let p = Point(0, lightnessHeight * t)
            colorPointNode.attitude.position = p
        }
    }
    
    func updateOwners(with event: DragEvent) {
        let p = document.convertScreenToWorld(event.screenPoint)
        
        guard let sheetView = document.madeSheetView(at: p) else {
            self.colorOwners = []
            return
        }
        let inP = sheetView.convertFromWorld(p)
        let topOwner = sheetView.sheetColorOwner(at: inP)
        let uuColor = topOwner.uuColor
        
        if document.isSelect(at: p),
           !document.isSelectedText,
           let f = document.selections.first?.rect {
            var colorOwners = [SheetColorOwner]()
            for (shp, _) in document.sheetViewValues {
                let ssFrame = document.sheetFrame(with: shp)
                if ssFrame.intersects(f),
                   let sheetView = document.sheetView(at: shp) {
                    
                    let b = sheetView.convertFromWorld(f)
                    for co in sheetView.sheetColorOwner(at: b) {
                        colorOwners.append(co)
                    }
                }
            }
            self.colorOwners = colorOwners
            firstUUColor = uuColor
        } else {
            var colorOwners = [SheetColorOwner]()
            if let co = sheetView.sheetColorOwner(with: uuColor) {
                colorOwners.append(co)
            }
            self.colorOwners = colorOwners
            firstUUColor = uuColor
        }
    }
    
    func capture() {
        var ssSet = Set<SheetView>()
        colorOwners.forEach {
            if ssSet.contains($0.sheetView) {
                $0.captureUUColor(isNewUndoGroup: false)
            } else {
                ssSet.insert($0.sheetView)
                $0.captureUUColor(isNewUndoGroup: true)
            }
        }
    }
    
    func changeLightness(with event: DragEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        func updateLightness() {
            let wp = document.convertScreenToWorld(event.screenPoint)
            let p = lightnessNode.convertFromWorld(wp)
            let t = (p.y / lightnessHeight).clipped(min: 0, max: 1)
            let lightness = Double.linear(Color.minLightness,
                                          Color.whiteLightness,
                                          t: t)
            var uuColor = firstUUColor
            uuColor.value.lightness = lightness
            editingUUColor = uuColor
            colorOwners.forEach { $0.uuColor = uuColor }
            
            editingLightness = lightness
        }
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            updateNode()
            updateOwners(with: event)
            fp = event.screenPoint
            let g = lightnessGradientWith(chroma: firstUUColor.value.chroma,
                                          hue: firstUUColor.value.hue)
            lightnessNode.lineType = .gradient(g)
            lightnessNode.path = Path([Pathline(lightnessPointsWith())])
            oldEditingLightness = firstUUColor.value.lightness
            editingLightness = oldEditingLightness
            beganLightnessPosition = document.convertScreenToWorld(fp)
            editingUUColor = firstUUColor
            isEditingLightness = true
        case .changed:
            updateLightness()
        case .ended:
            capture()
            colorOwners = []
            isEditingLightness = false
            lightnessNode.removeFromParent()
            tintBorderNode.removeFromParent()
            tintNode.removeFromParent()
            
            document.cursor = Document.defaultCursor
        }
    }
    
    let tintNode = Node(lineWidth: 2)
    let tintBorderNode = Node(lineWidth: 3.25, lineType: .color(.background))
    let tintLineNode = Node(lineWidth: 1, lineType: .color(.content))
    let tintOutlineNode = Node(lineWidth: 2.5, lineType: .color(.background))
    var tintLightness = 0.0
    var isEditingTint = false {
        didSet {
            guard isEditingTint != oldValue else { return }
            if isEditingTint {
                updateTintNode()
                tintBorderNode.lineType = .color(tintLightness > 50 ? .content : .background)
                document.rootNode.append(child: tintBorderNode)
                document.rootNode.append(child: tintNode)
                tintNode.append(child: tintOutlineNode)
                tintNode.append(child: tintLineNode)
                tintNode.append(child: colorPointNode)
            } else {
                colorPointNode.removeFromParent()
                tintNode.removeFromParent()
                tintLineNode.removeFromParent()
                tintOutlineNode.removeFromParent()
            }
        }
    }
    func updateTintNode(radius r: Double = 128, splitCount: Int = 360) {
        let rsc = 1 / Double(splitCount)
        var points = [Point](), colors = [Color]()
        for i in 0..<splitCount {
            let hue = Double(i) * rsc * 2 * .pi
            let color = Color(lightness: tintLightness,
                              unsafetyChroma: r, hue: hue)
            let p = color.tint.rectangular
            colors.append(color)
            points.append(p)
        }
        let path = Path([Pathline(points, isClosed: true)])
        tintNode.path = path
        tintNode.lineType = .gradient(colors)
        tintBorderNode.path = path
        tintBorderNode.lineType = .gradient(colors)
    }
    var beganTintPosition = Point() {
        didSet {
            tintBorderNode.attitude.position = tintWorldPosition
            tintNode.attitude.position = tintWorldPosition
        }
    }
    var tintWorldPosition: Point {
        let sfp = document.convertWorldToScreen(beganTintPosition)
        return document.convertScreenToWorld(sfp - oldEditingTintPosition)
    }
    var isSnappedTint = false {
        didSet {
            guard isSnappedTint != oldValue else { return }
            if isSnappedTint {
                Feedback.performAlignment()
            }
            colorPointNode.fillType = .color(isSnappedTint ? .selected : .content)
        }
    }
    var oldEditingTintPosition = Point()
    var editingTintPosition = Point() {
        didSet {
            colorPointNode.attitude.position = editingTintPosition
            updateTintLinePath()
        }
    }
    func updateTintLinePath() {
        let path = Path([Pathline([Point(), editingTintPosition])])
        tintLineNode.path = path
        tintOutlineNode.path = path
    }
    func changeTint(with event: DragEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        func updateTint() {
            let wp = document.convertScreenToWorld(event.screenPoint)
            let p = tintNode.convertFromWorld(wp)
            let fTintP = Point()
            let r = fTintP.distance(p)
            let theta = fTintP.angle(p)
            var uuColor = firstUUColor
            isSnappedTint = r < 2
            uuColor.value.chroma = isSnappedTint ? 0 : r
            uuColor.value.hue = theta
            let polarPoint = Point(uuColor.value.a, uuColor.value.b).polar
            uuColor.value.hue = polarPoint.theta
            uuColor.value.chroma = min(polarPoint.r, Color.maxChroma)
            editingUUColor = uuColor
            colorOwners.forEach { $0.uuColor = uuColor }
            
            editingTintPosition = PolarPoint(uuColor.value.chroma,
                                           uuColor.value.hue).rectangular
        }
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            updateNode()
            updateOwners(with: event)
            fp = event.screenPoint
            tintLightness = firstUUColor.value.lightness
            oldEditingTintPosition = PolarPoint(firstUUColor.value.chroma,
                                              firstUUColor.value.hue).rectangular
            editingTintPosition = oldEditingTintPosition
            beganTintPosition = document.convertScreenToWorld(fp)
            editingUUColor = firstUUColor
            isEditingTint = true
        case .changed:
            updateTint()
        case .ended:
            capture()
            colorOwners = []
            isEditingTint = false
            lightnessNode.removeFromParent()
            tintNode.removeFromParent()
            tintBorderNode.removeFromParent()
            
            document.cursor = Document.defaultCursor
        }
    }
}
