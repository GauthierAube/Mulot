import AppKit

/// Intercepte les boutons Précédent / Suivant / molette et la molette pour le pouce,
/// et transforme le bouton de pouce en gestes.
final class Mouse {
    static let shared = Mouse()

    private var tap: CFMachPort?
    private var swallowedUps: Set<Int64> = []
    private var thumbAccumulator = 0.0
    private var gestureStart: CGPoint?

    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    // MARK: - Bouton de pouce (gestes)

    // Le geste se lit PENDANT qu'on tient le bouton, pas au relâchement (16/11/2026) : dès que la souris part nettement
    // dans une direction (28 points), l'action part. Avant, rien ne se passait avant de lâcher le bouton, d'où un temps
    // de latence que le trackpad n'a pas.
    //
    // Deux gestes suivent ensuite la souris tant que le bouton est tenu :
    //  - de côté, réglé sur « Side : application suivante / précédente » : le carrousel horizontal du plein écran ;
    //  - vers le tiroir, réglé sur « Side : afficher le tiroir » : le tiroir s'ouvre, puis, si la souris continue,
    //    son sélecteur vertical d'applications apparaît (comme les quatre doigts au trackpad).
    // Au relâchement, l'application du centre prend la place.
    private var suiviTimer: Timer?
    private var carrouselActif = false
    private var tiroirActif = false
    /// L'action d'un geste simple déjà déclenchée pendant que le bouton est tenu : rien de plus au relâchement.
    private var gesteParti = false
    /// Le chemin, en points, au-delà duquel le geste part (assez pour ne pas le confondre avec un clic du bouton).
    private let seuilGeste: CGFloat = 28

    /// Déplacement de la souris, en points, pour avancer d'une fenêtre dans le carrousel horizontal. Réglable dans le
    /// panneau (« Sensibilité du carrousel ») : plus il est grand, moins le geste est sensible.
    static let carrouselPasDefaut: Double = 150
    static let carrouselPasPlage: ClosedRange<Double> = 80...600
    private var carrouselPas: CGFloat {
        CGFloat(UserDefaults.standard.object(forKey: "carrouselPas") as? Double ?? Self.carrouselPasDefaut)
    }
    /// La même chose pour le sélecteur vertical du tiroir (« Sensibilité du sélecteur du tiroir ») : l'écran est moins haut
    /// que large, il faut donc moins de chemin par application.
    static let tiroirPasDefaut: Double = 140
    static let tiroirPasPlage: ClosedRange<Double> = 60...400
    private var tiroirPas: CGFloat {
        CGFloat(UserDefaults.standard.object(forKey: "tiroirPas") as? Double ?? Self.tiroirPasDefaut)
    }
    /// Le chemin de la souris qui fait monter le tiroir de fermé à ouvert : il suit la souris, comme les doigts au trackpad.
    /// Au-delà, le sélecteur prend le relais dans le même mouvement.
    private let courseTiroir: CGFloat = 170

    /// Le geste de côté mène-t-il le carrousel de Side ? (Alors son réglage de sensibilité est proposé.)
    static var carrouselRegle: Bool {
        guard Square.installee else { return false }
        let d = Config.action(.gesteDroite), g = Config.action(.gesteGauche)
        return [d, g].contains(.squareSuivante) || [d, g].contains(.squarePrecedente)
    }
    /// Un geste vertical ouvre-t-il le tiroir de Side ? (Alors le réglage de son sélecteur est proposé.)
    static var tiroirRegle: Bool {
        Side.disponible && [Config.action(.gesteHaut), Config.action(.gesteBas)].contains(.sidePanneau)
    }

    /// +1 si glisser vers la droite mène à l'application suivante, -1 pour l'inverse, 0 si aucun geste horizontal n'est pour Square.
    private var sensCarrousel: CGFloat {
        guard Square.installee else { return 0 }
        let droite = Config.action(.gesteDroite), gauche = Config.action(.gesteGauche)
        if droite == .squareSuivante || gauche == .squarePrecedente { return 1 }
        if droite == .squarePrecedente || gauche == .squareSuivante { return -1 }
        return 0
    }
    /// +1 si glisser vers le haut ouvre le tiroir, -1 si c'est vers le bas.
    private var sensTiroir: CGFloat { Config.action(.gesteHaut) == .sidePanneau ? 1 : -1 }

    private func positionCarrousel(_ start: CGPoint) -> String {
        String(format: "%.3f", Double((NSEvent.mouseLocation.x - start.x) / carrouselPas * sensCarrousel))
    }
    /// Où en est le geste du tiroir : de 0 (fermé) à 1 (ouvert) pendant que le tiroir monte, puis 1 + le nombre
    /// d'applications parcourues dans le sélecteur (1,5 = une demi-application plus loin).
    private func positionTiroir(_ start: CGPoint) -> String {
        let chemin = (NSEvent.mouseLocation.y - start.y) * sensTiroir - seuilGeste
        let v = chemin <= courseTiroir ? chemin / courseTiroir : 1 + (chemin - courseTiroir) / tiroirPas
        return String(format: "%.3f", Double(v))
    }

