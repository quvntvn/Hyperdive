# Hyperdive — Briefing de reprise pour Claude assistant

## Qui je suis et comment on bosse

Je m'appelle Quvntvn (GitHub) / Hulku, dev intermédiaire sur Windows. Je développe Hyperdive, un jeu mobile Android portrait. J'utilise **Claude Code (CLI, Opus 4.8, Claude Pro)** pour l'exécution dans le repo, et je discute avec toi (Claude claude.ai) pour la stratégie : tu me donnes des prompts à coller dans Claude Code.

Dossier projet : `C:\Users\Hulku\Desktop\autre\dev\Hyperdive\hyperdive`. Git `origin/main` configuré, Claude Code auto-push à la fin de chaque tâche. `CLAUDE.md` à la racine décrit le contexte permanent.

Style attendu :
- Français, concis mais explicatif (j'apprends Godot, dis-moi le POURQUOI).
- Prompts ready-to-paste dans des blocs fenced à coller direct dans Claude Code, commits séparés en français au format `type(scope): desc`, `git push` à la fin.
- Quand un fix est risqué, dis-moi les pièges à surveiller.
- Itération rapide : je teste sur mobile puis te décris ce que je vois / partage des captures.
- En cas de bug visuel "ça ne s'affiche pas", utilise le **mode debug** : rendre le truc volontairement TRÈS visible (couleurs vives, grande taille) pour confirmer qu'il se rend, puis doser.
- Pour les gros morceaux (nouveau mode, gros contenu), faire un RAPPORT d'analyse + proposition AVANT de coder, qu'on valide ensemble.

## Le jeu — Hyperdive

Jeu de chute libre Android portrait, style Falling Fred mais avec une DA forte.

**Direction artistique du JEU (3D) : Mid-Century rétrofuturisme** (Les Indestructibles, Googie, Atomic Age). Palette stricte 7 couleurs :
- Orange brûlé `#E94F37`
- Turquoise rétro `#3CAEA3`
- Jaune moutarde `#F2C14E`
- Crème `#F4E9CD`
- Bordeaux `#7C2E2A`
- Bleu nuit doux `#1F305E`
- Marron noyer `#3D2C1E`

**DA de l'UI : glassmorphism moderne** (le projet a évolué — l'UI n'est plus strictement Mid-Century, elle est en verre translucide moderne). Voir section UI. L'univers 3D reste Mid-Century, l'UI est en verre : les deux cohabitent.

**Stack :** Godot 4.6.2 stable, renderer Forward Mobile, GDScript typé statiquement. Conventions : `snake_case` fichiers, `PascalCase` class_name, signaux verbe-passé.

## Gameplay actuel

- **Plongeon tête la première** (modes chute) : Node3D Character flippé (~180-210° X, `CHARACTER_BASE_ROT = (205,0,0)`), pose spread-eagle. Base des hanches élargie.
- **1 SEULE VIE** : tout obstacle = mort immédiate -> ragdoll physique. `MAX_LIVES = 1`.
- **Murs latéraux** : son de hit (`Audio.play_hit`) cooldown ~0.3s, PAS de perte de vie. Seuls les obstacles tuent. Couloir = 9 unités de large (`CORRIDOR_HALF_WIDTH = 4.5`).
- **Sway procédural des membres** : vélocité latérale + sin + jolt au choc, lerp floppy autour des `base_rotation`. En jetpack : sway léger autour de la pose fusée.
- **Contrôle** : finger-follow tactile (`TOUCH_FOLLOW_SPEED = 16`, doublé), clavier desktop. Mode TILT SUPPRIMÉ.
- **Trail "sang"** : émission constante, couleur = liquide équipé. Option "Aucun" (gratuite, défaut).
- **Parachute (victoire campagne)** : tween redresse le Character debout (~0.3s), ralenti, level_screen.
- **Ragdoll de mort** : spawn `global_rotation = $Character.global_rotation` (PAS global_transform). En jetpack : restaure gravity_scale=1 + vitesse vers le bas (on RETOMBE).
- **Retour haptique** : vibration courte au clic des boutons (20ms), marquée à la mort (120ms). Centralisé via `Settings.vibrate(ms)`. Option ON/OFF dans réglages. Voir section Audio/Haptique.

## Modes

- **Campagne** ("NIVEAU X" au menu) : niveaux chronométrés. `get_level_duration(level) = 30 + (level-1)*5`. Récompense `20 + level*10`. Vitesse fixe. PAS de pièces (CoinSpawner désactivé). Lancement DIRECT du niveau courant depuis le menu (plus de sous-menu) ; pièces/récompense affichées au pop-up de fin seulement.
- **Infini** ("CLASSIQUE" au menu) : distance/score. Vitesse +10% par 1000m FLUIDEMENT (move_toward, rampe ~10s), `vitesse_base x 1.1^floor(distance/1000)`. **Débloqué à la fin du niveau 1 de campagne** (flag `infinite_unlocked`, posé dans `complete_current_level`).
- **Jetpack** (ex-"envol", variante infinie) : on MONTE. **Débloqué à 1000m en mode infini** (`best_infinite_distance >= JETPACK_UNLOCK_DISTANCE`, =1000). Détails ci-dessous.

NB interne : `active_mode` reste "campaign"/"infinite"/"jetpack". Les libellés menu (NIVEAU/CLASSIQUE/JETPACK) sont juste l'affichage. Un mode verrouillé affiche la condition DANS le bouton grisé.

### Mode Jetpack — détail

Variante du mode infini (branche `active_mode != "campaign"` de main_game). Inversion centralisée par `Settings.get_fall_dir()` : +1 en jetpack (on monte), -1 sinon.

- **Mécanique** : `gravity_scale = 0`, poussée constante `linear_velocity.y = +_current_max_speed`. Score = `abs(global_position.y)` = altitude.
- **Rampe vitesse** : +10% tous les 500m (`SPEED_RAMP_STEP_JETPACK = 500`), même lissage move_toward que l'infini.
- **Caméra** : pitch vers le HAUT (~+35°, miroir chute), perso en bas. On voit le DOS du perso.
- **Obstacles + pièces** : mêmes objets, spawn en haut (via dir), descendent. Despawn dir-relatif.
- **Pose fusée** : debout penché ~12° avant (`JETPACK_CHARACTER_ROT`), bras le long du corps, jambes serrées (`JETPACK_ARM_L/R`, `JETPACK_LEG_L/R`, `JETPACK_HEAD`). Poses séparées des poses plongeon (if mode).
- **Jetpack** : réacteur dorsal (petit BoxMesh turquoise ~0.3x0.4x0.2) attaché au Torse, placé CÔTÉ CAMÉRA (+Z = dos visible), calé entre épaules et milieu du dos. `_setup_jetpack()`, visible jetpack only.
- **Flammes** : GPUParticles3D sous le réacteur, vers le bas, bouffées courtes (lifetime court), jaune `#F2C14E` -> orange `#E94F37`. Son propre matériau.
- **Fumée** : 2e GPUParticles3D, fine traînée grise semi-transparente en sillage. Son propre matériau.
- **Audio** : `jetpack.mp3` en boucle + whoosh du vent EN PLUS (les deux ensemble), volume jetpack modulé comme le whoosh. Démarré au début, arrêté à mort/pause.
- **Pas de skyline** en jetpack (ville retirée).
- **Boost powerup** : poussée inversée (vers le haut) en jetpack.

## Contenu

- **Shop 3 catégories (onglets)** :
  - **Skins** : Orange Brûlé (gratuit) + Turquoise 50, Jaune Moutarde 150, Crème Pâle 300, Bordeaux Lourd 450. + skins exclusifs défis (non vendus).
  - **Sang (trails)** : Aucun (gratuit) + Sang 40, Sang royal 80, Bile 110, Encre 140, Lait 160, Antigel 200, Sang d'or 250, Pétrole 280. Trail = GPUParticles3D avec SON PROPRE matériau. + trails exclusifs défis.
  - **Thèmes** : 1962 (gratuit) + Minuit 60, Océan 150, Coucher de soleil 200, Forêt 250, Monochrome 350. Changent wall_color + line_color (uniforms) + sky (ProceduralSky). Via `corridor_walls.gd`. Le thème pilote AUSSI la skyline (façade + brume) en modes chute.
  - Prix recalibrés : complétion totale ~3220 pièces (était 605). 1 item pas cher par catégorie pour gratification rapide. Items chers (Bordeaux/Mono/Pétrole) = objectifs long terme.
- **Pièces** : `coin.tscn` + CoinSpawner. 1 pièce tous les 14.4m (`SPAWN_INTERVAL_Y`), X aléatoire. Émission jaune. SEULEMENT en classique/jetpack (pas campagne).
- **Power-ups** (rares ~400-600m) : Bouclier (absorbe 1 choc), Ralenti (x0.5 ~3s), Aimant (attire pièces ~5s, EXCLU campagne), Boost (x2-3 + immunité ~2s, inversé en jetpack). Halo + rim blanc. HUD affiche effet + temps.

## Obstacles

- **Spawner** : `obstacle_spawner.gd`, `obstacle_scenes: Array[PackedScene]`, pioche PONDÉRÉE (le cube est dupliqué `CUBE_WEIGHT = 3` fois dans le pool -> sort 3x plus souvent).
- **Spawn** : `SPAWN_AHEAD = 60`, `SPAWN_INTERVAL_Y = 14.4`, X aléatoire `randf_range(-4.5, 4.5)`, Z=0. Spawn/despawn pilotés par `_dir` -> compatibles chute ET jetpack. `DESPAWN_BEHIND = 15`. Au despawn = obstacle esquivé (compté pour les stats via `register_obstacle_dodged`).
- **Matériau danger** : orange brûlé `#E94F37` émissif. La porte est en MARRON NOYER `#3D2C1E` (distincte de l'orange).
- **Mort** : collision = ragdoll via `obstacle_base.gd`.
- **Types actuels** (couloir 9 large, passage mini franchissable = 3 unités) :
  - **Cube** (base, le plus fréquent) : esquive latérale.
  - **Barre horizontale** : couvre ~6, passage ~3 d'un côté (aléatoire).
  - **Mur à trou** : couvre tout sauf ouverture ~3 (centre entre -3 et +3).
  - **Cube oscillant** (mobile) : glisse latéralement `sin(t*vitesse)*amplitude`, amplitude ~2.5. Oscillation X indépendante du sens chute/jetpack.
  - **Porte coulissante** (marron) : s'OUVRE À L'APPROCHE du joueur (distance abs au joueur < OPEN_DISTANCE -> openness vers 1). Ouverture ~5x rapide (franchissable à haute vitesse). Panneaux toujours mortels, passage central ouvert >=3. Marche chute ET jetpack (calcul en abs).
- **Laser : SUPPRIMÉ** (abandonné).
- **Pistes futures** : 2e lot mobiles (pendule, rouleau tournant...).

## Défis (missions)

- **Catalogue** : `missions_catalog.gd` (autoload **Missions**), constante `MISSIONS`. Extrait de cosmetics_catalog (qui ne les contient plus). Logique progression/claim dans `settings_manager.gd`. UI `missions_screen.gd`.
- **Structure défi** : `{id, name, desc, type, target, reward, [chain], [reward_skin/reward_trail]}`.
- **48 défis permanents** (30 paliers en 5 chaînes + 18 exploits) + 3 journaliers/jour seedés par date.
- **Chaînes de paliers** (`chain`) : distance classique, altitude jetpack, niveau campagne, pièces cumulées, parties jouées. L'UI n'affiche que le PROCHAIN palier non réclamé de chaque chaîne. Les exploits (sans chain) sont tous visibles.
- **Types de condition** reconnus dans `get_mission_progress` : campaign_level, infinite_distance, jetpack_distance, distance, coins_lifetime, total_games, obstacles_dodged, obstacles_run, coins_run, no_wall_time, powerups_used, deaths, ascetic, dual_distance (composé, min des 2), all_shop_skins/trails/themes, owned_skins/themes, trail_equipped.
- **Récompenses** : pièces + 8 cosmétiques EXCLUSIFS (price -1, non vendus au shop, débloqués par claim via `reward_skin`/`reward_trail`). Skins exclusifs : Chrome spatial, Or 1962, Vieux briscard, Funambule. Trails exclusifs : Comète, Confettis, Frôleur, Fantôme.
- Trail Confettis = rose uni (système trail monocouleur, pas de vrai multicolore sans gradient). Trail Fantôme = clair opaque (pas vaporeux sans baisser l'alpha). À peaufiner si voulu.

## Stats persistées (pour les défis)

Dans `settings_manager.gd` -> `settings.cfg`. Cumulées : `best_infinite_distance`, `best_jetpack_distance`, `coins_lifetime` (ne baisse jamais), `total_games`, `games_infinite/jetpack/campaign`, `total_deaths`, `total_obstacles_dodged`, `best_obstacles_run`, `best_coins_run`, `best_no_wall_time`, `powerups_used` (set), `ascetic_done`. Transient (par run) : `coins_this_run`, `obstacles_dodged_run`, `run_active`.
Hooks (un seul point chacun) : `register_run_start` (player._ready), `register_obstacle_dodged` (despawn obstacle, gated run_active), `register_powerup_used` (collect_powerup), `register_death` + `finalize_run` (_trigger_ragdoll / niveau réussi), `add_coin`, reset du streak sans-mur au hit de mur (player).
`best_*_run` = MEILLEURS scores par partie (comparés/sauvés au finalize, pas cumuls).

## UI / Design (glassmorphism)

- **Police Poppins** (`assets/fonts/Poppins-*.ttf`). Thème global `resources/ui/main_theme.tres` via `project.godot gui/theme/custom`.
- **Système verre** : autoload `Glass` (glass_manager.gd) + `glass_blur.gd` (GlassBlur, backdrop-blur réutilisable) + `UIAnimations.glass_card_style()`. Boutons : fond translucide + blur du décor derrière + arrondi UNIFORME 20, PAS d'ombre, PAS de contour. Toggle `Glass.USE_REAL_BLUR` (repli translucide si désactivé).
- **Blur** : vrai backdrop-blur via GlassBlur (ColorRect + shader `glass_blur.gdshader` + BackBufferCopy, show_behind_parent). Le masque arrondi suit le corner_radius RÉEL de l'élément, converti px GUI -> px écran via l'échelle canvas (stretch canvas_items -> sur mobile le canvas est mis à l'échelle ; sans conversion, coins anguleux). `apply_top_safe_area` géré centralement.
- **Titres** (variation `Title`) : crème/blanc, Poppins Bold. **Sous-titres** (variation `Subtitle`, jaune moutarde) : ex en-têtes VOLUME/AUTRE des réglages.
- **Sliders** (réglages) : style HSlider dans le thème (piste crème translucide, remplissage turquoise) pour rester lisibles sur le verre.
- **Tous les écrans** ont le verre : menu, shop, défis, game over, fin de niveau, pause, réglages. Les pop-ups en jeu (pause, game over, fin niveau) floutent le décor du jeu derrière (Backdrop GlassBlur plein écran + scrim léger 0.4).
- **Shop & Défis** : ÉCRANS PLEINS (même fond que le menu + blur), pas des pop-ups. Scroll tactile mobile OK (helper `allow_scroll_through` : Control non-boutons en MOUSE_FILTER_PASS pour laisser le drag remonter au ScrollContainer).
- **Menu** : entrées Niveau/Classique/Jetpack (+ Shop, Défis), conditionnelles (grisé + condition DANS le bouton si verrouillé). Titre HYPERDIVE animé. Engrenage en haut à droite (icône réduite ~40px, fond verre/blur inchangé plus grand autour). Boutons remontés (marge basse petits écrans).
- **Safe area** : `UIAnimations.apply_top_safe_area()` convertit `DisplayServer.get_display_safe_area()` (px physiques) en px GUI. Appliqué à l'engrenage + titre (menu) et au HUD. Gère encoche/poinçon/barre statut sur tous les téléphones.
- **Animations** : ouverture panneaux scale 0.92->1.0 + alpha sur 0.2s TRANS_BACK ; clic boutons scale 0.96 (+ haptique 20ms) via `UIAnimations.wire_button`.
- **Transitions de scène** : autoload `Transition` (CanvasLayer ~100 + ColorRect noir), `Transition.change_scene(path)` = fondu aller/retour.
- **Icône pièce** : `assets/ui/coin_icon.svg`. **Engrenage** : `assets/ui/gear_icon.svg`.
- **HUD en jeu** : bouton PAUSE en haut à GAUCHE (verre). Infos en haut à DROITE empilées (info principale du mode au-dessus — score "X m" en classique/jetpack, temps "Xs" en campagne — pièces en dessous, masquées en campagne). Fond verre/blur : LARGEUR FIXE (dimensionnée pour 99999), HAUTEUR ADAPTATIVE (1 ligne campagne, 2 lignes classique). Tout sous la safe area.

## Audio / Haptique

- Autoload `Audio` (AudioManagerClass, `scenes/autoload/audio_manager.tscn`). Bus Master/Music/SFX. Pool 6 SFX.
- Musique gameplay (`assets/audio/music/gameplay_loop.mp3`). Whoosh (`fall_whoosh.mp3`) modulé par vitesse via `set_whoosh_intensity`, variation aléatoire du volume.
- Jetpack (`assets/audio/music/jetpack.mp3`) : boucle en jetpack, EN PLUS du whoosh, volume modulé comme le whoosh. Loop activé sur l'import. PAS sur le bus Music. Stop à mort/pause.
- SFX `assets/audio/sfx/` : coin_pickup, obstacle_hit, game_over, ui_click. API : play_coin/hit/game_over/ui_click, play_music/duck/unduck, play/stop jetpack.
- **Haptique** : `Settings.vibrate(ms)` centralisé. Garde-fous : `vibration_enabled` (option réglages, persistée) + `OS.get_name() in {Android, iOS}` (PAS has_feature("mobile") qui court-circuitait sur l'APK). Boutons 20ms (via wire_button), mort 120ms (via _trigger_ragdoll). Permission VIBRATE requise dans l'export.
- Volumes persistés via Settings, AudioServer set_bus_volume_db.

## Décor / atmosphère

- **Façade fenêtres** (shader `wall_pattern.gdshader`, grille allumées/éteintes pseudo-aléatoires). Atténuées (win_mix ~0.50). wall_color assombrie x0.8.
- **Boucle menu fluide** : `LOOP_DISTANCE` = multiple EXACT de la période du motif (sinon saut au bouclage).
- **Skyline** (`city_skyline.gd`, partagé jeu+menu) : grille d'immeubles 3D + shader fenêtres, seed 1962. Modes chute : ancrée caméra, `pos=(0,-72,-90)`, `rot=(-45,0,0)` (plongée). PAS de skyline en jetpack. Couleur pilotée par le thème : façade `(theme*0.5).lerp(gris sombre,0.3)`, brume `theme.lerp(noir,0.7)` (sombre). Brume dans le shader : fondu selon distance caméra (`fog_start=55, fog_end=110`, plafonné ~0.5).
- **Hiérarchie visuelle** : décor terne (murs/skyline/fenêtres atténués) vs gameplay saturé (obstacles orange émissifs, pièces jaunes). Lointain toujours plus terne que proche.
- **Motes/poussières** dans le couloir (GPUParticles, faible opacité). Retirées de la piste AU MENU.
- **Nuages + étoiles** dans l'ouverture du haut (nuages -50% opacité, étoiles /2). En jetpack : nuages en fond gauche derrière les murs, opacité /2. Ciel + nuages étendus en jetpack (caméra vers le haut).

## Architecture / fichiers clés

- **Racine** : `CLAUDE.md`, `icon.svg`, `project.godot`, `export_presets.cfg`
- **Autoloads** : `Settings` (settings_manager.gd), `Catalog` (cosmetics_catalog.gd), `Missions` (missions_catalog.gd), `Audio` (audio_manager.tscn), `Transition` (scene_transition.tscn), `Glass` (glass_manager.gd)
- **Player** : `scripts/player/player.gd` (PlayerController : poses chute+jetpack, `_setup_jetpack`, hooks stats), `scenes/player/{player,ragdoll}.tscn`
- **Gameplay** : `scripts/gameplay/{follow_camera, obstacle_spawner, coin_spawner, corridor_walls, obstacle_base, obstacle_door, obstacle_oscillating, powerup_spawner}.gd` + `scripts/game/main_game.gd`
- **Utils** : `scripts/utils/{city_skyline, ui_animations}.gd` (UIAnimations : glass_card_style, wire_button, allow_scroll_through, apply_top_safe_area, top_safe_inset)
- **UI** : `scripts/ui/{game_hud, shop_screen, game_over_screen, main_menu, menu_camera, settings_screen, pause_screen, level_screen, missions_screen, glass_blur}.gd` + `glass_manager.gd`, scènes `scenes/ui/`
- **Collectibles** : `scripts/collectibles/{coin, powerup}.gd`
- **Scènes** : `scenes/game/main_game.tscn`, `scenes/ui/main_menu.tscn`, `scenes/obstacles/` (cube, barre, mur, oscillant, porte)
- **Shaders** : `assets/shaders/{halftone, wall_pattern, glass_blur}.gdshader` + shader skyline (dans city_skyline.gd)
- **Thème** : `resources/ui/main_theme.tres`. **Physique murs** : `resources/physics/frictionless.tres`
- **Audio** : `assets/audio/{music (gameplay_loop, jetpack), sfx}/`. **UI assets** : `assets/ui/{gear_icon, coin_icon}.svg`
- **APK** : buildé vers `C:\Users\Hulku\Desktop\autre\dev\Hyperdive\apk\Hyperdive.apk`

## Layers / conventions

- **CanvasLayer** : 0 post-process, 1 HUD, 5 pause, 6 game over, 7 shop, 8 settings, ~100 Transition
- **Physique** : interpolation 120Hz. Caméra `physics_interpolation_mode = OFF` (sinon double-interpolation = vibration). Suivi caméra Y rigide. La caméra suit `get_global_transform_interpolated().origin.y` du perso (pas global_position brute, sinon jitter entre la caméra non-interpolée et le perso rendu interpolé).
- **Mobile** : Portrait verrouillé, stretch aspect "expand"/canvas_items, max_fps=0 + V-Sync + Frame Pacing Swappy + Interpolation Physique -> 120Hz.
- **Signe dir** : source unique `Settings.get_fall_dir()` (+1 jetpack, -1 sinon). Ne PAS hardcoder un sens.

## Pièges Godot rencontrés (à connaître)

- `@export` NodePath fragile -> pattern par groupe (`add_to_group` + `get_first_node_in_group`).
- Modifs UI Godot fiables ; .tscn/project.godot par script peuvent diverger (orientation Android -> via l'UI).
- Désinstaller/réinstaller l'APK après changement d'orientation OU de permission (manifest changé).
- `Transform3D` row-major dans .tscn -> préférer `rotation_degrees`.
- `visible=true` sauvé par accident sur panels modaux = boucle au démarrage.
- Interpolation physique 120Hz -> caméra `physics_interpolation_mode=OFF` + suivre `get_global_transform_interpolated()` du perso (sinon jitter vertical).
- RigidBody enfants ignorent parfois la rotation root -> rotation par-partie (ragdoll).
- GPUParticles : changer `amount` redémarre. Trail/flammes/fumée = CHACUN son matériau.
- Ragdoll spawn : `global_rotation`, PAS `global_transform`.
- Objet ancré caméra (skyline) : position locale suit la rotation caméra -> recalculer par mode. L'angle RELATIF objet/caméra compte (skyline chute = -10° : caméra -35°, ville -45°).
- Dos vs ventre : en jetpack on voit le DOS (caméra derrière) -> réacteur dorsal CÔTÉ caméra (+Z).
- Boucle défilement : LOOP_DISTANCE multiple exact de la période, sinon saut.
- Mur à trou / barre / porte : passage mini 3 unités. Porte : ouverture rapide + déclenchée tôt pour rester franchissable à haute vitesse.
- Audio boucle : activer `loop` sur l'import du .mp3 ; stop à mort/pause ; pas sur bus Music.
- Rampe vitesse : toujours move_toward (lissage), jamais saut sec au palier.
- **Glass/blur sur mobile** : le corner_radius est en px GUI, le masque shader en px écran -> convertir via l'échelle canvas (stretch canvas_items met le canvas à l'échelle), sinon coins anguleux. Masque suit le rayon RÉEL de chaque élément.
- **Permission VIBRATE** : l'éditeur Godot remet `permissions/vibrate=false` dans export_presets.cfg à chaque ouverture de l'export. Pour figer : cocher Projet -> Exporter -> Android -> Permissions -> Vibrate dans l'UI. Sinon revérifier avant chaque build lancé après session éditeur.
- **Haptique garde-fou** : utiliser `OS.get_name() in {Android,iOS}`, PAS `has_feature("mobile")` (court-circuitait sur l'APK).
- **Scroll tactile** : les Control non-boutons en mouse_filter STOP (défaut) avalent le drag -> mettre PASS (helper allow_scroll_through) pour que le ScrollContainer reçoive le glissement.
- **Campagne sans pièces** : CoinSpawner désactivé -> les défis "pièces" vivent sur le mode classique, pas campagne.
- **PanelContainer adaptatif** : se dimensionne sur son contenu. Pour largeur fixe + hauteur adaptative : custom_minimum_size.x fixe + pas de hauteur forcée. Le GlassBlur doit suivre la taille réelle (recalcul si la hauteur change entre modes).

## Mes préférences et ton du jeu

- Itère vite : je teste sur mobile, je décris ou je partage des captures.
- Prompts concis, ciblés, avec le pourquoi.
- Ton arcade tendu : 1 vie, plongeon dramatique, ragdoll satisfaisant.
- Ton playful : sang/liquides drôles dans le shop (Bile, Antigel, Lait, etc.), noms de défis fun.
- Bugs visuels difficiles -> mode debug systématique (exagérer/colorer pour confirmer, puis doser).
- Gros morceaux -> rapport + proposition avant de coder.

## Pistes possibles (notées pour plus tard)

- Trails Confettis (multicolore via gradient) et Fantôme (vaporeux via alpha) à peaufiner.
- 2e lot d'obstacles (pendule, rouleau tournant...).
- Retirer le log debug `[haptic]` (confirmer stable d'abord).
- Distribution : itch.io (gratuit, upload APK, ~10 min) ou Play Store (25$, fiche, signature).
- Équilibrage 1 vie si trop dur (élargir couloir, réduire densité, ralentir).
- Tester sur vrai téléphone (particules + audio + haptique).