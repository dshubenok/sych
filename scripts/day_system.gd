extends Node
## Глобальный игровой цикл дня:
## пробуждение → планирование/Шарага → истощение → итоги → новый день.

signal day_started(day_number: int)
signal day_ending(day_number: int)
signal day_ended(day_number: int)

const WAKEUP_COST := 2
const UI_LAYER := 220
const ENERGY_ICON_SIZE := Vector2(64.0, 64.0)
const BUTTON_ENERGY_ICON_SIZE := Vector2(54.0, 54.0)
const FULL_ENERGY_PATH := "res://Icon_Energy_Full.png"
const RESULTS_IMAGE_PATH := "res://assets/ui/itogi.jpg"
const FADE_IN_TIME := 1.125
const FADE_OUT_TIME := 1.125

var day_number: int = 1
## Записка старосты обязательна только один раз. Дальше не блокирует доску и выход.
var starosta_note_read: bool = false
## Только для разработки: при запуске из редактора записка считается прочитанной
## с самого начала. В экспортированной игре не действует. Выключить — false.
# TODO: перед релизом убрать этот флаг и его проверку в scripts/world/floor_note.gd.
const DEV_SKIP_STAROSTA_NOTE := true

var _energy_texture: Texture2D = null
var _results_texture: Texture2D = null
var _wakeup_layer: CanvasLayer = null
var _overlay_layer: CanvasLayer = null
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _spent_today: int = 0
var _ending_day: bool = false
var _waking_up: bool = true
## Тесты выключают автозавершение, чтобы неудачный try_spend не вешал headless.
var end_on_failed_spend: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_waking_up = true
	_energy_texture = _load_texture(FULL_ENERGY_PATH)
	_results_texture = _load_texture(RESULTS_IMAGE_PATH)
	EnergySystem.energy_spent.connect(_on_energy_spent)
	EnergySystem.energy_spend_failed.connect(_on_energy_spend_failed)


## Начать день. Зовёт игровая сцена: в меню запуска экран пробуждения не нужен.
func begin_day() -> void:
	_show_wakeup_screen()


## keep_overlay: экран итогов остаётся сверху и гаснет уже поверх пробуждения,
## иначе между ними на кадр-другой проглядывает игровой мир.
func _show_wakeup_screen(keep_overlay: bool = false) -> void:
	_clear_layer(_wakeup_layer)
	if not keep_overlay:
		_clear_layer(_overlay_layer)
	_wakeup_layer = CanvasLayer.new()
	_wakeup_layer.layer = UI_LAYER
	_wakeup_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_wakeup_layer)

	EnergySystem.refill()
	_spent_today = 0
	_ending_day = false
	_waking_up = true
	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

	var root := _make_fullscreen_root()
	_wakeup_layer.add_child(root)
	# Полностью непрозрачный и сразу, без проявления: мир виден быть не должен.
	var dim := _make_dim(Color(0.0, 0.0, 0.0, 1.0))
	root.add_child(dim)

	var energy_row := HBoxContainer.new()
	energy_row.anchor_left = 0.055
	energy_row.anchor_top = 0.08
	energy_row.anchor_right = 0.34
	energy_row.anchor_bottom = 0.18
	energy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	energy_row.add_theme_constant_override("separation", 12)
	root.add_child(energy_row)
	for i in range(EnergySystem.max_energy):
		var icon := TextureRect.new()
		icon.texture = _energy_texture
		icon.custom_minimum_size = ENERGY_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		energy_row.add_child(icon)

	var title := _make_label("проснуться?", 40)
	title.anchor_left = 0.34
	title.anchor_top = 0.27
	title.anchor_right = 0.66
	title.anchor_bottom = 0.38
	root.add_child(title)

	var wake_button := _make_wakeup_button()
	wake_button.anchor_left = 0.39
	wake_button.anchor_top = 0.52
	wake_button.anchor_right = 0.61
	wake_button.anchor_bottom = 0.64
	root.add_child(wake_button)


func is_day_active() -> bool:
	return not _waking_up and not _ending_day


func request_end_day() -> void:
	if not is_day_active():
		return
	_end_day()


func _start_day() -> void:
	if not _waking_up:
		return
	_fade_out_and_clear(_wakeup_layer, FADE_OUT_TIME)
	EnergySystem.try_spend(WAKEUP_COST)
	_spent_today += WAKEUP_COST
	_waking_up = false
	get_tree().paused = false
	Input.set_mouse_mode(_prev_mouse_mode)
	_show_temporary_overlay("День %d" % day_number, 1.8, 0.74)
	day_started.emit(day_number)


func _on_energy_spend_failed(_amount: int) -> void:
	if not end_on_failed_spend or _waking_up or _ending_day:
		return
	call_deferred("_end_day")


func _on_energy_spent(amount: int) -> void:
	if _waking_up:
		return
	_spent_today += amount


