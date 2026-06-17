extends CanvasLayer
class_name BloodOverlay
# Éclaboussures de sang plein écran (GLOBAL, tous modes). Vit dans la scène de jeu : main_game
# l'instancie au _ready. CanvasLayer à layer 0 → AU-DESSUS du monde 3D mais SOUS le HUD (layer 1,
# altimètre/score) et la pause (layer 5) : l'UI critique reste visible et cliquable.
#
# Deux événements, branchés depuis player.gd :
#   • splatter_wall()  — touche de mur (collision latérale NON-FATALE) : tache fugace
#                        (plein → hold WALL_HOLD → fondu WALL_FADE → free).
#   • splatter_death() — mort : 1-2 taches PERMANENTES (pas de fondu), nettoyées avec la scène
#                        à la transition/redémarrage (elles sont enfants de cet overlay).
#
# Chaque tache : texture au hasard + rotation 0-360° + échelle aléatoire + miroir H/V aléatoire +
# position écran aléatoire + légère variation de teinte (rouge plus/moins sombre).

const LAYER := 0
const WALL_HOLD := 0.5      # tache murale à pleine opacité (s)
const WALL_FADE := 0.3      # puis fondu jusqu'à disparition (s)
const SCALE_MIN := 0.45
const SCALE_MAX := 0.95
const TINT_VAR := 0.12      # amplitude de la variation de teinte par tache
const TEX_COUNT := 12

var _textures: Array[Texture2D] = []

func _ready() -> void:
	layer = LAYER
	add_to_group("blood_overlay")
	for i in TEX_COUNT:
		var p := "res://assets/blood/splat_%02d.png" % (i + 1)
		if ResourceLoader.exists(p):
			_textures.append(load(p))

# Touche de mur : tache fugace (plein → hold → fondu → free).
func splatter_wall() -> void:
	var s := _spawn_splat()
	if s == null:
		return
	var tw := create_tween()
	tw.tween_interval(WALL_HOLD)
	tw.tween_property(s, "modulate:a", 0.0, WALL_FADE)
	tw.tween_callback(s.queue_free)

# Mort : 1-2 taches qui RESTENT (pas de fondu) jusqu'à la transition d'écran.
func splatter_death() -> void:
	var n := randi_range(1, 2)
	for i in n:
		_spawn_splat()

# Nettoyage explicite (la transition recharge la scène et libère l'overlay, mais on l'expose
# au cas où on voudrait effacer sans changer de scène).
func clear() -> void:
	for c in get_children():
		c.queue_free()

func _spawn_splat() -> Sprite2D:
	if _textures.is_empty():
		return null
	var spr := Sprite2D.new()
	spr.texture = _textures[randi() % _textures.size()]
	spr.rotation = randf() * TAU
	var sc := randf_range(SCALE_MIN, SCALE_MAX)
	spr.scale = Vector2(sc, sc)
	spr.flip_h = randf() < 0.5
	spr.flip_v = randf() < 0.5
	var vp := get_viewport().get_visible_rect().size
	spr.position = Vector2(randf() * vp.x, randf() * vp.y)
	# Variation de teinte : on assombrit légèrement et on désature un peu vers le rouge profond.
	var d := randf_range(-TINT_VAR, 0.04)
	spr.modulate = Color(clampf(1.0 + d, 0.7, 1.05), clampf(0.95 + d, 0.55, 1.0), clampf(0.92 + d, 0.55, 1.0), 1.0)
	add_child(spr)
	return spr