    /// 60 fois par seconde tant que le bouton est tenu.
    private func suivreLeGeste() {
        guard let start = gestureStart else { return }
        if tiroirActif { Side.envoyer("tiroir:suivre:" + positionTiroir(start)); return }
        if carrouselActif { Square.envoyer("carrousel:suivre:" + positionCarrousel(start)); return }
        guard !gesteParti else { return }
        let here = NSEvent.mouseLocation
        let dx = here.x - start.x, dy = here.y - start.y   // y vers le haut
        let slot: Slot
        if abs(dy) > seuilGeste, abs(dy) > 1.5 * abs(dx) { slot = dy > 0 ? .gesteHaut : .gesteBas }
        else if abs(dx) > seuilGeste, abs(dx) > 1.5 * abs(dy) { slot = dx > 0 ? .gesteDroite : .gesteGauche }
        else { return }
        let action = Config.action(slot)
        if action == .sidePanneau, Side.disponible {
            tiroirActif = true
            appLog("Geste \(slot.rawValue) → tiroir de Side, suivi")
            Side.envoyer("tiroir:debut")
            Side.envoyer("tiroir:suivre:" + positionTiroir(start))
            return
        }
        if (slot == .gesteDroite || slot == .gesteGauche), sensCarrousel != 0,
           [.squareSuivante, .squarePrecedente].contains(action) {
            carrouselActif = true
            Square.envoyer("carrousel:debut")
            Square.envoyer("carrousel:suivre:" + positionCarrousel(start))
            return
        }
        gesteParti = true
        appLog("Geste \(slot.rawValue) (dx \(Int(dx)), dy \(Int(dy))) → \(action.rawValue), bouton tenu")
        action.perform()
    }

    private func arreterLeSuivi() {
        suiviTimer?.invalidate(); suiviTimer = nil
        carrouselActif = false; tiroirActif = false; gesteParti = false
    }

    func gestureButton(pressed: Bool) {
        if GameMode.shared.isActive { gestureStart = nil; arreterLeSuivi(); return }
        let here = NSEvent.mouseLocation
        if pressed {
            arreterLeSuivi()
            gestureStart = here
            let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.suivreLeGeste() }
            RunLoop.main.add(t, forMode: .common)
            suiviTimer = t
            return
        }
        suiviTimer?.invalidate(); suiviTimer = nil
        guard let start = gestureStart else { arreterLeSuivi(); return }
        gestureStart = nil
        defer { arreterLeSuivi() }
        if tiroirActif {
            // Le tiroir ou son sélecteur suivaient la souris : Side pose l'application du centre (ou referme le tiroir
            // s'il était déjà ouvert et que la souris n'est pas allée jusqu'au sélecteur).
            appLog("Geste tiroir de Side, relâché à \(positionTiroir(start)) application")
            Side.envoyer("tiroir:fin")
            return
        }
        if carrouselActif {
            // Le carrousel était affiché : au relâchement, Side fait passer devant l'application du centre.
            let fin = positionCarrousel(start)
            appLog("Geste carrousel de Square, relâché à \(fin) fenêtre")
            Square.envoyer("carrousel:fin:" + fin)
            return
        }
        if gesteParti { return }              // l'action est déjà partie pendant le geste
        let dx = here.x - start.x, dy = here.y - start.y
        let slot: Slot
        if abs(dx) < seuilGeste && abs(dy) < seuilGeste { slot = .gesteClic }
        else if abs(dx) > abs(dy) { slot = dx > 0 ? .gesteDroite : .gesteGauche }
        else { slot = dy > 0 ? .gesteHaut : .gesteBas }
        let action = Config.action(slot)
        appLog("Geste \(slot.rawValue) (dx \(Int(dx)), dy \(Int(dy))) → \(action.rawValue)")
        if action == .sidePanneau, Side.disponible { Side.envoyer("panneau"); return }
        action.perform()
    }

    // MARK: - Interception des événements

    @discardableResult
    func startTap() -> Bool {
        if tap != nil { return true }
        let mask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.otherMouseUp.rawValue)
            | (1 << CGEventType.scrollWheel.rawValue)
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                        options: .defaultTap, eventsOfInterest: mask,
                                        callback: { _, type, event, _ in
                                            Mouse.shared.handle(type, event)
                                        }, userInfo: nil) else { return false }
        tap = t
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == syntheticMarker {
            return Unmanaged.passUnretained(event)
        }
        // Mode jeu : tout passe tel quel, sauf le relâchement d'un clic déjà avalé.
        if GameMode.shared.isActive {
            if type == .otherMouseUp,
               swallowedUps.remove(event.getIntegerValueField(.mouseEventButtonNumber)) != nil { return nil }
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .otherMouseDown, .otherMouseUp:
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            if type == .otherMouseUp && swallowedUps.remove(button) != nil { return nil }
            let slot: Slot
            switch button {
            case 2: slot = .molette
            case 3: slot = .precedent
            case 4: slot = .suivant
            default: return Unmanaged.passUnretained(event)
            }
            let action = Config.action(slot)
            if action == .defaut { return Unmanaged.passUnretained(event) }
            if type == .otherMouseDown {
                swallowedUps.insert(button)
                DispatchQueue.main.async { action.perform() }
            }
            return nil

        case .scrollWheel:
            let mode = Config.thumb
            guard mode != .defaut else { return Unmanaged.passUnretained(event) }
            // La molette pour le pouce = défilement horizontal pur, hors trackpad.
            let v = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let h = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
            let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
            let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
            guard v == 0, h != 0, phase == 0, momentum == 0 else { return Unmanaged.passUnretained(event) }
            if mode == .rien { return nil }
            thumbAccumulator += h
            // Pour le carrousel de Square, des crans plus espacés : on avance d'une fenêtre à la fois sans s'emballer.
            // (Réglable sans recompiler : defaults write app.mulot squareCran -float 150)
            let cranSquare = UserDefaults.standard.object(forKey: "squareCran") as? Double ?? 120
            let stepSize = mode == .square ? cranSquare : 20.0
            while abs(thumbAccumulator) >= stepSize {
                // Molette vers l'avant/droite = delta négatif sur macOS
                let dir = thumbAccumulator < 0 ? 1 : -1
                thumbAccumulator += Double(dir) * stepSize
                DispatchQueue.main.async { mode.step(dir) }
            }
            return nil

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
