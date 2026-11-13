import AppKit
import SwiftUI
import ServiceManagement

// MARK: - Palette (reprise d'Horizon)

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { ap in
            let hex = ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

enum Palette {
    static let accent = Color(light: 0xD86F4A, dark: 0xD86F4A)        // terracotta
    static let accentSoft = Color(light: 0xF7D9CD, dark: 0x4A3027)
    static let bg = Color(light: 0xFBF8F5, dark: 0x1F1C1A)
    static let card = Color(light: 0xFFFFFF, dark: 0x2A2624)
    static let line = Color(light: 0xE7E0DA, dark: 0x3A3431)
    static let fg = Color(light: 0x2B2724, dark: 0xF2EDE8)
    static let muted = Color(light: 0x685A4E, dark: 0xC4B9AD)
    static let error = Color(light: 0xC2402B, dark: 0xF07A64)
    static let success = Color(light: 0x4E8A3E, dark: 0x8DB87F)
    static let warning = Color(light: 0xD08A1E, dark: 0xF0B357)
    static let nsAccent = NSColor(srgbRed: 0xD8 / 255, green: 0x6F / 255, blue: 0x4A / 255, alpha: 1)
}

// MARK: - État affiché

final class PanelModel: ObservableObject {
    @Published var tick = 0
    func refresh() { tick += 1 }

    var logi: LogiManager { .shared }
    var tapRunning: Bool { Mouse.shared.isRunning }

    func action(_ s: Slot) -> Action { Config.action(s) }
    func set(_ s: Slot, _ a: Action) {
        Config.set(s, a)
        if s == .boutonMolette { logi.applyShiftButton() }
        refresh()
    }
    var wheel: WheelMode { Config.wheel }
    func setWheel(_ m: WheelMode) { Config.wheel = m; logi.applyWheel(); refresh() }
    var thumb: ThumbMode { Config.thumb }
    func setThumb(_ m: ThumbMode) { Config.thumb = m; refresh() }

    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }
    func toggleLogin() {
        let s = SMAppService.mainApp
        do { if s.status == .enabled { try s.unregister() } else { try s.register() } }
        catch { appLog("Lancement au démarrage : \(error.localizedDescription)") }
        refresh()
    }
}

// MARK: - Vue

struct PanelView: View {
    /// Pendant l'export en image, les menus macOS ne se dessinent pas : on montre leur contenu.
    static var captureMode = false
    @ObservedObject var model: PanelModel
    var onReconnect: () -> Void
    var onQuit: () -> Void
    var onResize: () -> Void = {}
    @State var expanded: String? = nil

