extends TextureRect
class_name EnergyDragIcon

const DRAG_TYPE := "energy_board_energy"
const FILLED_SLOT_DRAG_TYPE := "energy_board_filled_slot"


func setup(texture: Texture2D, icon_size: Vector2) -> void:
	custom_minimum_size = icon_size
	size = icon_size
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	self.texture = texture


func _get_drag_data(_at_position: Vector2) -> Variant:
	if EnergySystem.current_energy <= 0:
		return null

	var preview := _create_drag_preview()
	set_drag_preview(preview)

	return {
		"type": DRAG_TYPE,
	}


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
	var parent := get_parent()
	if parent and parent.has_signal("energy_returned"):
		var drag_data: Dictionary = data
		parent.emit_signal("energy_returned", int(drag_data["slot_index"]))


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
