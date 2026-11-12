import AppKit

/// Mode jeu : quand un jeu est au premier plan, Mulot s'efface.
/// Les boutons gardent leur rôle d'origine et le bouton de pouce ne fait plus de gestes,
/// pour que le jeu ne perde jamais la souris (changement de bureau, Mission Control…).
final class GameMode {
    static let shared = GameMode()

    /// Apps de jeu qui ne se déclarent pas toujours comme jeux (cloud gaming, lanceurs).
    private static let knownGames: Set<String> = [
        "com.nvidia.gfnpc.mall",          // GeForce NOW
        "com.valvesoftware.steam",        // Steam (Big Picture et jeux lancés depuis Steam)
        "com.blizzard.worldofwarcraft",
        "net.battle.app",                 // Battle.net
        "com.epicgames.EpicGamesLauncher",
        "com.codeweavers.CrossOver",
        "com.isaacmarovitz.Whisky",
        "com.apple.gamecenter",
    ]

    private(set) var activeApp: String?
    var isActive: Bool { activeApp != nil }
    var onChange: (() -> Void)?

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] n in
            let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.update(app)
        }
        update(NSWorkspace.shared.frontmostApplication)
    }

    private func update(_ app: NSRunningApplication?) {
        // Ouvrir la fenêtre de Mulot ne doit pas sortir du mode jeu.
        if app?.processIdentifier == ProcessInfo.processInfo.processIdentifier { return }
        let name = app.flatMap { Self.isGame($0) ? ($0.localizedName ?? String(localized: "un jeu")) : nil }
        guard name != activeApp else { return }
        activeApp = name
        appLog(name.map { "Mode jeu : \($0)" } ?? "Mode jeu terminé")
        onChange?()
    }

    /// Un jeu tourne-t-il, même s'il n'est pas au premier plan ?
    static var anyGameRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.activationPolicy == .regular && isGame($0) }
    }

    static func isGame(_ app: NSRunningApplication) -> Bool {
        if let id = app.bundleIdentifier, knownGames.contains(id) { return true }
        guard let url = app.bundleURL, let info = Bundle(url: url)?.infoDictionary else { return false }
        let category = (info["LSApplicationCategoryType"] as? String ?? "").lowercased()
        return category.contains("games")
    }
}
