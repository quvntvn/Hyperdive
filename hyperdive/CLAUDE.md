# CLAUDE.md — Hyperdive

> Fichier de contexte persistant pour Claude Code. Lu automatiquement au début de chaque session. À garder à jour quand le projet évolue (nouvelle mécanique, changement de convention, fin de phase).

## Vue d'ensemble

**Hyperdive** est un jeu mobile Android en orientation **portrait** où le joueur contrôle un personnage en chute libre traversant des décors rétrofuturistes.

- **Inspiration gameplay** : *Falling Fred*
- **Inspiration visuelle** : *Les Indestructibles* (Mid-Century Modern + Atomic Age + design d'espionnage 1960s)

Le joueur dirige sa chute latéralement pour esquiver des obstacles, récupérer des bonus, et accomplir des missions. La monnaie collectée se dépense dans un shop pour des cosmétiques (skins, traînées de particules) et des améliorations (résistance, vitesse, multiplicateurs de score).

## Stack technique

- **Moteur** : Godot 4 (renderer **Mobile**, pas Forward+ ni Compatibility)
- **Langage** : GDScript (pas C#)
- **Plateforme cible** : Android (export configuré plus tard, Phase F)
- **Plateforme de dev** : Windows
- **Versionning** : Git, commits petits et fréquents

## Direction artistique (NON NÉGOCIABLE)

Mid-Century retrofuturism. **NE PAS** dériver vers synthwave/néon 80s ni vers du réalisme PBR.

### Palette (à respecter strictement)

| Couleur | Hex | Usage |
|---|---|---|
| Orange brûlé | `#E94F37` | accent principal, danger, perso |
| Turquoise rétro | `#3CAEA3` | UI principale, ciel |
| Jaune moutarde | `#F2C14E` | récompenses, monnaie, étoiles |
| Crème | `#F4E9CD` | backgrounds clairs, textes |
| Bordeaux | `#7C2E2A` | ombres, accents foncés |
| Bleu nuit doux | `#1F305E` | ciel haut, contraste froid |
| Marron noyer | `#3D2C1E` | silhouettes, sol |

Aucune couleur n'est saturée pure. Pas de `#FF0000` ni `#0000FF`, jamais.

### Règles visuelles

- Matériaux : `BaseMaterial3D` en `shading_mode = unshaded` ou flat — pas de PBR
- Une seule `DirectionalLight3D` chaude, ombres marquées
- Bloom **très léger** uniquement, jamais saturé
- Post-processing prévu : shader plein écran halftone + grain papier
- Formes des obstacles : courbes Googie, boomerangs, paraboles, étoiles à 4 branches — pas de cubes basiques
- Typographie : épaisse géométrique (Bungee, Anton, Alfa Slab One)
- Silhouettes lisibles à la Saul Bass : le perso doit être reconnaissable en ombre chinoise

## Gameplay core

- Vue 3D, caméra qui suit le perso vers le bas
- Orientation **portrait uniquement**
- **Deux schémas de contrôle**, switchables dans les options :
  - **Tactile** : drag horizontal du doigt pour orienter la chute
  - **Tilt** : accéléromètre du téléphone pour orienter la chute
- Score = distance parcourue en mètres
- Monnaie : pièces ramassées en chutant
- Game over : barre de vie à zéro après accumulation de chocs
- Boucle de méta-progression : pièces → shop → cosmétiques + upgrades
- Missions : objectifs ponctuels donnant des bonus (ex. "tomber 500 m sans toucher d'obstacle")

## Structure du projet

```
hyperdive/
├── CLAUDE.md
├── README.md
├── project.godot
├── assets/
│   ├── audio/        # music/ et sfx/
│   ├── fonts/
│   ├── models/
│   ├── shaders/
│   └── textures/
├── scenes/
│   ├── main/         # menu principal, splash
│   ├── game/         # scènes de gameplay
│   ├── player/       # scènes du joueur
│   ├── obstacles/    # prefabs d'obstacles
│   ├── ui/           # HUD, shop, écrans
│   └── effects/      # particules, vfx
├── scripts/
│   ├── autoload/     # singletons (GameState, AudioManager, SaveSystem)
│   ├── player/
│   ├── gameplay/
│   ├── ui/
│   └── utils/
└── resources/        # .tres custom
    ├── cosmetics/
    ├── upgrades/
    └── missions/
```

## Conventions de code GDScript

- **Fichiers** : `snake_case.gd` et `snake_case.tscn`
- **Classes** : `PascalCase` avec `class_name MyClass`
- **Variables et fonctions** : `snake_case`
- **Constantes** : `SCREAMING_SNAKE_CASE`
- **Signaux** : verbe au passé → `player_died`, `obstacle_hit`, `coin_collected`
- **Typage statique systématique** : `var speed: float = 10.0`, jamais `var speed = 10.0`
- **Une scène = une responsabilité** (Player.tscn ne gère pas le HUD)
- Préférer `_physics_process` à `_process` pour tout ce qui touche à la physique
- Préférer les signaux aux références directes (couplage faible)
- Pas de magic numbers : extraire en constantes nommées en haut du script

## Conventions Git

Format des messages : `type(scope): description courte`

Types : `feat`, `fix`, `refactor`, `art`, `docs`, `chore`

Exemples :
- `feat(player): ajout du contrôle au tilt`
- `art(palette): application de l'orange brûlé sur le perso`
- `fix(camera): la caméra ne suit plus le joueur après respawn`
- `refactor(obstacles): extraction du spawner en autoload`

Un commit par changement logique cohérent. Pas de commit "wip" géant en fin de session.

## Phase actuelle : Phase A — Prototype jouable

**Objectif unique** : valider la sensation de chute. Tout le reste attend.

### À faire dans l'ordre

1. Scène `scenes/game/main_game.tscn` : sol, ciel, caméra verticale
2. Scène `scenes/player/player.tscn` : personnage primitive (cube ou capsule) en orange brûlé
3. Script de chute : gravité + contrôle latéral
4. Script du contrôle tactile (drag du doigt, testable à la souris)
5. Script du contrôle tilt (accéléromètre, testable plus tard sur mobile)
6. Option `control_mode` pour switcher entre les deux
7. Caméra qui suit la position Y du joueur
8. Obstacles primitive qui spawnent procéduralement sous le joueur
9. Détection de collision = perte de vie
10. Compteur de mètres parcourus affiché à l'écran

### À NE PAS faire en Phase A

- Pas d'art final (juste des primitives colorées dans la palette)
- Pas d'export Android (on teste sur PC, souris simule le tactile)
- Pas de shop, pas de missions, pas de menu principal
- Pas de son
- Pas d'animations complexes du perso
- Pas de ragdoll encore (viendra en Phase A.2 si le timing le permet)

## Phases suivantes (pour info, ne pas anticiper)

- **Phase A.2** : ragdoll réaliste avec `PhysicalBone3D`
- **Phase B** : génération procédurale avancée + application complète de la DA
- **Phase C** : missions + système de progression
- **Phase D** : shop + monnaie + cosmétiques + upgrades
- **Phase E** : sons + musique + polish général
- **Phase F** : export Android + signature + publication Play Store

## Règles d'engagement pour Claude Code

- **Toujours** lire ce fichier au début d'une session
- **Toujours** demander avant d'installer un plugin externe (privilégier les nodes Godot natifs)
- **Toujours** respecter la palette et les règles de DA listées ci-dessus
- **Toujours** garder en tête que la cible est mobile : perf, batterie, taille APK
- **Toujours** typer les variables statiquement en GDScript
- **Mettre à jour ce fichier** quand une convention change, qu'une mécanique est ajoutée, ou qu'une phase est terminée
- **Préférer plusieurs petits commits** à un gros commit final
- Si une décision impacte la DA, le gameplay core, ou l'architecture, **demander avant d'agir**

## Notes diverses

- Le perso n'a pas encore de nom (à trouver en Phase B)
- Le nom "Hyperdive" peut évoluer si la dispo Play Store pose problème (à vérifier avant publication)
- Cible technique : 60 FPS sur un mobile mid-range (Snapdragon 7xx ou équivalent)
- Langue de l'app au lancement : français, mais structurer dès le départ avec des clés i18n pour faciliter l'anglais plus tard