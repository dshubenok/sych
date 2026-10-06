extends Area3D
class_name LocationPortal

## Дверь/переход в другую локацию. По умолчанию срабатывает, когда игрок
## входит в зону; можно переключить на ручной режим (по взаимодействию).

const PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")

@export var target_location_id: StringName
@export var target_entry: StringName = &""
## true — переход сразу при входе в зону; false — только по «E».
@export var auto_travel: bool = true
@export var prompt_offset: Vector3 = Vector3(0.0, 2.2, 0.0)
## Если не пусто, первое «E» — реплика, следующее — переход.
@export var aside_before_travel: String = ""
## Дверь открывается только после подтверждённого плана на доске.
@export var unlock_on_plan: bool = false

## Пока true, переход не срабатывает и «E» не показывается.
var interaction_locked: bool = false

var _player_in_range: bool = false
var _prompt: Node3D = null
var _exit_aside_done: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_mask = 0xFFFFFFFF
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_label()
	if not auto_travel:
		_prompt = PROMPT_SCENE.instantiate()
		add_child(_prompt)
		_prompt.position = prompt_offset
		_prompt.visible = false
	if unlock_on_plan:
		interaction_locked = not QuestSystem.has_confirmed_plan()
		if not QuestSystem.quest_spawned.is_connected(_on_plan_confirmed):
			QuestSystem.quest_spawned.connect(_on_plan_confirmed)
		_refresh_prompt()

func _on_plan_confirmed(_quest_id: String) -> void:
	if unlock_on_plan:
		set_interaction_locked(false)

func set_interaction_locked(locked: bool) -> void:
	interaction_locked = locked
	var label := get_node_or_null(^"Label") as Node3D
	if label:
		label.visible = not locked
	_refresh_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if auto_travel or interaction_locked or not _player_in_range:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if aside_before_travel != "" and not _exit_aside_done:
			_exit_aside_done = true
			if AsideSystem.say(aside_before_travel, false, false):
				AsideSystem.finished.connect(_refresh_prompt, CONNECT_ONE_SHOT)
			_refresh_prompt()
		else:
			_travel()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_in_range = true
	if auto_travel:
		if not interaction_locked:
			_travel()
		return
	_refresh_prompt()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group(&"player"):
		_player_in_range = false
		_exit_aside_done = false
		_refresh_prompt()

func _refresh_prompt() -> void:
	if _prompt:
		_prompt.visible = _player_in_range and not interaction_locked and not auto_travel

## Ручной переход (например, по нажатию «E»).
func interact() -> void:
	_travel()

func _travel() -> void:
	if target_location_id == &"":
		push_warning("[LocationPortal] target_location_id не задан на %s" % name)
		return
	LocationManager.travel_to(target_location_id, target_entry)

func _update_label() -> void:
	var label := get_node_or_null(^"Label") as Label3D
	if label and target_location_id != &"":
		label.text = "→ %s" % LocationRegistry.get_title(target_location_id)
