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

Jeu de chute libre Android portrait, style Falling Fred mais avec une DA forte, doublé d'une **campagne narrative de 40 chapitres** (l'histoire de Hyperdive).

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
- **Parachute (victoire campagne)** : tween redresse le Character debout (~0.3s), ralenti, déclenche l'écran de victoire de chapitre (`win_parachute()`).
- **Ragdoll de mort** : spawn `global_rotation = $Character.global_rotation` (PAS global_transform). En jetpack : restaure gravity_scale=1 + vitesse vers le bas (on RETOMBE). Le ragdoll hérite du MÊME matériau que le perso vivant (skin équipé : metallic/roughness/aniso/émission, pas juste l'albedo).
- **Retour haptique** : vibration courte au clic des boutons (20ms), marquée à la mort (120ms), graduée au ramassage de power-up (35-70ms). Centralisé via `Settings.vibrate(ms)`. Option ON/OFF dans réglages. Voir section Audio/Haptique.

## Modes

Quatre contextes de jeu. `Settings.active_mode` ("infinite"/"jetpack") pilote le SENS de chute via `get_fall_dir()` ; deux garde-fous globaux (`Story.active`, `Coop.active`) se superposent en surcouche au gameplay solo pour la campagne et le tournoi.

- **Campagne** (bouton HISTOIRE au menu) : campagne NARRATIVE de 40 chapitres. Ouvre la CARTE de l'histoire (pas un lancement direct). Détaillée ci-dessous. Remplace l'ancien mode "NIVEAU X" chronométré (supprimé).
- **Infini** ("CLASSIQUE" au menu) : distance/score. Vitesse +10% par 1000m FLUIDEMENT (move_toward, rampe ~10s), `vitesse_base x 1.1^floor(distance/1000)`. **Débloqué à la fin du chapitre 1 de campagne** (flag `infinite_unlocked`, posé dans `Story.complete_chapter`).
- **Jetpack** (variante infinie) : on MONTE. **Débloqué à la fin du chapitre 20** (`jetpack_unlocked`, posé dans `Story.complete_chapter`). Détails ci-dessous.
- **Tournoi** (autoload `Coop`, pass-and-play local 2-5 joueurs) : variante multijoueur des modes infini/jetpack. Détaillé ci-dessous.

NB interne : `active_mode` reste "infinite"/"jetpack". Les libellés menu (HISTOIRE/CLASSIQUE/JETPACK/TOURNOI) sont juste l'affichage. Un mode verrouillé affiche la condition DANS le bouton grisé.

### Mode Jetpack — détail

Variante du mode infini (branche `active_mode != "campaign"` de main_game). Inversion centralisée par `Settings.get_fall_dir()` : +1 en jetpack (on monte), -1 sinon.

- **Mécanique** : `gravity_scale = 0`, poussée constante `linear_velocity.y = +_current_max_speed`. Score = `abs(global_position.y)` = altitude.
- **Rampe vitesse** : +10% tous les 500m (`SPEED_RAMP_STEP_JETPACK = 500`), même lissage move_toward que l'infini.
- **Caméra** : pitch vers le HAUT (~+35°, miroir chute), perso en bas. On voit le DOS du perso.
- **Obstacles + pièces** : mêmes objets, spawn en haut (via dir), descendent. Despawn dir-relatif.
- **Pose fusée** : debout penché ~12° avant (`JETPACK_CHARACTER_ROT`), bras le long du corps, jambes serrées. Poses séparées des poses plongeon (if mode).
- **Jetpack** : réacteur dorsal (petit BoxMesh turquoise) attaché au Torse, placé CÔTÉ CAMÉRA (+Z = dos visible). `_setup_jetpack()`, visible jetpack only.
- **Flammes + fumée** : 2 GPUParticles3D sous le réacteur (chacun son matériau) : flammes jaune->orange vers le bas, fine traînée grise en sillage.
- **Audio** : `jetpack.mp3` en boucle + whoosh du vent EN PLUS, volume modulé comme le whoosh. Stop à mort/pause.
- **Pas de skyline** en jetpack (ville retirée).
- **Boost powerup** : poussée inversée (vers le haut) en jetpack.

### Mode Tournoi — détail (autoload `Coop`)

Pass-and-play LOCAL : 2 à 5 joueurs se passent le téléphone. `Coop.active` = garde-fou global (surcouche sur le solo : force la couleur du joueur, coupe les pièces, court-circuite TOUS les hooks de stats perso, redirige la mort vers le flux coop). État transient, non persisté. Toute la logique (scores, barème, classements, départage) vit dans `coop_session.gd` ; les écrans ne font que lire/appeler son API ; tout le routage de scènes passe par cet autoload.

- **Config** (`coop_config_screen`) : nombre de joueurs (2-5), pseudos, nombre de manches (1-10), mode (**Mix** = tiré aléatoirement par manche / **Classique** / **Jetpack**). Les modes Mix sont pré-tirés au `start_session`.
- **Couleurs joueurs** (5 teintes distinctes) : J1 orange `#E94F37`, J2 turquoise `#3CAEA3`, J3 jaune moutarde `#F2C14E`, J4 rose `#EC4899`, J5 vert `#4CAF50`. Forcent la couleur du perso ce tour-là.
- **Ordre de jeu** : MÉLANGÉ à chaque manche (un round peut être J3→J1→J2, le suivant J2→J3→J1). N'affecte pas le scoring, seulement l'ordre de passation.
- **Pass-and-play** : passation (`coop_passation`) entre chaque joueur (qui joue + son mode + scores déjà posés). La mort = fin du tour → `Coop.end_turn(score)`.
- **Barème de points** par PLACE façon Mario Kart : `PLACE_POINTS = [10, 7, 5, 3, 1]`. Ex-æquo en "competition ranking" (même score = même place = mêmes points).
- **Classement de manche** (`coop_round_result`) après que tous ont joué. **Classement général** trié par points (départage : meilleur score unique → manches gagnées → index).
- **HUD live coop** : lignes par joueur (nom + score, couleur joueur), couronne SVG (`crown_icon.svg`) devant le leader, mise à jour temps réel (SFX dépassement / prise de tête). Le joueur courant joue, les autres sont des repères de score à battre.
- **Bonus "meilleur score du tournoi"** : +1 point au(x) joueur(s) au plus haut score individuel toutes manches confondues. Calculé en fin de dernière manche, AVANT le départage (peut changer qui est 1er).
- **Round final de départage** (`coop_tiebreak`) : si égalité de POINTS à la 1re place après la dernière manche, round final entre les seuls ex-æquo, mode tiré au hasard, **vitesse +10% tous les 100m** (mort subite rapide). Re-égalité → on relance entre les nouveaux ex-æquo. +1 point bonus au vainqueur du départage (cumulable avec le bonus meilleur score → +2 max).
- **Écran final** (`coop_final`) : podium / classement, couronne au vainqueur, REJOUER (même config, modes Mix re-tirés).
- **Vitesse coop** : rampe dédiée plus agressive, **+5% tous les 150m** (`SPEED_RAMP_STEP_COOP = 150`, `FACTOR_COOP = 1.05`) → manches courtes et nerveuses.
- **Setup en jeu** : pièces OFF + power-ups sans aimant (`PowerupSpawner.set_campaign_mode(true)`) + `GameHUD.set_coop_mode()`. PAS d'objectif : la manche se joue jusqu'à la mort.
- **Défis coop** existants (catégorie tournoi).

### Campagne narrative — détail (autoload `Story`)

L'histoire de Hyperdive en **40 chapitres** (`story.gd`, const `CHAPTERS`). Chaque chapitre : `{n, title, text, image, type}`. `type` = **"story"** (narration : lire pour avancer) ou **"play"** (jouable : un niveau à réussir). Répartition : 19 narration + 21 jouables (14 chute, 7 jetpack). Textes définitifs en place ; les IMAGES (`assets/story/ch01-40.png`) ne sont PAS encore présentes → placeholder dégradé élégant par chapitre (jamais cassé).

- **Progression** : `Settings.story_chapter` (persisté), débloquage LINÉAIRE. `story_chapter` = plus haut chapitre débloqué = chapitre COURANT. `< courant` = complété, `> courant` = verrouillé.
- **`Story.active`** : garde-fou global (miroir de `Coop.active`) → court-circuite les records perso. SEULE exception : la récompense PIÈCES de `complete_chapter` (NON gatée → monnaie réelle du shop). Jouer un chapitre ne pollue jamais best_distance/best_jetpack/etc.
- **Chapitre jouable** : champs en plus → `mode` ("fall"/"jetpack"), `objective {kind, value}`, `text_when` ("before" = lire avant de jouer / "after" = lire après la réussite, en outro).
- **Objectifs** : `distance` (atteindre value m), `survive` (survivre value s), `dodge` (esquiver value obstacles via `Story.dodged`/`notify_dodge`), `descent` (OUVERTURE ch.1 : MOURIR = réussir — **réservé étape 4, pas encore implémenté**, le `_process` du driver l'ignore).
- **Thème imposé par chapitre** (arc visuel narratif) : champ `theme` sur CHAQUE chapitre. `Story.current_theme_id()` (thème du chapitre actif, "" sinon) PRIME sur `Settings.equipped_theme` EN JEU : `corridor_walls._apply_theme` (gaté `not _is_menu`) + skyline (3e param de `attach_to`, passé par main_game). Override TRANSIENT : `equipped_theme` jamais écrit, le SKIN reste celui du joueur. CARTE + menu = thème ÉQUIPÉ (hub). Lecteur : placeholder teinté par le thème du chapitre (sky_top→sky_horizon assombris). Cycle jour/nuit FIGÉ à phase 0 (= thème pur) pendant un chapitre. Thèmes utilisés : 5 du shop (sunset, minuit, mono, ocean, gold) + 4 dédiés campagne (`CAMPAIGN_THEMES`) : Simulation (cyan numérique sur noir), Sang & Verre (rouge-noir oppressant), Aube (rose-orangé doux), Trouble (gris-violacé désaturé, finale ch.36-40).
- **CARTE** (`campaign_screen.gd`) : ÉCRAN PLEIN en verre, chemin vertical en zig-zag entre les **2 tours de Vertex** (calque de fond, shader `tower_windows.gdshader`, teinté par le thème), 40 nœuds construits en code. Nœud courant glow + titre, complétés badge ✓, verrouillés cadenas (`lock_icon.svg`). Couleur nœud = type (crème narration, turquoise chute, jaune jetpack). Pivot ↓↑ au ch.20 (inversion). Bouton "Archives" (galerie) + retour. Ouverture centrée sur le chapitre courant.
- **Lecteur immersif** (`chapter_reader.gd`) : image plein fond (ou placeholder), voiles dégradés, titre + texte scrollable, fondu cinématique. Contextes : `story` (CONTINUER = complète + retour carte), `play_before` (JOUER = lance le niveau), `outro` (texte après victoire, lecture seule), `gallery` (relecture ◀▶ parmi les chapitres débloqués).
- **Galerie "Archives"** : relecture de tous les chapitres débloqués depuis la carte.
- **Lancement d'un chapitre jouable** : `campaign_screen._launch_chapter` → `Story.start_chapter(n)` (pose `active=true`, `active_chapter`, `dodged=0`, `Settings.active_mode = "jetpack"|"infinite"`) → `Transition.change_scene(main_game)`. L'objectif passe par Story (`Story.current_objective()` lu par main_game).
- **Driver d'objectif** (`main_game.gd`, quand `Story.active`) : `_process` lit l'objectif, calcule la progression (distance/survie/esquive), pousse le HUD (`update_story_progress` → "320 / 800 m", "12 / 24 s", "8 / 15 esquives") et déclenche la réussite à `cur >= value`. Pièces OFF + power-ups sans aimant (même setup que coop).
- **Victoire** (`chapter_end_screen.gd`, état "victory") : `win_parachute()` → `Story.complete_chapter(n)` → écran verre "CHAPITRE RÉUSSI" + pièces gagnées + CONTINUER. Flux : si `text_when=="after"` → pose `Story.pending_outro` → retour menu lit l'outro dans le lecteur puis carte ; sinon retour carte direct.
- **Échec doux** (`chapter_end_screen`, état "failure") : la mort en campagne (`player.gd`, branche `Story.active`) affiche "TU ES TOMBÉ" + RÉESSAYER (reload même chapitre) + RETOUR CAMPAGNE. Retry ILLIMITÉ, aucune stat, aucune perte, aucun record. Le chapitre n'est complété QUE sur objectif atteint (en jeu), jamais à l'échec.
- **`Story.complete_chapter(n)`** : crédite les pièces (NON gaté), gère les déblocages de mode (**CLASSIQUE au ch.1, JETPACK au ch.20**), avance `story_chapter` d'un cran. Récompense : 15 pièces (narration) ou `40 + n*5` (jouable, croissant).
- **Cohérence modes** : seuls les chapitres jetpack sont 21/23/26/28/34/38 (tous ≥21, après le déblocage ch.20). Le ch.14 a été passé en CHUTE (était un risque d'incohérence narrative : jetpack avant déblocage).

## Contenu

- **Shop "Cosmétique" (3 catégories, onglets)** :
  - **Skins** : Orange Brûlé (gratuit) + Turquoise 50, Crème Pâle 300, Bordeaux Lourd 450, **Or 10000** (achetable haut de gamme, métal brossé doré : metallic + anisotropie + émission). + skins exclusifs défis (price -1, non vendus, débloqués par claim) : **Acier** (id `chrome`, métal sombre anthracite), Vieux briscard, Funambule, **Chrome poli** (id `steel`, métal clair réfléchissant).
  - **Sang (trails)** : Aucun (gratuit) + Sang 40, Sang royal 80, Bile 110, Encre 140, Lait 160, Antigel 200, Pétrole 280, **Sillage d'or 10000** (achetable, ramp HDR doré scintillant). + trails exclusifs défis : Comète, **Sillage chromé** (id `steel`, ramp HDR chrome), Confettis (ramp arc-en-ciel multicolore réel), Frôleur, Fantôme (bleu pâle + `alpha` bas = vaporeux). Trail = GPUParticles3D avec SON PROPRE matériau ; les trails à `ramp` utilisent un gradient de couleur le long de la durée de vie.
  - **Thèmes** : 1962 (gratuit) + Minuit 60, Océan 150, Coucher de soleil 200, Forêt 250, Monochrome 350, **Âge d'or 10000** (achetable, ambiance dorée luxe). + **Acier** (id `steel`, exclusif défi). Changent wall_color + line_color + sky (sky_top/sky_horizon). Via `corridor_walls.gd`. Le thème pilote AUSSI la skyline et les tours de la carte campagne. + 4 thèmes CAMPAGNE dans `Catalog.CAMPAIGN_THEMES` (tableau séparé : jamais vendus/équipables, invisibles au shop, au défi Décorateur et au debug unlock ; résolus par `get_theme`) : Simulation, Sang & Verre, Aube, Trouble — imposés par chapitre (voir campagne).
  - Cadenas SVG (`lock_icon.svg`) sur les exclusifs encore verrouillés. 3 items "Or/Âge d'or/Sillage d'or" à 10000 = objectifs très long terme.
- **Pièces** : `coin.tscn` + CoinSpawner. 1 pièce tous les 14.4m, X aléatoire. Émission jaune. SEULEMENT en classique/jetpack solo (pas campagne, pas coop).
- **Power-ups** — voir section dédiée ci-dessous.

## Power-ups (refondus)

Spawn rares (`powerup_spawner.gd`, intervalle 400-600m), tirage PONDÉRÉ (`WEIGHTS`). 5 types. En campagne/coop : pool sans aimant (`TYPES_CAMPAIGN`). HUD = pastilles + compte à rebours.

- **Bouclier** (turquoise) : absorbe 1 choc. Aura = **bulle Fresnel** (shader `shield_bubble.gdshader`, transparente au centre, lumineuse aux bords). Au choc : éclatement turquoise (`_shield_shatter`, SAUVEGARDE jamais rouge) + **détruit l'obstacle** percuté (`_destroy_obstacle_shield`, burst coloré).
- **Ralenti** (sablier bleu nuit + accents crème, halo crème) : ralentit le temps + vignette ~3s.
- **Aimant** (fer à cheval jaune) : attire les pièces ~5s. EXCLU campagne/coop (pas de pièces).
- **Boost** (flèche orange, `BOOST_DURATION = 4s`) : invincibilité + **PULVÉRISE** les obstacles touchés (par forme touchée via `_on_body_shape_entered`, burst + son throttlé + shake). Inversé en jetpack. Aura Fresnel orange (signale l'immunité). + **filet d'invincibilité 0,5s APRÈS le boost** (`BOOST_GRACE_DURATION`, évite la mort injuste à la reprise, l'aura s'estompe).
- **Méga-boost** (flèche/halo magenta `#B026FF`, JACKPOT très rare ~2,5%) : même mécanique que le boost mais **durée 2× (8s)**, FX amplifiés (traînée plus dense, burst de ramassage/pulvérisation plus spectaculaires, halo plus gros, vibration 70ms). Réutilise le SFX du boost.
- **Juice ramassage** : SFX dédié + vibration + flash plein écran (`post_process.flash`) + shake léger + "pop" de l'objet + burst de particules. Ressources de burst PARTAGÉES par type (statiques) → pas de recompilation de shader = pas de micro-freeze au ramassage.

## Obstacles

- **Spawner** : `obstacle_spawner.gd`, `obstacle_scenes: Array[PackedScene]`, pioche PONDÉRÉE (le cube est dupliqué `CUBE_WEIGHT = 3` fois dans le pool -> sort 3x plus souvent).
- **Spawn** : `SPAWN_AHEAD = 60`, `SPAWN_INTERVAL_Y = 14.4`, X aléatoire `randf_range(-4.5, 4.5)`, Z=0. Spawn/despawn pilotés par `_dir` -> compatibles chute ET jetpack. `DESPAWN_BEHIND = 15`. Au despawn = obstacle esquivé (compté via `Settings.register_obstacle_dodged` + `Story.notify_dodge`).
- **Matériau danger** : orange brûlé `#E94F37` émissif. La porte est en MARRON NOYER `#3D2C1E`.
- **Mort** : collision = ragdoll via `obstacle_base.gd` (sauf invincibilité boost/bouclier = pulvérisation).
- **Types actuels** (couloir 9 large, passage mini franchissable = 3 unités) :
  - **Cube** (base, le plus fréquent) : esquive latérale.
  - **Barre horizontale** : couvre ~6, passage ~3 d'un côté (aléatoire).
  - **Mur à trou** : couvre tout sauf ouverture ~3 (centre entre -3 et +3).
  - **Cube oscillant** (mobile) : glisse latéralement `sin(t*vitesse)*amplitude`, amplitude ~2.5.
  - **Porte coulissante** (marron) : s'OUVRE À L'APPROCHE du joueur (ouverture ~5x rapide, déclenchée tôt → franchissable à haute vitesse). Panneaux toujours mortels, passage central >=3. Marche chute ET jetpack (calcul en abs).
- **Zones rares d'obstacles : RETIRÉES.** `special_scenes` est VIDE → comportement 100% normal (le gate `not special_scenes.is_empty()` court-circuite tout). Les obstacles **zigzag et spirale ont été abandonnés**. Le tableau + la logique de zone restent en place pour réintroduire facilement plus tard, mais rien ne se déclenche aujourd'hui.
- **Laser : SUPPRIMÉ** (abandonné).

## Défis (missions)

- **Catalogue** : `missions_catalog.gd` (autoload **Missions**), constante `MISSIONS`. Logique progression/claim dans `settings_manager.gd`. UI `missions_screen.gd`.
- **Structure défi** : `{id, name, desc, type, target, reward, [chain], [reward_skin/reward_trail]}`.
- **Défis permanents** (paliers en chaînes + exploits) + 3 journaliers/jour seedés par date.
- **Chaînes de paliers** (`chain`) : distance classique, altitude jetpack, niveau campagne (réadapté à `story_chapter`), pièces cumulées, parties jouées. L'UI n'affiche que le PROCHAIN palier non réclamé de chaque chaîne. Exploits (sans chain) tous visibles. + défis coop/tournoi.
- **Types de condition** reconnus dans `get_mission_progress` : campaign_level (= `story_chapter`), infinite_distance, jetpack_distance, distance, coins_lifetime, total_games, obstacles_dodged, obstacles_run, coins_run, no_wall_time, powerups_used, deaths, ascetic, dual_distance, all_shop_skins/trails/themes, owned_skins/themes, trail_equipped, + conditions coop.
- **Récompenses** : pièces + cosmétiques EXCLUSIFS (price -1, débloqués par claim via `reward_skin`/`reward_trail`). Skins exclusifs : Acier (id chrome), Vieux briscard, Funambule, Chrome poli (id steel). Trails exclusifs : Comète, Sillage chromé (id steel), Confettis, Frôleur, Fantôme. + thème exclusif Acier (id steel).

## Stats persistées (pour les défis)

Dans `settings_manager.gd` -> `settings.cfg`. Cumulées : `best_infinite_distance`, `best_jetpack_distance`, `coins_lifetime`, `total_games`, `games_infinite/jetpack/campaign`, `total_deaths`, `total_obstacles_dodged`, `best_obstacles_run`, `best_coins_run`, `best_no_wall_time`, `powerups_used` (set), `ascetic_done`, `story_chapter`. Transient (par run) : `coins_this_run`, `obstacles_dodged_run`, `run_active`.
Hooks (un seul point chacun) : `register_run_start`, `register_obstacle_dodged` (despawn, gated run_active), `register_powerup_used`, `register_death` + `finalize_run`, `add_coin`, reset du streak sans-mur au hit de mur.
**Gates** : `Story.active` ET `Coop.active` court-circuitent les hooks de stats perso (records solo intouchés). Seule la récompense pièces de `Story.complete_chapter` passe outre.
**Micro-freeze ramassage corrigé** : la sauvegarde des stats se fait en FIN de partie (`finalize_run`), pas à chaque pièce (évitait un `save_settings` disque à chaque ramassage).

## UI / Design (glassmorphism)

- **Police Poppins** (`assets/fonts/Poppins-*.ttf`). Thème global `resources/ui/main_theme.tres` via `project.godot gui/theme/custom`.
- **Système verre** : autoload `Glass` (glass_manager.gd) + `glass_blur.gd` (GlassBlur, backdrop-blur réutilisable) + `UIAnimations.glass_card_style()`. Boutons : fond translucide + blur du décor + arrondi UNIFORME 20, PAS d'ombre, PAS de contour. Toggle `Glass.USE_REAL_BLUR`.
- **Blur** : vrai backdrop-blur via GlassBlur (ColorRect + shader `glass_blur.gdshader` + BackBufferCopy). Masque arrondi converti px GUI -> px écran via l'échelle canvas. `apply_top_safe_area` central.
- **Titres** (variation `Title`) crème/blanc Poppins Bold. **Sous-titres** (variation `Subtitle`, jaune moutarde).
- **Sliders** (réglages) : style HSlider du thème (piste crème, remplissage turquoise).
- **Tous les écrans** ont le verre : menu, shop, défis, game over, victoire/échec chapitre, pause, réglages, carte campagne, lecteur, écrans tournoi. Les pop-ups en jeu floutent le décor (Backdrop GlassBlur plein écran + scrim).
- **Fonds des écrans pleins** : même décor que le menu FLOUTÉ + masquage de l'UI menu (PAS de fond opaque). Panneaux assombris MODÉRÉMENT, boutons clairs.
- **Shop & Défis & Carte campagne** : ÉCRANS PLEINS, pas des pop-ups. Scroll tactile OK (`allow_scroll_through`).
- **Menu** : entrées HISTOIRE/CLASSIQUE/JETPACK/TOURNOI (+ Cosmétique, Défis), conditionnelles (grisé + condition si verrouillé). **Deux records affichés** : Classique (`best_infinite_distance`) + Jetpack (`best_jetpack_distance`) + pièces. Titre HYPERDIVE animé. Engrenage en haut à droite (verre/blur).
- **`format_number`** (`ui_animations.gd`) : séparateur de milliers en espace INSÉCABLE (U+00A0) — `1561161` → "1 561 161". Affichage seulement, la logique garde des ints.
- **Safe area** : `UIAnimations.apply_top_safe_area()` convertit `get_display_safe_area` (px physiques) en px GUI.
- **Animations** : ouverture scale 0.92->1.0 + alpha 0.2s TRANS_BACK ; clic scale 0.96 (+ haptique 20ms) via `UIAnimations.wire_button(s)`.
- **Transitions de scène** : autoload `Transition` (CanvasLayer ~100 + ColorRect noir), `Transition.change_scene(path)` / `reload_scene()` = fondu.
- **Icônes SVG** : `coin_icon`, `gear_icon`, `crown_icon` (leader coop), `lock_icon` (verrouillés). SVG > glyphes police (les emojis ne rendent pas sous Android avec Poppins).
- **HUD en jeu** : PAUSE en haut à GAUCHE. Infos en haut à DROITE (score/temps + pièces). Largeur fixe, hauteur adaptative. Mode campagne : progression vers l'objectif. Mode coop : lignes par joueur + couronne leader. Tout sous la safe area.

## Audio / Haptique

- Autoload `Audio` (AudioManagerClass, `scenes/autoload/audio_manager.tscn`). Bus Master/Music/SFX. Pool SFX.
- Musique gameplay (`assets/audio/music/gameplay_loop.mp3`). Whoosh (`fall_whoosh.mp3`) modulé par vitesse via `set_whoosh_intensity`.
- Jetpack (`assets/audio/music/jetpack.mp3`) : boucle en jetpack, EN PLUS du whoosh. Loop activé sur l'import. PAS sur le bus Music. Stop à mort/pause.
- SFX de base `assets/audio/sfx/` : coin_pickup, obstacle_hit, game_over, ui_click.
- **SFX power-up SYNTHÉTISÉS** (`_generate_powerup_sfx`, AudioStreamWAV générés au démarrage via `_make_arp`/`_make_sweep`) : bouclier (arpège), ralenti (sweep descendant), aimant (sweep montant carré), boost (sweep montant scié), + éclatement bouclier (`play_shield_break`), + SFX coop (dépassement `play_coop_overtake`, prise de tête `play_coop_lead`). Pas de fichiers audio pour ceux-là. API : `play_powerup(type)`, `play_shield_break`, `play_coop_*`, play_coin/hit/game_over/ui_click, play_music/duck/unduck, play/stop jetpack/whoosh.
- **Haptique** : `Settings.vibrate(ms)` centralisé. Garde-fous : `vibration_enabled` (persisté) + `OS.get_name() in {Android, iOS}` (PAS has_feature("mobile")). Boutons 20ms, mort 120ms, power-up 35-70ms. Permission VIBRATE requise dans l'export. Log debug `[haptic]` encore en place (À RETIRER).
- Volumes persistés via Settings, AudioServer set_bus_volume_db.

## Décor / atmosphère

- **Cycle jour/nuit CONTINU** (`corridor_walls.gd`) : un cycle complet jour→crépuscule→nuit→aube tous les `CYCLE_DISTANCE = 3750m`, piloté par la distance parcourue. FIGÉ à phase 0 en campagne (`Story.active`) → le thème du chapitre s'affiche pur, sans dérive. **Ne touche QUE le CIEL/FOND** (ProceduralSky + skyline lointaine + champ d'étoiles) — N'AFFECTE PAS murs/perso/obstacles (la lisibilité gameplay reste constante). Étoiles = GPUParticles fixes (vélocité zéro, sphère lointaine rayon 90), alpha additif modulé par le cycle (0 le jour → plein la nuit).
- **`ambient_light_color` neutralisé** (gris froid `(0.48,0.5,0.55)` dans les scènes) pour éviter le délavage des couleurs par la lumière ambiante du ciel.
- **Zones visuelles d'ambiance** (autoload `Zones` + scheduler dans `corridor_walls.gd`, `VISUAL_NAMES = ["neon","clouds","cosmic"]`) : programmées en avance, blend doux entrée/sortie, OVERRIDE temporaire de la sortie du cycle jour/nuit. Désactivées en campagne/coop/story (`_zones_enabled`). Chacune a un twist vitesse assorti.
  - **neon** : rush néon (vitesse ×1.10).
  - **cosmic** : flottement cosmique (vitesse <1), étoiles à fond, lumières basses.
  - **clouds** : ÉCLAIRCIE subtile (teinte claire douce) + **raréfaction d'obstacles** (`CLOUD_SPACING_MULT = 1.7`). **AUCUN objet nuage** — le système de nuages visuels (sprites) a été ABANDONNÉ, la zone n'affiche que l'ambiance.
- **Nuages RETIRÉS partout** : ni zone "clouds" (plus de sprite), ni nuages jetpack. Ne plus les documenter comme présents.
- **Exclusion mutuelle** (autoload `Zones`) : une zone visuelle et une zone d'obstacles ne se chevauchent jamais (chaque producteur réserve une bande de `depth` dir-relative). Comme `special_scenes` est vide, seules les zones visuelles existent en pratique.
- **Façade fenêtres** (shader `wall_pattern.gdshader`, grille allumées/éteintes). Atténuées. Tours de la carte campagne via `tower_windows.gdshader`.
- **Boucle menu fluide** : `LOOP_DISTANCE` = multiple EXACT de la période du motif.
- **Skyline** (`city_skyline.gd`, partagé jeu+menu) : grille d'immeubles 3D + shader fenêtres, seed 1962. Modes chute : ancrée caméra `pos=(0,-72,-90)`, `rot=(-45,0,0)`. PAS de skyline en jetpack. Couleur pilotée par le thème, suit le cycle jour/nuit (fond lointain).
- **Hiérarchie visuelle** : décor terne (murs/skyline atténués) vs gameplay saturé (obstacles orange émissifs, pièces jaunes). Lointain toujours plus terne.
- **Motes/poussières** dans le couloir (GPUParticles, faible opacité). Retirées au MENU.

## Architecture / fichiers clés

- **Racine** : `CLAUDE.md`, `icon.svg`, `project.godot`, `export_presets.cfg`
- **Autoloads** : `Settings` (settings_manager.gd), `Catalog` (cosmetics_catalog.gd), `Missions` (missions_catalog.gd), `Story` (story.gd), `Coop` (coop_session.gd), `Zones` (zones.gd), `Audio` (audio_manager.tscn), `Transition` (scene_transition.gd), `Glass` (glass_manager.gd)
- **Player** : `scripts/player/player.gd` (PlayerController : poses chute+jetpack, `_setup_jetpack`, power-ups boost/bouclier/méga-boost, pulvérisation, hooks stats), `scenes/player/{player,ragdoll}.tscn`
- **Gameplay** : `scripts/gameplay/{follow_camera, obstacle_spawner, coin_spawner, corridor_walls, obstacle_base, obstacle_door, obstacle_oscillating, obstacle_bar, obstacle_wall, powerup_spawner, main_game}.gd`
- **Utils** : `scripts/utils/{city_skyline, ui_animations}.gd` (UIAnimations : glass_card_style, wire_button(s), allow_scroll_through, apply_top_safe_area, format_number, pop_in, make_glass_panel)
- **UI** : `scripts/ui/{game_hud, shop_screen, game_over_screen, main_menu, menu_camera, settings_screen, pause_screen, missions_screen, glass_blur}.gd` + glass_manager.gd
- **Campagne** : `scripts/ui/{campaign_screen, chapter_reader, chapter_end_screen}.gd` + autoload `story.gd`
- **Tournoi** : `scripts/ui/{coop_config_screen, coop_passation, coop_round_result, coop_tiebreak, coop_final}.gd` + autoload `coop_session.gd`
- **Collectibles** : `scripts/collectibles/{coin, powerup}.gd`
- **Effets** : `scripts/effects/post_process.gd` (flash, vignette)
- **Scènes** : `scenes/game/main_game.tscn`, `scenes/ui/` (menu + tous les écrans), `scenes/obstacles/` (cube, barre, mur, oscillant, porte)
- **Shaders** : `assets/shaders/{halftone, wall_pattern, glass_blur, shield_bubble, tower_windows, speed_lines}.gdshader` + shader skyline (dans city_skyline.gd)
- **Thème** : `resources/ui/main_theme.tres`. **Physique murs** : `resources/physics/frictionless.tres`
- **Audio** : `assets/audio/{music (gameplay_loop, jetpack), sfx}/`. **UI assets** : `assets/ui/{gear,coin,crown,lock}_icon.svg`. **Story** : `assets/story/` (images ch01-40.png À AJOUTER — placeholder en attendant)
- **APK** : buildé vers `C:\Users\Hulku\Desktop\autre\dev\Hyperdive\apk\Hyperdive.apk`

## Layers / conventions

- **CanvasLayer** : 0 post-process, 1 HUD, 5 pause, 6 game over, 7 shop, 8 settings, ~100 Transition. Carte campagne / lecteur / écrans tournoi = CanvasLayer dédiés.
- **Physique** : interpolation 120Hz. Caméra `physics_interpolation_mode = OFF`. La caméra suit `get_global_transform_interpolated().origin.y` du perso (pas global_position brute).
- **Mobile** : Portrait verrouillé, stretch aspect "expand"/canvas_items, max_fps=0 + V-Sync + Frame Pacing Swappy + Interpolation Physique -> 120Hz.
- **Signe dir** : source unique `Settings.get_fall_dir()` (+1 jetpack, -1 sinon). Ne PAS hardcoder un sens.
- **`depth`** (zones) : coord dir-relative monotone croissante (`get_fall_dir() * y`), positive en chute ET jetpack. Repère partagé par tous les producteurs de zones.

## Pièges Godot rencontrés (à connaître)

- `@export` NodePath fragile -> pattern par groupe (`add_to_group` + `get_first_node_in_group`).
- Modifs UI Godot fiables ; .tscn/project.godot par script peuvent diverger (orientation Android -> via l'UI).
- Désinstaller/réinstaller l'APK après changement d'orientation OU de permission (manifest changé).
- `Transform3D` row-major dans .tscn -> préférer `rotation_degrees`.
- `visible=true` sauvé par accident sur panels modaux = boucle au démarrage.
- Interpolation physique 120Hz -> caméra `physics_interpolation_mode=OFF` + suivre `get_global_transform_interpolated()` du perso.
- RigidBody enfants ignorent parfois la rotation root -> rotation par-partie (ragdoll).
- GPUParticles : changer `amount` redémarre. Trail/flammes/fumée/burst = CHACUN son matériau. Ressources de burst power-up MISES EN COMMUN (statiques) pour éviter la recompilation de shader = micro-freeze au ramassage.
- Ragdoll spawn : `global_rotation`, PAS `global_transform`. Hérite du matériau COMPLET du skin (pas juste l'albedo).
- Objet ancré caméra (skyline) : recalculer la position locale par mode (l'angle RELATIF objet/caméra compte).
- Dos vs ventre : en jetpack on voit le DOS -> réacteur dorsal CÔTÉ caméra (+Z).
- Boucle défilement : LOOP_DISTANCE multiple exact de la période.
- Mur à trou / barre / porte : passage mini 3 unités. Porte : ouverture rapide + déclenchée tôt.
- Audio boucle : activer `loop` sur l'import du .mp3 ; stop à mort/pause ; pas sur bus Music.
- SFX synthétisés : `AudioStreamWAV` générés au démarrage (`_make_arp`/`_make_sweep`) — pas de fichiers pour les power-ups/coop.
- Rampe vitesse : toujours move_toward (lissage), jamais saut sec. 4 régimes : solo (+10%/1000m chute, /500m jetpack), coop (+5%/150m), tiebreak (+10%/100m).
- **Glass/blur sur mobile** : corner_radius en px GUI, masque shader en px écran -> convertir via l'échelle canvas (stretch canvas_items), sinon coins anguleux.
- **Permission VIBRATE** : l'éditeur Godot remet `permissions/vibrate=false` dans export_presets.cfg à chaque ouverture de l'export. Pour figer : cocher dans l'UI Projet -> Exporter -> Android -> Permissions -> Vibrate. Revérifier avant chaque build post-session éditeur.
- **Haptique garde-fou** : `OS.get_name() in {Android,iOS}`, PAS `has_feature("mobile")`.
- **Scroll tactile** : Control non-boutons en mouse_filter PASS (helper allow_scroll_through) pour que le ScrollContainer reçoive le drag.
- **Garde-fous globaux** : `Story.active` et `Coop.active` gatent les stats perso. Toujours vérifier qu'un nouveau hook de stat respecte ces gates (sinon la campagne/le tournoi pollue les records solo).
- **`Settings.active_mode`** ne vaut que "infinite"/"jetpack" (l'ancien "campaign" a disparu avec l'ancien mode niveau). Le contexte campagne se lit via `Story.active`, pas via active_mode.
- **Cycle jour/nuit** : limité au ciel/fond (sample de courbes par phase). Ne JAMAIS l'étendre aux murs/perso/obstacles (casserait la lisibilité). Les zones visuelles l'overrident par blend.
- **PanelContainer adaptatif** : largeur fixe (custom_minimum_size.x) + pas de hauteur forcée = hauteur adaptative. Le GlassBlur doit suivre la taille réelle.
- **Thème par chapitre (campagne)** : override TRANSIENT via `Story.current_theme_id()`, gaté `not _is_menu` dans corridor_walls — au retour d'un chapitre, le menu s'affiche AVANT `Story.clear()` (sans le gate, le fond du menu prendrait le thème du chapitre). Ne JAMAIS écrire `equipped_theme` pour imposer un thème.

## Mes préférences et ton du jeu

- Itère vite : je teste sur mobile, je décris ou je partage des captures.
- Prompts concis, ciblés, avec le pourquoi.
- Ton arcade tendu : 1 vie, plongeon dramatique, ragdoll satisfaisant.
- Ton playful : sang/liquides drôles dans le shop (Bile, Antigel, Lait, etc.), noms de défis fun.
- Campagne narrative : ton mélancolique/SF (l'histoire d'un homme qui tombe en boucle dans une simulation).
- Bugs visuels difficiles -> mode debug systématique (exagérer/colorer pour confirmer, puis doser).
- Gros morceaux -> rapport + proposition avant de coder.

## Outils DEBUG TEMP en place (À RETIRER avant distribution)

- **Touche `U`** (clavier) / **appui long ~0.8s sur le titre HYPERDIVE** (menu) → `Settings.debug_unlock_all()` : débloque tous les cosmétiques + 99999 pièces + toutes les stats à fond + tous les chapitres (`story_chapter = chapter_count`) + modes débloqués. Ne marque PAS les défis claimed (on teste le flux de claim).
- **PageUp / PageDown** sur la carte campagne → avance/recule `story_chapter` d'un chapitre (tester états + lancer chute/jetpack sans tout dérouler).
- **Log `[haptic]`** dans `Settings.vibrate` (print à chaque vibration).

## PENDING connus (avant distribution)

- **Retirer les outils debug** ci-dessus (touche U / appui long titre, PageUp/PageDown carte, log `[haptic]`).
- **Images des 40 chapitres** : ajouter `assets/story/ch01.png` … `ch40.png` (le lecteur affiche un placeholder dégradé tant qu'elles manquent).
- **Étape 4 campagne** : point spécial ch.1 (objectif `descent` = ouverture jouable où MOURIR = réussir). Le driver d'objectif l'ignore actuellement (stub déjà retiré côté carte).
- **Keystore release** : configurer une signature de release (actuellement debug) pour le Play Store.
- **Permission VIBRATE** : re-vérifier qu'elle est cochée dans l'export Android avant chaque build (l'éditeur la décoche).
- **Tester sur vrai téléphone** : particules + audio synthétisé + haptique + cycle jour/nuit + tournoi pass-and-play.

## Pistes possibles (notées pour plus tard)

- Réintroduire une zone rare d'obstacles (`special_scenes` est prêt) : pendule, rouleau tournant…
- Distribution : itch.io (gratuit, ~10 min) ou Play Store (25$, fiche, signature).
- Équilibrage 1 vie si trop dur (élargir couloir, réduire densité, ralentir).
