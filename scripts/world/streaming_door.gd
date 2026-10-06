extends Node3D
class_name StreamingDoor

## Бесшовная дверь внутри Территории шараги. По «E» рядом аддитивно
## подгружает локацию за дверью и пристыковывает её к проёму. Дверь остаётся
## открытой до конца дня. Кабинет из пула: над проёмом значок энергии, по «E»
## экран выбора из двух вариантов.

const ENERGY_ICON_TEXTURE := preload("res://Icon_Energy_Full.png")
const ICON_BASE_Y := 3.2

@export var target_location_id: StringName
@export var target_entry: StringName = &""
@export var room_entry_cost: int = 1
## Кабинет уже есть в меше: не стримим заглушку, только открываем проём и ставим вывеску.
@export var in_place: bool = false
@export var sign_anchor: NodePath

var _open: bool = false
var _player_in_range: bool = false
var _message_label: Label3D = null
var _message_active: bool = false
var _energy_icon: MeshInstance3D = null
var _energy_spent: bool = false

func _ready() -> void:
	$InteractionArea.body_entered.connect(_on_body_entered)
	$InteractionArea.body_exited.connect(_on_body_exited)
	$Prompt.visible = false
	_ensure_message_label()
	_ensure_energy_icon()
	refresh_label()
	call_deferred("_restore_if_opened")

func _process(_delta: float) -> void:
	if _energy_icon == null or not _energy_icon.visible:
		return
	_energy_icon.position.y = ICON_BASE_Y + sin(Time.get_ticks_msec() * 0.003) * 0.08

## id локации, которой принадлежит эта дверь (ищем вверх по дереву).
func owner_location_id() -> StringName:
	var n := get_parent()
	while n:
		var id = n.get("location_id")
		if id != null and id != &"":
			return id
		n = n.get_parent()
	return &""

## Мировой трансформ проёма (+Z смотрит наружу комнаты).
func threshold_transform() -> Transform3D:
	return global_transform

func refresh_label() -> void:
	_ensure_energy_icon()
	var label := $TargetLabel as Label3D
	var hang_can := _needs_energy() and not _open and not _energy_spent
	_energy_icon.visible = hang_can
	if _needs_energy():
		# Имя кабинета только на 3D-вывеске внутри, не над дверью.
		label.text = ""
		label.visible = false
		return
	label.visible = true
	if target_location_id != &"":
		label.text = "→ %s" % RoomPool.door_label(target_location_id)


## После ухода домой и возвращения дверь, открытая сегодня, снова открыта.
func _restore_if_opened() -> void:
	if _open:
		return
	var committed := RoomPool.is_slot(target_location_id) and RoomPool.is_committed(target_location_id)
	if not committed and not LocationManager.was_opened_today(target_location_id) \
			and not LocationManager.is_loaded(target_location_id):
		return
	_energy_spent = true
	if in_place:
		LocationManager.open_in_place_room(self)
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


func _needs_energy() -> bool:
	return RoomPool.is_slot(target_location_id) and room_entry_cost > 0


## Попытка открыть дверь. Для кабинетов из пула сначала экран выбора.
func try_open() -> bool:
	if _open:
		return true
	if LocationManager.is_loaded(target_location_id):
		if in_place:
			LocationManager.open_in_place_room(self)
		else:
			LocationManager.open_streaming_door(self)
		return true
	if _needs_energy():
		return _begin_draft()
	if in_place:
		LocationManager.open_in_place_room(self)
		return true
	LocationManager.open_streaming_door(self)
	return true


## Списать энергию за выбранный кабинет и открыть дверь.
## Уже занятая уникальная комната открывает пустой слот.
func apply_choice(room_id: StringName) -> bool:
	if _open:
		return true
	if RoomPool.is_taken(room_id):
		room_id = &""
	var cost: int = RoomPool.entry_cost(room_id)
	if not EnergySystem.try_spend(cost):
		return false
	if not RoomPool.commit(target_location_id, room_id):
		EnergySystem.restore(cost)
		return false
	_energy_spent = true
	if in_place:
		LocationManager.open_in_place_room(self)
	else:
		LocationManager.open_streaming_door(self)
	return true


func _begin_draft() -> bool:
	if RoomDraftUi.is_open():
		return false
	if RoomPool.get_drawn(target_location_id) != &"":
		_energy_spent = true
		if in_place:
			LocationManager.open_in_place_room(self)
		else:
			LocationManager.open_streaming_door(self)
		return true
	var offer: Array[StringName] = RoomPool.offer_for(target_location_id)
	if offer.is_empty():
		return apply_choice(&"")
	$Prompt.visible = false
	RoomDraftUi.open_for(self, offer)
	return true


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_in_range = true
	if _open:
		return
	# Коридоры и выход — без «E». Энергенка только у кабинетов.
	if not _needs_energy():
		try_open()
		return
	if not LocationManager.is_loaded(target_location_id) and not _message_active:
		$Prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_in_range = false
	$Prompt.visible = false


func show_prompt_if_near() -> void:
	if _player_in_range and not _open and not _message_active:
		$Prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or _open:
		return
	if DialogSystem.is_active() or RoomDraftUi.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		try_open()
		get_viewport().set_input_as_handled()


func _ensure_energy_icon() -> void:
	if _energy_icon:
		return
	_energy_icon = MeshInstance3D.new()
	_energy_icon.name = "EnergyIcon"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	_energy_icon.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ENERGY_ICON_TEXTURE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.1
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = false
	_energy_icon.material_override = mat
	_energy_icon.position = Vector3(0, ICON_BASE_Y, 0.25)
	_energy_icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_energy_icon.visible = false
	add_child(_energy_icon)


func _ensure_message_label() -> void:
	if _message_label:
		return
	_message_label = Label3D.new()
	_message_label.name = "EnergyMessage"
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
		if _player_in_range and not _open:
			$Prompt.visible = true
	)
