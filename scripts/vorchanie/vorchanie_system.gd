extends Node

## Ворчание — короткие реплики Сыча поверх мира, в поле ворчания снизу экрана.
## Обычное ворчание глушит «E», пока видно.
## «Поворчать и сделать» (дверь, записка, комикс) — нет: следующее «E»
## выполняет действие, не дожидаясь, пока строка исчезнет.
##
##   VorchanieSystem.vorchat("Записка? Под моей дверью? У МЕНЯ ТАЙНЫЙ ПОКЛОННИК")
##   VorchanieSystem.vorchat("Наружа. Вэээ.", false, false)

const PANEL_SCENE := preload("res://scenes/ui/vorchanie_panel.tscn")

signal finished

var _panel: CanvasLayer = null
var _blocks_input: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_active() -> bool:
	return _panel != null and is_instance_valid(_panel)


## Ворчать: показать короткую текстовую реакцию Сыча в поле ворчания.
func vorchat(text: String, replace: bool = false, blocks_input: bool = true) -> bool:
	if text.strip_edges().is_empty():
		return false
	if is_active():
		if not replace:
			return false
		var previous: CanvasLayer = _panel
		if previous.finished.is_connected(_on_panel_finished):
			previous.finished.disconnect(_on_panel_finished)
		_panel = null
		previous.queue_free()
	_blocks_input = blocks_input
	_panel = PANEL_SCENE.instantiate()
	get_tree().root.add_child(_panel)
	_panel.play(text)
	_panel.finished.connect(_on_panel_finished, CONNECT_ONE_SHOT)
	return true


func _input(event: InputEvent) -> void:
	if not is_active() or not _blocks_input:
		return
	# Глушим только «E», чтобы ворчание не открывало записку или доску.
	# Остальное управление не трогаем: игра не на паузе.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		get_viewport().set_input_as_handled()


func _on_panel_finished() -> void:
	if _panel:
		_panel.queue_free()
	_panel = null
	_blocks_input = true
	finished.emit()
