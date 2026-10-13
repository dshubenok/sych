extends Node3D
class_name EncounterItem
## Предмет энкаунтера сбора в мире: надпись на стене в Туалете (ответ 1), энкаунтер сбора
## слухов в Актовом зале (ответ 3), ошейник на Складе. Стоит в кабинете всегда
## (стабильное содержимое, план демо §6); «нужным» его делает активный этап ветки.
## По E:
##   • предмет нужен активному энкаунтеру → ворчание + предмет зачтён (BranchSystem.collect_item);
##   • предмет уже получен → ворчание «уже взято» (ошейник при этом исчезает из мира);
##   • никому не нужен → ворчание «пока не нужно» (объект остаётся на месте).
## Шаблон зоны E повторяет остальные интерактивные объекты; общий компонент
## взаимодействия (поток A) должен заменить его, не трогая логику предмета.

const INTERACTION_PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")

## Идентификатор предмета (BranchSystem.ITEM_*).
@export var item_id: String = ""
## Ворчание Сыча, когда предмет получен (контент — поток G).
@export_multiline var vorchanie_on_collect: String = ""
## Пул ворчания, когда предмет никому сейчас не нужен (контент — поток G).
@export var vorchanie_not_wanted: PackedStringArray = []
## Пул ворчания, когда предмет уже получен раньше (контент — поток G).
@export var vorchanie_already_collected: PackedStringArray = []
## Убирать объект из мира после получения (ошейник — да, надпись на стене — нет).
@export var hide_when_collected: bool = false
@export var interaction_radius: float = 2.0
@export var prompt_offset: Vector3 = Vector3(0.0, 2.0, 0.0)

var _sych_in_range: bool = false
var _prompt: Node3D = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_ensure_area()
	_prompt = INTERACTION_PROMPT_SCENE.instantiate()
	add_child(_prompt)
	_prompt.position = prompt_offset
	_prompt.visible = false
	if not BranchSystem.item_collected.is_connected(_on_item_collected):
		BranchSystem.item_collected.connect(_on_item_collected)
	_apply_collected_visibility()


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
	if not _sych_in_range or not visible:
		return
	if ComicDialogueSystem.is_active() or VorchanieSystem.is_active():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		interact()
		get_viewport().set_input_as_handled()


func is_collected() -> bool:
	return BranchSystem.is_item_collected(item_id)


## Взаимодействие с предметом. Возвращает true, если предмет получен этим нажатием.
func interact() -> bool:
	if is_collected():
		_vorchat_from(vorchanie_already_collected)
		return false
	if BranchSystem.collect_item(item_id):
		if vorchanie_on_collect != "":
			VorchanieSystem.vorchat(vorchanie_on_collect, true)
		_apply_collected_visibility()
		return true
	_vorchat_from(vorchanie_not_wanted)
	return false


func _on_item_collected(collected_item_id: String) -> void:
	if collected_item_id == item_id:
		_apply_collected_visibility()


func _apply_collected_visibility() -> void:
	if hide_when_collected and is_collected():
		visible = false
		_sych_in_range = false
	_refresh_prompt()


func _refresh_prompt() -> void:
	if _prompt:
		_prompt.visible = _sych_in_range and visible


func _vorchat_from(pool: PackedStringArray) -> void:
	if pool.is_empty():
		return
	VorchanieSystem.vorchat(pool[_rng.randi_range(0, pool.size() - 1)], true)
