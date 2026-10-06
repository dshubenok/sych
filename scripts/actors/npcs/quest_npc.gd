extends Node3D
class_name QuestNpc
## NPC, привязанный к квесту:
##   • скрыт в мире, пока его квест не заспавнен (reveal_on_quest);
##   • при спавне квеста становится видимым и доступным для взаимодействия;
##   • по E показывает приветствие или комикс, затем завершает квест.
##   • energy_upgrade_id — одноразовый +1 к максимуму энергии.

const INTERACTION_PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")

## Квест, спавн которого открывает (показывает) этого NPC. Пусто — NPC виден сразу.
@export var reveal_on_quest: String = ""
## Квест, который завершается при взаимодействии. Пусто — ничего не завершает.
@export var completes_quest: String = ""
## ID комикс-диалога (JSON в res://assets/dialogs/). Пусто — только приветствие.
@export var dialog_id: String = ""
## Одноразовый апгрейд пула энергии после диалога/приветствия.
@export var energy_upgrade_id: StringName = &""
@export var interaction_radius: float = 2.5
@export var prompt_offset: Vector3 = Vector3(0.0, 2.4, 0.0)
@export var greeting: String = "Привет!"
@export var greeting_font_size: int = 48
@export var greeting_duration: float = 2.5
## Скрывать NPC, пока reveal_on_quest не заспавнен.
@export var hidden_until_revealed: bool = true

var _player_in_range: bool = false
var _revealed: bool = false
var _done: bool = false
var _prompt: Node3D = null
var _message_label: Label3D = null
var _message_active: bool = false


func _ready() -> void:
	_ensure_area()
	_prompt = INTERACTION_PROMPT_SCENE.instantiate()
	add_child(_prompt)
	_prompt.position = prompt_offset
	_prompt.visible = false
	_create_message_label()

	_revealed = not hidden_until_revealed
	if reveal_on_quest != "" and QuestSystem.get_state(reveal_on_quest) >= QuestSystem.State.ACTIVE:
		_revealed = true
	if completes_quest != "" and QuestSystem.get_state(completes_quest) == QuestSystem.State.COMPLETED:
		_done = true
		_revealed = true
	visible = _revealed

	if not QuestSystem.quest_spawned.is_connected(_on_quest_spawned):
		QuestSystem.quest_spawned.connect(_on_quest_spawned)


func _on_quest_spawned(quest_id: String) -> void:
	if quest_id == reveal_on_quest:
		_reveal()


func _reveal() -> void:
	if _revealed:
		return
	_revealed = true
	visible = true
	_refresh_prompt()


func _ensure_area() -> void:
	var area: Area3D = get_node_or_null("InteractionArea") as Area3D
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
		_refresh_prompt()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group(&"player"):
		_player_in_range = false
		if _prompt:
			_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _can_interact():
		return
	if DialogSystem.is_active():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()
		get_viewport().set_input_as_handled()


func _can_interact() -> bool:
	return _revealed and _player_in_range and not _done and not _message_active


func _refresh_prompt() -> void:
	if _prompt == null:
		return
	_prompt.visible = _can_interact()


func _interact() -> void:
	if _done:
		return
	if dialog_id != "":
		if DialogSystem.start_dialog(dialog_id):
			if not DialogSystem.dialog_finished.is_connected(_on_dialog_finished):
				DialogSystem.dialog_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)
		return
	_show_greeting()
	_finish_interaction()


func _on_dialog_finished(finished_dialog_id: String) -> void:
	if finished_dialog_id != dialog_id:
		return
	_finish_interaction()


func _finish_interaction() -> void:
	if _done:
		return
	_done = true
	if _prompt:
		_prompt.visible = false
	if completes_quest != "":
		QuestSystem.complete_quest(completes_quest)
	if energy_upgrade_id != &"":
		EnergySystem.collect_upgrade(energy_upgrade_id)


func _create_message_label() -> void:
	_message_label = Label3D.new()
	_message_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_message_label.no_depth_test = false
	_message_label.fixed_size = true
	_message_label.pixel_size = 0.006
	_message_label.font_size = greeting_font_size
	_message_label.outline_size = 16
	_message_label.modulate = Color(1, 0.95, 0.45, 1)
	_message_label.outline_modulate = Color(0, 0, 0, 1)
	_message_label.position = prompt_offset
	_message_label.visible = false
	add_child(_message_label)


func _show_greeting() -> void:
	if _message_active:
		return
	_message_active = true
	if _prompt:
		_prompt.visible = false
	_message_label.text = greeting
	_message_label.visible = true

	var timer := get_tree().create_timer(greeting_duration)
	timer.timeout.connect(func() -> void:
		_message_label.visible = false
		_message_active = false
		_refresh_prompt()
	)
