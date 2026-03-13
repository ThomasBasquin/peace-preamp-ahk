# Peace Preamp AHK

Script AutoHotkey v2 pour contrôler le preamp de [Peace](https://sourceforge.net/projects/peace-equalizer-apo-extension/) (interface graphique d'Equalizer APO) avec un OSD à l'écran.

## Fonctionnalités

- Réglage du preamp par pas de 0.5 dB avec affichage OSD
- Deux profils : **Casque** (plafond -10 dB) et **Enceintes** (plafond -3 dB)
- Mute toggle
- Avertissement visuel à l'approche du plafond
- Synchronisation périodique avec `peace.txt` (détecte les changements externes)
- Réinstallation automatique du hook clavier (contourne l'éjection par certains jeux)

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
2. Lancer `peace_preamp.ahk` — le script demande les droits administrateur (nécessaire pour écrire dans `Program Files\EqualizerAPO\config\peace.txt`)

## Configuration

Les profils sont définis en haut du script dans la `Map` `profiles`. Chaque profil contient :

| Paramètre | Description |
|-----------|-------------|
| `default` | Valeur initiale au changement de profil |
| `min` | Plancher (dB) |
| `max` | Plafond (dB) |
| `step` | Pas d'incrémentation (dB) |
| `warnZone` | Zone d'avertissement avant le plafond (dB) |