    var body: some View {
        let _ = model.tick
        VStack(alignment: .leading, spacing: 14) {
            header
            warnings
            section(String(localized: "Bouton de pouce")) {
                rows([Slot.gesteClic, .gesteHaut, .gesteBas, .gesteGauche, .gesteDroite])
                // Le geste de côté mène le carrousel de Side : sa sensibilité se règle ici.
                if Mouse.carrouselRegle {
                    Divider().overlay(Palette.line).padding(.leading, 86)
                    SensibiliteCarrousel()
                }
            }
            section(String(localized: "Boutons")) {
                rows([Slot.suivant, .precedent, .molette, .boutonMolette])
            }
            section(String(localized: "Molettes")) {
                wheelRow
                Divider().overlay(Palette.line).padding(.leading, 86)
                thumbRow
            }
            footer
        }
        .padding(16)
        .frame(width: 380)
        .background(Palette.bg)
        .foregroundStyle(Palette.fg)
        .tint(Palette.accent)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mulot").font(.system(size: 21, weight: .bold, design: .rounded))
                Text(PanelView.captureMode ? String(localized: "\("MX Master 3S") · connectée")
                     : model.logi.deviceName.map { String(localized: "\($0) · connectée") } ?? String(localized: "Souris non détectée"))
                    .font(.system(size: 13)).foregroundStyle(Palette.muted)
            }
            Spacer()
            if let b = model.logi.battery {
                HStack(spacing: 4) {
                    Image(systemName: model.logi.charging ? "battery.100.bolt" : batteryIcon(b))
                    Text(verbatim: "\(b) %").monospacedDigit()
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Capsule().fill(batteryColor(b).opacity(0.15)))
                .foregroundStyle(batteryColor(b))
            }
        }
    }

    /// Vert comme sur iOS ; orange sous 30 %, rouge sous 20 %.
    private func batteryColor(_ b: Int) -> Color {
        b <= 20 ? Palette.error : b <= 30 ? Palette.warning : Palette.success
    }

    private func batteryIcon(_ b: Int) -> String {
        b > 80 ? "battery.100" : b > 55 ? "battery.75" : b > 30 ? "battery.50" : b > 10 ? "battery.25" : "battery.0"
    }

    @ViewBuilder private var warnings: some View {
        if PanelView.captureMode { EmptyView() } else {
        if let game = GameMode.shared.activeApp {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill").font(.system(size: 15))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mode jeu : \(game)").font(.system(size: 13, weight: .semibold))
                    Text("Les boutons gardent leur rôle d'origine, sans gestes.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
                Spacer()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.accent.opacity(0.10)))
            .foregroundStyle(Palette.fg)
        }
        if let err = model.logi.lastError { warning(err, action: nil) }
        if !model.tapRunning {
            warning(String(localized: "Autorise Mulot dans Accessibilité")) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
        }
    }

    private func warning(_ text: String, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(text).font(.system(size: 12, weight: .medium)).multilineTextAlignment(.leading)
                Spacer()
                if action != nil { Image(systemName: "arrow.up.right") }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.error.opacity(0.12)))
            .foregroundStyle(Palette.error)
        }
        .buttonStyle(.plain)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold)).tracking(0.8)
                .foregroundStyle(Palette.muted).padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func rows(_ slots: [Slot]) -> some View {
        ForEach(Array(slots.enumerated()), id: \.offset) { i, slot in
            if i > 0 { Divider().overlay(Palette.line).padding(.leading, 86) }
            slotRow(slot)
        }
    }

    private func slotRow(_ slot: Slot) -> some View {
        expandable(id: slot.rawValue,
                   image: MouseArt.image(slot.spot, arrow: slot.arrow),
                   caption: slot.shortLabel,
                   value: slot.actionLabel(model.action(slot)),
                   choices: slot.choices.map { a in (slot.actionLabel(a), a == model.action(slot), { model.set(slot, a) }) })
    }

    private var wheelRow: some View {
        expandable(id: "wheel",
                   image: MouseArt.image(.molette, arrow: .verticale),
                   caption: String(localized: "Grande molette"),
                   value: model.wheel.label,
                   choices: WheelMode.allCases.map { m in (m.choiceLabel, m == model.wheel, { model.setWheel(m) }) })
    }

    private var thumbRow: some View {
        expandable(id: "thumb",
                   image: MouseArt.image(.pouceMolette, arrow: .horizontale),
                   caption: String(localized: "Molette du pouce"),
                   value: model.thumb.label,
                   choices: ThumbMode.proposes.map { m in (m.label, m == model.thumb, { model.setThumb(m) }) })
    }

    /// Une ligne qui ouvre, sur le côté de la fenêtre, un menu de ses choix.
    private func expandable(id: String, image: NSImage, caption: String, value: String,
                            choices: [(String, Bool, () -> Void)]) -> some View {
        let open = expanded == id
        return Button {
            expanded = open ? nil : id
        } label: {
            row(image: image, caption: caption, value: value, open: open)
        }
        .buttonStyle(.plain)
        .background(open ? Palette.accentSoft.opacity(0.55) : Color.clear)
        .popover(isPresented: Binding(get: { expanded == id && !PanelView.captureMode },
                                      set: { if !$0, expanded == id { expanded = nil } }),
                 arrowEdge: .trailing) {
            ChoiceMenu(title: caption, choices: choices) { expanded = nil }
        }
    }

    private func row(image: NSImage, caption: String, value: String, open: Bool) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).frame(width: 58, height: 39)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Palette.fg)
                Text(caption).font(.system(size: 11.5)).foregroundStyle(Palette.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                .foregroundStyle(open ? Palette.accent : Palette.muted)
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private var footer: some View {
        HStack {
            if PanelView.captureMode {
                // L'export en image ne sait pas dessiner l'interrupteur macOS : on en dessine un.
                HStack(spacing: 8) {
                    Text("Au démarrage").font(.system(size: 12)).fixedSize()
                    Capsule().fill(Palette.line).frame(width: 26, height: 15)
                        .overlay(Circle().fill(Color.white).padding(2), alignment: .leading)
                }
            } else {
                Toggle(isOn: Binding(get: { model.launchAtLogin }, set: { _ in model.toggleLogin() })) {
                    Text("Au démarrage").font(.system(size: 12)).fixedSize()
                }
                .toggleStyle(.switch).controlSize(.mini)
            }
            if !PanelView.captureMode {
                Menu {
                    Picker("Langue", selection: Binding(get: { Langue.choisie }, set: { Langue.choisir($0) })) {
                        ForEach(Langue.allCases) { Text($0.nom).tag($0) }
                    }
                    .pickerStyle(.inline)
                    Text("Mulot redémarre pour changer de langue.")
                } label: {
                    Image(systemName: "globe").font(.system(size: 12))
                }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                .help("Langue")
                .accessibilityLabel("Langue")
            }
            Spacer()
            Button("Reconnecter", action: onReconnect)
            Button("Quitter", action: onQuit).keyboardShortcut("q")
        }
        .buttonStyle(FooterButton())
    }
}

