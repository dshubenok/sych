extends CanvasLayer
class_name EnergyBoardUi

signal closed

const FULL_HEART_PATH := "res://Icon_Energy_Full.png"
const KOTIK_EMPTY_HEART_PATH := "res://Board_Test_Cut/Heart_Kotik_Empty.png"
const KOTIK_SELECTED_HEART_PATH := "res://Board_Test_Cut/Heart_Kotik_Selected.png"
const KOTIK_SPAWNED_HEART_PATH := "res://Board_Test_Cut/Heart_Kotik_Spawned.png"
const KOTIK_COMPLETED_HEART_PATH := "res://Board_Test_Cut/Heart_Kotik_Completed.png"
const LISIK_EMPTY_HEART_PATH := "res://Board_Test_Cut/Heart_Lisik_Empty.png"
const LISIK_SELECTED_HEART_PATH := "res://Board_Test_Cut/Heart_Lisik_Selected.png"
const LISIK_SPAWNED_HEART_PATH := "res://Board_Test_Cut/Heart_Lisik_Spawned.png"
const LISIK_COMPLETED_HEART_PATH := "res://Board_Test_Cut/Heart_Lisik_Completed.png"
const ENERGY_ICON_SIZE := Vector2(34.0, 67.0)
const HEART_SIZE := Vector2(96.0, 96.0)
const NOTE_ROTATION_DEG := 17.5
const NOTE_LINES: PackedStringArray = [
	"1. беру энергинку, которых",
	"у меня и так мало",
	"2. перетаскиваю в пустое",
	"сердечко",
	"3. ок - принимаю решение",
	"работать в этот проект",
]
const NOTE_LINE_COUNT := 6
const ENERGY_GAP_RATIO := 0.12
const HEART_GAP_RATIO := 0.23
const HISTORIAN_SLOTS: Array[int] = [4, 5, -1]
const KOTIK_SLOTS: Array[int] = [0, -1, -1]
const OPEN_LINE := "Что бы такого сделать чтобы нихера не делать?"
const CONFIRM_LINE := "Дальше надо перестать планировать и реализовать план. Как? Да хрен его знает, на месте разберемся."
const HISTORIAN_COMMENT := "Кому вообще нужна история..."
const KOTIK_COMMENT := "Боже, ну что за Котик..."
const ENERGY_DRAG_ICON_SCRIPT := preload("res://scripts/ui/energy_drag_icon.gd")
const ENERGY_BOARD_SLOT_SCRIPT := preload("res://scripts/ui/energy_board_slot.gd")

@onready var _available_energy: EnergyReturnZone = $Root/BoardFrame/BoardContent/AvailableEnergy/Icons
@onready var _kotik_slots: HBoxContainer = $Root/BoardFrame/BoardContent/KotikSlots
@onready var _lisik_slots: HBoxContainer = $Root/BoardFrame/BoardContent/LisikSlots
@onready var _confirm_button: Button = $Root/BoardFrame/BoardContent/ConfirmButton
@onready var _close_button: Button = $Root/BoardFrame/BoardContent/CloseButton
@onready var _hint: Label = $Root/Hint
@onready var _board_content: Control = $Root/BoardFrame/BoardContent
@onready var _how_to: Control = $Root/BoardFrame/BoardContent/HowTo
@onready var _how_to_text: Label = $Root/BoardFrame/BoardContent/HowTo/Text
@onready var _historian_name: Label = $Root/BoardFrame/BoardContent/HistorianName
@onready var _kotik_name: Label = $Root/BoardFrame/BoardContent/KotikName

