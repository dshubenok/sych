extends HBoxContainer
class_name EnergyReturnZone

signal energy_returned(slot_index: int)

const FILLED_SLOT_DRAG_TYPE := "energy_board_filled_slot"


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if EnergySystem.current_energy >= EnergySystem.max_energy:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var drag_data: Dictionary = data
	return drag_data.get("type", "") == FILLED_SLOT_DRAG_TYPE and drag_data.has("slot_index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var drag_data: Dictionary = data
	energy_returned.emit(int(drag_data["slot_index"]))