func _end_day() -> void:
	if _ending_day or _waking_up:
		return
	_ending_day = true
	day_ending.emit(day_number)
	if RoomDraftUi.is_open() and is_instance_valid(RoomDraftUi.current):
		RoomDraftUi.current.queue_free()
	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	_show_temporary_overlay("Ой, всё", 1.8, 0.96)
	await get_tree().create_timer(1.9, true).timeout
	_show_results_screen()


func _show_results_screen() -> void:
	_clear_layer(_overlay_layer)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = UI_LAYER + 1
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_overlay_layer)

	var root := _make_fullscreen_root()
	_overlay_layer.add_child(root)
	var background := TextureRect.new()
	background.texture = _results_texture
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	root.add_child(_make_dim(Color(0.0, 0.0, 0.0, 0.18)))
	_fade_in_layer(_overlay_layer, FADE_IN_TIME)

	var box := VBoxContainer.new()
	box.anchor_left = 0.22
	box.anchor_top = 0.25
	box.anchor_right = 0.62
	box.anchor_bottom = 0.63
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)

	box.add_child(_make_results_label("Итоги дня %d" % day_number, 38))
	box.add_child(_make_results_label("Потрачено энергинок: %d" % _spent_today, 27))
	box.add_child(_make_results_label("Сделано: тестовые события дня", 25))
	box.add_child(_make_results_label("Как распорядился днём: день завершён", 25))

	var button := Button.new()
	button.text = "Новый день"
	button.anchor_left = 0.39
	button.anchor_top = 0.78
	button.anchor_right = 0.61
	button.anchor_bottom = 0.88
	button.add_theme_font_size_override("font_size", 36)
	button.pressed.connect(_finish_results)
	root.add_child(button)


func _finish_results() -> void:
	day_ended.emit(day_number)
	day_number += 1
	_show_wakeup_screen(true)
	_fade_out_and_clear(_overlay_layer, FADE_OUT_TIME)


func _show_temporary_overlay(text: String, seconds: float, dim_alpha: float = 0.82) -> void:
	_clear_layer(_overlay_layer)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = UI_LAYER
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_overlay_layer)

	var root := _make_fullscreen_root()
	_overlay_layer.add_child(root)
	root.add_child(_make_dim(Color(0.0, 0.0, 0.0, dim_alpha)))
	var label := _make_label(text, 56)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.offset_left = -360.0
	label.offset_top = -60.0
	label.offset_right = 360.0
	label.offset_bottom = 60.0
	root.add_child(label)
	_fade_in_layer(_overlay_layer, FADE_IN_TIME)

	var layer_ref := _overlay_layer
	var timer := get_tree().create_timer(seconds, true)
	timer.timeout.connect(func() -> void:
		_fade_out_and_clear(layer_ref, FADE_OUT_TIME)
	)


func _make_fullscreen_root() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	return root


func _make_dim(color: Color) -> ColorRect:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = color
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dim


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 0.94, 0.72, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 8)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_results_label(text: String, font_size: int) -> Label:
	var label := _make_label(text, font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color(1, 0.93, 0.98, 1))
	label.add_theme_color_override("font_outline_color", Color(0.18, 0.03, 0.12, 1))
	label.add_theme_constant_override("outline_size", 10)
	return label


func _make_wakeup_button() -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_start_day)

	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	button.add_child(content)

	var label := _make_label("да", 48)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(86.0, 62.0)
	content.add_child(label)

	for i in range(WAKEUP_COST):
		var icon := TextureRect.new()
		icon.texture = _energy_texture
		icon.custom_minimum_size = BUTTON_ENERGY_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)

	return button


func _clear_layer(layer: Variant) -> void:
	if not is_instance_valid(layer):
		return
	if layer is CanvasLayer:
		layer.queue_free()


func _fade_in_layer(layer: CanvasLayer, duration: float) -> void:
	if not is_instance_valid(layer):
		return
	var target := _get_fade_target(layer)
	if target == null:
		return
	target.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(target, "modulate:a", 1.0, duration)


func _fade_out_and_clear(layer: Variant, duration: float, after_clear: Callable = Callable()) -> void:
	if not is_instance_valid(layer) or not layer is CanvasLayer:
		if after_clear.is_valid():
			after_clear.call()
		return
	var target := _get_fade_target(layer)
	if target == null:
		_clear_layer(layer)
		if after_clear.is_valid():
			after_clear.call()
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(target, "modulate:a", 0.0, duration)
	tween.finished.connect(func() -> void:
		_clear_layer(layer)
		if after_clear.is_valid():
			after_clear.call()
	)


func _get_fade_target(layer: CanvasLayer) -> Control:
	if not is_instance_valid(layer):
		return null
	for child in layer.get_children():
		if child is Control:
			return child
	return null


func _load_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		push_warning("[DaySystem] Не удалось загрузить текстуру: %s" % path)
		return null
	return ImageTexture.create_from_image(image)
