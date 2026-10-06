extends CanvasLayer
class_name CorkboardUi

## 2D-интерфейс пробковой доски: планирование дня. Энергинка вкладывается в сердечко
## перетаскиванием, «ок» подтверждает план.

signal closed

const ENERGINKA_ICON_PATH := "res://Icon_Energinka_Full.png"
const KOTIK_EMPTY_HEART_PATH := "res://Board_Test_Cut/Heart_Kotik_Empty.png"
const KOTIK_SELECTED_HEART_PATH := "res://Board_Test_Cut/Heart_Kotik_Selected.png"
const KOTIK_ACTIVE_HEART_PATH := "res://Board_Test_Cut/Heart_Kotik_Active.png"
const KOTIK_COMPLETED_HEART_PATH := "res://Board_Test_Cut/Heart_Kotik_Completed.png"
const LISIK_EMPTY_HEART_PATH := "res://Board_Test_Cut/Heart_Lisik_Empty.png"
const LISIK_SELECTED_HEART_PATH := "res://Board_Test_Cut/Heart_Lisik_Selected.png"
const LISIK_ACTIVE_HEART_PATH := "res://Board_Test_Cut/Heart_Lisik_Active.png"
const LISIK_COMPLETED_HEART_PATH := "res://Board_Test_Cut/Heart_Lisik_Completed.png"
const ENERGINKA_ICON_SIZE := Vector2(34.0, 67.0)
const HEART_SIZE := Vector2(96.0, 96.0)
const STICKER_ROTATION_DEG := 17.5
const STICKER_LINES: PackedStringArray = [
	"1. беру энергинку, которых",
	"у меня и так мало",
	"2. перетаскиваю в пустое",
	"сердечко",
	"3. ок - принимаю решение",
	"работать в этот проект",
]
const STICKER_LINE_COUNT := 6
const ENERGINKA_GAP_RATIO := 0.12
const HEART_GAP_RATIO := 0.23
const HISTORIAN_SLOTS: Array[int] = [4, 5, -1]
const KOTIK_SLOTS: Array[int] = [0, -1, -1]
const OPEN_LINE := "Что бы такого сделать чтобы нихера не делать?"
const CONFIRM_LINE := "Дальше надо перестать планировать и реализовать план. Как? Да хрен его знает, на месте разберемся."
const HISTORIAN_COMMENT := "Кому вообще нужна история..."
const KOTIK_COMMENT := "Боже, ну что за Котик..."
const ENERGINKA_DRAG_ICON_SCRIPT := preload("res://scripts/ui/energinka_drag_icon.gd")
const CORKBOARD_HEART_SCRIPT := preload("res://scripts/ui/corkboard_heart.gd")

@onready var _available_energinka: EnerginkaReturnZone = $Root/BoardFrame/BoardContent/AvailableEnerginka/Icons
@onready var _kotik_hearts: HBoxContainer = $Root/BoardFrame/BoardContent/KotikHearts
@onready var _lisik_hearts: HBoxContainer = $Root/BoardFrame/BoardContent/LisikHearts
@onready var _confirm_plan_button: Button = $Root/BoardFrame/BoardContent/ConfirmPlanButton
@onready var _close_button: Button = $Root/BoardFrame/BoardContent/CloseButton
@onready var _hint: Label = $Root/Hint
@onready var _board_content: Control = $Root/BoardFrame/BoardContent
@onready var _sticker: Control = $Root/BoardFrame/BoardContent/Sticker
@onready var _sticker_text: Label = $Root/BoardFrame/BoardContent/Sticker/Text
@onready var _historian_name: Label = $Root/BoardFrame/BoardContent/HistorianName
@onready var _kotik_name: Label = $Root/BoardFrame/BoardContent/KotikName

