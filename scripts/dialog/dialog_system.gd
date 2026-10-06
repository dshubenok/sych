extends Node
## Глобальная точка входа в систему «комиксных» диалогов.
## Регистрируется как autoload (см. project.godot → [autoload] DialogSystem).
##
## Использование из любого места:
##   DialogSystem.start_dialog("demonologist_intro")

const DIALOGS_DIR := "res://assets/dialogs/"
const DIALOG_PLAYER_SCENE := preload("res://scenes/ui/dialog_player.tscn")

signal dialog_started(dialog_id: String)
signal dialog_finished(dialog_id: String)

var _active_player: CanvasLayer = null
var _active_dialog_id: String = ""
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_active() -> bool:
	return _active_player != null


func start_dialog(dialog_id: String) -> bool:
	if is_active():
		return false

	var data := _load_dialog(dialog_id)
	if data.is_empty() or not data.has("panels"):
		push_warning("[DialogSystem] Диалог не найден или пуст: %s" % dialog_id)
		return false

	_active_dialog_id = dialog_id
	_active_player = DIALOG_PLAYER_SCENE.instantiate()
	get_tree().root.add_child(_active_player)
	_active_player.finished.connect(_on_dialog_player_finished)

	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

	_active_player.play(data)
	dialog_started.emit(dialog_id)
	return true


func _load_dialog(dialog_id: String) -> Dictionary:
	var path := DIALOGS_DIR + dialog_id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("[DialogSystem] Файл не найден: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[DialogSystem] JSON невалидный: %s" % path)
		return {}
	return parsed


func _on_dialog_player_finished() -> void:
	var id := _active_dialog_id
	if _active_player:
		_active_player.queue_free()
	_active_player = null
	_active_dialog_id = ""
	get_tree().paused = false
	Input.set_mouse_mode(_prev_mouse_mode)
	dialog_finished.emit(id)
