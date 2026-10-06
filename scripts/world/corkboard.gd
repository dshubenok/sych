extends Node3D
class_name Corkboard

## Пробковая доска: физический объект в Сычевальне, по «E» открывает 2D-интерфейс планирования дня.

const INTERACTION_PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")
const CORKBOARD_UI_SCENE := preload("res://scenes/ui/corkboard_ui.tscn")

@export var interaction_radius: float = 2.4
@export var prompt_offset: Vector3 = Vector3(0.0, 2.1, 0.0)
@export var slot_count: int = 8

var _sych_in_range: bool = false
var _prompt: Node3D = null
var _active_ui: CorkboardUi = null
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
## Пока true, подсказка «E» скрыта и доска не открывается.
var interaction_locked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	slot_count = max(1, slot_count)
	_ensure_area()
	_prompt = INTERACTION_PROMPT_SCENE.instantiate()
	add_child(_prompt)
	_prompt.position = prompt_offset
	_prompt.visible = false


func set_interaction_locked(locked: bool) -> void:
	interaction_locked = locked
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if interaction_locked or not _sych_in_range or _active_ui != null:
		return
	if ComicDialogueSystem.is_active() or VorchanieSystem.is_active():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_open_corkboard()
		get_viewport().set_input_as_handled()


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
		_update_prompt()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group(&"sych"):
		_sych_in_range = false
		_update_prompt()


func _update_prompt() -> void:
	if _prompt:
		_prompt.visible = _sych_in_range and not interaction_locked and _active_ui == null


func _open_corkboard() -> void:
	if _active_ui != null:
		return

	_active_ui = CORKBOARD_UI_SCENE.instantiate()
	get_tree().root.add_child(_active_ui)
	_active_ui.setup(slot_count)
	_active_ui.closed.connect(_close_corkboard, CONNECT_ONE_SHOT)

	_update_prompt()
	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	VorchanieSystem.vorchat("Что бы такого сделать чтобы нихера не делать?")


func _close_corkboard() -> void:
	if _active_ui:
		_active_ui.queue_free()
	_active_ui = null
	get_tree().paused = false
	Input.set_mouse_mode(_prev_mouse_mode)
	_update_prompt()