var _slot_count: int = 8
var _closing: bool = false
var _applying_layout: bool = false
var _energinka_texture: Texture2D = null
var _textures: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_energinka_texture = _load_texture(ENERGINKA_ICON_PATH)
	_textures = {
		BranchSystem.BRANCH_KOTIK: {
			# Empty — сердечко свободно; Selected — энергинка вложена, план не подтверждён;
			# Active — активное сердечко (этап ACTIVE); Completed — закрытое сердечко.
			BranchSystem.State.EMPTY: _load_texture(KOTIK_EMPTY_HEART_PATH),
			BranchSystem.State.PENDING: _load_texture(KOTIK_SELECTED_HEART_PATH),
			BranchSystem.State.ACTIVE: _load_texture(KOTIK_ACTIVE_HEART_PATH),
			BranchSystem.State.COMPLETED: _load_texture(KOTIK_COMPLETED_HEART_PATH),
		},
		BranchSystem.BRANCH_LISIK: {
			BranchSystem.State.EMPTY: _load_texture(LISIK_EMPTY_HEART_PATH),
			BranchSystem.State.PENDING: _load_texture(LISIK_SELECTED_HEART_PATH),
			BranchSystem.State.ACTIVE: _load_texture(LISIK_ACTIVE_HEART_PATH),
			BranchSystem.State.COMPLETED: _load_texture(LISIK_COMPLETED_HEART_PATH),
		},
	}
	_confirm_plan_button.text = "ок"
	_close_button.text = "закрыть"
	if not _board_content.resized.is_connected(_apply_layout):
		_board_content.resized.connect(_apply_layout)
	if not _available_energinka.energinka_returned.is_connected(_return_energinka):
		_available_energinka.energinka_returned.connect(_return_energinka)
	if not _confirm_plan_button.pressed.is_connected(_on_confirm_plan_pressed):
		_confirm_plan_button.pressed.connect(_on_confirm_plan_pressed)
	if not _close_button.pressed.is_connected(_close):
		_close_button.pressed.connect(_close)
	_bind_polaroid([
		$Root/BoardFrame/BoardContent/HistorianPortrait,
		$Root/BoardFrame/BoardContent/HistorianPlate,
		$Root/BoardFrame/BoardContent/HistorianName,
	], HISTORIAN_COMMENT)
	_bind_polaroid([
		$Root/BoardFrame/BoardContent/KotikPortrait,
		$Root/BoardFrame/BoardContent/KotikPlate,
		$Root/BoardFrame/BoardContent/KotikName,
	], KOTIK_COMMENT)
	if not EnerginkaSystem.energinka_changed.is_connected(_on_energinka_changed):
		EnerginkaSystem.energinka_changed.connect(_on_energinka_changed)
	if not BranchSystem.branch_stage_state_changed.is_connected(_on_branch_stage_state_changed):
		BranchSystem.branch_stage_state_changed.connect(_on_branch_stage_state_changed)
	_refresh()
	call_deferred("_apply_layout")


func setup(slot_count: int) -> void:
	_slot_count = max(1, slot_count)
	if is_node_ready():
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if _is_close_event(event):
		get_viewport().set_input_as_handled()
		_close()


func _refresh() -> void:
	_refresh_available_energinka()
	_refresh_hearts()
	_confirm_plan_button.disabled = not BranchSystem.has_pending()


func _refresh_available_energinka() -> void:
	for child in _available_energinka.get_children():
		child.queue_free()

	var available_energinka: int = maxi(0, EnerginkaSystem.energinka_pool - BranchSystem.get_pending_count())
	if available_energinka <= 0:
		return

	for i in range(available_energinka):
		var icon: EnerginkaDragIcon = ENERGINKA_DRAG_ICON_SCRIPT.new()
		icon.setup(_energinka_texture, _energinka_icon_size())
		_available_energinka.add_child(icon)


