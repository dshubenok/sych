extends Node3D
class_name StreamingDoor

## Бесшовная дверь внутри Территории шараги. По «E» рядом аддитивно
## подгружает локацию за дверью и пристыковывает её к проёму. Дверь остаётся
## открытой до конца дня. Слот кабинета: над проёмом значок энергинки, по «E»
## экран выбора кабинетов из двух вариантов.

const ENERGINKA_ICON_TEXTURE := preload("res://Icon_Energinka_Full.png")
const ICON_BASE_Y := 3.2

@export var target_location_id: StringName
@export var target_entry: StringName = &""
@export var cabinet_energinka_cost: int = 1
## Кабинет уже есть в меше: не стримим заглушку, только открываем проём и ставим вывеску.
@export var in_place: bool = false
@export var sign_anchor: NodePath

var _open: bool = false
var _sych_in_range: bool = false
var _message_label: Label3D = null
var _message_active: bool = false
var _energinka_icon: MeshInstance3D = null
var _energinka_spent: bool = false

func _ready() -> void:
	$InteractionArea.body_entered.connect(_on_body_entered)
	$InteractionArea.body_exited.connect(_on_body_exited)
	$Prompt.visible = false
	_ensure_message_label()
	_ensure_energinka_icon()
	refresh_label()
	call_deferred("_restore_if_opened")

func _process(_delta: float) -> void:
	if _energinka_icon == null or not _energinka_icon.visible:
		return
	_energinka_icon.position.y = ICON_BASE_Y + sin(Time.get_ticks_msec() * 0.003) * 0.08

## id локации, которой принадлежит эта дверь (ищем вверх по дереву).
func owner_location_id() -> StringName:
	var n := get_parent()
	while n:
		var id = n.get("location_id")
		if id != null and id != &"":
			return id
		n = n.get_parent()
	return &""

## Мировой трансформ проёма (+Z смотрит наружу кабинета).
func threshold_transform() -> Transform3D:
	return global_transform

func refresh_label() -> void:
	_ensure_energinka_icon()
	var label := $TargetLabel as Label3D
	var hang_icon := _needs_energinka() and not _open and not _energinka_spent
	_energinka_icon.visible = hang_icon
	if _needs_energinka():
		# Имя кабинета только на 3D-вывеске внутри, не над дверью.
		label.text = ""
		label.visible = false
		return
	label.visible = true
	if target_location_id != &"":
		label.text = "→ %s" % CabinetPool.door_label(target_location_id)


## После ухода домой и возвращения дверь, открытая сегодня, снова открыта.
func _restore_if_opened() -> void:
	if _open:
		return
	var selected := CabinetPool.is_cabinet_slot(target_location_id) and CabinetPool.has_selected_cabinet(target_location_id)
	if not selected and not LocationManager.was_opened_today(target_location_id) \
			and not LocationManager.is_loaded(target_location_id):
		return
	_energinka_spent = true
	if in_place:
		LocationManager.open_in_place_cabinet(self)
	elif LocationManager.is_loaded(target_location_id):
		set_open(true)
	else:
		LocationManager.open_streaming_door(self)


func set_open(value: bool) -> void:
	_open = value
	var shape := get_node_or_null("Blocker/Shape") as CollisionShape3D
	if shape:
		shape.set_deferred("disabled", value)
	if has_node("Slab"):
		$Slab.visible = not value
	if has_node("Prompt"):
		$Prompt.visible = false
	refresh_label()


func _needs_energinka() -> bool:
	return CabinetPool.is_cabinet_slot(target_location_id) and cabinet_energinka_cost > 0


## Открыть дверь. Для слотов кабинетов сначала экран выбора кабинетов.
func open_door() -> bool:
	if _open:
		return true
	if LocationManager.is_loaded(target_location_id):
		if in_place:
			LocationManager.open_in_place_cabinet(self)
		else:
			LocationManager.open_streaming_door(self)
		return true
	if _needs_energinka():
		return _begin_cabinet_choice()
	if in_place:
		LocationManager.open_in_place_cabinet(self)
		return true
	LocationManager.open_streaming_door(self)
	return true


## Вытащить кабинет: списать энергинки за выбранный кабинет и открыть дверь.
## Уже занятый специальный кабинет открывает пустой слот.
func select_cabinet(cabinet_id: StringName) -> bool:
	if _open:
		return true
	if CabinetPool.is_taken(cabinet_id):
		cabinet_id = &""
	var cost: int = CabinetPool.energinka_cost(cabinet_id)
	if not EnerginkaSystem.spend_energinka(cost):
		return false
	if not CabinetPool.select_cabinet(target_location_id, cabinet_id):
		EnerginkaSystem.gain_energinka(cost)
		return false
	_energinka_spent = true
	if in_place:
		LocationManager.open_in_place_cabinet(self)
	else:
		LocationManager.open_streaming_door(self)
	return true


func _begin_cabinet_choice() -> bool:
	if CabinetChoiceUi.is_open():
		return false
	if CabinetPool.get_selected_cabinet(target_location_id) != &"":
		_energinka_spent = true
		if in_place:
			LocationManager.open_in_place_cabinet(self)
		else:
			LocationManager.open_streaming_door(self)
		return true
	var cabinet_choice: Array[StringName] = CabinetPool.cabinet_choice_for(target_location_id)
	if cabinet_choice.is_empty():
		return select_cabinet(&"")
	$Prompt.visible = false
	CabinetChoiceUi.open_for(self, cabinet_choice)
	return true


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"sych"):
		return
	_sych_in_range = true
	if _open:
		return
	# Коридоры и выход — без «E». Энергинка только у кабинетов.
	if not _needs_energinka():
		open_door()
		return
	if not LocationManager.is_loaded(target_location_id) and not _message_active:
		$Prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group(&"sych"):
		return
	_sych_in_range = false
	$Prompt.visible = false


func show_prompt_if_near() -> void:
	if _sych_in_range and not _open and not _message_active:
		$Prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not _sych_in_range or _open:
		return
	if ComicDialogueSystem.is_active() or CabinetChoiceUi.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		open_door()
		get_viewport().set_input_as_handled()


func _ensure_energinka_icon() -> void:
	if _energinka_icon:
		return
	_energinka_icon = MeshInstance3D.new()
	_energinka_icon.name = "EnerginkaIcon"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	_energinka_icon.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ENERGINKA_ICON_TEXTURE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.1
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = false
	_energinka_icon.material_override = mat
	_energinka_icon.position = Vector3(0, ICON_BASE_Y, 0.25)
	_energinka_icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_energinka_icon.visible = false
	add_child(_energinka_icon)


func _ensure_message_label() -> void:
	if _message_label:
		return
	_message_label = Label3D.new()
	_message_label.name = "EnerginkaMessage"
	_message_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_message_label.no_depth_test = false
	_message_label.font_size = 36
	_message_label.outline_size = 12
	_message_label.modulate = Color(1, 0.55, 0.4, 1)
	_message_label.position = Vector3(0, 2.7, 0)
	_message_label.visible = false
	add_child(_message_label)


func _show_message(text: String) -> void:
	_ensure_message_label()
	_message_active = true
	$Prompt.visible = false
	_message_label.text = text
	_message_label.visible = true
	var timer := get_tree().create_timer(1.4, true)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(_message_label):
			return
		_message_label.visible = false
		_message_active = false
		if _sych_in_range and not _open:
			$Prompt.visible = true
	)
