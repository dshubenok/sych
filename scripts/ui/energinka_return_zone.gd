extends HBoxContainer
class_name EnerginkaReturnZone

## Блок доступных энергинок на пробковой доске: сюда возвращают энергинку из сердечка.

signal energinka_returned(slot_index: int)

const FILLED_HEART_DRAG_TYPE := "corkboard_filled_heart"


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if EnerginkaSystem.energinka_pool >= EnerginkaSystem.max_energinka:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var drag_data: Dictionary = data
	return drag_data.get("type", "") == FILLED_HEART_DRAG_TYPE and drag_data.has("slot_index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var drag_data: Dictionary = data
	energinka_returned.emit(int(drag_data["slot_index"]))
