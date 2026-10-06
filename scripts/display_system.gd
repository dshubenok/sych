extends Node

## Режим окна: переключение полного экрана по F11 / Alt+Enter (действие
## `toggle_fullscreen`). Работает всегда — и в стартовом меню, и на паузе.
## Размер окна и масштабирование UI заданы в project.godot ([display]):
## базовый вьюпорт 1280×720, stretch canvas_items / expand — интерфейс
## растягивается на всё окно при любом его размере.

const ACTION := &"toggle_fullscreen"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(ACTION):
		return
	if event is InputEventKey and event.echo:
		return
	get_viewport().set_input_as_handled()
	toggle_fullscreen()


static func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


static func set_fullscreen(enabled: bool) -> void:
	# На macOS и Web нужен именно WINDOW_MODE_FULLSCREEN (не EXCLUSIVE):
	# это нативный полноэкранный режим с нормальным выходом из него.
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


static func toggle_fullscreen() -> void:
	set_fullscreen(not is_fullscreen())
