extends CanvasLayer
class_name MainMenu

## Меню: стартовое меню при запуске игры и игровое меню по Escape в процессе.
## Фон — четыре кадра, сменяются по кругу каждые 3 секунды,
## поверх них лежит слой с нарисованными кнопками: свой для стартового меню
## («начать», «выйти») и свой для игрового меню.

const GAME_SCENE := "res://scenes/main.tscn"
const START_MENU_ART := "res://меню начало игры.png"
const GAME_MENU_ART := "res://меню свежее.png"
const BACKGROUNDS: Array[String] = [
	"res://photo_2025-10-04_15-46-35.jpg",
	"res://photo_2025-10-04_15-46-38.jpg",
	"res://photo_2025-10-04_15-46-41.jpg",
	"res://photo_2025-10-04_15-46-45.jpg",
]
const SWITCH_INTERVAL := 3.0
const FADE_TIME := 0.45

enum Mode {
	START_MENU, ## стартовое меню: игры ещё нет
	GAME_MENU,  ## игровое меню: вызвано по Escape поверх игры
}

static var current: MainMenu = null

@onready var _back: TextureRect = $Frame/Art/Back
@onready var _front: TextureRect = $Frame/Art/Front
@onready var _overlay: TextureRect = $Frame/Art/Overlay
@onready var _patch: Panel = $Frame/Art/Patch
@onready var _timer: Timer = $SwitchTimer
@onready var _start_menu_buttons: Control = $Frame/Art/StartMenuButtons
@onready var _start_button: Button = $Frame/Art/StartMenuButtons/StartButton
@onready var _start_menu_quit_button: Button = $Frame/Art/StartMenuButtons/StartMenuQuitButton
@onready var _game_menu_buttons: Control = $Frame/Art/GameMenuButtons
@onready var _save_button: Button = $Frame/Art/GameMenuButtons/SaveButton
@onready var _end_day_button: Button = $Frame/Art/GameMenuButtons/EndDayButton
@onready var _new_game_button: Button = $Frame/Art/GameMenuButtons/NewGameButton
@onready var _quit_button: Button = $Frame/Art/GameMenuButtons/QuitButton

var mode: int = Mode.START_MENU

var _frames: Array[Texture2D] = []
var _index: int = 0
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _fade: Tween = null


static func is_open() -> bool:
	return current != null and is_instance_valid(current)


## Открыть игровое меню поверх игры: ставит дерево на паузу и показывает курсор.
static func open_game_menu(tree: SceneTree) -> void:
	if is_open():
		return
	var scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	if scene == null:
		return
	var menu: MainMenu = scene.instantiate()
	menu.mode = Mode.GAME_MENU
	tree.root.add_child(menu)
	tree.paused = true


func _ready() -> void:
	current = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var in_game := mode == Mode.GAME_MENU
	_overlay.texture = load(GAME_MENU_ART if in_game else START_MENU_ART) as Texture2D
	_start_menu_buttons.visible = not in_game
	_game_menu_buttons.visible = in_game
	# На слое стартового меню кнопок всего две, а на фоне нарисованы четыре:
	# лишние закрываем заплаткой цвета бумаги.
	_patch.visible = not in_game
	_load_frames()

	# Сохранение ещё не сделано. День можно закончить только из игры.
	_save_button.disabled = true
	_end_day_button.disabled = not in_game or not DaySystem.is_day_active()
	_start_button.pressed.connect(_on_new_game_pressed)
	_start_menu_quit_button.pressed.connect(_on_quit_pressed)
	_end_day_button.pressed.connect(_on_end_day_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_timer.wait_time = SWITCH_INTERVAL
	_timer.timeout.connect(_next_frame)
	if _frames.size() > 1:
		_timer.start()
	if in_game:
		_new_game_button.grab_focus()
	else:
		_start_button.grab_focus()


func _exit_tree() -> void:
	if current == self:
		current = null


func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.GAME_MENU:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


## Закрыть игровое меню и вернуться в игру.
func close() -> void:
	if mode != Mode.GAME_MENU:
		return
	get_tree().paused = false
	Input.set_mouse_mode(_prev_mouse_mode)
	queue_free()


func _load_frames() -> void:
	_frames.clear()
	for path in BACKGROUNDS:
		var tex := load(path) as Texture2D
		if tex == null:
			push_warning("Меню: не загрузился фон %s" % path)
			continue
		_frames.append(tex)
	if _frames.is_empty():
		return
	_back.texture = _frames[0]
	_front.texture = _frames[0]
	_front.modulate.a = 0.0


func _next_frame() -> void:
	if _frames.size() < 2:
		return
	_index = (_index + 1) % _frames.size()
	_front.texture = _frames[_index]
	_front.modulate.a = 0.0
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_front, "modulate:a", 1.0, FADE_TIME)
	_fade.tween_callback(_commit_frame)


func _commit_frame() -> void:
	_back.texture = _frames[_index]
	_front.modulate.a = 0.0


## «Закончить день»: нажать «Ой, всё» (кнопка переехала из HUD).
func _on_end_day_pressed() -> void:
	if not DaySystem.is_day_active():
		return
	_end_day_button.disabled = true
	close()
	DaySystem.trigger_oy_vse()


## «Начать» и «Новая игра»: всё с чистого листа, как будто игру только запустили.
func _on_new_game_pressed() -> void:
	_start_button.disabled = true
	_new_game_button.disabled = true
	_timer.stop()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_reset_progress()
	var err := get_tree().change_scene_to_file(GAME_SCENE)
	if err != OK:
		push_error("Меню: не удалось загрузить %s (код %d)" % [GAME_SCENE, err])
		_start_button.disabled = false
		_new_game_button.disabled = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_timer.start()
		return
	queue_free()


## Автозагрузки живут дольше сцены, их состояние чистим руками.
func _reset_progress() -> void:
	LocationManager.reset_streamed()
	CabinetPool.reroll_sharaga()
	BranchSystem.reset_progress()
	EnerginkaSystem.reset_progress()
	DaySystem.day_number = 1
	DaySystem.starosta_note_read = false


func _on_quit_pressed() -> void:
	get_tree().quit()
