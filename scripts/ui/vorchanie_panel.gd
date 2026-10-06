extends CanvasLayer

## Поле ворчания: реплика Сыча снизу экрана. Сама гаснет, «E» в это время не действует.

signal finished

@onready var _root: Control = $Root
@onready var _label: Label = $Root/Bottom/Bubble/Label

var _closing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func play(text: String) -> void:
	_label.text = text
	_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.18)
	var seconds := clampf(1.8 + text.length() * 0.05, 2.6, 7.5)
	var timer := get_tree().create_timer(seconds, true)
	timer.timeout.connect(_close)


func _close() -> void:
	if _closing:
		return
	_closing = true
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.22)
	tween.finished.connect(func() -> void:
		finished.emit()
	)
