import Foundation

/// Réglages, enregistrés dans les préférences macOS.
enum Slot: String, CaseIterable {
    case gesteClic, gesteHaut, gesteBas, gesteGauche, gesteDroite
    case precedent, suivant, molette

    var label: String {
        switch self {
        case .gesteClic: return "Bouton de pouce : simple clic"
        case .gesteHaut: return "Geste vers le haut ↑"
        case .gesteBas: return "Geste vers le bas ↓"
        case .gesteGauche: return "Geste vers la gauche ←"
        case .gesteDroite: return "Geste vers la droite →"
        case .precedent: return "Bouton Précédent"
        case .suivant: return "Bouton Suivant"
        case .molette: return "Clic de la molette"
        }
    }

    /// Libellé court affiché au-dessus de l'action.
    var shortLabel: String {
        switch self {
        case .gesteClic: return "Appuyer"
        case .gesteHaut: return "Appuyer et glisser vers le haut"
        case .gesteBas: return "Appuyer et glisser vers le bas"
        case .gesteGauche: return "Appuyer et glisser à gauche"
        case .gesteDroite: return "Appuyer et glisser à droite"
        case .precedent: return "Bouton arrière"
        case .suivant: return "Bouton avant"
        case .molette: return "Clic de la molette"
        }
    }

    /// Où se trouve le bouton sur le dessin de la souris.
    var spot: Spot {
        switch self {
        case .gesteClic, .gesteHaut, .gesteBas, .gesteGauche, .gesteDroite: return .geste
        case .precedent: return .precedent
        case .suivant: return .suivant
        case .molette: return .molette
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
        }
    }

    /// Les actions qui ont un sens pour ce bouton.
    var choices: [Action] {
        switch self {
        case .precedent, .suivant, .molette: return Action.allCases
        default: return Action.allCases.filter { $0 != .defaut }
        }
    }
}

enum Config {
    static let d = UserDefaults.standard

    static func action(_ s: Slot) -> Action {
        d.string(forKey: "slot." + s.rawValue).flatMap(Action.init) ?? s.defaultAction
    }
    static func set(_ s: Slot, _ a: Action) { d.set(a.rawValue, forKey: "slot." + s.rawValue) }

    static var thumb: ThumbMode {
        get { d.string(forKey: "thumb").flatMap(ThumbMode.init) ?? .defaut }
        set { d.set(newValue.rawValue, forKey: "thumb") }
    }
}
