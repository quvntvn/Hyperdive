extends CanvasLayer
class_name SceneTransition

const FADE_DURATION: float = 0.25

var _is_transitioning: bool = false

func _ready() -> void:
	$Overlay.color = Color(0, 0, 0, 0)
	$Overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	$Overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var t1 := create_tween()
	t1.tween_property($Overlay, "color:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_LINEAR)
	await t1.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property($Overlay, "color:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_LINEAR)
	await t2.finished
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
