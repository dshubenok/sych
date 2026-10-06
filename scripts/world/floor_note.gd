extends Node3D

## Записка на полу. В первый раз, пока её не прочитали, доска и выход закрыты.
## После первого прочтения она остаётся на полу, но больше ничего не блокирует.

const PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")
const VIEWER_SCENE := preload("res://scenes/ui/note_viewer.tscn")

@export var note_texture: Texture2D
@export var interaction_radius: float = 1.15
@export var prompt_offset: Vector3 = Vector3(0.0, 0.55, 0.0)
## Первое «E» показывает эту реплику Сыча, следующее открывает записку.
@export_multiline var aside_before_open: String = ""

var has_been_read: bool = false
var _aside_done: bool = false

var _player_in_range: bool = false
var _prompt: Node3D
var _viewer = null
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	_ensure_area()
	_prompt = PROMPT_SCENE.instantiate()
	add_child(_prompt)
	_prompt.position = prompt_offset
	_prompt.visible = false
	# Обязательное чтение только в первый день. Со второго дня флаг уже стоит.
	if DaySystem.day_number > 1:
		DaySystem.starosta_note_read = true
	# TODO: перед релизом убрать вместе с DaySystem.DEV_SKIP_STAROSTA_NOTE.
	if DaySystem.DEV_SKIP_STAROSTA_NOTE and OS.has_feature("editor"):
		DaySystem.starosta_note_read = true
	has_been_read = DaySystem.starosta_note_read
	_aside_done = has_been_read
	call_deferred("_set_room_locked", not has_been_read)


func _unhandled_input(event: InputEvent) -> void:
	if _viewer != null or not _player_in_range:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if aside_before_open != "" and not _aside_done:
			_aside_done = true
			if AsideSystem.say(aside_before_open, false, false):
				AsideSystem.finished.connect(_update_prompt, CONNECT_ONE_SHOT)
			_update_prompt()
		else:
			_open()
		get_viewport().set_input_as_handled()


func _ensure_area() -> void:
	var area := get_node_or_null("InteractionArea") as Area3D
	if area == null:
		area = Area3D.new()
		area.name = "InteractionArea"
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = interaction_radius
		shape.shape = sphere
		area.add_child(shape)
		add_child(area)
	area.monitoring = true
	area.monitorable = true
	area.collision_mask = 0xFFFFFFFF
	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)
	if not area.body_exited.is_connected(_on_body_exited):
		area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(&"player"):
		_player_in_range = true
		_update_prompt()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group(&"player"):
		_player_in_range = false
		_update_prompt()


func _open() -> void:
	if _viewer != null or note_texture == null:
		return
	_viewer = VIEWER_SCENE.instantiate()
	get_tree().root.add_child(_viewer)
	_viewer.show_note(note_texture)
	_viewer.closed.connect(_on_viewer_closed, CONNECT_ONE_SHOT)
	_update_prompt()
	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true


func _on_viewer_closed() -> void:
	_viewer = null
	get_tree().paused = false
	Input.set_mouse_mode(_prev_mouse_mode)
	if not has_been_read:
		has_been_read = true
		DaySystem.starosta_note_read = true
		_set_room_locked(false)
	_update_prompt()


func _update_prompt() -> void:
	if _prompt:
		_prompt.visible = _player_in_range and _viewer == null


func _set_room_locked(locked: bool) -> void:
	var host := get_parent()
	if host == null:
		return
	for child in host.get_children():
		if child is LocationPortal and child.unlock_on_plan:
			child.set_interaction_locked(locked or not QuestSystem.has_confirmed_plan())
		elif child.has_method("set_interaction_locked"):
			child.set_interaction_locked(locked)
