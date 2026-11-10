import AppKit
import SwiftUI

/// Outil de développement : `Mulot.app/Contents/MacOS/Mulot --capture dossier`
/// exporte la fenêtre en PNG, en mode clair et sombre.
enum Capture {
    @MainActor static func run(to dir: String) {
        _ = NSApplication.shared
        PanelView.captureMode = true
        for (name, ap) in [("clair", NSAppearance.Name.aqua), ("sombre", .darkAqua)] {
            NSApp.appearance = NSAppearance(named: ap)
            NSAppearance.current = NSAppearance(named: ap)
            let view = PanelView(model: PanelModel(), onReconnect: {}, onQuit: {})
                .environment(\.colorScheme, ap == .darkAqua ? .dark : .light)
            let r = ImageRenderer(content: view)
            r.scale = 2
            guard let cg = r.cgImage else { continue }
            let rep = NSBitmapImageRep(cgImage: cg)
            try? rep.representation(using: .png, properties: [:])?
                .write(to: URL(fileURLWithPath: "\(dir)/fenetre-\(name).png"))
        }
    }
}
