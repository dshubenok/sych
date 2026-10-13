extends Node3D

## Записка старосты на полу (план демо §2.3). Одно E: ворчание Сыча + открытие
## записки отдельным 2D-экраном. Пока её не прочитали в первый день, комикс,
## пробковая доска и выход закрыты. Прочитанная остаётся на полу и открывается
## снова, уже без ворчания.

const VIEWER_SCENE := preload("res://scenes/ui/note_viewer.tscn")

const STATE_UNREAD := &"unread"
const STATE_READ := &"read"

@export var note_texture: Texture2D
## Ворчание первого взаимодействия: Сыч комментирует записку и тем же E открывает её.
@export_multiline var vorchanie_before_open: String = ""

var has_been_read: bool = false
var interaction: Interaction = null

var _viewer = null
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	# Обязательное чтение только в первый день. Со второго дня флаг уже стоит.
	if DaySystem.day_number > 1:
		DaySystem.starosta_note_read = true
	# TODO: перед релизом убрать вместе с DaySystem.DEV_SKIP_STAROSTA_NOTE.
	if DaySystem.DEV_SKIP_STAROSTA_NOTE and OS.has_feature("editor"):
		DaySystem.starosta_note_read = true
	has_been_read = DaySystem.starosta_note_read

	interaction = Interaction.ensure(self, 1.15, Vector3(0.0, 0.55, 0.0))
	var unread := InteractionState.new()
	unread.id = STATE_UNREAD
	if vorchanie_before_open != "":
		unread.vorchanie_pool = [vorchanie_before_open]
	unread.next_state = STATE_READ
	interaction.add_state(unread)
	var read := InteractionState.new()
	read.id = STATE_READ
	interaction.add_state(read)
	interaction.set_interaction_state(STATE_READ if has_been_read else STATE_UNREAD)
	interaction.action.connect(_on_action)
	call_deferred("_set_location_locked", not has_been_read)


func _on_action(_interaction: Interaction) -> void:
	_open()


func _open() -> void:
	if _viewer != null or note_texture == null:
		return
	_viewer = VIEWER_SCENE.instantiate()
	get_tree().root.add_child(_viewer)
	_viewer.show_note(note_texture)
	_viewer.closed.connect(_on_viewer_closed, CONNECT_ONE_SHOT)
	interaction.busy = true
	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true


func _on_viewer_closed() -> void:
	_viewer = null
	get_tree().paused = false
	Input.set_mouse_mode(_prev_mouse_mode)
	interaction.busy = false
	if not has_been_read:
		has_been_read = true
		DaySystem.starosta_note_read = true
		_set_location_locked(false)


func _set_location_locked(locked: bool) -> void:
	var host := get_parent()
	if host == null:
		return
	for child in host.get_children():
		if child is LocationPortal and child.unlock_on_plan:
			child.set_interaction_locked(locked or not BranchSystem.has_confirmed_plan())
		elif child.has_method("set_interaction_locked"):
			child.set_interaction_locked(locked)
