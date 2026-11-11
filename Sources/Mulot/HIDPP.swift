import Foundation
import IOKit.hid
import AppKit

/// Dialogue avec la souris Logitech en HID++ 2.0 (Bluetooth direct, index 0xFF).
/// Sert à « détourner » le bouton de pouce (sinon il n'envoie rien à macOS)
/// et à lire la batterie.
final class LogiManager {
    static let shared = LogiManager()

    // Identifiants HID++
    static let gestureCID: UInt16 = 0x00C3     // bouton de pouce (gestes)
    static let featReprog: UInt16 = 0x1B04     // REPROG_CONTROLS_V4
    static let featBatteryUnified: UInt16 = 0x1004
    static let featBatteryLegacy: UInt16 = 0x1000
    static let featDeviceName: UInt16 = 0x0005

    private let swID: UInt8 = 0x0A
    private var manager: IOHIDManager!
    private var device: IOHIDDevice?
    private let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)

    private var features: [UInt16: UInt8] = [:]
    private var pending: [(key: UInt16, callback: ([UInt8]?) -> Void)] = []
    private var pressedCIDs: Set<UInt16> = []

    // État exposé
    private(set) var deviceName: String?
    private(set) var battery: Int?
    private(set) var charging = false
    private(set) var gestureReady = false
    private(set) var lastError: String?

    var onGestureButton: ((Bool) -> Void)?   // true = appuyé
    var onStateChange: (() -> Void)?

    func start() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [kIOHIDVendorIDKey: 0x046D, kIOHIDTransportKey: "Bluetooth Low Energy"]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, dev in
            Unmanaged<LogiManager>.fromOpaque(ctx!).takeUnretainedValue().attach(dev)
        }, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, dev in
            Unmanaged<LogiManager>.fromOpaque(ctx!).takeUnretainedValue().detach(dev)
        }, ctx)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        // La batterie se rafraîchit toutes les 5 minutes.
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.readBattery() }
        // Quand elle s'endort, la souris oublie le détournement du bouton de pouce :
        // on le redemande régulièrement et au réveil du Mac.
        Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.reassert() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self?.reassert() }
        }
    }

    /// Rend le bouton de pouce à la souris (à la fermeture de l'app).
    func stop() {
        guard device != nil, let idx = features[Self.featReprog] else { return }
        let cid = Self.gestureCID
        send(idx, 3, [UInt8(cid >> 8), UInt8(cid & 0xFF), 0x02, 0, 0]) { _ in }
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    }

    // MARK: - Connexion

    private func attach(_ dev: IOHIDDevice) {
        // Seule la collection qui accepte les longs messages HID++ (20 octets) nous intéresse.
        let maxOut = IOHIDDeviceGetProperty(dev, kIOHIDMaxOutputReportSizeKey as CFString) as? Int ?? 0
        guard maxOut >= 20, device == nil else { return }
        let r = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone))
        guard r == kIOReturnSuccess else {
            lastError = "Accès à la souris refusé (Surveillance de la saisie ?)"
            log("IOHIDDeviceOpen a échoué : \(String(format: "0x%08x", r))")
            onStateChange?()
            // On réessaie tant que l'autorisation n'est pas donnée.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.attach(dev) }
            return
        }
        device = dev
        deviceName = IOHIDDeviceGetProperty(dev, kIOHIDProductKey as CFString) as? String
        features = [:]; pending = []; pressedCIDs = []; gestureReady = false; lastError = nil
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(dev, buffer, 64, { ctx, _, _, _, _, report, len in
            let bytes = Array(UnsafeBufferPointer(start: report, count: len))
            Unmanaged<LogiManager>.fromOpaque(ctx!).takeUnretainedValue().received(bytes)
        }, ctx)
        log("Souris connectée : \(deviceName ?? "?")")
        onStateChange?()
        // Laisse la liaison Bluetooth se stabiliser avant de parler à la souris.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.setup() }
    }

    private func detach(_ dev: IOHIDDevice) {
        guard let d = device, d === dev else { return }
        device = nil; gestureReady = false; battery = nil
        log("Souris déconnectée")
        if pressedCIDs.contains(Self.gestureCID) { onGestureButton?(false) }
        pressedCIDs = []
        onStateChange?()
    }

    private func setup(attempt: Int = 1) {
        guard device != nil else { return }
        feature(Self.featReprog) { [weak self] idx in
            guard let self else { return }
            guard let idx else {
                if attempt < 4 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.setup(attempt: attempt + 1) }
                } else {
                    self.lastError = "La souris ne répond pas (Logi Options+ est-il fermé ?)"
                    self.onStateChange?()
                }
                return
            }
            if !self.paused { self.divertGesture(idx) }
            self.readBattery()
        }
    }

    /// Mode jeu : le bouton de pouce est rendu à la souris tant que c'est vrai.
    var paused = false {
        didSet {
            guard paused != oldValue, device != nil, let idx = features[Self.featReprog] else { return }
            if paused {
                if pressedCIDs.contains(Self.gestureCID) { onGestureButton?(false) }
                pressedCIDs = []
                let cid = Self.gestureCID
                send(idx, 3, [UInt8(cid >> 8), UInt8(cid & 0xFF), 0x02, 0, 0]) { _ in }
            } else {
                divertGesture(idx)
            }
        }
    }

    private func reassert() {
        guard device != nil, !paused, let idx = features[Self.featReprog] else { return }
        divertGesture(idx, quiet: true)
    }

    private func divertGesture(_ idx: UInt8, quiet: Bool = false) {
        let cid = Self.gestureCID
        // setCidReporting : divert (bit 0) + divert valide (bit 1)
        send(idx, 3, [UInt8(cid >> 8), UInt8(cid & 0xFF), 0x03, 0, 0]) { [weak self] resp in
            guard let self else { return }
            let was = self.gestureReady
            self.gestureReady = resp != nil
            self.lastError = resp == nil ? "Impossible d'activer le bouton de pouce" : nil
            if !quiet || was != self.gestureReady {
                self.log(resp != nil ? "Bouton de pouce activé" : "Échec du détournement du bouton de pouce")
            }
            self.onStateChange?()
        }
    }

    func readBattery() {
        guard device != nil else { return }
        feature(Self.featBatteryUnified) { [weak self] idx in
            guard let self else { return }
            if let idx {
                self.send(idx, 1, []) { resp in
                    guard let p = resp else { return }
                    self.battery = Int(p[0]); self.charging = p[2] == 1 || p[2] == 2
                    self.onStateChange?()
                }
            } else {
                self.feature(Self.featBatteryLegacy) { idx in
                    guard let idx else { return }
                    self.send(idx, 0, []) { resp in
                        guard let p = resp else { return }
                        self.battery = Int(p[0]); self.charging = p[2] >= 1 && p[2] <= 3
                        self.onStateChange?()
                    }
                }
            }
        }
    }

    // MARK: - Protocole

    /// Demande l'index d'une fonction HID++ (mémorisé ensuite).
    private func feature(_ id: UInt16, _ done: @escaping (UInt8?) -> Void) {
        if let idx = features[id] { return done(idx) }
        send(0x00, 0, [UInt8(id >> 8), UInt8(id & 0xFF)]) { [weak self] resp in
            guard let p = resp, p[0] != 0 else { return done(nil) }
            self?.features[id] = p[0]
            done(p[0])
        }
    }

    private func send(_ featureIndex: UInt8, _ function: UInt8, _ params: [UInt8],
                      _ done: @escaping ([UInt8]?) -> Void) {
        guard let dev = device else { return done(nil) }
        var report = [UInt8](repeating: 0, count: 20)
        report[0] = 0x11; report[1] = 0xFF; report[2] = featureIndex
        report[3] = (function << 4) | swID
        for (i, b) in params.prefix(16).enumerated() { report[4 + i] = b }
        let key = UInt16(featureIndex) << 8 | UInt16(report[3])
        pending.append((key, done))
        let r = report.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, 0x11, $0.baseAddress!, 20)
        }
        if r != kIOReturnSuccess {
            log("Envoi HID++ échoué : \(String(format: "0x%08x", r))")
            resolve(key, nil)
            return
        }
        // Délai de garde : pas de réponse en 1,5 s = échec.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.resolve(key, nil) }
    }

    private func resolve(_ key: UInt16, _ payload: [UInt8]?) {
        guard let i = pending.firstIndex(where: { $0.key == key }) else { return }
        let cb = pending.remove(at: i).callback
        cb(payload)
    }

    private func received(_ raw: [UInt8]) {
        // Certains pilotes omettent l'identifiant de rapport : on le remet.
        var r = raw
        if r.first != 0x11 && r.first != 0x10 { r.insert(0x11, at: 0) }
        guard r.count >= 7 else { return }
        let featIdx = r[2], fnSw = r[3]

        // Erreur HID++ 2.0 : [0xFF, featIdx, fnSw, code]
        if featIdx == 0xFF {
            let key = UInt16(r[3]) << 8 | UInt16(r[4])
            log("Erreur HID++ \(r[5]) pour \(String(format: "%04x", key))")
            resolve(key, nil)
            return
        }
        // Réponse à une de nos demandes
        if fnSw & 0x0F == swID {
            resolve(UInt16(featIdx) << 8 | UInt16(fnSw), Array(r[4...]))
            return
        }
        // Notification : boutons détournés (fonction 0 de REPROG_CONTROLS_V4)
        if let reprog = features[Self.featReprog], featIdx == reprog, fnSw >> 4 == 0 {
            var now: Set<UInt16> = []
            var i = 4
            while i + 1 < r.count && i < 12 {
                let cid = UInt16(r[i]) << 8 | UInt16(r[i + 1])
                if cid != 0 { now.insert(cid) }
                i += 2
            }
            let was = pressedCIDs.contains(Self.gestureCID), isNow = now.contains(Self.gestureCID)
            pressedCIDs = now
            if was != isNow { onGestureButton?(isNow) }
        }
    }

    private func log(_ s: String) { appLog(s) }
}

/// Journal lisible dans ~/Library/Logs/Mulot.log
func appLog(_ s: String) {
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(s)\n"
    let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Mulot.log")
    if let h = try? FileHandle(forWritingTo: url) {
        h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
    } else {
        try? line.write(to: url, atomically: true, encoding: .utf8)
    }
}
