# Mulot : journal des modifications

Une petite app Mac, dans la barre des menus, qui remplace Logi Options+ pour les souris Logitech MX Master en Bluetooth (testée avec la MX Master 3S). Elle règle les boutons et les gestes du pouce, sans compte ni logiciel Logitech. Les dernières modifications sont en haut.

## 12 novembre 2026 (soir) : Mulot en anglais

- Mulot s'affiche en anglais sur tout Mac qui n'est pas réglé en français, et reste en français sinon.
- Un petit globe, en bas de la fenêtre, permet de choisir : automatique (langue du Mac), français ou English. Mulot redémarre pour changer de langue.
- Les textes viennent d'un catalogue de traduction Apple (`Localizable.xcstrings`), mis à jour à chaque compilation quand Xcode est installé. Les fichiers compilés (`Resources/en.lproj`, `fr.lproj`) sont gardés dans le dépôt, pour compiler sans Xcode.

## 12 novembre 2026 : actions pour Square

- Quatre nouvelles actions pour les boutons et les gestes du pouce, qui pilotent l'app **Square** (grille des fenêtres ouvertes) : afficher la grille, application suivante, application précédente, agrandir la fenêtre.
- Nouveau mode pour la **molette du pouce** : « Square : changer d'application » (un cran vers la droite, application suivante ; vers la gauche, précédente).
- **Le carrousel de Square suit la souris** : si un geste horizontal du pouce est réglé sur « application suivante » ou « précédente » de Square, le carrousel apparaît dès que la souris part de côté, bouton tenu, la suit, et l'application du centre passe devant au relâchement. Un geste très court garde l'ancien comportement (changement direct).
- Avec la molette du pouce en mode Square, chaque cran avance le carrousel d'une fenêtre, et le choix se fait quand la molette s'arrête. Les crans sont plus espacés, pour ne pas s'emballer.
- Deux actions pour l'app **Side** : afficher le Finder (la carte) et afficher le panneau du bas. Elles n'apparaissent que si Side est installée dans une version qui accepte ces commandes.
- Correction : un clic sur l'icône de la barre des menus referme bien la fenêtre quand elle est ouverte (elle se rouvrait aussitôt).
- Ces choix n'apparaissent que si Square est installée sur le Mac : pour les autres utilisateurs de Mulot, rien ne change.
- Mulot envoie ses commandes à Square par un message entre applications (`com.gauthieraube.square.commande`). Vérifié du côté de Square ; pas encore essayé avec les boutons de la souris.

## 11 novembre 2026 : réglages de la grande molette

- Nouvelle ligne **Grande molette** : choisir quand la molette passe des crans à la roue libre (automatique avec bascule facile, normale ou difficile), ou la garder toujours à crans ou toujours en roue libre. Le réglage est envoyé à la souris (fonction SmartShift) à chaque connexion. Pas encore testé sur une vraie souris.
- Le **bouton derrière la molette** devient réglable : par défaut il bascule toujours entre crans et roue libre, mais on peut lui donner n'importe quelle autre action.
- La section « Molette du pouce » devient « Molettes » et regroupe les deux molettes. Les lignes sont un peu plus serrées pour que la fenêtre ne grandisse pas.

## 10 novembre 2026 (nuit) : mode jeu

- Quand un jeu est au premier plan (GeForce NOW, Steam, Battle.net, CrossOver, ou toute app classée « Jeux »), Mulot s'efface : les boutons gardent leur rôle d'origine et le bouton de pouce ne fait plus de gestes. Avant, un appui involontaire du pouce changeait de bureau en pleine partie et le jeu perdait la souris.
- La fenêtre l'indique (« Mode jeu : … ») et l'icône de la barre des menus devient une manette. Mulot reprend la main dès qu'on revient à une autre app.
- Quand un jeu tourne, Mulot n'ouvre plus sa fenêtre de réglages toute seule au lancement, et `build.sh --install` la relance en arrière-plan : le jeu garde la souris.

