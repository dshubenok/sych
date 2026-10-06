extends CanvasLayer
class_name CabinetChoiceUi

## Модальное окно выбора кабинетов: игрок вытаскивает один из двух. Стоимость в энергинках списывается при выборе.

const ENERGINKA_ICON_PATH := "res://Icon_Energinka_Full.png"
const CARD_COLORS := {
	&"demonologist": Color(0.46, 0.22, 0.34),
	&"library": Color(0.24, 0.28, 0.44),
	&"toilet": Color(0.22, 0.36, 0.34),
	&"greenhouse": Color(0.28, 0.40, 0.22),
	&"historian_cabinet": Color(0.42, 0.32, 0.20),
	&"classroom": Color(0.34, 0.32, 0.30),
	&"assembly_hall": Color(0.40, 0.28, 0.24),
	&"cafeteria": Color(0.38, 0.30, 0.18),
	&"gym": Color(0.22, 0.30, 0.38),
}

const CREAM := Color(0.93, 0.84, 0.70)
const WINDOW_BG := Color(0.14, 0.10, 0.09, 0.98)
const HEADER_BG := Color(0.18, 0.13, 0.11, 1)

static var current: CabinetChoiceUi = null

var _door: StreamingDoor = null
var _message: Label = null
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _energinka_icon: Texture2D = null
var _cabinet_choice: Array = []


static func is_open() -> bool:
	return current != null


static func open_for(door: StreamingDoor, cabinet_choice: Array) -> void:
	if current != null:
		return
	var ui := CabinetChoiceUi.new()
	ui._door = door
	ui._cabinet_choice = cabinet_choice
	var tree := door.get_tree()
	ui._prev_mouse_mode = Input.get_mouse_mode()
	tree.root.add_child(ui)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	tree.paused = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	current = self
	_energinka_icon = load(ENERGINKA_ICON_PATH) as Texture2D
	_build()


func _exit_tree() -> void:
	if current == self:
		current = null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_Q:
			get_viewport().set_input_as_handled()
			_cancel()


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(780, 520)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(wrap)

	var shadow := Panel.new()
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = 10
	shadow.offset_top = 12
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 12, 0))
	wrap.add_child(shadow)

	var window := PanelContainer.new()
	window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.offset_right = -10
	window.offset_bottom = -12
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	var window_style := _flat(WINDOW_BG, CREAM, 12, 3)
	window_style.shadow_color = Color(0, 0, 0, 0.35)
	window_style.shadow_size = 8
	window.add_theme_stylebox_override("panel", window_style)
	wrap.add_child(window)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	window.add_child(body)

	body.add_child(_make_header())

	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 28)
	content.add_theme_constant_override("margin_right", 28)
	content.add_theme_constant_override("margin_top", 20)
	content.add_theme_constant_override("margin_bottom", 20)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)
	content.add_child(inner)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(row)
	for cabinet_id in _cabinet_choice:
		row.add_child(_make_card(cabinet_id))

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 22)
	_message.add_theme_color_override("font_color", Color(1, 0.55, 0.4))
	_message.custom_minimum_size = Vector2(0, 28)
	inner.add_child(_message)

	inner.add_child(_make_cancel_button())


func _make_header() -> PanelContainer:
	var header := PanelContainer.new()
	var header_style := _flat(HEADER_BG, CREAM, 10, 0)
	header_style.corner_radius_bottom_left = 0
	header_style.corner_radius_bottom_right = 0
	header_style.border_width_bottom = 2
	header.add_theme_stylebox_override("panel", header_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	header.add_child(row)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 22)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pad)

	var title := Label.new()
	title.text = "Выберите кабинет"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", CREAM)
	pad.add_child(title)

	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(56, 52)
	close.flat = true
	close.add_theme_font_size_override("font_size", 36)
	close.add_theme_color_override("font_color", CREAM)
	close.add_theme_color_override("font_hover_color", Color(1, 0.7, 0.55))
	close.pressed.connect(_cancel)
	row.add_child(close)
	return header


func _make_cancel_button() -> Button:
	var cancel := Button.new()
	cancel.text = "Отмена"
	cancel.custom_minimum_size = Vector2(180, 44)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := _flat(Color(0.22, 0.16, 0.14), CREAM, 8, 2)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	cancel.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.30, 0.22, 0.18)
	cancel.add_theme_stylebox_override("hover", hover)
	cancel.add_theme_stylebox_override("pressed", hover)
	cancel.add_theme_font_size_override("font_size", 22)
	cancel.add_theme_color_override("font_color", CREAM)
	cancel.pressed.connect(_cancel)
	return cancel


func _make_card(cabinet_id: StringName) -> Button:
	var cost: int = CabinetPool.energinka_cost(cabinet_id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(300, 260)
	card.flat = true
	var bg: Color = CARD_COLORS.get(cabinet_id, Color(0.22, 0.22, 0.28))
	var style := _flat(bg, CREAM, 10, 2)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 24
	style.content_margin_bottom = 18
	card.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.12)
	hover.border_color = Color(1, 0.96, 0.86)
	hover.set_border_width_all(3)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 16)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	var name_label := Label.new()
	name_label.text = CabinetPool.cabinet_title(cabinet_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color(1, 0.96, 0.88))
	inner.add_child(name_label)
	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 8)
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(cost_row)
	for i in range(cost):
		var energinka := TextureRect.new()
		energinka.custom_minimum_size = Vector2(44, 44)
		energinka.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		energinka.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		energinka.texture = _energinka_icon
		energinka.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_row.add_child(energinka)
	card.pressed.connect(_on_select_cabinet.bind(cabinet_id))
	return card


func _flat(bg: Color, border: Color, radius: int = 8, border_w: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_w)
	style.set_corner_radius_all(radius)
	return style


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cancel()


func _on_select_cabinet(cabinet_id: StringName) -> void:
	if _door == null:
		return
	if not _door.select_cabinet(cabinet_id):
		_close()
		return
	_close()


func _cancel() -> void:
	_close()


func _close() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(_prev_mouse_mode)
	if is_instance_valid(_door):
		_door.show_prompt_if_near()
	queue_free()