func _apply_layout() -> void:
	if _applying_layout:
		return
	var height := _board_content.size.y
	if height < 20.0:
		return
	_applying_layout = true
	var plate_font := int(clampf(round(height * 0.028), 12, 28))
	var button_font := int(clampf(round(height * 0.032), 14, 30))
	_historian_name.add_theme_font_size_override("font_size", plate_font)
	_kotik_name.add_theme_font_size_override("font_size", plate_font)
	_confirm_plan_button.add_theme_font_size_override("font_size", button_font)
	_close_button.add_theme_font_size_override("font_size", button_font)
	# Стикер по высоте как на макете. Кегль — максимальный, при котором шесть строк
	# заполняют поле, а самая длинная строка не переносится. Ширина стикера подстраивается под текст.
	var sticker_h := height * 0.30
	var pad_y_ratio := 0.045
	var pad_x_ratio := 0.045
	var inner_h := sticker_h * (1.0 - pad_y_ratio * 2.0)
	var font := _sticker_text.get_theme_font("font")
	var sticker_font := 10
	for size in range(10, 72):
		if font.get_height(size) * STICKER_LINE_COUNT > inner_h:
			break
		sticker_font = size
	_sticker_text.add_theme_font_size_override("font_size", sticker_font)
	_sticker_text.add_theme_constant_override("line_spacing", 0)
	var text_w := 0.0
	for line in STICKER_LINES:
		text_w = maxf(text_w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, sticker_font).x)
	text_w += 8.0
	var sticker_w := text_w / (1.0 - pad_x_ratio * 2.0)
	var sticker_size := Vector2(sticker_w, sticker_h)
	var center := Vector2(_board_content.size.x * 0.974, height * 0.606)
	var origin := center - sticker_size * 0.5
	_sticker.rotation = 0.0
	_sticker.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_sticker.offset_left = origin.x
	_sticker.offset_top = origin.y
	_sticker.offset_right = origin.x + sticker_size.x
	_sticker.offset_bottom = origin.y + sticker_size.y
	_sticker.pivot_offset = sticker_size * 0.5
	_sticker.rotation = deg_to_rad(STICKER_ROTATION_DEG)
	var pad_x := sticker_size.x * pad_x_ratio
	var pad_y := sticker_size.y * pad_y_ratio
	_sticker_text.offset_left = pad_x
	_sticker_text.offset_top = pad_y
	_sticker_text.offset_right = -pad_x
	_sticker_text.offset_bottom = -pad_y
	_refresh()
	_applying_layout = false


func _energinka_icon_size() -> Vector2:
	var box := _available_energinka.get_parent() as Control
	var area := box.size if box != null else _available_energinka.size
	if area.x < 20.0 or area.y < 20.0:
		return ENERGINKA_ICON_SIZE
	var slots := maxi(EnerginkaSystem.max_energinka, 5)
	var width := area.x / (float(slots) + ENERGINKA_GAP_RATIO * float(slots - 1))
	var gap := width * ENERGINKA_GAP_RATIO
	_available_energinka.add_theme_constant_override("separation", int(round(gap)))
	return Vector2(width, area.y)


func _refresh_hearts() -> void:
	_fill_hearts(_kotik_hearts, HISTORIAN_SLOTS, BranchSystem.BRANCH_LISIK)
	_fill_hearts(_lisik_hearts, KOTIK_SLOTS, BranchSystem.BRANCH_KOTIK)


func _fill_hearts(container: HBoxContainer, slot_indices: Array[int], branch: String) -> void:
	for child in container.get_children():
		child.queue_free()
	for slot_index in slot_indices:
		var has_branch_stage := slot_index >= 0 and BranchSystem.has_branch_stage_for_slot(slot_index)
		var unlocked := has_branch_stage and BranchSystem.is_slot_unlocked(slot_index)
		var state := BranchSystem.get_state_for_slot(slot_index) if has_branch_stage else BranchSystem.State.EMPTY
		var can_accept := has_branch_stage and unlocked and state == BranchSystem.State.EMPTY and _has_unreserved_energinka()
		var can_return := has_branch_stage and unlocked and state == BranchSystem.State.PENDING
		var heart: CorkboardHeart = CORKBOARD_HEART_SCRIPT.new()
		var heart_size := _heart_size(container)
		heart.setup(
			slot_index,
			_texture_for(branch, state),
			can_accept,
			can_return,
			heart_size,
			"",
			false
		)
		if state == BranchSystem.State.EMPTY:
			heart.modulate = Color(0.55, 0.55, 0.55, 1.0 if unlocked else 0.35)
		heart.energinka_dropped.connect(_place_energinka)
		if state == BranchSystem.State.ACTIVE or state == BranchSystem.State.COMPLETED:
			heart.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			heart.mouse_entered.connect(_on_confirmed_heart_hovered.bind(slot_index))
		container.add_child(heart)


