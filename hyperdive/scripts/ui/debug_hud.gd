extends Label
class_name DebugHUD

func _ready() -> void:
	Settings.control_mode_changed.connect(_on_control_mode_changed)
	text = "Control: " + SettingsManager.ControlMode.keys()[Settings.control_mode]

func _on_control_mode_changed(mode: SettingsManager.ControlMode) -> void:
	text = "Control: " + SettingsManager.ControlMode.keys()[mode]
