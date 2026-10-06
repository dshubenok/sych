extends Node3D

## Комикс в Сычевальне — источник энергинок. Пока записка не прочитана — без «E».
## Первое «E» — ворчание, второе — +1 энергинка, дальше пул ворчания.

const PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")

const INTRO_LINE := "Комикс про то, как один Пингвин не справляется. Охренительный."
## Пул ворчания после прочтения.
const DONE_LINES: PackedStringArray = [
	"Всё, начиталась",
	"Не",
	"Уф, буквы",
]

enum Phase { INTRO, READ, LOOP }

@export var interaction_radius: float = 1.05
@export var prompt_offset: Vector3 = Vector3(0.0, 0.7, 0.0)
@export var energinka_reward: int = 1

var interaction_locked: bool = false

var _phase: Phase = Phase.INTRO
var _sych_in_range: bool = false
var _prompt: Node3D


func _ready() -> void:
	_ensure_area()
	_prompt = PROMPT_SCENE.instantiate()
	add_child(_prompt)
	_prompt.position = prompt_offset
	_prompt.visible = false


func set_interaction_locked(locked: bool) -> void:
	interaction_locked = locked
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if interaction_locked or not _sych_in_range:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_on_interact()
		get_viewport().set_input_as_handled()


func _on_interact() -> void:
	match _phase:
		Phase.INTRO:
			_phase = Phase.READ
			_vorchat(INTRO_LINE)
		Phase.READ:
			EnerginkaSystem.gain_energinka(energinka_reward)
			_phase = Phase.LOOP
		Phase.LOOP:
			_vorchat(DONE_LINES[randi() % DONE_LINES.size()])


func _vorchat(line: String) -> void:
	if VorchanieSystem.vorchat(line, true, false):
		VorchanieSystem.finished.connect(_update_prompt, CONNECT_ONE_SHOT)
	_update_prompt()


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
	if body.is_in_group(&"sych"):
		_sych_in_range = true
		_update_prompt()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group(&"sych"):
		_sych_in_range = false
		_update_prompt()


func _update_prompt() -> void:
	if _prompt:
		_prompt.visible = _sych_in_range and not interaction_locked