var _slot_count: int = 8
var _closing: bool = false
var _applying_layout: bool = false
var _energy_texture: Texture2D = null
var _textures: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_energy_texture = _load_texture(FULL_HEART_PATH)
	_textures = {
		QuestSystem.BRANCH_KOTIK: {
			# Empty — слот свободен; Selected — энергия на сердце, не подтверждено;
			# Spawned — квест взят (ACTIVE); Completed — выполнен.
			QuestSystem.State.EMPTY: _load_texture(KOTIK_EMPTY_HEART_PATH),
			QuestSystem.State.PENDING: _load_texture(KOTIK_SELECTED_HEART_PATH),
			QuestSystem.State.ACTIVE: _load_texture(KOTIK_SPAWNED_HEART_PATH),
			QuestSystem.State.COMPLETED: _load_texture(KOTIK_COMPLETED_HEART_PATH),
		},
		QuestSystem.BRANCH_LISIK: {
			QuestSystem.State.EMPTY: _load_texture(LISIK_EMPTY_HEART_PATH),
			QuestSystem.State.PENDING: _load_texture(LISIK_SELECTED_HEART_PATH),
			QuestSystem.State.ACTIVE: _load_texture(LISIK_SPAWNED_HEART_PATH),
			QuestSystem.State.COMPLETED: _load_texture(LISIK_COMPLETED_HEART_PATH),
		},
	}
	_confirm_button.text = "ок"
	_close_button.text = "закрыть"
	if not _board_content.resized.is_connected(_apply_layout):
		_board_content.resized.connect(_apply_layout)
	if not _available_energy.energy_returned.is_connected(_return_energy):
		_available_energy.energy_returned.connect(_return_energy)
	if not _confirm_button.pressed.is_connected(_on_confirm_pressed):
		_confirm_button.pressed.connect(_on_confirm_pressed)
	if not _close_button.pressed.is_connected(_close):
		_close_button.pressed.connect(_close)
	_bind_card([
		$Root/BoardFrame/BoardContent/HistorianPortrait,
		$Root/BoardFrame/BoardContent/HistorianPlate,
		$Root/BoardFrame/BoardContent/HistorianName,
	], HISTORIAN_COMMENT)
	_bind_card([
		$Root/BoardFrame/BoardContent/KotikPortrait,
		$Root/BoardFrame/BoardContent/KotikPlate,
		$Root/BoardFrame/BoardContent/KotikName,
	], KOTIK_COMMENT)
	if not EnergySystem.energy_changed.is_connected(_on_energy_changed):
		EnergySystem.energy_changed.connect(_on_energy_changed)
	if not QuestSystem.quest_state_changed.is_connected(_on_quest_state_changed):
		QuestSystem.quest_state_changed.connect(_on_quest_state_changed)
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
	_refresh_available_energy()
	_refresh_slots()
	_confirm_button.disabled = not QuestSystem.has_pending()


func _refresh_available_energy() -> void:
	for child in _available_energy.get_children():
		child.queue_free()

	var available_energy: int = maxi(0, EnergySystem.current_energy - QuestSystem.get_pending_count())
	if available_energy <= 0:
		return

	for i in range(available_energy):
		var icon: EnergyDragIcon = ENERGY_DRAG_ICON_SCRIPT.new()
		icon.setup(_energy_texture, _energy_icon_size())
		_available_energy.add_child(icon)


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
	_confirm_button.add_theme_font_size_override("font_size", button_font)
	_close_button.add_theme_font_size_override("font_size", button_font)
	# Стикер по высоте как на макете. Кегль — максимальный, при котором шесть строк
	# заполняют поле, а самая длинная строка не переносится. Ширина стикера подстраивается под текст.
	var note_h := height * 0.30
	var pad_y_ratio := 0.045
	var pad_x_ratio := 0.045
	var inner_h := note_h * (1.0 - pad_y_ratio * 2.0)
	var font := _how_to_text.get_theme_font("font")
	var note_font := 10
	for size in range(10, 72):
		if font.get_height(size) * NOTE_LINE_COUNT > inner_h:
			break
		note_font = size
	_how_to_text.add_theme_font_size_override("font_size", note_font)
	_how_to_text.add_theme_constant_override("line_spacing", 0)
	var text_w := 0.0
	for line in NOTE_LINES:
		text_w = maxf(text_w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, note_font).x)
	text_w += 8.0
	var note_w := text_w / (1.0 - pad_x_ratio * 2.0)
	var note_size := Vector2(note_w, note_h)
	var center := Vector2(_board_content.size.x * 0.974, height * 0.606)
	var origin := center - note_size * 0.5
	_how_to.rotation = 0.0
	_how_to.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_how_to.offset_left = origin.x
	_how_to.offset_top = origin.y
	_how_to.offset_right = origin.x + note_size.x
	_how_to.offset_bottom = origin.y + note_size.y
	_how_to.pivot_offset = note_size * 0.5
	_how_to.rotation = deg_to_rad(NOTE_ROTATION_DEG)
	var pad_x := note_size.x * pad_x_ratio
	var pad_y := note_size.y * pad_y_ratio
	_how_to_text.offset_left = pad_x
	_how_to_text.offset_top = pad_y
	_how_to_text.offset_right = -pad_x
	_how_to_text.offset_bottom = -pad_y
	_refresh()
	_applying_layout = false


func _energy_icon_size() -> Vector2:
	var box := _available_energy.get_parent() as Control
	var area := box.size if box != null else _available_energy.size
	if area.x < 20.0 or area.y < 20.0:
		return ENERGY_ICON_SIZE
	var slots := maxi(EnergySystem.max_energy, 5)
	var width := area.x / (float(slots) + ENERGY_GAP_RATIO * float(slots - 1))
	var gap := width * ENERGY_GAP_RATIO
	_available_energy.add_theme_constant_override("separation", int(round(gap)))
	return Vector2(width, area.y)


func _refresh_slots() -> void:
	_fill_hearts(_kotik_slots, HISTORIAN_SLOTS, QuestSystem.BRANCH_LISIK)
	_fill_hearts(_lisik_slots, KOTIK_SLOTS, QuestSystem.BRANCH_KOTIK)


