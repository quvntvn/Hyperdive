# Hyperdive — Briefing de reprise pour Claude assistant

## Qui je suis et comment on bosse

Je m'appelle Quvntvn (GitHub) / Hulku, dev intermédiaire sur Windows. Je développe Hyperdive, un jeu mobile Android portrait. J'utilise **Claude Code (CLI, Sonnet, Claude Pro)** pour l'exécution dans le repo, et je discute avec toi (Claude claude.ai) pour la stratégie : tu me donnes des prompts à coller dans Claude Code.

Dossier projet : `C:\Users\Hulku\Desktop\autre\dev\Hyperdive\hyperdive`. Git `origin/main` configuré, Claude Code auto-push à la fin de chaque tâche. `CLAUDE.md` à la racine décrit le contexte permanent.

Style attendu :
- Français, concis mais explicatif (j'apprends Godot, dis-moi le POURQUOI).
- Prompts ready-to-paste dans des blocs fenced ``` à coller direct dans Claude Code, commits séparés en français au format `type(scope): desc`, `git push` à la fin.
- Quand un fix est risqué, dis-moi les pièges à surveiller.
- Itération rapide : je teste puis te décris ce que je vois. Je peux à nouveau partager des captures/vidéos dans cette nouvelle conv.
- En cas de bug visuel "ça ne s'affiche pas", utilise le **mode debug** : rendre le truc volontairement TRÈS visible (couleurs vives, grande taille) pour confirmer qu'il se rend, puis doser.

## Le jeu — Hyperdive

Jeu de chute libre Android portrait, style Falling Fred mais avec une DA forte.

**Direction artistique : Mid-Century rétrofuturisme** (Les Indestructibles, Googie, Atomic Age). PAS synthwave. Palette stricte 7 couleurs :
- Orange brûlé `#E94F37`
- Turquoise rétro `#3CAEA3`
- Jaune moutarde `#F2C14E`
- Crème `#F4E9CD`
- Bordeaux `#7C2E2A`
- Bleu nuit doux `#1F305E`
- Marron noyer `#3D2C1E`

**Stack :** Godot 4.6.2 stable, renderer Forward Mobile, GDScript typé statiquement. Conventions : `snake_case` fichiers, `PascalCase` class_name, signaux verbe-passé.

## Gameplay actuel

- **Plongeon tête la première** (modes chute) : le Node3D Character est flippé (~180-210° autour X, `CHARACTER_BASE_ROT = (205,0,0)`), pose spread-eagle bras/jambes écartés. Base des hanches élargie pour éviter le croisement des jambes.
- **1 SEULE VIE** : tout obstacle = mort immédiate → ragdoll physique (la mort est satisfaisante). `MAX_LIVES = 1`. Indicateur de vies du HUD retiré.
- **Murs latéraux** : son de hit (`Audio.play_hit`) avec cooldown ~0.3s, PAS de perte de vie. Seuls les obstacles tuent. Couloir = 9 unités de large (`CORRIDOR_HALF_WIDTH = 4.5`).
- **Sway procédural des membres** : pilotage par vélocité latérale + sin + jolt au choc, lerp floppy autour des `base_rotation` de la pose. Battement amplifié pour rendre la chute vivante. (En envol : sway léger autour de la pose fusée, voir plus bas.)
- **Contrôle** : finger-follow tactile mobile (`TOUCH_FOLLOW_SPEED=8`), clavier desktop. **Mode TILT/inclinaison SUPPRIMÉ**.
- **Trail "sang"** : émission constante pendant la chute, couleur = liquide équipé. Option "Aucun" (gratuite, défaut) → pas d'émission.
- **Parachute (victoire campagne)** : à l'ouverture, tween redresse le Character vers debout (~0.3s) pour que le parachute soit au-dessus de la tête. Ralenti puis level_screen.
- **Ragdoll de mort** : spawn avec `global_rotation = $Character.global_rotation` (PAS `global_transform`, sinon double scale 1.5) → démarre tête en bas comme le perso. Si parties ignorent la rotation root, appliquer rotation par-partie. En envol : restaure `gravity_scale=1` + vitesse vers le bas (on RETOMBE).

## Modes

- **Campagne** : niveaux chronométrés. `get_level_duration(level) = 30 + (level-1)*5`. Récompense `20 + level*10`. Vitesse fixe.
- **Infini** : distance/score. **Vitesse de chute augmente de 10% par 1000 m, FLUIDEMENT** (rampe ~10s, move_toward, pas de à-coup), cumulatif `vitesse_base × 1.1^floor(distance/1000)`. **Débloqué au niveau 2** (`INFINITE_UNLOCK_LEVEL = 2`).
- **Envol** (variante infinie) : on MONTE comme avec un jetpack. **Débloqué au niveau 5** (`ENVOL_UNLOCK_LEVEL = 5`). Détails ci-dessous.

### Mode Envol — détail

Variante du mode Infini (passe par la branche `active_mode != "campaign"` de main_game). Inversion mécanique centralisée par un signe `dir` (+1 en envol = on monte, -1 sinon).

- **Mécanique** : `gravity_scale = 0`, poussée constante `linear_velocity.y = +_current_max_speed` (vitesse constante, pas d'accélération physique). Score = `abs(global_position.y)` = altitude.
- **Rampe de vitesse** : +10% tous les **500m**, FLUIDEMENT (même lissage move_toward que l'infini), `vitesse_base × 1.1^floor(altitude/500)`.
- **Caméra** : pitch vers le HAUT (rotation X ~+35°, miroir de la chute), offset pour mettre le perso en BAS de l'écran. On voit le DOS du perso (caméra derrière lui).
- **Obstacles + pièces** : mêmes objets, spawnés en haut (via `dir`), descendent vers le joueur. Despawn dir-relatif.
- **Pose fusée** : perso debout penché ~12° avant (`ENVOL_CHARACTER_ROT = (-12,0,0)`), bras le long du corps, jambes serrées (`ENVOL_ARM_L/R`, `ENVOL_LEG_L/R`, `ENVOL_HEAD`). Poses ENVOL séparées des poses plongeon (if sur le mode) pour ne pas casser la chute. Sway léger réactivé en envol (faible amplitude autour des base_rotation envol).
- **Jetpack** : réacteur dorsal (petit BoxMesh turquoise `#3CAEA3` ~0.3×0.4×0.2) attaché au Torse, placé CÔTÉ CAMÉRA (+Z = le dos visible), calé entre épaules et milieu du dos, tête visible au-dessus. Créé dans `_setup_jetpack()`, visible uniquement en envol.
- **Flammes** : GPUParticles3D sous le réacteur, émission vers le bas, look "bouffées" courtes et denses (lifetime court), dégradé jaune `#F2C14E` → orange `#E94F37`. Son propre matériau.
- **Fumée** : 2e GPUParticles3D, fine traînée grise semi-transparente en sillage derrière les flammes (lifetime plus long, opacité faible). Son propre matériau.
- **Audio** : son `jetpack.mp3` en boucle continue + le whoosh du vent EN PLUS (les deux jouent ensemble), volume du jetpack varié aléatoirement comme le whoosh. Démarré au début de partie envol, arrêté à la mort/pause.
- **Pas de skyline** en mode envol (ville retirée pour ce mode, plus lisible).

## Contenu

- **Shop 3 catégories (systèmes parallèles, sélecteur d'onglets)** :
  - **Skins** (5 couleurs perso)
  - **Sang** : "Aucun" (gratuit, défaut, pas d'émission) + Sang rouge (payant 15) + Sang royal bleu + Bile + Sang d'or + Encre + Antigel + Lait + Pétrole. Trail = GPUParticles3D avec SON PROPRE ParticleProcessMaterial (pas celui du corps).
  - **Thèmes** : 1962 (défaut), Minuit, Coucher de soleil, Océan, Monochrome. Changent `wall_color` + `line_color` (uniforms shader) + sky_top/sky_horizon (ProceduralSkyMaterial). Appliqués via `corridor_walls.gd` (existe dans main_game ET main_menu). **Le thème pilote aussi la skyline** (façade + brume, voir Décor).
- **Défis** : libellé `Défi`. 7 permanents basés sur stats persistées + 3 journaliers/jour seedés par date (types distance/coins/time/games), reset au changement de jour.
- **Pièces** : `coin.tscn` + `CoinSpawner`. Espacement vertical ×4. Émission jaune `#F2C14E` (multiplier ~0.5) pour la visibilité.
- **Obstacles** : famille de plusieurs types (mêmes obstacles dans tous les modes), pioche aléatoire uniforme via `obstacle_scenes.pick_random()`. Voir section Obstacles.
- **Power-ups** (rares, ~400-600m) :
  - **Bouclier** (turquoise, forme écusson) : absorbe le PROCHAIN choc d'obstacle. Intégré avec `_trigger_ragdoll` (pas de ragdoll si shield).
  - **Ralenti** (bleu nuit, sablier) : vitesse de chute ×0.5 pendant ~3s.
  - **Aimant** (jaune, fer à cheval) : attire les pièces ~5s. **EXCLU du mode campagne** (pas de pièces).
  - **Boost** (orange brûlé, flèche bas) : plongée ×2-3 + immunité aux obstacles pendant ~2s. Intégré avec `_trigger_ragdoll`. **En envol : poussée inversée (vers le haut)**.
  - **Halo lumineux** + **rim/fresnel blanc** sur chacun pour pop. HUD affiche effet actif + temps restant.

## Obstacles

- **Pioche** : `obstacle_spawner.gd`, `obstacle_scenes: Array[PackedScene]`, `pick_random()` uniforme. Pour ajouter un type : ajouter la scène dans le tableau.
- **Spawn** : `SPAWN_AHEAD = 60`, `SPAWN_INTERVAL_Y = 14.4` (espacement vertical doublé), X aléatoire `randf_range(-4.5, 4.5)`, Z=0. Spawn/despawn pilotés par `_dir` → compatibles chute ET envol. `DESPAWN_BEHIND = 15`.
- **Matériau danger** : orange brûlé `#E94F37` émissif (multiplier ~0.3) pour ressortir du fond. (NB : on a essayé de différencier les couleurs par forme, mais le registre reste chaud = danger, jamais le jaune des pièces ni le turquoise du ciel.)
- **Mort** : collision = ragdoll, via `obstacle_base.gd` (hérité par tous les types).
- **Types actuels** (couloir = 9 large, passage mini garanti = 3 unités) :
  - **Cube** (base) : ponctuel, esquive latérale.
  - **Barre horizontale** : couvre ~6 unités, laisse un passage ~3 d'un côté (gauche/droite aléatoire).
  - **Mur à trou** : couvre toute la largeur sauf une ouverture ~3 mini à position latérale aléatoire (centre entre -3 et +3 pour rester atteignable).
  - **Cube oscillant** (mobile) : glisse latéralement en va-et-vient `position.x = centre + sin(t*vitesse)*amplitude`, amplitude ~2.5 max (reste dans le couloir). Oscillation X indépendante du sens chute/envol.
  - **Porte coulissante** (mobile, timing) bordeaux `#7C2E2A` : 2 panneaux qui s'écartent/rejoignent (cycle fermé 1.0s / ouvert 1.6s + transitions 0.4s). Ouverts → passage central ≥3. Panneaux toujours mortels (pas de toggle collision) ; c'est l'espace central qui laisse passer. Cycle temporel → identique chute/envol.
  - **Laser balayant** (mobile, timing) bordeaux `#7C2E2A` : barre fine pleine largeur qui s'allume/éteint. Éteint (1.8s) = collision OFF (passable). **Avertissement (0.5s, pulse, collision encore OFF)** avant allumage → pas de mort surprise. Allumé (0.9s) = collision ON, mortel. Matériau PROPRE par instance (émission animée). Collision via `CollisionShape3D.disabled` selon la phase.
- **Pistes futures** : 3e lot (pendule type boule de démolition, soucoupe qui traverse horizontalement).

## UI / Design

- **Police Poppins** partout (`assets/fonts/Poppins-*.ttf`). Thème global `resources/ui/main_theme.tres` assigné via `project.godot gui/theme/custom`.
- **Boutons** : turquoise opaque avec ombre, coins arrondis 12, hover/pressed/disabled, marges généreuses, font_color crème.
- **Titres** (variation `Title`) : orange brûlé `#E94F37`, Poppins Bold, taille ~52-72. Appliqué à HYPERDIVE, SHOP, GAME OVER, PAUSE, RÉGLAGES, DÉFIS, NIVEAU X.
- **Sous-titres** (variation `Subtitle`) : jaune moutarde.
- **Contours de texte** (font_outline_size ~4-6 sombre) pour lisibilité sur tous fonds.
- **Icône pièce SVG** (`assets/ui/coin_icon.svg`, cercle doré + anneau intérieur) dans le HUD.
- **Panneaux modaux opaques** (StyleBoxFlat alpha 1.0 sur le panneau central, scrim séparé pour assombrir le fond).
- **Transitions de scène en fondu** : autoload `Transition` (CanvasLayer layer ~100 + ColorRect noir). `Transition.change_scene(path)` = fondu→change_scene_to_file→fondu retour. Gère les appels multiples, garantit alpha 0 final.
- **Animation ouverture panneaux** : scale 0.92→1.0 + alpha 0→1 sur 0.2s, TRANS_BACK EASE_OUT.
- **Feedback clic boutons** : scale 0.96 au press, retour à 1.0 au release.
- **Engrenage réglages** : `assets/ui/gear_icon.svg`, TextureButton en haut à droite du menu.
- **Bouton ENVOL au menu** : visible/activé seulement si `is_envol_unlocked()` (niveau > 5). Idem bouton infini (niveau > 2).
- **Icône d'app** : `icon.svg` racine (plongeur Mid-Century crème sur ciel dégradé bleu nuit→bordeaux + lignes couloir jaune), assignée `application/config/icon`.
- **Splash** : `boot_splash/bg_color = #1F305E`, image = icône du projet.

## Audio

- Autoload `Audio` (AudioManagerClass, scène `scenes/autoload/audio_manager.tscn`).
- Bus Master/Music/SFX. Pool 6 SFX players.
- Musique gameplay (jazz exotica, `assets/audio/music/gameplay_loop.mp3`).
- Whoosh (`fall_whoosh.mp3`) modulé par vitesse via `set_whoosh_intensity(intensity)`, avec variation aléatoire du volume.
- Jetpack (`assets/audio/music/jetpack.mp3`) : boucle continue en mode envol, EN PLUS du whoosh, volume varié aléatoirement comme le whoosh. API play/stop dédiée. NE PAS jouer sur le bus Music (sinon affecté par duck_music). Loop activé sur l'import du .mp3.
- SFX `assets/audio/sfx/` : coin_pickup, obstacle_hit, game_over, ui_click.
- API : `play_coin/hit/game_over/ui_click`, `play_music/duck_music/unduck_music`, play/stop jetpack.
- Volumes persistés via Settings, AudioServer set_bus_volume_db.

## Décor / atmosphère

- **Façade de fenêtres défilante** sur les murs (shader `wall_pattern.gdshader` : grille de fenêtres allumées/éteintes pseudo-aléatoires). Grille cohérente, bons axes monde/UV. Fenêtres atténuées (win_mix ~0.50) pour ne pas voler l'attention aux obstacles. Murs : `wall_color` assombrie ×0.8.
- **Boucle du menu fluide** : `MenuCam LOOP_DISTANCE` = multiple EXACT de la période du motif de fenêtres (ex 20.25 = 1.35 × 15 cellules) → aucun saut visible au bouclage. Aligner LOOP_DISTANCE sur k×période sinon le motif saute.
- **Skyline (ville lointaine)** : `scripts/utils/city_skyline.gd` (partagé jeu + menu). Grille d'immeubles 3D (BoxMesh) avec shader fenêtres lumineuses (jaune, allumées/éteintes pseudo-aléatoires), seed fixe 1962 (ville stable).
  - **Modes chute** : ancrée à la caméra, `pos=(0,-72,-90)`, `rot=(-45,0,0)` (plongée douce, on voit les toits d'en haut). Placement validé, NE PAS toucher.
  - **Mode envol** : PAS de skyline (retirée).
  - **Couleur pilotée par le thème** : façade = `(theme_color*0.5).lerp(gris sombre, 0.3)` (désaturée/en retrait). Brume = `theme_color.lerp(noir, 0.7)` (sombre, teintée thème). Même source de couleur que `corridor_walls`.
  - **Brume** (dans le shader skyline) : fondu de la façade vers fog_color selon distance caméra (`fog_start=55, fog_end=110`, mélange plafonné ~0.5). Premier plan net, fond estompé. Régler par distance, pas trop fort sinon noie la ville.
- **Hiérarchie visuelle** : décor terne (murs assombris, skyline désaturée, fenêtres atténuées) vs gameplay saturé (obstacles orange émissifs, pièces jaunes brillantes). Le lointain doit toujours être plus terne que le proche (perspective atmosphérique).
- **Motes/poussières flottantes** dans l'air du couloir (GPUParticles, faible opacité, mouvement lent).
- **Nuages doux** + **étoiles** (petites particules) dans l'ouverture lumineuse du haut. Nuages opacité réduite (-50%), étoiles nombre /2. En envol, ciel + nuages étendus pour couvrir le haut de l'écran (caméra inclinée vers le haut).
- **Ancien décor latéral** SUPPRIMÉ.

## Architecture / fichiers clés

- **Racine** : `CLAUDE.md`, `icon.svg`, `project.godot`, `export_presets.cfg`
- **Autoloads** :
  - `Settings` → `scripts/autoload/settings_manager.gd` (modes, déblocages, durées, volumes)
  - `Catalog` → `scripts/autoload/cosmetics_catalog.gd`
  - `Audio` → `scripts/autoload/audio_manager.gd` (scène `scenes/autoload/audio_manager.tscn`)
  - `Missions` → `scripts/autoload/missions_catalog.gd`
  - `Transition` → `scripts/autoload/scene_transition.gd`
- **Player** : `scripts/player/player.gd` (PlayerController, contient `_setup_jetpack()`, poses chute + envol), `scenes/player/{player,ragdoll}.tscn`
- **Gameplay** : `scripts/gameplay/{follow_camera, obstacle_spawner, coin_spawner, corridor_walls, obstacle_base, powerup_spawner}.gd`, + `scripts/game/main_game.gd` (MainGame, gère campagne/envol, crée la skyline en chute)
- **Utils** : `scripts/utils/city_skyline.gd` (skyline partagée jeu+menu)
- **UI** : `scripts/ui/{game_hud, shop_screen, game_over_screen, main_menu, menu_camera, settings_screen, pause_screen, level_screen, missions_screen}.gd`, scènes correspondantes `scenes/ui/`
- **Collectibles** : `scripts/collectibles/{coin, powerup}.gd`, scènes `scenes/collectibles/`
- **Scènes principales** : `scenes/game/main_game.tscn`, `scenes/ui/main_menu.tscn`, `scenes/obstacles/` (cube, barre, mur à trou, cube oscillant)
- **Shaders** : `assets/shaders/{halftone, wall_pattern}.gdshader` + shader skyline (dans city_skyline.gd)
- **Thème UI** : `resources/ui/main_theme.tres`
- **Physique** : `resources/physics/frictionless.tres` (murs)
- **Police** : `assets/fonts/Poppins-{Bold,Medium,Regular}.ttf`
- **Audio** : `assets/audio/{music, sfx}/` (music contient gameplay_loop.mp3, jetpack.mp3 ; sfx les bruitages courts)
- **UI assets** : `assets/ui/{gear_icon, coin_icon}.svg`

## Layers / conventions

- **CanvasLayer** : 0 post-process, 1 HUD, 5 pause, 6 game over, 7 shop, 8 settings, ~100 Transition
- **Physique** : interpolation activée (120Hz). DÉSACTIVER l'interpolation SUR LA CAMÉRA (`physics_interpolation_mode = OFF`) sinon double-interpolation = vibration. Suivi caméra Y rigide (offset fixe, pas de lerp Y).
- **Mobile** : Portrait verrouillé, stretch aspect "expand", max_fps=0 + V-Sync + Frame Pacing Swappy + Interpolation Physique activée → 120Hz.
- **Signe dir** : un seul point de vérité pour l'inversion chute/envol (envol = +1 on monte, -1 sinon). Lu par player, spawners, caméra. Ne PAS hardcoder un sens.

## Pièges Godot rencontrés (à connaître)

- `@export` NodePath fragile → préférer **pattern par groupe** (`add_to_group` + `get_first_node_in_group`) pour références cross-scène.
- Modifs UI Godot fiables ; modifs `.tscn`/`project.godot` par script peuvent diverger (ex orientation Android → faire via l'UI Godot).
- Désinstaller/réinstaller l'APK après changement d'orientation.
- `Transform3D` row-major dans les .tscn → préférer `rotation_degrees`.
- `visible=true` sauvegardé par accident sur panels modaux = boucle au démarrage.
- Interpolation physique 120Hz → caméra `physics_interpolation_mode=OFF` sinon vibration.
- RigidBody enfants d'une scène instanciée peuvent ignorer la rotation du root → appliquer la rotation par-partie si besoin (ragdoll).
- GPUParticles : changer `amount` redémarre. Trail/flammes/fumée doivent avoir CHACUN leur PROPRE matériau (pas partagé).
- Ragdoll spawn : `global_rotation`, PAS `global_transform` (sinon double scale 1.5 du Character).
- **Objet ancré à la caméra** (skyline, jetpack) : sa position locale suit la rotation de la caméra. En envol la caméra est inclinée → recalculer l'offset par mode. L'angle relatif objet/caméra est ce qui compte (la skyline chute a un relatif de -10° : caméra -35°, ville -45°).
- **Dos vs ventre** : en envol la caméra suit le perso par derrière → on voit son DOS → le réacteur dorsal va CÔTÉ CAMÉRA (+Z), pas à l'opposé.
- **Boucle de défilement** : LOOP_DISTANCE doit être un multiple exact de la période du motif, sinon saut visible.
- **Mur à trou / barre** : passage mini 3 unités (couloir = 9) sinon mort garantie = injouable.
- **Audio en boucle** : activer `loop` sur l'import du .mp3 (sinon s'arrête après 1 lecture) ; bien stop à la mort/pause ; pas sur le bus Music.
- **Rampe de vitesse** : toujours move_toward (lissage), jamais un saut sec au palier.

## Mes préférences et ton du jeu

- Itère vite : je teste, je décris en mots ou je partage des captures.
- Prompts concis, ciblés, avec le pourquoi.
- Ton arcade tendu : 1 vie, plongeon dramatique, ragdoll satisfaisant.
- Ton playful : sang/liquides drôles dans le shop (Bile, Antigel, Lait, etc.).
- Pour les bugs visuels difficiles à décrire, **mode debug** systématique : rendre exagérément visible/coloré pour confirmer, puis doser.

## Pistes possibles

- 2e lot d'obstacles (pendule, soucoupe horizontale).
- Distribution itch.io (gratuit, upload APK, page de jeu en 10 min) ou Play Store (25$ une fois, fiche, signature, vérifications).
- Équilibrage 1 vie si trop dur (élargir couloir, réduire densité, ralentir).
- Tester sur vrai téléphone (particules + audio jetpack/vent peuvent différer du PC).
- Profiter du jeu.