extends CanvasLayer
## HUD энергинок: иконки энергинок справа сверху. Завершение дня переехало в меню по Escape.

const FULL_ENERGINKA_PATH := "res://Icon_Energinka_Full.png"
const EMPTY_ENERGINKA_PATH := "res://Icon_Energinka_Empty.png"
const ENERGINKA_SIZE := Vector2(80.0, 80.0)
const CREAM := Color(0.93, 0.84, 0.70)

@onready var _energinkas: HBoxContainer = $Root/TopRight/Energinkas
@onready var _refill_button: Button = $Root/TopRight/RefillEnerginkaButton

var _full_energinka_texture: Texture2D = null
var _empty_energinka_texture: Texture2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_full_energinka_texture = _load_texture(FULL_ENERGINKA_PATH)
	_empty_energinka_texture = _load_texture(EMPTY_ENERGINKA_PATH)
	_style_refill_button()
	_refill_button.pressed.connect(_on_refill_pressed)
	EnerginkaSystem.energinka_changed.connect(_on_energinka_changed)
	_on_energinka_changed(EnerginkaSystem.energinka_pool, EnerginkaSystem.max_energinka)


func _on_energinka_changed(current: int, maximum: int) -> void:
	_ensure_energinka_count(maximum)
	for i in range(_energinkas.get_child_count()):
		var energinka := _energinkas.get_child(i) as TextureRect
		energinka.texture = _full_energinka_texture if i < current else _empty_energinka_texture


func _ensure_energinka_count(count: int) -> void:
	while _energinkas.get_child_count() < count:
		var energinka := TextureRect.new()
		energinka.custom_minimum_size = ENERGINKA_SIZE
		energinka.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		energinka.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_energinkas.add_child(energinka)

	while _energinkas.get_child_count() > count:
		_energinkas.get_child(_energinkas.get_child_count() - 1).queue_free()


func _style_refill_button() -> void:
	_refill_button.text = "Восстановить энергинки (R)"
	_refill_button.focus_mode = Control.FOCUS_NONE
	_refill_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_refill_button.tooltip_text = "Тест: восстановить весь пул энергинок"
	_refill_button.add_theme_font_size_override("font_size", 22)
	_refill_button.add_theme_color_override("font_color", CREAM)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.10, 0.09, 0.92)
	style.border_color = CREAM
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_refill_button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.16, 0.14, 0.95)
	_refill_button.add_theme_stylebox_override("hover", hover)
	_refill_button.add_theme_stylebox_override("pressed", hover)


func _on_refill_pressed() -> void:
	EnerginkaSystem.refill()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		EnerginkaSystem.refill()
		get_viewport().set_input_as_handled()


func _load_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		push_warning("[EnerginkaHud] Не удалось загрузить иконку энергинки: %s" % path)
		return null
	return ImageTexture.create_from_image(image)
