import AppKit
import ApplicationServices

/// Bureaux et écrans : passer à gauche / à droite.
enum Screens {
    // Repère global « haut-gauche » utilisé par CoreGraphics et l'Accessibilité.
    private static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }
    private static func cgRect(_ r: NSRect) -> CGRect {
        CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    private static func screen(containing p: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) } ?? NSScreen.main
    }

    /// L'écran voisin à gauche (dir < 0) ou à droite (dir > 0).
    private static func neighbor(of s: NSScreen, _ dir: Int) -> NSScreen? {
        NSScreen.screens
            .filter { $0 != s && (dir > 0 ? $0.frame.midX > s.frame.midX : $0.frame.midX < s.frame.midX) }
            .min { abs($0.frame.midX - s.frame.midX) < abs($1.frame.midX - s.frame.midX) }
    }

    // MARK: - Bureaux (Spaces)

    private typealias ConnFn = @convention(c) () -> Int32
    private typealias CopyFn = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private static let cg = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW)
    private static let conn = dlsym(cg, "CGSMainConnectionID").map { unsafeBitCast($0, to: ConnFn.self) }
    private static let copySpaces = dlsym(cg, "CGSCopyManagedDisplaySpaces").map { unsafeBitCast($0, to: CopyFn.self) }

    /// Nombre de bureaux (et d'apps en plein écran) sur l'écran donné.
    private static func desktopCount(on s: NSScreen) -> Int {
        guard let conn, let copySpaces,
              let arr = copySpaces(conn())?.takeRetainedValue() as? [[String: Any]] else { return 1 }
        var uuid = ""
        if let n = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
           let u = CGDisplayCreateUUIDFromDisplayID(n.uint32Value)?.takeRetainedValue() {
            uuid = CFUUIDCreateString(nil, u) as String
        }
        let entry = arr.count == 1 ? arr[0] : arr.first { ($0["Display Identifier"] as? String) == uuid }
        // Les apps en plein écran comptent aussi : ⌃← / ⌃→ passent de l'une à l'autre.
        return (entry?["Spaces"] as? [[String: Any]])?.count ?? 1
    }

    /// Bureau ou app plein écran voisins s'il y en a, sinon l'écran voisin.
    static func desktopOrScreen(_ dir: Int) {
        let here = screen(containing: NSEvent.mouseLocation)
        if let here, desktopCount(on: here) > 1 {
            Keys.combo(dir > 0 ? 124 : 123, [.maskControl, .maskSecondaryFn])
        } else {
            jumpCursor(dir)
        }
    }

    // MARK: - Écrans

    /// Amène le pointeur au centre de l'écran voisin et active la fenêtre qui s'y trouve.
    static func jumpCursor(_ dir: Int) {
        guard let here = screen(containing: NSEvent.mouseLocation), let there = neighbor(of: here, dir) else { return }
        let r = cgRect(there.frame)
        let target = CGPoint(x: r.midX, y: r.midY)
        CGWarpMouseCursorPosition(target)
        CGAssociateMouseAndMouseCursorPosition(1)
        focusWindow(at: target)
    }

    /// Envoie la fenêtre active sur l'écran voisin, à la même place relative.
    static func moveWindow(_ dir: Int) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ax, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let win = ref else { return }
        let window = win as! AXUIElement
        guard var pos = point(window, kAXPositionAttribute), var size = size(window) else { return }

        let center = NSPoint(x: pos.x + size.width / 2, y: primaryHeight - (pos.y + size.height / 2))
        guard let from = screen(containing: center), let to = neighbor(of: from, dir) else { return }
        let a = cgRect(from.visibleFrame), b = cgRect(to.visibleFrame)
        size.width = min(size.width, b.width); size.height = min(size.height, b.height)
        let rx = a.width > size.width ? (pos.x - a.minX) / (a.width - size.width) : 0
        let ry = a.height > size.height ? (pos.y - a.minY) / (a.height - size.height) : 0
        pos = CGPoint(x: b.minX + max(0, min(1, rx)) * (b.width - size.width),
                      y: b.minY + max(0, min(1, ry)) * (b.height - size.height))
        set(window, kAXSizeAttribute, size)
        set(window, kAXPositionAttribute, pos)
        set(window, kAXSizeAttribute, size)
        CGWarpMouseCursorPosition(CGPoint(x: pos.x + size.width / 2, y: pos.y + size.height / 2))
    }

    private static func focusWindow(at p: CGPoint) {
        let sys = AXUIElementCreateSystemWide()
        var el: AXUIElement?
        guard AXUIElementCopyElementAtPosition(sys, Float(p.x), Float(p.y), &el) == .success, let el else { return }
        var pid: pid_t = 0
        AXUIElementGetPid(el, &pid)
        NSRunningApplication(processIdentifier: pid)?.activate()
    }

    private static func point(_ w: AXUIElement, _ attr: String) -> CGPoint? {
        var v: CFTypeRef?; var p = CGPoint.zero
        guard AXUIElementCopyAttributeValue(w, attr as CFString, &v) == .success,
              AXValueGetValue(v as! AXValue, .cgPoint, &p) else { return nil }
        return p
    }
    private static func size(_ w: AXUIElement) -> CGSize? {
        var v: CFTypeRef?; var s = CGSize.zero
        guard AXUIElementCopyAttributeValue(w, kAXSizeAttribute as CFString, &v) == .success,
              AXValueGetValue(v as! AXValue, .cgSize, &s) else { return nil }
        return s
    }
    private static func set(_ w: AXUIElement, _ attr: String, _ p: CGPoint) {
        var p = p; if let v = AXValueCreate(.cgPoint, &p) { AXUIElementSetAttributeValue(w, attr as CFString, v) }
    }
    private static func set(_ w: AXUIElement, _ attr: String, _ s: CGSize) {
        var s = s; if let v = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(w, attr as CFString, v) }
    }
}
