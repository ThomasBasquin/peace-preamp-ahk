# Peace Preamp AHK

Script AutoHotkey v2 pour contrôler le preamp de [Peace](https://sourceforge.net/projects/peace-equalizer-apo-extension/) (interface graphique d'Equalizer APO) avec un OSD à l'écran.

## Fonctionnalités

- Réglage du preamp par pas de 0.5 dB avec affichage OSD
- Deux profils : **Casque** (plafond -10 dB) et **Enceintes** (plafond -3 dB)
- Mute toggle
- Avertissement visuel à l'approche du plafond
- Synchronisation périodique avec `peace.txt` (détecte les changements externes)
- Réinstallation automatique du hook clavier (contourne l'éjection par certains jeux)
- OSD affichant le profil actif dès le lancement du script
- Nouvelle tentative automatique (~1.2 s) si le périphérique du profil visé n'est pas encore détecté comme actif (DAC USB qui se réveille), et confirmation réelle (pas supposée) que Peace a bien chargé le profil avant de mettre à jour l'OSD

## Prérequis

- [AutoHotkey v2](https://www.autohotkey.com/)
- [Equalizer APO](https://sourceforge.net/projects/equalizerapo/)
- [Peace Equalizer](https://sourceforge.net/projects/peace-equalizer-apo-extension/)

## Raccourcis

| Raccourci | Action |
|-----------|--------|
| `F13` | Baisser le preamp (-0.5 dB) |
| `F14` | Monter le preamp (+0.5 dB) |
| `F15` | Toggle mute |
| `Ctrl+Alt+F1` | Profil Enceintes |
| `Ctrl+Alt+F2` | Profil Casque |

> Les touches F13–F15 sont typiquement assignées via un clavier programmable ou un logiciel de remapping.

## Installation

1. Installer les prérequis ci-dessus
2. Le script a besoin des droits administrateur (il écrit dans `Program Files\EqualizerAPO\config\`). Pour éviter une invite UAC à chaque démarrage de Windows, il est lancé via une tâche planifiée **"Peace Preamp Controller"** (déclencheur : ouverture de session, niveau d'exécution : le plus élevé) plutôt que via un raccourci dans le dossier Démarrage — une tâche planifiée en élévation maximale ne redemande pas de confirmation UAC.
3. Lancé manuellement (double-clic), le script s'auto-élève via `RunAs` et redemande donc l'UAC — c'est normal, ça ne concerne que ce cas d'usage.

## Diagnostic

Chaque tentative de switch de profil (recherche du périphérique, résultat, confirmation) est journalisée dans `%TEMP%\peace_preamp.log` (rotation automatique au-delà de 256 Ko). Utile pour comprendre après coup un switch casque/enceintes qui semble avoir échoué.

## Configuration

Les profils sont définis en haut du script dans la `Map` `profiles`. Chaque profil contient :

| Paramètre | Description |
|-----------|-------------|
| `default` | Valeur initiale au changement de profil |
| `min` | Plancher (dB) |
| `max` | Plafond (dB) |
| `step` | Pas d'incrémentation (dB) |
| `warnZone` | Zone d'avertissement avant le plafond (dB) |
