# Mulot : journal des modifications

Une petite app Mac, dans la barre des menus, qui remplace Logi Options+ pour la souris Logitech MX Master 3S en Bluetooth. Elle règle les boutons et les gestes du pouce, sans compte ni logiciel Logitech. Les dernières modifications sont en haut.

## 10 novembre 2026 : préparation open source

- Ajout de la licence MIT et d'une page de présentation (README) en anglais et en français, avec les souris compatibles.
- Captures de la fenêtre (mode clair et sombre) dans `docs/`, régénérées avec `build/Mulot.app/Contents/MacOS/Mulot --capture docs`.

## 10 novembre 2026 : menu sur le côté et icône

- Un clic sur une ligne n'agrandit plus la fenêtre : la liste des choix s'ouvre dans un petit menu à droite de la fenêtre (la fenêtre se décale un peu vers la gauche pour lui laisser la place). Le choix en cours est coché en terracotta.
- Mulot a maintenant son icône d'app (une souris blanche sur fond terracotta), visible dans Applications et le Finder. Elle se régénère avec `swift tools/make-icon.swift`.

## 10 novembre 2026 : première version

**La fenêtre**
- Un clic sur l'icône de souris dans la barre des menus ouvre une fenêtre aux couleurs d'Horizon (terracotta, fond crème, mode sombre géré).
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