/// Menu latéral : la liste des choix d'une ligne, celui en cours coché.
struct ChoiceMenu: View {
    let title: String
    let choices: [(String, Bool, () -> Void)]
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold)).tracking(0.8)
                .foregroundStyle(Palette.muted)
                .padding(.horizontal, 10).padding(.top, 4).padding(.bottom, 4)
            ForEach(Array(choices.enumerated()), id: \.offset) { _, c in
                ChoiceItem(title: c.0, selected: c.1) { c.2(); done() }
            }
        }
        .padding(8)
        .frame(width: 260)
        .background(Palette.bg)
        .foregroundStyle(Palette.fg)
    }
}

struct ChoiceItem: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 13, weight: selected ? .semibold : .regular)).lineLimit(1)
                Spacer()
                if selected { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7).fill(
                selected ? Palette.accent : (hover ? Palette.line.opacity(0.7) : Color.clear)))
            .foregroundStyle(selected ? Color.white : Palette.fg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct FooterButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium)).fixedSize()
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Palette.line.opacity(configuration.isPressed ? 1 : 0.6)))
            .foregroundStyle(Palette.fg)
    }
}

// MARK: - Fenêtre flottante sous l'icône

/// Relais vers le contrôleur, utilisable avant la fin de son initialisation.
final class Resizer { var fit: () -> Void = {} ; func callAsFunction() { fit() } }

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}

final class PanelController {
    private let panel: FloatingPanel
    private var host: NSHostingView<AnyView>!
    private var outsideMonitor: Any?
    private var resizer: Resizer?
    let model = PanelModel()

    init(onReconnect: @escaping () -> Void, onQuit: @escaping () -> Void) {
        panel = FloatingPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let resizer = Resizer()
        host = NSHostingView(rootView: AnyView(
            PanelView(model: model, onReconnect: onReconnect, onQuit: onQuit, onResize: { [weak resizer] in resizer?.fit() })
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.line, lineWidth: 1))
        ))
        panel.contentView = host
        resizer.fit = { [weak self] in self?.fit() }
        self.resizer = resizer
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(below button: NSStatusBarButton) {
        if panel.isVisible { close(); return }
        // Un clic sur l'icône alors que la fenêtre est ouverte : l'appui l'a déjà refermée (macOS le voit comme un clic
        // « ailleurs »), et le relâchement arrive ici juste après. Il ne doit pas la rouvrir.
        if Date().timeIntervalSince(closedAt) < 0.4 { return }
        model.refresh()
        let size = host.fittingSize
        guard let win = button.window else { return }
        let b = win.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = win.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        var x = b.midX - size.width / 2
        // Garde ~280 pt à droite pour le menu des choix, qui s'ouvre de ce côté.
        x = min(max(x, screen.minX + 8), screen.maxX - size.width - 288)
        show(NSRect(x: x, y: b.minY - size.height - 6, width: size.width, height: size.height))
    }

    /// Ouvre la fenêtre en haut au centre de l'écran (icône de la barre des menus cachée).
    func showCentered() {
        if panel.isVisible { panel.makeKeyAndOrderFront(nil); return }
        model.refresh()
        let size = host.fittingSize
        let screen = (NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main!).visibleFrame
        show(NSRect(x: screen.midX - size.width / 2 - 140, y: screen.maxY - size.height - 40,
                    width: size.width, height: size.height))
    }

    private func show(_ frame: NSRect) {
        panel.setFrame(frame, display: true)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    /// Ajuste la hauteur au contenu (ligne dépliée ou non) en gardant le haut en place.
    private func fit() {
        let size = host.fittingSize
        var f = panel.frame
        f.origin.y = f.maxY - size.height
        f.size = size
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(f, display: true)
        }
    }

    private var closedAt = Date.distantPast

    func close() {
        if panel.isVisible { closedAt = Date() }
        panel.orderOut(nil)
        if let m = outsideMonitor { NSEvent.removeMonitor(m); outsideMonitor = nil }
    }

    func refresh() { model.refresh() }
}


/// Le réglage de sensibilité du carrousel de Side, quand le bouton de pouce le mène : de combien la souris doit glisser
/// pour passer d'une application à la suivante.
struct SensibiliteCarrousel: View {
    @AppStorage("carrouselPas") private var pas: Double = Mouse.carrouselPasDefaut

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Sensibilité du carrousel").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.fg)
                Spacer()
                Text("\(Int(pas.rounded())) pt par application").font(.system(size: 11.5)).monospacedDigit().foregroundStyle(Palette.muted)
            }
            HStack(spacing: 8) {
                Text("Vif").font(.system(size: 11)).foregroundStyle(Palette.muted)
                // Le curseur va de « vif » (peu de chemin) à « posé » (beaucoup de chemin).
                Slider(value: $pas, in: Mouse.carrouselPasPlage)
                Text("Posé").font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            Text("Bouton de pouce tenu : le chemin que fait la souris pour passer à l'application suivante dans Side.")
                .font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}
