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
    // Actions du plein écran de Side (grille des fenêtres, carrousel ; ex-Square) : proposées si Side est installé.
    case squareGrille, squareSuivante, squarePrecedente, squareAgrandir
    // Actions de l'app Side (carte Finder, panneau du bas) : proposées seulement si Side les accepte sur ce Mac.
    case sideCarte, sidePanneau

    /// Cette action a besoin de l'app Side.
    var pourSide: Bool { self == .sideCarte || self == .sidePanneau }

    /// Cette action a besoin de l'app Square.
    var pourSquare: Bool {
        switch self {
        case .squareGrille, .squareSuivante, .squarePrecedente, .squareAgrandir: return true
        default: return false
        }
    }

    var label: String {
        switch self {
        case .defaut: return String(localized: "Par défaut")
        case .rien: return String(localized: "Rien")
        case .precedent: return String(localized: "Page précédente (⌘[)")
        case .suivant: return String(localized: "Page suivante (⌘])")
        case .missionControl: return String(localized: "Mission Control")
        case .fenetresApp: return String(localized: "Fenêtres de l'app")
        case .bureau: return String(localized: "Afficher le bureau")
        case .apps: return String(localized: "Toutes les apps")
        case .bureauGauche: return String(localized: "Bureau ou écran de gauche")
        case .bureauDroite: return String(localized: "Bureau ou écran de droite")
        case .fenetreGauche: return String(localized: "Envoyer la fenêtre à gauche")
        case .fenetreDroite: return String(localized: "Envoyer la fenêtre à droite")
        case .clicMilieu: return String(localized: "Clic du milieu")
        case .lecturePause: return String(localized: "Lecture / pause")
        case .spotlight: return String(localized: "Spotlight")
        case .capture: return String(localized: "Capture d'écran (⌘⇧5)")
        case .copier: return String(localized: "Copier")
        case .coller: return String(localized: "Coller")
        case .fermerOnglet: return String(localized: "Fermer l'onglet (⌘W)")
        case .squareGrille: return String(localized: "Side : afficher la grille")
        case .squareSuivante: return String(localized: "Side : application suivante")
        case .squarePrecedente: return String(localized: "Side : application précédente")
        case .squareAgrandir: return String(localized: "Side : agrandir la fenêtre")
        case .sideCarte: return String(localized: "Side : afficher le Finder")
        case .sidePanneau: return String(localized: "Side : afficher le panneau du bas")
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
        case .squareGrille: Square.envoyer("grille")
        case .squareSuivante: Square.envoyer("suivante")
        case .squarePrecedente: Square.envoyer("precedente")
        case .squareAgrandir: Square.envoyer("agrandir")
        case .sideCarte: Side.envoyer("carte")
        case .sidePanneau: Side.envoyer("panneau")
        }
    }
}

/// L'app Side (carte Finder qui descend du bord de l'écran). Mulot lui envoie ses commandes par un message entre applications.
enum Side {
    static let identifiant = "com.gauthieraube.side"

    /// Side est-elle installée, dans une version qui accepte ces commandes ? (Elle le signale dans ses réglages.)
    static var disponible: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifiant) != nil
            && (CFPreferencesCopyAppValue("commandesExterieures" as CFString, identifiant as CFString) as? Bool) == true
    }

    static func envoyer(_ commande: String) {
        DistributedNotificationCenter.default().postNotificationName(.init(identifiant + ".commande"), object: commande,
                                                                     userInfo: nil, deliverImmediately: true)
    }
}

/// L'app Square (grille des fenêtres ouvertes). Mulot lui envoie ses commandes par un message entre applications.
enum Square {
    static let identifiant = "com.gauthieraube.square"

    /// Le plein écran est-il disponible ? Depuis le 13/11/2026, Square fait partie de Side, qui écoute toujours les commandes
    /// adressées à Square. Ses actions sont donc proposées si Side ou l'ancien Square est installé.
    static var installee: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifiant) != nil
            || NSWorkspace.shared.urlForApplication(withBundleIdentifier: Side.identifiant) != nil
    }

    static func envoyer(_ commande: String) {
        DistributedNotificationCenter.default().postNotificationName(.init(identifiant + ".commande"), object: commande,
                                                                     userInfo: nil, deliverImmediately: true)
    }
}

/// Ce que fait la molette pour le pouce.
enum ThumbMode: String, CaseIterable {
    case defaut, onglets, volume, zoom, bureaux, square, rien

    /// Les modes proposés : celui du carrousel seulement si Side (ou l'ancien Square) est installé.
    static var proposes: [ThumbMode] { allCases.filter { $0 != .square || Square.installee } }

    var label: String {
        switch self {
        case .defaut: return String(localized: "Défilement horizontal")
        case .onglets: return String(localized: "Changer d'onglet")
        case .volume: return String(localized: "Volume")
        case .zoom: return String(localized: "Zoom (⌘+ / ⌘−)")
        case .bureaux: return String(localized: "Changer de bureau")
        case .square: return String(localized: "Side : changer d'application")
        case .rien: return String(localized: "Rien")
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
        // Chaque cran avance le carrousel de Square d'une fenêtre ; il choisit quand la molette s'arrête.
        case .square: Square.envoyer(right ? "carrousel:cran:1" : "carrousel:cran:-1")
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
