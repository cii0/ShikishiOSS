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

struct Action {
    var name: String, quasimode: Quasimode,
        isHidden = false, isEnableRoot = true
}
struct ActionList {
    typealias Group = [Action]
    
    var actionGroups: [Group]
    var actions: [Action]
    
    init(_ actionGroups: [Group]) {
        self.actionGroups = actionGroups
        actions = actionGroups.reduce(into: [Action]()) { $0 += $1 }
    }
}
extension ActionList {
    static let `default`
        = ActionList([[Action(name: "Draw Line".localized,
                              quasimode: .drawLine,
                              isEnableRoot: false),
                       Action(name: "Draw Straight Line".localized,
                              quasimode: .drawStraightLine,
                              isEnableRoot: false)],
                      [Action(name: "Lasso Cut".localized,
                              quasimode: .lassoCut),
                       Action(name: "Select by Range".localized,
                               quasimode: .select)],
                      [Action(name: "Change Lightness".localized,
                              quasimode: .changeLightness,
                              isEnableRoot: false),
                       Action(name: "Change Tint".localized,
                              quasimode: .changeTint,
                              isEnableRoot: false)],
                      [Action(name: "Select Version".localized,
                              quasimode: .selectVersion)],
                      [Action(name: "Input Character".localized,
                              quasimode: .inputCharacter,
                              isEnableRoot: false),
                       Action(name: "Run".localized,
                              quasimode: .run,
                              isHidden: !System.isVersion2,
                              isEnableRoot: false),
                       Action(name: "Open Menu".localized,
                              quasimode: .openMenu),
                       Action(name: "Look Up".localized,
                             quasimode: .lookUp)],
                      [Action(name: "Scroll".localized,
                               quasimode: .scroll),
                        Action(name: "Zoom".localized,
                               quasimode: .zoom),
                        Action(name: "Rotate".localized,
                               quasimode: .rotate)],
                      [Action(name: "Undo".localized,
                              quasimode: .undo),
                       Action(name: "Redo".localized,
                              quasimode: .redo)],
                      [Action(name: "Cut".localized,
                              quasimode: .cut),
                       Action(name: "Copy".localized,
                              quasimode: .copy),
                       Action(name: "Paste".localized,
                              quasimode: .paste),
                       Action(name: "Resize Paste".localized,
                              quasimode: .scalingPaste,
                              isEnableRoot: false)],
                      [Action(name: "Find".localized,
                              quasimode: .find,
                              isHidden: !System.isVersion2,
                              isEnableRoot: false)],
                      [Action(name: "Change to Draft".localized,
                              quasimode: .changeToDraft,
                              isEnableRoot: false),
                       Action(name: "Cut Draft".localized,
                              quasimode: .cutDraft,
                              isEnableRoot: false)],
                      [Action(name: "Make Faces".localized,
                              quasimode: .makeFaces,
                              isEnableRoot: false),
                       Action(name: "Cut Faces".localized,
                              quasimode: .cutFaces,
                              isEnableRoot: false)],
                      [Action(name: "Change to Superscript".localized,
                              quasimode: .changeToSuperscript,
                              isHidden: !System.isVersion2,
                              isEnableRoot: false),
                       Action(name: "Change to Subscript".localized,
                              quasimode: .changeToSubscript,
                              isHidden: !System.isVersion2,
                              isEnableRoot: false),
                       Action(name: "Change to Vertical Text".localized,
                              quasimode: .changeToVerticalText,
                              isEnableRoot: false),
                       Action(name: "Change to Horizontal Text".localized,
                              quasimode: .changeToHorizontalText,
                              isEnableRoot: false)]])
}
extension ActionList {
    func node(isEditingSheet: Bool) -> Node {
        let fontSize = 14.0
        let padding = fontSize / 2, lineWidth = 1.0, cornerRadius = 8.0
        let margin = fontSize / 2 + 1.0, imagePadding = 3.0
        
        func textNode(with string: String,
                      color: Color = .content) -> (size: Size, node: Node)? {
            let typesetter = Text(string: string, size: fontSize).typesetter
            let paddingSize = Size(square: imagePadding)
            guard let b = typesetter.typoBounds else { return nil }
            let nb = b.outset(by: paddingSize).integral
            guard let texture = typesetter
                    .texture(with: nb,
                             fillColor: color,
                             backgroundColor: Color(lightness: color.lightness,
                                                    opacity: 0)) else {
                return nil
            }
            
            return (b.integral.size, Node(path: Path(nb),
                                  fillType: .texture(texture)))
        }
        
        var quasimodeNodes = [Node]()
        var borderNodes = [(height: Double, node: Node)]()
        var children = [Node]()
        
        var w = 0.0, h = margin
        for (i, actionGroup) in actionGroups.reversed().enumerated() {
            var isDraw = false
            for action in actionGroup.reversed() {
                guard !action.isHidden else { continue }
                let color: Color = !isEditingSheet && !action.isEnableRoot ? Color(lightness: Color.content.lightness, opacity: 0.3) :
                    .content
                guard let (nts, nNode) = textNode(with: action.name, color: color),
                      let (its, iNode)
                        = textNode(with: action.quasimode.inputDisplayString, color: color) else { continue }
                nNode.attitude.position = Point((margin + imagePadding).rounded(),
                                                h + fontSize / 2 - imagePadding)
                iNode.attitude.position = Point(-its.width + imagePadding,
                                                h + fontSize / 2 - imagePadding)
                let qw: Double, qNode: Node
                if let (mts, mNode)
                    = textNode(with: action.quasimode.modifierDisplayString, color: color) {
                    
                    qw = (its.width + padding + mts.width).rounded()
                    mNode.attitude.position = Point(-qw + imagePadding,
                                                    h + fontSize / 2 - imagePadding)
                    qNode = Node(children: [iNode, mNode])
                } else {
                    qw = its.width.rounded()
                    qNode = Node(children: [iNode])
                }
                w = max(w, nts.width + qw + margin * 2)
                quasimodeNodes.append(qNode)
                children.append(nNode)
                children.append(qNode)
                h += fontSize + padding
                isDraw = true
            }
            if isDraw {
                h += -padding + margin
                
                if i < actionGroups.count - 1 {
                    let borderNode = Node(lineWidth: lineWidth,
                                          lineType: .color(.subBorder))
                    children.append(borderNode)
                    borderNodes.append((h, borderNode))
                    h += margin
                }
            }
        }
        
        w += margin * 2
        
        for node in quasimodeNodes {
            node.attitude.position.x = (w - margin).rounded()
        }
        for (height, node) in borderNodes {
            node.path = Path(Edge(Point(0, height), Point(w, height)))
        }
        
        let f = Rect(x: 0, y: 0, width: w, height: h)
        let node = Node(children: children,
                        attitude: Attitude(position: Point()),
                        path: Path(f, cornerRadius: cornerRadius),
                        lineWidth: lineWidth, lineType: .color(.subBorder),
                        fillType: .color(Color.disabled.with(opacity: 0.95)))
        return Node(children: [node],
                    path: Path(f.inset(by: -margin)))
    }
}
