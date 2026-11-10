import AppKit
import Carbon.HIToolbox

/// Marque nos propres événements pour ne pas les retraiter.
let syntheticMarker: Int64 = 0x5155_4D58

enum Action: String, CaseIterable {
    case defaut, rien
    case precedent, suivant
    case missionControl, fenetresApp, bureau, apps
    case bureauGauche, bureauDroite, fenetreGauche, fenetreDroite
    case clicMilieu, lecturePause, spotlight, capture, copier, coller, fermerOnglet

    var label: String {
        switch self {
        case .defaut: return "Par défaut"
        case .rien: return "Rien"
        case .precedent: return "Page précédente (⌘[)"
        case .suivant: return "Page suivante (⌘])"
        case .missionControl: return "Mission Control"
        case .fenetresApp: return "Fenêtres de l'app"
        case .bureau: return "Afficher le bureau"
        case .apps: return "Toutes les apps"
        case .bureauGauche: return "Bureau ou écran de gauche"
        case .bureauDroite: return "Bureau ou écran de droite"
        case .fenetreGauche: return "Envoyer la fenêtre à gauche"
        case .fenetreDroite: return "Envoyer la fenêtre à droite"
        case .clicMilieu: return "Clic du milieu"
        case .lecturePause: return "Lecture / pause"
        case .spotlight: return "Spotlight"
        case .capture: return "Capture d'écran (⌘⇧5)"
        case .copier: return "Copier"
        case .coller: return "Coller"
        case .fermerOnglet: return "Fermer l'onglet (⌘W)"
        }
    }

    func perform() {
        switch self {
        case .defaut, .rien: break
        case .precedent: Keys.combo(kVK_ANSI_LeftBracket, .maskCommand)
        case .suivant: Keys.combo(kVK_ANSI_RightBracket, .maskCommand)
        case .missionControl: Keys.dock("com.apple.expose.awake")
        case .fenetresApp: Keys.dock("com.apple.expose.front.awake")
        case .bureau: Keys.dock("com.apple.showdesktop.awake")
        case .apps: NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Apps.app"))
        case .bureauGauche: Screens.desktopOrScreen(-1)
        case .bureauDroite: Screens.desktopOrScreen(1)
        case .fenetreGauche: Screens.moveWindow(-1)
        case .fenetreDroite: Screens.moveWindow(1)
        case .clicMilieu: Keys.middleClick()
        case .lecturePause: Keys.media(16)
        case .spotlight: Keys.combo(kVK_Space, .maskCommand)
        case .capture: Keys.combo(kVK_ANSI_5, [.maskCommand, .maskShift])
        case .copier: Keys.combo(kVK_ANSI_C, .maskCommand)
        case .coller: Keys.combo(kVK_ANSI_V, .maskCommand)
        case .fermerOnglet: Keys.combo(kVK_ANSI_W, .maskCommand)
        }
    }
}

/// Ce que fait la molette pour le pouce.
enum ThumbMode: String, CaseIterable {
    case defaut, onglets, volume, zoom, bureaux, rien

    var label: String {
        switch self {
        case .defaut: return "Défilement horizontal"
        case .onglets: return "Changer d'onglet"
        case .volume: return "Volume"
        case .zoom: return "Zoom (⌘+ / ⌘−)"
        case .bureaux: return "Changer de bureau"
        case .rien: return "Rien"
        }
    }

    /// direction > 0 : vers la droite
    func step(_ direction: Int) {
        let right = direction > 0
        switch self {
        case .defaut, .rien: break
        case .onglets: Keys.combo(kVK_Tab, right ? .maskControl : [.maskControl, .maskShift])
        case .volume: Keys.media(right ? 0 : 1)
        case .zoom: Keys.combo(right ? kVK_ANSI_Equal : kVK_ANSI_Minus, .maskCommand)
        case .bureaux: (right ? Action.bureauDroite : Action.bureauGauche).perform()
        }
    }
}

enum Keys {
    static func combo(_ key: Int, _ flags: CGEventFlags) {
        let src = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(key), keyDown: down) else { continue }
            e.flags = flags
            e.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
            e.post(tap: .cghidEventTap)
        }
    }

    /// Mission Control et ses variantes, déclenchés par le Dock lui-même
    /// (macOS refuse qu'on lance directement l'app Mission Control).
    private typealias DockFn = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Int32
    private static let dockNotify: DockFn? = {
        let h = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_NOW)
        return dlsym(h, "CoreDockSendNotification").map { unsafeBitCast($0, to: DockFn.self) }
    }()
    static func dock(_ name: String) { _ = dockNotify?(name as CFString, nil) }

    /// Touches multimédia (0 volume +, 1 volume −, 16 lecture/pause).
    static func media(_ key: Int32) {
        for down in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
            let data1 = Int((key << 16) | ((down ? 0xA : 0xB) << 8))
            guard let ev = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: flags,
                                              timestamp: 0, windowNumber: 0, context: nil,
                                              subtype: 8, data1: data1, data2: -1) else { continue }
            ev.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    static func middleClick() {
        let loc = CGEvent(source: nil)?.location ?? .zero
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            guard let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: loc,
                                  mouseButton: .center) else { continue }
            e.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
            e.post(tap: .cghidEventTap)
        }
    }
}
