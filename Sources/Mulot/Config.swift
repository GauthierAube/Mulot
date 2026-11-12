import Foundation

/// Réglages, enregistrés dans les préférences macOS.
enum Slot: String, CaseIterable {
    case gesteClic, gesteHaut, gesteBas, gesteGauche, gesteDroite
    case precedent, suivant, molette, boutonMolette

    var label: String {
        switch self {
        case .gesteClic: return String(localized: "Bouton de pouce : simple clic")
        case .gesteHaut: return String(localized: "Geste vers le haut ↑")
        case .gesteBas: return String(localized: "Geste vers le bas ↓")
        case .gesteGauche: return String(localized: "Geste vers la gauche ←")
        case .gesteDroite: return String(localized: "Geste vers la droite →")
        case .precedent: return String(localized: "Bouton Précédent")
        case .suivant: return String(localized: "Bouton Suivant")
        case .molette: return String(localized: "Clic de la molette")
        case .boutonMolette: return String(localized: "Bouton derrière la molette")
        }
    }

    /// Libellé court affiché au-dessus de l'action.
    var shortLabel: String {
        switch self {
        case .gesteClic: return String(localized: "Appuyer")
        case .gesteHaut: return String(localized: "Appuyer et glisser vers le haut")
        case .gesteBas: return String(localized: "Appuyer et glisser vers le bas")
        case .gesteGauche: return String(localized: "Appuyer et glisser à gauche")
        case .gesteDroite: return String(localized: "Appuyer et glisser à droite")
        case .precedent: return String(localized: "Bouton arrière")
        case .suivant: return String(localized: "Bouton avant")
        case .molette: return String(localized: "Clic de la molette")
        case .boutonMolette: return String(localized: "Bouton derrière la molette")
        }
    }

    /// Où se trouve le bouton sur le dessin de la souris.
    var spot: Spot {
        switch self {
        case .gesteClic, .gesteHaut, .gesteBas, .gesteGauche, .gesteDroite: return .geste
        case .precedent: return .precedent
        case .suivant: return .suivant
        case .molette: return .molette
        case .boutonMolette: return .superieur
        }
    }
    var arrow: Arrow? {
        switch self {
        case .gesteHaut: return .haut
        case .gesteBas: return .bas
        case .gesteGauche: return .gauche
        case .gesteDroite: return .droite
        default: return nil
        }
    }

    /// Réglages de départ, repris de Logi Options+.
    var defaultAction: Action {
        switch self {
        case .gesteClic: return .missionControl
        case .gesteHaut: return .missionControl
        case .gesteBas: return .fenetresApp
        case .gesteGauche: return .bureauGauche
        case .gesteDroite: return .bureauDroite
        case .precedent: return .precedent
        case .suivant: return .suivant
        case .molette: return .apps
        case .boutonMolette: return .defaut
        }
    }

    /// Libellé d'une action pour ce bouton (« Par défaut » dit ce que fait la souris d'origine).
    func actionLabel(_ a: Action) -> String {
        if a == .defaut && self == .boutonMolette { return String(localized: "Crans ↔ roue libre") }
        return a.label
    }

    /// Les actions qui ont un sens pour ce bouton.
    var choices: [Action] {
        // Les actions de Square ne sont proposées que si Square est installée sur ce Mac.
        // De même pour celles de Side.
        let possibles = Action.allCases.filter { (!$0.pourSquare || Square.installee) && (!$0.pourSide || Side.disponible) }
        switch self {
        case .precedent, .suivant, .molette, .boutonMolette: return possibles
        default: return possibles.filter { $0 != .defaut }
        }
    }
}

enum Config {
    static let d = UserDefaults.standard

    static func action(_ s: Slot) -> Action {
        d.string(forKey: "slot." + s.rawValue).flatMap(Action.init) ?? s.defaultAction
    }
    static func set(_ s: Slot, _ a: Action) { d.set(a.rawValue, forKey: "slot." + s.rawValue) }

    static var wheel: WheelMode {
        get { d.string(forKey: "wheel").flatMap(WheelMode.init) ?? .auto }
        set { d.set(newValue.rawValue, forKey: "wheel") }
    }

    static var thumb: ThumbMode {
        get { d.string(forKey: "thumb").flatMap(ThumbMode.init) ?? .defaut }
        set { d.set(newValue.rawValue, forKey: "thumb") }
    }
}

/// Comportement de la grande molette (fonction SmartShift de la souris).
enum WheelMode: String, CaseIterable {
    case autoFacile, auto, autoDifficile, crans, libre

    var label: String {
        switch self {
        case .autoFacile: return String(localized: "Roue libre dès qu'on la lance")
        case .auto: return String(localized: "Crans, roue libre si on la lance")
        case .autoDifficile: return String(localized: "Roue libre seulement si on la lance fort")
        case .crans: return String(localized: "Toujours à crans")
        case .libre: return String(localized: "Toujours en roue libre")
        }
    }

    /// Libellé court dans le menu des choix.
    var choiceLabel: String {
        switch self {
        case .autoFacile: return String(localized: "Automatique, bascule facile")
        case .auto: return String(localized: "Automatique (par défaut)")
        case .autoDifficile: return String(localized: "Automatique, bascule difficile")
        case .crans: return String(localized: "Toujours à crans")
        case .libre: return String(localized: "Toujours en roue libre")
        }
    }

    /// Réglage HID++ : mode (1 = roue libre, 2 = crans, 0 = inchangé)
    /// et seuil de bascule automatique (vitesse ; 0xFF = jamais).
    var hidpp: (mode: UInt8, threshold: UInt8) {
        switch self {
        case .autoFacile: return (2, 6)
        case .auto: return (2, 12)
        case .autoDifficile: return (2, 24)
        case .crans: return (2, 0xFF)
        case .libre: return (1, 0)
        }
    }
}
