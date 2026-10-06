extends CanvasLayer
## HUD энергии: сердца справа сверху. Завершение дня переехало в меню по Escape.

const FULL_HEART_PATH := "res://Icon_Energy_Full.png"
const EMPTY_HEART_PATH := "res://Icon_Energy_Empty.png"
const HEART_SIZE := Vector2(80.0, 80.0)
const CREAM := Color(0.93, 0.84, 0.70)

@onready var _hearts: HBoxContainer = $Root/TopRight/Hearts
@onready var _refill_button: Button = $Root/TopRight/RefillEnergyButton

var _full_heart_texture: Texture2D = null
var _empty_heart_texture: Texture2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_full_heart_texture = _load_texture(FULL_HEART_PATH)
	_empty_heart_texture = _load_texture(EMPTY_HEART_PATH)
	_style_refill_button()
	_refill_button.pressed.connect(_on_refill_pressed)
	EnergySystem.energy_changed.connect(_on_energy_changed)
	_on_energy_changed(EnergySystem.current_energy, EnergySystem.max_energy)


func _on_energy_changed(current: int, maximum: int) -> void:
	_ensure_heart_count(maximum)
	for i in range(_hearts.get_child_count()):
		var heart := _hearts.get_child(i) as TextureRect
		heart.texture = _full_heart_texture if i < current else _empty_heart_texture


func _ensure_heart_count(count: int) -> void:
	while _hearts.get_child_count() < count:
		var heart := TextureRect.new()
		heart.custom_minimum_size = HEART_SIZE
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hearts.add_child(heart)

	while _hearts.get_child_count() > count:
		_hearts.get_child(_hearts.get_child_count() - 1).queue_free()


func _style_refill_button() -> void:
	_refill_button.text = "Повысить энергию (R)"
	_refill_button.focus_mode = Control.FOCUS_NONE
	_refill_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_refill_button.tooltip_text = "Тест: восстановить весь пул"
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
	EnergySystem.refill()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		EnergySystem.refill()
		get_viewport().set_input_as_handled()


func _load_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		push_warning("[EnergyHud] Не удалось загрузить иконку энергии: %s" % path)
		return null
	return ImageTexture.create_from_image(image)
