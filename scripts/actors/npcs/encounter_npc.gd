extends Node3D
class_name BranchStageNpc
## NPC, привязанный к этапу ветки (энкаунтер):
##   • скрыт в мире, пока его этап не запланирован (reveal_on_branch_stage);
##   • когда этап запланирован, становится видимым и доступным для взаимодействия;
##   • по E показывает приветствие или комиксный диалог, затем закрывает этап ветки.
##   • energinka_upgrade_id — одноразовый +1 к максимуму энергинок.

const INTERACTION_PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")

## Этап ветки, планирование которого открывает (показывает) этого NPC. Пусто — NPC виден сразу.
@export var reveal_on_branch_stage: String = ""
## Этап ветки, который закрывается при взаимодействии. Пусто — ничего не закрывает.
@export var completes_branch_stage: String = ""
## ID комиксного диалога (JSON в res://assets/comic_dialogues/). Пусто — только приветствие.
@export var comic_dialogue_id: String = ""
## Одноразовый апгрейд пула энергинок после диалога/приветствия.
@export var energinka_upgrade_id: StringName = &""
@export var interaction_radius: float = 2.5
@export var prompt_offset: Vector3 = Vector3(0.0, 2.4, 0.0)
@export var greeting: String = "Привет!"
@export var greeting_font_size: int = 48
@export var greeting_duration: float = 2.5
## Скрывать NPC, пока reveal_on_branch_stage не запланирован.
@export var hidden_until_revealed: bool = true

var _sych_in_range: bool = false
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
	if reveal_on_branch_stage != "" and BranchSystem.get_state(reveal_on_branch_stage) >= BranchSystem.State.ACTIVE:
		_revealed = true
	if completes_branch_stage != "" and BranchSystem.get_state(completes_branch_stage) == BranchSystem.State.COMPLETED:
		_done = true
		_revealed = true
	visible = _revealed

	if not BranchSystem.branch_stage_planned.is_connected(_on_branch_stage_planned):
		BranchSystem.branch_stage_planned.connect(_on_branch_stage_planned)


func _on_branch_stage_planned(branch_stage_id: String) -> void:
	if branch_stage_id == reveal_on_branch_stage:
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
	if body.is_in_group(&"sych"):
		_sych_in_range = true
		_refresh_prompt()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group(&"sych"):
		_sych_in_range = false
		if _prompt:
			_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _can_interact():
		return
	if ComicDialogueSystem.is_active():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()
		get_viewport().set_input_as_handled()


func _can_interact() -> bool:
	return _revealed and _sych_in_range and not _done and not _message_active


func _refresh_prompt() -> void:
	if _prompt == null:
		return
	_prompt.visible = _can_interact()


func _interact() -> void:
	if _done:
		return
	if comic_dialogue_id != "":
		if ComicDialogueSystem.start_comic_dialogue(comic_dialogue_id):
			if not ComicDialogueSystem.comic_dialogue_finished.is_connected(_on_comic_dialogue_finished):
				ComicDialogueSystem.comic_dialogue_finished.connect(_on_comic_dialogue_finished, CONNECT_ONE_SHOT)
		return
	_show_greeting()
	_finish_interaction()


func _on_comic_dialogue_finished(finished_comic_dialogue_id: String) -> void:
	if finished_comic_dialogue_id != comic_dialogue_id:
		return
	_finish_interaction()


func _finish_interaction() -> void:
	if _done:
		return
	_done = true
	if _prompt:
		_prompt.visible = false
	if completes_branch_stage != "":
		BranchSystem.complete_branch_stage(completes_branch_stage)
	if energinka_upgrade_id != &"":
		EnerginkaSystem.collect_upgrade(energinka_upgrade_id)


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
