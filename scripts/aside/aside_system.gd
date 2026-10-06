extends Node

## Реплики от лица игрового персонажа поверх мира.
## Обычная реплика глушит «E», пока видна.
## «Поворчать и сделать» (дверь, записка, комикс) — нет: следующее «E»
## выполняет действие, не дожидаясь, пока строка исчезнет.
##
##   AsideSystem.say("Записка? Под моей дверью? У МЕНЯ ТАЙНЫЙ ПОКЛОННИК")
##   AsideSystem.say("Наружа. Вэээ.", false, false)

const LINE_SCENE := preload("res://scenes/ui/aside_line.tscn")

signal finished

var _line: CanvasLayer = null
var _blocks_input: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_active() -> bool:
	return _line != null and is_instance_valid(_line)


func say(text: String, replace: bool = false, blocks_input: bool = true) -> bool:
	if text.strip_edges().is_empty():
		return false
	if is_active():
		if not replace:
			return false
		var previous: CanvasLayer = _line
		if previous.finished.is_connected(_on_line_finished):
			previous.finished.disconnect(_on_line_finished)
		_line = null
		previous.queue_free()
	_blocks_input = blocks_input
	_line = LINE_SCENE.instantiate()
	get_tree().root.add_child(_line)
	_line.play(text)
	_line.finished.connect(_on_line_finished, CONNECT_ONE_SHOT)
	return true


func _input(event: InputEvent) -> void:
	if not is_active() or not _blocks_input:
		return
	# Глушим только «E», чтобы реплика не открывала записку или доску.
	# Остальное управление не трогаем: игра не на паузе.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		get_viewport().set_input_as_handled()


func _on_line_finished() -> void:
	if _line:
		_line.queue_free()
	_line = null
	_blocks_input = true
	finished.emit()
