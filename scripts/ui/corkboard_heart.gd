extends TextureRect
class_name CorkboardHeart

## Сердечко на пробковой доске: UI-представление одного этапа ветки.
## Принимает перетаскиваемую энергинку (available_heart) и отдаёт её обратно, пока план не подтверждён.

signal energinka_dropped(branch_stage_id: String)

const DRAG_TYPE := "corkboard_energinka"
const FILLED_HEART_DRAG_TYPE := "corkboard_filled_heart"

var branch_stage_id: String = ""
var _can_accept: bool = false
var _can_return: bool = false


func setup(stage_id: String, heart_texture: Texture2D, can_accept_energinka: bool, can_return_energinka: bool, icon_size: Vector2, tooltip: String, dim: bool) -> void:
	branch_stage_id = stage_id
	_can_accept = can_accept_energinka
	_can_return = can_return_energinka
	custom_minimum_size = icon_size
	size = icon_size
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture = heart_texture
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
		"type": FILLED_HEART_DRAG_TYPE,
		"branch_stage_id": branch_stage_id,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not _can_accept or EnerginkaSystem.energinka_pool <= 0:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var drag_data: Dictionary = data
	return drag_data.get("type", "") == DRAG_TYPE


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		energinka_dropped.emit(branch_stage_id)


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
