extends Area3D
class_name Interaction

## Общее взаимодействие (interaction) интерактивного объекта — GDD §7 «Interaction Model».
## Дочерний узел интерактивного объекта. Отвечает за:
##   • зону взаимодействия: своя CollisionShape3D или сфера interaction_radius;
##   • подсказку «E» над объектом, пока Сыч в зоне и взаимодействие доступно;
##   • input-действие `interact` (E): ворчание и/или действие ОДНИМ нажатием;
##   • стоимость в энергинках: списывается до действия; не хватает — действие
##     не выполняется, Сыч говорит «Ой, всё» и DaySystem заканчивает день (GDD §7, §12);
##   • лимит действий на день и смену состояния взаимодействия (InteractionState).
##
## Режимы (GDD §7, план демо §9):
##   только ворчание      — vorchanie_pool не пуст, has_action = false;
##   ворчание + действие  — vorchanie_pool не пуст, has_action = true;
##   только действие      — vorchanie_pool пуст, has_action = true.
## Само действие выполняет владелец — по сигналу `action`.
##
##   var interaction := Interaction.ensure(self, 1.2, Vector3(0, 0.6, 0))
##   interaction.vorchanie_pool = ["Записка? Под моей дверью?"]
##   interaction.action.connect(_open)

const PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")
## Реплика Сыча, когда на платное действие не хватает энергинок (GDD §12).
const OY_VSE_LINE := "Ой, всё"

## Действие взаимодействия: владелец выполняет его здесь (энергинки уже списаны).
signal action(interaction: Interaction)
## Взаимодействие состоялось: ворчание и/или действие выполнены.
signal performed(interaction: Interaction)
## Платное действие не выполнено: не хватило энергинок.
signal action_refused(interaction: Interaction)
signal sych_entered
signal sych_exited

## Радиус сферы зоны, если в сцене нет своей CollisionShape3D.
@export var interaction_radius: float = 1.5:
	set(value):
		interaction_radius = value
		if _auto_shape and _auto_shape.shape is SphereShape3D:
			(_auto_shape.shape as SphereShape3D).radius = value
@export var prompt_offset: Vector3 = Vector3(0.0, 2.2, 0.0):
	set(value):
		prompt_offset = value
		if _prompt:
			_prompt.position = value
## Стоимость действия в энергинках (energinka_cost); 0 — бесплатно.
@export var energinka_cost: int = 0
## Лимит действий на день; 0 — без лимита. Сбрасывается с началом дня.
@export var uses_per_day: int = 0
## Пул ворчания текущего состояния: на каждое взаимодействие — случайная реплика.
@export var vorchanie_pool: PackedStringArray = []
## Есть ли действие. false — объект только ворчит.
@export var has_action: bool = true
## Состояние после выполненного действия (пусто — остаться).
@export var next_state: StringName = &""
## Состояния взаимодействия; активируются через set_interaction_state().
@export var states: Array[InteractionState] = []
## Состояние на старте (пусто — настройки узла как есть).
@export var initial_state: StringName = &""
## Заблокировано: нет подсказки и реакции на E (например, пока не прочитана записка).
@export var locked: bool = false:
	set(value):
		locked = value
		_update_prompt()

## Текущее состояние взаимодействия (interaction_state).
var interaction_state: StringName = &""
## Сколько действий выполнено сегодня.
var uses_today: int = 0
## Действие в процессе (открыт его интерфейс): подсказки и повторного E нет.
var busy: bool = false:
	set(value):
		busy = value
		_update_prompt()

var _sych_in_range: bool = false
var _prompt: Node3D = null
var _auto_shape: CollisionShape3D = null
var _states_by_id: Dictionary = {}


## Вернуть Interaction владельца: дочерний узел «Interaction» или создать новый.
static func ensure(owner_node: Node, radius: float = 1.5, offset: Vector3 = Vector3(0.0, 2.2, 0.0)) -> Interaction:
	var existing := owner_node.get_node_or_null(^"Interaction") as Interaction
	if existing:
		return existing
	var interaction := Interaction.new()
	interaction.name = "Interaction"
	interaction.interaction_radius = radius
	interaction.prompt_offset = offset
	owner_node.add_child(interaction)
	return interaction


