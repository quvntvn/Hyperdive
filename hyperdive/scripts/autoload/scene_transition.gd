extends CanvasLayer
class_name SceneTransition

const FADE_DURATION: float = 0.25

var _is_transitioning: bool = false

func _ready() -> void:
	$Overlay.color = Color(0, 0, 0, 0)
	$Overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

# `fade_out` permet un fondu au noir plus DOUX que le défaut (ex. victoire de chapitre : ~1 s
# au lieu de 0,25 s, le défaut restant inchangé pour tous les autres appelants).
func change_scene(path: String, fade_out: float = FADE_DURATION, fade_in: float = FADE_DURATION) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	$Overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var t1 := create_tween()
	t1.tween_property($Overlay, "color:a", 1.0, fade_out).set_trans(Tween.TRANS_SINE)
	await t1.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property($Overlay, "color:a", 0.0, fade_in).set_trans(Tween.TRANS_LINEAR)
	await t2.finished
	$Overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false

# Fondu noir MANUEL, sans changement de scène (victoire de chapitre HISTOIRE : couper net
# l'action avant l'écran de réussite). L'appelant enchaîne fade_from_black() quand son écran
# est prêt. Réutilise l'overlay ET le verrou _is_transitioning : tant qu'on est au noir, un
# change_scene concurrent est ignoré ; le verrou ne se libère qu'au fade_from_black.
func fade_to_black(duration: float = FADE_DURATION) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	$Overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property($Overlay, "color:a", 1.0, duration).set_trans(Tween.TRANS_LINEAR)
	await t.finished

func fade_from_black(duration: float = FADE_DURATION) -> void:
	var t := create_tween()
	t.tween_property($Overlay, "color:a", 0.0, duration).set_trans(Tween.TRANS_LINEAR)
	await t.finished
	$Overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false

func reload_scene() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	$Overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var t1 := create_tween()
	t1.tween_property($Overlay, "color:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_LINEAR)
	await t1.finished
	get_tree().reload_current_scene()
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property($Overlay, "color:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_LINEAR)
	await t2.finished
	$Overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
