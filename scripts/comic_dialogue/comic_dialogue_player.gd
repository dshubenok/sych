extends CanvasLayer
## UI-слой комиксного диалога (страница из четырёх кадров комикса).
## • Кадры появляются по очереди с интервалом `frame_reveal_interval`.
## • E / Пробел / ЛКМ — пропустить таймер к следующему кадру; после показа
##   всех — закрыть комиксный диалог.
## • ESC / Q / ПКМ — скипнуть весь комиксный диалог в любой момент.

signal finished

const COMIC_FRAME_SCENE := preload("res://scenes/ui/comic_frame.tscn")

const HINT_REVEALING := "E / Пробел / ЛКМ — дальше        ESC — пропустить"
const HINT_DONE := "E / Пробел / ЛКМ — продолжить        ESC — пропустить"

@export var frame_reveal_interval: float = 2.0

@onready var _grid: GridContainer = $Root/Page/AspectRatio/Grid
@onready var _hint: Label = $Root/Hint

var _frames_data: Array = []
var _revealed: int = 0
var _all_revealed: bool = false
var _reveal_token: int = 0
var _closing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hint.text = ""


func play(data: Dictionary) -> void:
	_frames_data = data.get("frames", [])
	_revealed = 0
	_all_revealed = false
	_closing = false
	_reveal_token += 1

	for child in _grid.get_children():
		child.queue_free()

	_grid.columns = 2 if _frames_data.size() >= 2 else 1

	for i in range(_frames_data.size()):
		var frame: ComicFrame = COMIC_FRAME_SCENE.instantiate()
		_grid.add_child(frame)
		frame.set_hidden_placeholder()

	_hint.text = HINT_REVEALING
	_reveal_next()


func _reveal_next() -> void:
	_reveal_token += 1
	if _revealed >= _frames_data.size():
		_mark_all_revealed()
		return

	var frame_node: ComicFrame = _grid.get_child(_revealed) as ComicFrame
	frame_node.apply_data(_frames_data[_revealed])
	_revealed += 1

	if _revealed >= _frames_data.size():
		_mark_all_revealed()
		return

	var token := _reveal_token
	var timer := get_tree().create_timer(frame_reveal_interval)
	timer.timeout.connect(func() -> void:
		if token == _reveal_token:
			_reveal_next()
	)


func _mark_all_revealed() -> void:
	_all_revealed = true
	_hint.text = HINT_DONE


func _close() -> void:
	if _closing:
		return
	_closing = true
	_reveal_token += 1
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if _is_skip_event(event):
		get_viewport().set_input_as_handled()
		_close()
		return
	if _is_advance_event(event):
		get_viewport().set_input_as_handled()
		if _all_revealed:
			_close()
		else:
			_reveal_next()


func _is_advance_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER
	if event is InputEventMouseButton and event.pressed:
		return event.button_index == MOUSE_BUTTON_LEFT
	return false


func _is_skip_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ESCAPE or event.keycode == KEY_Q
	if event is InputEventMouseButton and event.pressed:
		return event.button_index == MOUSE_BUTTON_RIGHT
	return false