func _fill_hearts(container: HBoxContainer, slot_indices: Array[int], branch: String) -> void:
	for child in container.get_children():
		child.queue_free()
	for slot_index in slot_indices:
		var has_quest := slot_index >= 0 and QuestSystem.has_quest_for_slot(slot_index)
		var unlocked := has_quest and QuestSystem.is_slot_unlocked(slot_index)
		var state := QuestSystem.get_state_for_slot(slot_index) if has_quest else QuestSystem.State.EMPTY
		var can_accept := has_quest and unlocked and state == QuestSystem.State.EMPTY and _has_unreserved_energy()
		var can_return := has_quest and unlocked and state == QuestSystem.State.PENDING
		var slot: EnergyBoardSlot = ENERGY_BOARD_SLOT_SCRIPT.new()
		var heart_size := _heart_size(container)
		slot.setup(
			slot_index,
			_texture_for(branch, state),
			can_accept,
			can_return,
			heart_size,
			"",
			false
		)
		if state == QuestSystem.State.EMPTY:
			slot.modulate = Color(0.55, 0.55, 0.55, 1.0 if unlocked else 0.35)
		slot.energy_dropped.connect(_place_energy)
		if state == QuestSystem.State.ACTIVE or state == QuestSystem.State.COMPLETED:
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			slot.mouse_entered.connect(_on_confirmed_heart_hovered.bind(slot_index))
		container.add_child(slot)


func _heart_size(container: HBoxContainer) -> Vector2:
	var area := container.size
	if area.y < 20.0 or area.x < 20.0:
		return HEART_SIZE
	var side := area.x / (3.0 + HEART_GAP_RATIO * 2.0)
	side = minf(side, area.y)
	container.add_theme_constant_override("separation", int(round(side * HEART_GAP_RATIO)))
	return Vector2(side, side)


func _bind_card(parts: Array, line: String) -> void:
	var hover := {"over": false}
	for part in parts:
		var control := part as Control
		control.mouse_filter = Control.MOUSE_FILTER_STOP
		control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		control.mouse_entered.connect(func() -> void:
			var was_over: bool = hover["over"]
			hover["over"] = true
			if not was_over:
				_grumble(line)
		)
		control.mouse_exited.connect(func() -> void:
			hover["over"] = false
			var mouse := control.get_global_mouse_position()
			for other in parts:
				var card_part := other as Control
				if card_part.get_global_rect().has_point(mouse):
					hover["over"] = true
					return
		)


func _texture_for(branch: String, state: int) -> Texture2D:
	var branch_textures: Dictionary = _textures.get(branch, {})
	return branch_textures.get(state, null)


func _place_energy(slot_index: int) -> void:
	if not QuestSystem.can_accept_slot(slot_index):
		return
	if not _has_unreserved_energy():
		_grumble("Недостаточно энергии.")
		_refresh_available_energy()
		return

	QuestSystem.set_pending(QuestSystem.get_quest_id_for_slot(slot_index))
	_grumble("Энергия размещена. Нажми «Ок», чтобы принять план.")
	_refresh()


func _return_energy(slot_index: int) -> void:
	if QuestSystem.get_state_for_slot(slot_index) != QuestSystem.State.PENDING:
		return
	QuestSystem.cancel_pending(QuestSystem.get_quest_id_for_slot(slot_index))
	_grumble("Энергия возвращена.")
	_refresh()


func _on_confirm_pressed() -> void:
	if not QuestSystem.has_pending():
		_grumble("Нет квестов для подтверждения.")
		return
	var cost := QuestSystem.get_pending_count()
	if not EnergySystem.try_spend(cost):
		_grumble("Недостаточно энергии.")
		_refresh()
		return
	QuestSystem.confirm_pending()
	_refresh()
	_grumble(CONFIRM_LINE)


func _on_confirmed_heart_hovered(slot_index: int) -> void:
	_grumble(QuestSystem.get_confirmed_description(slot_index))


func _grumble(text: String) -> void:
	if text.is_empty():
		return
	AsideSystem.say(text, true)


func _on_energy_changed(_current: int, _maximum: int) -> void:
	_refresh_available_energy()


func _on_quest_state_changed(_quest_id: String, _state: int) -> void:
	_refresh()


func _close() -> void:
	if _closing:
		return
	_closing = true
	_cancel_pending_quests()
	closed.emit()


## При выходе из доски откатываем только непринятые изменения.
## ACTIVE остаётся до выполнения энкаунтера в Шараге.
func _cancel_pending_quests() -> void:
	for i in range(_slot_count):
		if QuestSystem.get_state_for_slot(i) != QuestSystem.State.PENDING:
			continue
		QuestSystem.cancel_pending(QuestSystem.get_quest_id_for_slot(i))


func _has_unreserved_energy() -> bool:
	return EnergySystem.current_energy - QuestSystem.get_pending_count() > 0


func _is_close_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ESCAPE or event.keycode == KEY_Q
	if event is InputEventMouseButton and event.pressed:
		return event.button_index == MOUSE_BUTTON_RIGHT
	return false


func _load_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		push_warning("[EnergyBoardUi] Не удалось загрузить иконку: %s" % path)
		return null
	return ImageTexture.create_from_image(image)
