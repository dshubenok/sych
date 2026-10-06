extends TextureRect
class_name EnergyBoardSlot

signal energy_dropped(slot_index: int)

const DRAG_TYPE := "energy_board_energy"
const FILLED_SLOT_DRAG_TYPE := "energy_board_filled_slot"

var slot_index: int = -1
var _can_accept: bool = false
var _can_return: bool = false


func setup(index: int, slot_texture: Texture2D, can_accept_energy: bool, can_return_energy: bool, icon_size: Vector2, tooltip: String, dim: bool) -> void:
	slot_index = index
	_can_accept = can_accept_energy
	_can_return = can_return_energy
	custom_minimum_size = icon_size
	size = icon_size
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture = slot_texture
	tooltip_text = tooltip
	modulate = Color(1, 1, 1, 0.45) if dim else Color(1, 1, 1, 1)
	if _can_return:
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	elif _can_accept:
		mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _can_return:
		return null

	var preview := _create_drag_preview()
	set_drag_preview(preview)

	return {
		"type": FILLED_SLOT_DRAG_TYPE,
		"slot_index": slot_index,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not _can_accept or EnergySystem.current_energy <= 0:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var drag_data: Dictionary = data
	return drag_data.get("type", "") == DRAG_TYPE


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		energy_dropped.emit(slot_index)


func _create_drag_preview() -> Control:
	var preview_size := size
	if preview_size.x <= 0.0 or preview_size.y <= 0.0:
		preview_size = custom_minimum_size

	var preview_root := Control.new()
	preview_root.custom_minimum_size = preview_size
	preview_root.size = preview_size
	preview_root.clip_contents = true

	var preview_icon := TextureRect.new()
	preview_icon.texture = texture
	preview_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon.modulate = Color(1, 1, 1, 0.85)
	preview_root.add_child(preview_icon)

	return preview_root
