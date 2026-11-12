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

    // Carrousel de Square : quand un geste horizontal du pouce est réglé sur « application suivante / précédente » de Square,
    // le carrousel de Square apparaît dès que la souris part de côté, suit la souris tant que le bouton est tenu,
    // et l'application du centre passe devant au relâchement.
    private var carrouselTimer: Timer?
    private var carrouselActif = false
    private let carrouselPas: CGFloat = 150      // déplacement de la souris, en points, pour avancer d'une fenêtre

    /// +1 si glisser vers la droite mène à l'application suivante, -1 pour l'inverse, 0 si aucun geste horizontal n'est pour Square.
    private var sensCarrousel: CGFloat {
        guard Square.installee else { return 0 }
        let droite = Config.action(.gesteDroite), gauche = Config.action(.gesteGauche)
        if droite == .squareSuivante || gauche == .squarePrecedente { return 1 }
        if droite == .squarePrecedente || gauche == .squareSuivante { return -1 }
        return 0
    }

    private func positionCarrousel(_ start: CGPoint) -> String {
        String(format: "%.3f", Double((NSEvent.mouseLocation.x - start.x) / carrouselPas * sensCarrousel))
    }

    private func suivreLeCarrousel() {
        guard let start = gestureStart else { return }
        let here = NSEvent.mouseLocation
        let dx = here.x - start.x, dy = here.y - start.y
        if !carrouselActif {
            // Il s'allume quand la souris part nettement de côté.
            guard abs(dx) > 24, abs(dx) > 1.5 * abs(dy) else { return }
            carrouselActif = true
            Square.envoyer("carrousel:debut")
        }
        Square.envoyer("carrousel:suivre:" + positionCarrousel(start))
    }

    func gestureButton(pressed: Bool) {
        if GameMode.shared.isActive { gestureStart = nil; carrouselTimer?.invalidate(); carrouselTimer = nil; carrouselActif = false; return }
        let here = NSEvent.mouseLocation
        if pressed {
            gestureStart = here
            carrouselActif = false
            carrouselTimer?.invalidate()
            if sensCarrousel != 0 {
                let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.suivreLeCarrousel() }
                RunLoop.main.add(t, forMode: .common)
                carrouselTimer = t
            }
            return
        }
        carrouselTimer?.invalidate(); carrouselTimer = nil
        guard let start = gestureStart else { return }
        if carrouselActif {
            // Le carrousel était affiché : au relâchement, Square fait passer devant l'application du centre.
            carrouselActif = false
            gestureStart = nil
            let fin = positionCarrousel(start)
            appLog("Geste carrousel de Square, relâché à \(fin) fenêtre")
            Square.envoyer("carrousel:fin:" + fin)
            return
        }
        gestureStart = nil
        let dx = here.x - start.x, dy = here.y - start.y   // y vers le haut
        let threshold: CGFloat = 40
        let slot: Slot
        if abs(dx) < threshold && abs(dy) < threshold { slot = .gesteClic }
        else if abs(dx) > abs(dy) { slot = dx > 0 ? .gesteDroite : .gesteGauche }
        else { slot = dy > 0 ? .gesteHaut : .gesteBas }
        let action = Config.action(slot)
        appLog("Geste \(slot.rawValue) (dx \(Int(dx)), dy \(Int(dy))) → \(action.rawValue)")
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
