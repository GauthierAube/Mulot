import AppKit

/// Images de la MX Master 3S (vue de dessus et vue de côté) avec un point rouge
/// sur le bouton concerné, et une flèche pour les gestes.
enum Spot {
    case molette, superieur, pouceMolette, suivant, precedent, geste

    /// Quelle image, et où se trouve le bouton (en pixels de l'image, origine en haut à gauche).
    var place: (image: String, x: CGFloat, y: CGFloat) {
        switch self {
        case .molette: return ("souris-dessus", 272, 140)
        case .geste: return ("souris-dessus", 39, 447)
        case .superieur: return ("souris-dessus", 272, 235)
        case .pouceMolette: return ("souris-cote", 530, 120)
        case .suivant: return ("souris-cote", 500, 235)
        case .precedent: return ("souris-cote", 630, 198)
        }
    }
}

enum Arrow { case haut, bas, gauche, droite, horizontale, verticale }

enum MouseArt {
    private static var sources: [String: NSImage] = [:]

    private static func source(_ name: String) -> NSImage? {
        if let img = sources[name] { return img }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        sources[name] = img
        return img
    }

    static func image(_ spot: Spot?, arrow: Arrow? = nil, height: CGFloat = 44) -> NSImage {
        let box = NSSize(width: height * 1.5, height: height)
        return NSImage(size: box, flipped: true) { rect in
            guard let spot, let src = source(spot.place.image),
                  let rep = src.representations.first else { return true }
            // Taille réelle en pixels, pour placer le point au bon endroit.
            let pw = CGFloat(rep.pixelsWide), ph = CGFloat(rep.pixelsHigh)
            let scale = min(rect.width / pw, rect.height / ph)
            let w = pw * scale, h = ph * scale
            let frame = NSRect(x: (rect.width - w) / 2, y: (rect.height - h) / 2, width: w, height: h)
            src.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)

            if let arrow {
                // Flèche sur une zone libre du corps de la souris.
                let anchor: CGPoint = spot.place.image == "souris-dessus" ? CGPoint(x: 285, y: 520) : CGPoint(x: 690, y: 380)
                drawArrow(arrow, at: CGPoint(x: frame.minX + anchor.x * scale, y: frame.minY + anchor.y * scale),
                          length: height * 0.22)
            }
            let p = CGPoint(x: frame.minX + spot.place.x * scale, y: frame.minY + spot.place.y * scale)
            let r = max(4.5, height * 0.11)
            let dot = NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
            Palette.nsAccent.setFill(); dot.fill()
            NSColor.white.setStroke(); dot.lineWidth = 1.5; dot.stroke()
            return true
        }
    }

    private static func drawArrow(_ a: Arrow, at c: CGPoint, length: CGFloat) {
        Palette.nsAccent.setStroke(); Palette.nsAccent.setFill()
        func one(_ dx: CGFloat, _ dy: CGFloat) {
            let end = CGPoint(x: c.x + dx * length, y: c.y + dy * length)
            let start = CGPoint(x: c.x - dx * length, y: c.y - dy * length)
            let line = NSBezierPath(); line.move(to: start); line.line(to: end)
            line.lineWidth = 2.2; line.lineCapStyle = .round; line.stroke()
            let head = length * 0.55
            let tip = CGPoint(x: end.x + dx * head * 0.6, y: end.y + dy * head * 0.6)
            let tri = NSBezierPath()
            tri.move(to: tip)
            tri.line(to: CGPoint(x: end.x - dy * head * 0.6, y: end.y + dx * head * 0.6))
            tri.line(to: CGPoint(x: end.x + dy * head * 0.6, y: end.y - dx * head * 0.6))
            tri.close(); tri.fill()
        }
        switch a {
        case .haut: one(0, -1)
        case .bas: one(0, 1)
        case .gauche: one(-1, 0)
        case .droite: one(1, 0)
        case .horizontale: one(1, 0); one(-1, 0)
        case .verticale: one(0, 1); one(0, -1)
        }
    }
}
