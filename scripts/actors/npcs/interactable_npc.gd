extends Node3D
class_name InteractableNpc
## Вешай этот скрипт на корневой Node3D персонажа — он:
##   • создаёт триггерную Area3D вокруг NPC (если её ещё нет);
##   • показывает Label3D "E" над головой, когда Сыч в зоне;
##   • по нажатию E запускает ComicDialogueSystem.start_comic_dialogue(comic_dialogue_id).

const INTERACTION_PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")

## ID комиксного диалога — имя JSON-файла в res://assets/comic_dialogues/ без расширения.
@export var comic_dialogue_id: String = ""
## Радиус триггерной сферы (если Area3D создаётся автоматически).
@export var interaction_radius: float = 2.5
## Смещение подсказки "E" относительно корня NPC.
@export var prompt_offset: Vector3 = Vector3(0.0, 2.4, 0.0)
## Сколько энергинок потратить после завершения комиксного диалога.
@export var energinka_cost_after_comic_dialogue: int = 0
## Текст, который показывается над NPC вместо запуска диалога.
@export var interaction_message: String = ""
## Размер шрифта для `interaction_message`.
@export var interaction_message_font_size: int = 96
## Сколько секунд показывать `interaction_message`.
@export var interaction_message_duration: float = 2.0
## Сколько энергинок получить после показа сообщения.
@export var energinka_restore_after_message: int = 0

var _sych_in_range: bool = false
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
		if _prompt and not _message_active:
			_prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group(&"sych"):
		_sych_in_range = false
		if _prompt:
			_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _sych_in_range:
		return
	if ComicDialogueSystem.is_active():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if interaction_message != "":
			_show_interaction_message()
			get_viewport().set_input_as_handled()
			return
		if comic_dialogue_id == "":
			return
		if energinka_cost_after_comic_dialogue > 0 and not EnerginkaSystem.can_spend_energinka(energinka_cost_after_comic_dialogue):
			EnerginkaSystem.spend_energinka(energinka_cost_after_comic_dialogue)
			get_viewport().set_input_as_handled()
			return
		var comic_dialogue_started := ComicDialogueSystem.start_comic_dialogue(comic_dialogue_id)
		if comic_dialogue_started and energinka_cost_after_comic_dialogue > 0:
			ComicDialogueSystem.comic_dialogue_finished.connect(_on_comic_dialogue_finished, CONNECT_ONE_SHOT)
		get_viewport().set_input_as_handled()


func _on_comic_dialogue_finished(finished_comic_dialogue_id: String) -> void:
	if finished_comic_dialogue_id != comic_dialogue_id:
		return
	EnerginkaSystem.spend_energinka(energinka_cost_after_comic_dialogue)


func _create_message_label() -> void:
	_message_label = Label3D.new()
	_message_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_message_label.no_depth_test = false
	_message_label.fixed_size = true
	_message_label.pixel_size = 0.006
	_message_label.font_size = interaction_message_font_size
	_message_label.outline_size = 16
	_message_label.modulate = Color(1, 0.95, 0.45, 1)
	_message_label.outline_modulate = Color(0, 0, 0, 1)
	_message_label.position = prompt_offset
	_message_label.visible = false
	add_child(_message_label)


func _show_interaction_message() -> void:
	if _message_active:
		return
	_message_active = true
	if _prompt:
		_prompt.visible = false
	_message_label.text = interaction_message
	_message_label.visible = true
	EnerginkaSystem.gain_energinka(energinka_restore_after_message)

	var timer := get_tree().create_timer(interaction_message_duration)
	timer.timeout.connect(func() -> void:
		_message_label.visible = false
		_message_active = false
		if _sych_in_range and _prompt:
			_prompt.visible = true
	)