## 10 novembre 2026 (nuit) : DMG à partager

- `./make-dmg.sh` fabrique `dist/Mulot-<version>.dmg` : l'app pour Mac Apple Silicon et Intel, un raccourci vers Applications et un Lisez-moi qui explique l'installation et les autorisations.
- Sans certificat Developer ID, macOS bloque la première ouverture : il faut cliquer « Ouvrir quand même » dans Réglages Système › Confidentialité et sécurité.

## 10 novembre 2026 (soir) : icône et réglages toujours accessibles

- Mulot a maintenant sa propre icône : une souris crème sur fond terracotta, tirée du dessin de la MX Master, avec la molette et le bouton de pouce. Elle se régénère avec `python3 tools/make-icon.py`.
- Si l'icône de la barre des menus est cachée (encoche du MacBook ou masquée par macOS), la fenêtre de réglages s'ouvre d'elle-même au milieu de l'écran.
- Ouvrir Mulot depuis le Finder ou Spotlight alors qu'elle tourne déjà affiche les réglages.

## 10 novembre 2026 : préparation open source

- Ajout de la licence MIT et d'une page de présentation (README) en anglais et en français, avec les souris compatibles.
- Captures de la fenêtre (mode clair et sombre) dans `docs/`, régénérées avec `build/Mulot.app/Contents/MacOS/Mulot --capture docs`.

## 10 novembre 2026 : menu sur le côté et icône

- Un clic sur une ligne n'agrandit plus la fenêtre : la liste des choix s'ouvre dans un petit menu à droite de la fenêtre (la fenêtre se décale un peu vers la gauche pour lui laisser la place). Le choix en cours est coché en terracotta.

## 10 novembre 2026 : première version

**La fenêtre**
- Un clic sur l'icône de souris dans la barre des menus ouvre une fenêtre terracotta sur fond crème (mode sombre géré).
- Chaque bouton a sa ligne : un dessin de la souris avec un point sur le bouton concerné, l'action en gros, et le geste qui la déclenche en dessous.
- Un clic sur une ligne la déplie en douceur et fait apparaître tous les choix en pastilles, l'une après l'autre. Un clic sur une pastille choisit l'action.
- En haut : le nom de la souris et sa batterie (verte, orange sous 30 %, rouge sous 20 %). En bas : lancer au démarrage, reconnecter, quitter.

**Les boutons**
- **Bouton de pouce** : un clic ouvre Mission Control. Appuyer et glisser vers le haut : Mission Control ; vers le bas : les fenêtres de l'app ; à gauche ou à droite : le bureau voisin (ou l'app en plein écran voisine), sinon l'autre écran.
- **Boutons avant et arrière** : page suivante et page précédente (⌘] et ⌘[).
- **Clic de la molette** : toutes les apps.
- **Molette du pouce** : défilement horizontal, ou au choix changer d'onglet, le volume, le zoom ou le bureau.
- **Bouton derrière la molette** : garde son rôle d'origine (cran ou roue libre), géré par la souris elle-même.
- Actions possibles en plus : envoyer la fenêtre sur l'écran de gauche ou de droite, afficher le bureau, clic du milieu, lecture/pause, Spotlight, capture d'écran, copier, coller, fermer l'onglet.

**Sous le capot**
- La souris est pilotée en Bluetooth avec le protocole HID++ de Logitech, pour que le bouton de pouce envoie ses appuis à Mulot.
- Mulot redemande ce réglage toutes les 15 secondes et au réveil du Mac, car la souris l'oublie quand elle s'endort.
- Il faut autoriser Mulot dans Réglages Système › Confidentialité et sécurité › **Surveillance de la saisie** et **Accessibilité**.
- Journal de fonctionnement : `~/Library/Logs/Mulot.log`.
- Compiler et installer : `./build.sh --install`.
