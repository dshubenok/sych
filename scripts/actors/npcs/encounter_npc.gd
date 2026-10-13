extends Node3D
class_name EncounterNpc
## Персонаж, через которого проходят энкаунтеры веток (Историк, Котик).
## Стоит в своём кабинете всегда; что делать по E, решает BranchSystem.get_npc_interaction():
##   • есть активный энкаунтер с этим персонажем (поговорить / отдать предмет / сообщить ответ) —
##     запускается комиксный диалог энкаунтера, после него энкаунтер засчитывается;
##   • энкаунтера нет — персонаж отвечает репликой из своего пула (idle_lines) над головой.
## Шаблон зоны E повторяет остальные интерактивные объекты; общий компонент
## взаимодействия (поток A) должен заменить его, не трогая логику энкаунтеров.

const INTERACTION_PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")

## Идентификатор персонажа для BranchSystem (BranchSystem.NPC_HISTORIAN / NPC_KOTIK).
@export var npc_id: String = ""
## Реплики персонажа, когда ему нечего сказать по веткам (случайная из пула).
@export var idle_lines: PackedStringArray = []
@export var interaction_radius: float = 2.5
@export var prompt_offset: Vector3 = Vector3(0.0, 2.4, 0.0)
@export var line_font_size: int = 48
## Секунд на реплику при минимальной длине; длинные держатся дольше.
@export var line_min_duration: float = 2.0
@export var line_seconds_per_char: float = 0.05

var _sych_in_range: bool = false
var _prompt: Node3D = null
var _line_label: Label3D = null
var _line_active: bool = false
var _pending_interaction: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_ensure_area()
	_prompt = INTERACTION_PROMPT_SCENE.instantiate()
	add_child(_prompt)
	_prompt.position = prompt_offset
	_prompt.visible = false
	_create_line_label()


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
		_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_interact():
		return
	if ComicDialogueSystem.is_active():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()
		get_viewport().set_input_as_handled()


func _can_interact() -> bool:
	return _sych_in_range and not _line_active and _pending_interaction.is_empty()


func _refresh_prompt() -> void:
	if _prompt == null:
		return
	_prompt.visible = _can_interact()


## Есть ли сейчас у персонажа энкаунтер для Сыча (для тестов и подсказок).
func has_encounter_interaction() -> bool:
	return not BranchSystem.get_npc_interaction(npc_id).is_empty()


func _interact() -> void:
	var interaction := BranchSystem.get_npc_interaction(npc_id)
	if interaction.is_empty():
		_say_idle_line()
		return
	var comic_dialogue_id: String = interaction.get("comic_dialogue", "")
	if comic_dialogue_id != "" and ComicDialogueSystem.start_comic_dialogue(comic_dialogue_id):
		_pending_interaction = interaction
		_refresh_prompt()
		if not ComicDialogueSystem.comic_dialogue_finished.is_connected(_on_comic_dialogue_finished):
			ComicDialogueSystem.comic_dialogue_finished.connect(_on_comic_dialogue_finished, CONNECT_ONE_SHOT)
		return
	# Диалога нет (или не загрузился) — энкаунтер засчитывается сразу, чтобы ветка не застряла.
	BranchSystem.resolve_npc_interaction(interaction)
	_refresh_prompt()


func _on_comic_dialogue_finished(_comic_dialogue_id: String) -> void:
	var interaction := _pending_interaction
	_pending_interaction = {}
	BranchSystem.resolve_npc_interaction(interaction)
	_refresh_prompt()


func _create_line_label() -> void:
	_line_label = Label3D.new()
	_line_label.name = "Line"
	_line_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_line_label.no_depth_test = false
	_line_label.fixed_size = true
	_line_label.pixel_size = 0.006
	_line_label.font_size = line_font_size
	_line_label.outline_size = 16
	_line_label.modulate = Color(1, 0.95, 0.45, 1)
	_line_label.outline_modulate = Color(0, 0, 0, 1)
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.width = 900.0
	_line_label.position = prompt_offset
	_line_label.visible = false
	add_child(_line_label)


func _say_idle_line() -> void:
	if idle_lines.is_empty() or _line_active:
		return
	_line_active = true
	_refresh_prompt()
	var line: String = idle_lines[_rng.randi_range(0, idle_lines.size() - 1)]
	_line_label.text = line
	_line_label.visible = true
	var duration := maxf(line_min_duration, line.length() * line_seconds_per_char)
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(_line_label):
			return
		_line_label.visible = false
		_line_active = false
		_refresh_prompt()
	)