func _ready() -> void:
	# Модальные экраны ставят дерево на паузу — тогда E до объектов не доходит.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	monitoring = true
	monitorable = false
	collision_mask = 0xFFFFFFFF
	_ensure_shape()
	_prompt = PROMPT_SCENE.instantiate()
	_prompt.position = prompt_offset
	_prompt.visible = false
	add_child(_prompt)
	for state in states:
		if state and state.id != &"":
			_states_by_id[state.id] = state
	if initial_state != &"":
		set_interaction_state(initial_state)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	if not DaySystem.day_started.is_connected(_on_day_started):
		DaySystem.day_started.connect(_on_day_started)
	_update_prompt()


func _ensure_shape() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			return
	_auto_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = interaction_radius
	_auto_shape.shape = sphere
	add_child(_auto_shape)


## Добавить/заменить состояние из кода (альтернатива экспорту `states`).
func add_state(state: InteractionState) -> void:
	if state == null or state.id == &"":
		return
	_states_by_id[state.id] = state


## Перейти в состояние взаимодействия: применить его ворчание, действие и стоимость.
func set_interaction_state(id: StringName) -> bool:
	var state: InteractionState = _states_by_id.get(id, null)
	if state == null:
		push_warning("[Interaction] Нет состояния «%s» у %s" % [id, get_parent().name if get_parent() else name])
		return false
	interaction_state = id
	vorchanie_pool = state.vorchanie_pool
	has_action = state.has_action
	energinka_cost = state.energinka_cost
	uses_per_day = state.uses_per_day
	next_state = state.next_state
	_update_prompt()
	return true


func is_sych_in_range() -> bool:
	return _sych_in_range


## Действие сейчас доступно (есть, не исчерпан дневной лимит).
func has_action_now() -> bool:
	return has_action and (uses_per_day <= 0 or uses_today < uses_per_day)


## Взаимодействие доступно: не заблокировано, не занято и есть чем ответить на E.
func is_available() -> bool:
	if locked or busy:
		return false
	return has_action_now() or not vorchanie_pool.is_empty()


## Взаимодействие по одному нажатию E: ворчание и/или действие.
## Возвращает true, если что-то произошло (ворчание и/или действие).
func interact() -> bool:
	if not is_available():
		return false
	var do_action := has_action_now()
	if do_action and energinka_cost > 0 and not EnerginkaSystem.can_spend_energinka(energinka_cost):
		# Не хватает энергинок: действие не выполняется, Сыч говорит «Ой, всё»,
		# неудачная трата запускает завершение дня в DaySystem.
		VorchanieSystem.vorchat(OY_VSE_LINE)
		EnerginkaSystem.spend_energinka(energinka_cost)
		action_refused.emit(self)
		_update_prompt()
		return false
	if not vorchanie_pool.is_empty():
		VorchanieSystem.vorchat(vorchanie_pool[randi() % vorchanie_pool.size()])
	if do_action:
		if energinka_cost > 0:
			EnerginkaSystem.spend_energinka(energinka_cost)
		uses_today += 1
		action.emit(self)
		if next_state != &"":
			set_interaction_state(next_state)
	performed.emit(self)
	_update_prompt()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _sych_in_range or not is_available():
		return
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		interact()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"sych"):
		return
	_sych_in_range = true
	_update_prompt()
	sych_entered.emit()


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group(&"sych"):
		return
	_sych_in_range = false
	_update_prompt()
	sych_exited.emit()


func _on_day_started(_day: int) -> void:
	uses_today = 0
	_update_prompt()


## Подсказка «E» видна, пока Сыч в зоне и взаимодействие доступно.
func _update_prompt() -> void:
	if _prompt:
		_prompt.visible = _sych_in_range and is_available()
