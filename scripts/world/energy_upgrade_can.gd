extends Node3D
class_name EnergyUpgradeCan

## Банка в мире: по «E» выпивается, исчезает, максимум энергии растёт навсегда.

const INTERACTION_PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")

@export var upgrade_id: StringName = &"sharaga_can"
@export var energy_bonus: int = 1
@export var interaction_radius: float = 2.0
@export var prompt_offset: Vector3 = Vector3(0.0, 3.05, 0.0)
@export var interaction_message: String = "ФФФФФЬЬЬ"
@export var interaction_message_font_size: int = 20
@export var interaction_message_duration: float = 2.0

var _player_in_range: bool = false
var _prompt: Node3D = null
var _message_label: Label3D = null
var _drunk: bool = false


func _ready() -> void:
	if EnergySystem.has_upgrade(upgrade_id):
		queue_free()
		return
	_ensure_area()
	_prompt = INTERACTION_PROMPT_SCENE.instantiate()
	add_child(_prompt)
	_prompt.position = prompt_offset
	_prompt.visible = false
	var e_label := _prompt.get_node_or_null("Label3D") as Label3D
	if e_label:
		e_label.font_size = 48
		e_label.outline_size = 8
		e_label.pixel_size = 0.004
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
	if _drunk:
		return
	if body.is_in_group(&"player"):
		_player_in_range = true
		if _prompt:
			_prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group(&"player"):
		_player_in_range = false
		if _prompt:
			_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _drunk or not _player_in_range:
		return
	if DialogSystem.is_active() or RoomDraftUi.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_drink()
		get_viewport().set_input_as_handled()


func _drink() -> void:
	if _drunk:
		return
	if not EnergySystem.collect_upgrade(upgrade_id, energy_bonus):
		queue_free()
		return
	_drunk = true
	if _prompt:
		_prompt.visible = false
	var mesh := get_node_or_null("MeshInstance3D") as Node
	if mesh:
		mesh.visible = false
	_show_drink_message()


func _create_message_label() -> void:
	_message_label = Label3D.new()
	_message_label.name = "DrinkMessage"
	_message_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_message_label.no_depth_test = false
	_message_label.fixed_size = true
	_message_label.pixel_size = 0.004
	_message_label.font_size = interaction_message_font_size
	_message_label.outline_size = 8
	_message_label.modulate = Color(1, 0.95, 0.45, 1)
	_message_label.outline_modulate = Color(0, 0, 0, 1)
	_message_label.position = prompt_offset
	_message_label.visible = false
	add_child(_message_label)


func _show_drink_message() -> void:
	if _message_label == null:
		queue_free()
		return
	_message_label.text = interaction_message
	_message_label.visible = true
	var timer := get_tree().create_timer(interaction_message_duration)
	timer.timeout.connect(func() -> void:
		queue_free()
	)
