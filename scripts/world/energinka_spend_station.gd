extends Node3D
class_name EnerginkaSpendStation
## Тестовая точка расхода энергинок на локации.
## Нужна, чтобы проверять истощение дня без полноценного энкаунтера.

const INTERACTION_PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")

@export var interaction_radius: float = 2.0
@export var prompt_offset: Vector3 = Vector3(0.0, 2.2, 0.0)
@export var energinka_cost: int = 1
@export var success_message: String = "Минус энергинка"
@export var no_energinka_message: String = "Нет энергинок"
@export var message_duration: float = 1.4

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
	if not _sych_in_range or ComicDialogueSystem.is_active():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_spend_energinka()
		get_viewport().set_input_as_handled()


func _spend_energinka() -> void:
	var spent := EnerginkaSystem.spend_energinka(energinka_cost)
	_show_message(success_message if spent else no_energinka_message)


func _create_message_label() -> void:
	_message_label = Label3D.new()
	_message_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_message_label.no_depth_test = false
	_message_label.fixed_size = true
	_message_label.pixel_size = 0.006
	_message_label.font_size = 36
	_message_label.outline_size = 14
	_message_label.modulate = Color(1, 0.95, 0.45, 1)
	_message_label.outline_modulate = Color(0, 0, 0, 1)
	_message_label.position = prompt_offset
	_message_label.visible = false
	add_child(_message_label)


func _show_message(text: String) -> void:
	_message_active = true
	if _prompt:
		_prompt.visible = false
	_message_label.text = text
	_message_label.visible = true

	var timer := get_tree().create_timer(message_duration, true)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(_message_label):
			return
		_message_label.visible = false
		_message_active = false
		if _sych_in_range and _prompt:
			_prompt.visible = true
	)
