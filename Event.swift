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

enum Phase: Int8, Codable {
    case began, changed, ended
}

struct InputKeyType {
    static let click = InputKeyType(name: "Click".localized)
    static let subClick = InputKeyType(name: "SubClick".localized)
    static let lookUpTap = InputKeyType(name: "LookUpOperate".localized)
    static let a = InputKeyType(name: "Ａ"), b = InputKeyType(name: "Ｂ")
    static let c = InputKeyType(name: "Ｃ"), d = InputKeyType(name: "Ｄ")
    static let e = InputKeyType(name: "Ｅ"), f = InputKeyType(name: "Ｆ")
    static let g = InputKeyType(name: "Ｇ"), h = InputKeyType(name: "Ｈ")
    static let i = InputKeyType(name: "Ｉ"), j = InputKeyType(name: "Ｊ")
    static let k = InputKeyType(name: "Ｋ"), l = InputKeyType(name: "Ｌ")
    static let m = InputKeyType(name: "Ｍ"), n = InputKeyType(name: "Ｎ")
    static let o = InputKeyType(name: "Ｏ"), p = InputKeyType(name: "Ｐ")
    static let q = InputKeyType(name: "Ｑ"), r = InputKeyType(name: "Ｒ")
    static let s = InputKeyType(name: "Ｓ"), t = InputKeyType(name: "Ｔ")
    static let u = InputKeyType(name: "Ｕ"), v = InputKeyType(name: "Ｖ")
    static let w = InputKeyType(name: "Ｗ"), x = InputKeyType(name: "Ｘ")
    static let y = InputKeyType(name: "Ｙ"), z = InputKeyType(name: "Ｚ")
    static let no0 = InputKeyType(name: "0"), no1 = InputKeyType(name: "1")
    static let no2 = InputKeyType(name: "2"), no3 = InputKeyType(name: "3")
    static let no4 = InputKeyType(name: "4"), no5 = InputKeyType(name: "5")
    static let no6 = InputKeyType(name: "6"), no7 = InputKeyType(name: "7")
    static let no8 = InputKeyType(name: "8"), no9 = InputKeyType(name: "9")
    static let minus = InputKeyType(name: "-")
    static let equals = InputKeyType(name: "=")
    static let leftBracket = InputKeyType(name: "[")
    static let rightBracket = InputKeyType(name: "]")
    static let backslash = InputKeyType(name: "/")
    static let frontslash = InputKeyType(name: "\\")
    static let apostrophe = InputKeyType(name: "`")
    static let backApostrophe = InputKeyType(name: "^")
    static let comma = InputKeyType(name: ",")
    static let period = InputKeyType(name: ".")
    static let semicolon = InputKeyType(name: ";")
    static let underscore = InputKeyType(name: "_")
    static let space = InputKeyType(name: "space")
    static let `return` = InputKeyType(name: "return")
    static let tab = InputKeyType(name: "tab")
    static let delete = InputKeyType(name: "delete")
    static let escape = InputKeyType(name: "esc")
    static let command = InputKeyType(name: "⌘")
    static let shift = InputKeyType(name: "⇧")
    static let option = InputKeyType(name: "⌥")
    static let control = InputKeyType(name: "⌃")
    static let up = InputKeyType(name: "↑")
    static let down = InputKeyType(name: "↓")
    static let left = InputKeyType(name: "←")
    static let right = InputKeyType(name: "→")
    
    var name: String
}
extension InputKeyType: Hashable {}
extension InputKeyType {
    var isText: Bool {
        switch self {
        case .click, .subClick, .lookUpTap,
             .space, .`return`, .tab, .delete,
             .escape, .command, .shift, .option, .control,
             .up, .down, .left, .right:
            return false
        default:
            return true
        }
    }
    var isTextEdit: Bool {
        switch self {
        case .click, .subClick, .lookUpTap,
             .escape, .command, .shift, .option, .control:
            return false
        default:
            return true
        }
    }
    var isInputText: Bool {
        switch self {
        case .click, .subClick, .lookUpTap,
             .escape, .command, .shift, .option, .control,
             .up, .down, .left, .right:
            return false
        default:
            return true
        }
    }
    var isArrow: Bool {
        switch self {
        case .up, .down, .left, .right:
            return true
        default:
            return false
        }
    }
}

struct EventType {
    static let indicate = EventType(name: "Indicate".localized)
    static let drag = EventType(name: "Drag".localized)
    static let subDrag = EventType(name: "SubDrag".localized)
    static let scroll = EventType(name: "Scroll".localized)
    static let pinch = EventType(name: "Pinch".localized)
    static let rotate = EventType(name: "Rotate".localized)
    static let keyInput = EventType(name: "KeyInput".localized)
    static let vPinch = EventType(name: "V Pinch".localized)
    
