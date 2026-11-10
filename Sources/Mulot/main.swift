import AppKit
import ApplicationServices
import IOKit.hid

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private var panel: PanelController!
    private let logi = LogiManager.shared
    private let mouse = Mouse.shared

    func applicationDidFinishLaunching(_ n: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Mulot")
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        panel = PanelController(onReconnect: { [weak self] in self?.reconnect() },
                                onQuit: { NSApp.terminate(nil) })

        logi.onGestureButton = { [weak self] pressed in self?.mouse.gestureButton(pressed: pressed) }
        logi.onStateChange = { [weak self] in self?.refreshIcon(); self?.panel.refresh() }

        appLog("Démarrage — surveillance saisie : \(IOHIDCheckAccess(kIOHIDRequestTypeListenEvent).rawValue), accessibilité : \(AXIsProcessTrusted())")
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        logi.start()
        ensureAccessibility(prompt: true)
    }

    func applicationWillTerminate(_ n: Notification) { logi.stop() }

    /// Accessibilité : indispensable pour intercepter les clics et envoyer des raccourcis.
    private func ensureAccessibility(prompt: Bool) {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts) && mouse.startTap() { refreshIcon(); panel.refresh(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.ensureAccessibility(prompt: false) }
    }

    private func refreshIcon() {
        let ok = logi.gestureReady && mouse.isRunning
        item.button?.image = NSImage(systemSymbolName: ok ? "computermouse.fill" : "computermouse",
                                     accessibilityDescription: "Mulot")
        item.button?.title = logi.battery.map { " \($0) %" } ?? ""
        item.button?.imagePosition = .imageLeading
    }

    @objc private func togglePanel() {
        guard let button = item.button else { return }
        panel.toggle(below: button)
    }

    private func reconnect() {
        // Relance l'app : le plus simple pour tout réinitialiser.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1; open \"\(Bundle.main.bundleURL.path)\""]
        try? p.run()
        NSApp.terminate(nil)
    }
}

if let i = CommandLine.arguments.firstIndex(of: "--capture"), i + 1 < CommandLine.arguments.count {
    MainActor.assumeIsolated { Capture.run(to: CommandLine.arguments[i + 1]) }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
