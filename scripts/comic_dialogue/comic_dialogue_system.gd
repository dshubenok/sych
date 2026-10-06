extends Node
## Глобальная точка входа в систему комиксных диалогов (ровно четыре кадра, без вариантов ответа).
## Регистрируется как autoload (см. project.godot → [autoload] ComicDialogueSystem).
##
## Использование из любого места:
##   ComicDialogueSystem.start_comic_dialogue("historian_intro")

const COMIC_DIALOGUES_DIR := "res://assets/comic_dialogues/"
const COMIC_DIALOGUE_PLAYER_SCENE := preload("res://scenes/ui/comic_dialogue_player.tscn")

signal comic_dialogue_started(comic_dialogue_id: String)
signal comic_dialogue_finished(comic_dialogue_id: String)

var _active_player: CanvasLayer = null
var _active_comic_dialogue_id: String = ""
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_active() -> bool:
	return _active_player != null


func start_comic_dialogue(comic_dialogue_id: String) -> bool:
	if is_active():
		return false

	var data := _load_comic_dialogue(comic_dialogue_id)
	if data.is_empty() or not data.has("frames"):
		push_warning("[ComicDialogueSystem] Комиксный диалог не найден или пуст: %s" % comic_dialogue_id)
		return false

	_active_comic_dialogue_id = comic_dialogue_id
	_active_player = COMIC_DIALOGUE_PLAYER_SCENE.instantiate()
	get_tree().root.add_child(_active_player)
	_active_player.finished.connect(_on_comic_dialogue_player_finished)

	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

	_active_player.play(data)
	comic_dialogue_started.emit(comic_dialogue_id)
	return true


func _load_comic_dialogue(comic_dialogue_id: String) -> Dictionary:
	var path := COMIC_DIALOGUES_DIR + comic_dialogue_id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("[ComicDialogueSystem] Файл не найден: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[ComicDialogueSystem] JSON невалидный: %s" % path)
		return {}
	return parsed


func _on_comic_dialogue_player_finished() -> void:
	var id := _active_comic_dialogue_id
	if _active_player:
		_active_player.queue_free()
	_active_player = null
	_active_comic_dialogue_id = ""
	get_tree().paused = false
	Input.set_mouse_mode(_prev_mouse_mode)
	comic_dialogue_finished.emit(id)
