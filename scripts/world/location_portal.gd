extends Area3D
class_name LocationPortal

## Дверь/переход в другую локацию. По умолчанию срабатывает, когда Сыч входит в зону;
## в ручном режиме (auto_travel = false) — через общее взаимодействие Interaction:
## одно E — ворчание («Наружа. Вэээ.») и тем же нажатием переход (план демо §2.4).

@export var target_location_id: StringName
@export var target_entry: StringName = &""
## true — переход сразу при входе в зону; false — только по E.
@export var auto_travel: bool = true
@export var prompt_offset: Vector3 = Vector3(0.0, 2.2, 0.0)
## Ворчание Сыча при выходе; переход происходит тем же E.
@export var vorchanie_before_travel: String = ""
## Дверь открывается только после подтверждённого плана на доске.
@export var unlock_on_plan: bool = false

## Пока true, переход не срабатывает и «E» не показывается.
var interaction_locked: bool = false
var interaction: Interaction = null

var _sych_in_range: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_mask = 0xFFFFFFFF
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_label()
	if not auto_travel:
		_ensure_interaction()
	if unlock_on_plan:
		set_interaction_locked(not BranchSystem.has_confirmed_plan())
		if not BranchSystem.branch_stage_planned.is_connected(_on_plan_confirmed):
			BranchSystem.branch_stage_planned.connect(_on_plan_confirmed)

## Зона взаимодействия повторяет зону портала (его CollisionShape3D).
func _ensure_interaction() -> void:
	interaction = get_node_or_null(^"Interaction") as Interaction
	if interaction == null:
		interaction = Interaction.new()
		interaction.name = "Interaction"
		interaction.prompt_offset = prompt_offset
		var own_shape := get_node_or_null(^"CollisionShape3D") as CollisionShape3D
		if own_shape and own_shape.shape:
			var copy := CollisionShape3D.new()
			copy.shape = own_shape.shape
			copy.transform = own_shape.transform
			interaction.add_child(copy)
		add_child(interaction)
	if vorchanie_before_travel != "":
		interaction.vorchanie_pool = [vorchanie_before_travel]
	interaction.locked = interaction_locked
	interaction.action.connect(_on_interaction_action)

func _on_plan_confirmed(_branch_stage_id: String) -> void:
	if unlock_on_plan:
		set_interaction_locked(false)

func set_interaction_locked(locked: bool) -> void:
	interaction_locked = locked
	var label := get_node_or_null(^"Label") as Node3D
	if label:
		label.visible = not locked
	if interaction:
		interaction.locked = locked

func _on_interaction_action(_interaction: Interaction) -> void:
	_travel()

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"sych"):
		return
	_sych_in_range = true
	if auto_travel and not interaction_locked:
		_travel()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group(&"sych"):
		_sych_in_range = false

## Ручной переход (например, из кода или теста).
func interact() -> void:
	if interaction:
		interaction.interact()
	else:
		_travel()

func _travel() -> void:
	if target_location_id == &"":
		push_warning("[LocationPortal] target_location_id не задан на %s" % name)
		return
	# Выход из Сычевальни — переход с трамваем, затем Шарага (GDD §2, §4; план демо §5).
	if target_location_id == &"sharaga" and LocationManager.current_location_id == &"sychevalnya":
		TramTransition.play(target_location_id, target_entry)
		return
	LocationManager.travel_to(target_location_id, target_entry)

func _update_label() -> void:
	var label := get_node_or_null(^"Label") as Label3D
	if label and target_location_id != &"":
		label.text = "→ %s" % LocationRegistry.get_title(target_location_id)