func _heart_size(container: HBoxContainer) -> Vector2:
	var area := container.size
	if area.y < 20.0 or area.x < 20.0:
		return HEART_SIZE
	var side := area.x / (3.0 + HEART_GAP_RATIO * 2.0)
	side = minf(side, area.y)
	container.add_theme_constant_override("separation", int(round(side * HEART_GAP_RATIO)))
	return Vector2(side, side)


## Полароид ветки (портрет + подпись): наведение — ворчание.
func _bind_polaroid(parts: Array, line: String) -> void:
	var hover := {"over": false}
	for part in parts:
		var control := part as Control
		control.mouse_filter = Control.MOUSE_FILTER_STOP
		control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		control.mouse_entered.connect(func() -> void:
			var was_over: bool = hover["over"]
			hover["over"] = true
			if not was_over:
				_vorchat(line)
		)
		control.mouse_exited.connect(func() -> void:
			hover["over"] = false
			var mouse := control.get_global_mouse_position()
			for other in parts:
				var polaroid_part := other as Control
				if polaroid_part.get_global_rect().has_point(mouse):
					hover["over"] = true
					return
		)


func _texture_for(branch: String, state: int) -> Texture2D:
	var branch_textures: Dictionary = _textures.get(branch, {})
	return branch_textures.get(state, null)


## Вложить энергинку в сердечко.
func _place_energinka(slot_index: int) -> void:
	if not BranchSystem.can_accept_slot(slot_index):
		return
	if not _has_unreserved_energinka():
		_vorchat("Недостаточно энергинок.")
		_refresh_available_energinka()
		return

	BranchSystem.invest_energinka(BranchSystem.get_branch_stage_id_for_slot(slot_index))
	_vorchat("Энергинка вложена. Нажми «Ок», чтобы подтвердить план.")
	_refresh()


func _return_energinka(slot_index: int) -> void:
	if BranchSystem.get_state_for_slot(slot_index) != BranchSystem.State.PENDING:
		return
	BranchSystem.cancel_pending(BranchSystem.get_branch_stage_id_for_slot(slot_index))
	_vorchat("Энергинка возвращена.")
	_refresh()


func _on_confirm_plan_pressed() -> void:
	if not BranchSystem.has_pending():
		_vorchat("Нет этапов для подтверждения.")
		return
	var cost := BranchSystem.get_pending_count()
	if not EnerginkaSystem.spend_energinka(cost):
		_vorchat("Недостаточно энергинок.")
		_refresh()
		return
	BranchSystem.confirm_plan()
	_refresh()
	_vorchat(CONFIRM_LINE)


func _on_confirmed_heart_hovered(slot_index: int) -> void:
	_vorchat(BranchSystem.get_confirmed_description(slot_index))


func _vorchat(text: String) -> void:
	if text.is_empty():
		return
	VorchanieSystem.vorchat(text, true)


func _on_energinka_changed(_current: int, _maximum: int) -> void:
	_refresh_available_energinka()


func _on_branch_stage_state_changed(_branch_stage_id: String, _state: int) -> void:
	_refresh()


func _close() -> void:
	if _closing:
		return
	_closing = true
	_cancel_pending_branch_stages()
	closed.emit()


## При выходе из доски откатываем только неподтверждённые изменения.
## ACTIVE остаётся до прохождения энкаунтера в Шараге.
func _cancel_pending_branch_stages() -> void:
	for i in range(_slot_count):
		if BranchSystem.get_state_for_slot(i) != BranchSystem.State.PENDING:
			continue
		BranchSystem.cancel_pending(BranchSystem.get_branch_stage_id_for_slot(i))


func _has_unreserved_energinka() -> bool:
	return EnerginkaSystem.energinka_pool - BranchSystem.get_pending_count() > 0


func _is_close_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ESCAPE or event.keycode == KEY_Q
	if event is InputEventMouseButton and event.pressed:
		return event.button_index == MOUSE_BUTTON_RIGHT
	return false


func _load_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		push_warning("[CorkboardUi] Не удалось загрузить иконку: %s" % path)
		return null
	return ImageTexture.create_from_image(image)
