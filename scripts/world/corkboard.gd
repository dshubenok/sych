extends Node3D
class_name Corkboard

## Пробковая доска: физический объект в Сычевальне (GDD §5). Одно E: ворчание
## «Что бы такого сделать…» и тем же нажатием открывается 2D-интерфейс планирования
## с паузой и затемнением мира.

const CORKBOARD_UI_SCENE := preload("res://scenes/ui/corkboard_ui.tscn")
const OPEN_LINE := "Что бы такого сделать чтобы нихера не делать?"

@export var slot_count: int = 8

var interaction: Interaction = null

var _active_ui: CorkboardUi = null
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	slot_count = max(1, slot_count)
	interaction = Interaction.ensure(self, 2.4, Vector3(0.0, 2.1, 0.0))
	interaction.vorchanie_pool = [OPEN_LINE]
	interaction.action.connect(_on_action)


func set_interaction_locked(locked: bool) -> void:
	interaction.locked = locked


func _on_action(_interaction: Interaction) -> void:
	_open_corkboard()


func _open_corkboard() -> void:
	if _active_ui != null:
		return
	_active_ui = CORKBOARD_UI_SCENE.instantiate()
	get_tree().root.add_child(_active_ui)
	_active_ui.setup(slot_count)
	_active_ui.closed.connect(_close_corkboard, CONNECT_ONE_SHOT)
	interaction.busy = true
	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true


func _close_corkboard() -> void:
	if _active_ui:
		_active_ui.queue_free()
	_active_ui = null
	get_tree().paused = false
	Input.set_mouse_mode(_prev_mouse_mode)
	interaction.busy = false