    var name: String
}
extension EventType: Hashable {}

struct ModifierKeys: OptionSet {
    let rawValue: Int
    
    static let shift = ModifierKeys(rawValue: 1 << 0)
    static let control = ModifierKeys(rawValue: 1 << 1)
    static let option = ModifierKeys(rawValue: 1 << 2)
    static let command = ModifierKeys(rawValue: 1 << 3)
}
extension ModifierKeys: Hashable {}
extension ModifierKeys {
    var displayString: String {
        var str = ""
        if contains(.shift) {
            str.append("⇧")
        }
        if contains(.control) {
            str.append("⌃")
        }
        if contains(.option) {
            str.append("⌥")
        }
        if contains(.command) {
            str.append("⌘")
        }
        return str
    }
}
struct Quasimode {
    var modifierKeys: ModifierKeys
    var type: EventType
    var inputKeyType: InputKeyType?
    
    init(modifier modifierKeys: ModifierKeys = [], _ type: EventType) {
        self.modifierKeys = modifierKeys
        self.type = type
    }
    init(modifier modifierKeys: ModifierKeys = [], _ inputKeyType: InputKeyType) {
        self.modifierKeys = modifierKeys
        type = .keyInput
        self.inputKeyType = inputKeyType
    }
}
extension Quasimode: Hashable {}
extension Quasimode {
    var displayString: String {
        let mt = modifierKeys.displayString
        return mt.isEmpty ? inputDisplayString : mt + " " + inputDisplayString
    }
    var modifierDisplayString: String {
        modifierKeys.displayString
    }
    var inputDisplayString: String {
        inputKeyType?.name ?? type.name
    }
}
extension Quasimode {
    static let zoom = Quasimode(.pinch)
    static let rotate = Quasimode(.rotate)
    static let scroll = Quasimode(.scroll)
    
    static let drawLine = Quasimode(.drag)
    static let drawStraightLine = Quasimode(modifier: [.shift], .drag)
    
    static let changeToDraft = Quasimode(modifier: [.command], .d)
    static let cutDraft = Quasimode(modifier: [.shift, .command], .d)
    
    static let makeFaces = Quasimode(modifier: [.command], .b)
    static let cutFaces = Quasimode(modifier: [.shift, .command], .b)
    static let changeLightness = Quasimode(modifier: [.option], .drag)
    static let changeTint = Quasimode(modifier: [.shift, .option], .drag)
    
    static let inputCharacter = Quasimode(.keyInput)
    static let changeToSuperscript = Quasimode(modifier: [.command], .up)
    static let changeToSubscript = Quasimode(modifier: [.command], .down)
    static let changeToVerticalText = Quasimode(modifier: [.command], .l)
    static let changeToHorizontalText = Quasimode(modifier: [.command, .shift], .l)
    static let lookUp = Quasimode(.lookUpTap)
    
    static let lassoCut = Quasimode(modifier: [.command], .drag)
    static let select = Quasimode(modifier: [.shift, .command], .drag)
    static let unselect = Quasimode(modifier: [.shift, .command], .click)
    static let find = Quasimode(modifier: [.command], .f)
    static let cut = Quasimode(modifier: [.command], .x)
    static let copy = Quasimode(modifier: [.command], .c)
    static let paste = Quasimode(modifier: [.command], .v)
    static let scalingPaste = Quasimode(modifier: [.command], .vPinch)
    
    static let undo = Quasimode(modifier: [.command], .z)
    static let redo = Quasimode(modifier: [.shift, .command], .z)
    static let selectVersion = Quasimode(modifier: [.control], .drag)
    
    static let run = Quasimode(.click)
    static let openMenu = Quasimode(.subClick)
}

protocol Event {
    var screenPoint: Point { get }
    var time: Double { get }
    var phase: Phase { get }
}

struct InputKeyEvent: Event {
    var screenPoint: Point, time: Double, pressure: Double, phase: Phase,
        isRepeat: Bool
    var inputKeyType: InputKeyType
}

struct DragEvent: Event {
    var screenPoint: Point, time: Double, pressure: Double, phase: Phase
}
extension DragEvent {
    init(_ event: InputKeyEvent) {
        screenPoint = event.screenPoint
        time = event.time
        pressure = 1
        phase = event.phase
    }
}

struct ScrollEvent: Event {
    var screenPoint: Point, time: Double, scrollDeltaPoint: Point
    var phase: Phase, touchPhase: Phase?, momentumPhase: Phase?
}

struct PinchEvent: Event {
    var screenPoint: Point, time: Double, magnification: Double, phase: Phase
}

struct RotateEvent: Event {
    var screenPoint: Point, time: Double, rotationQuantity: Double, phase: Phase
}
