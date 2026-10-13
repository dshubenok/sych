extends Node

## Переход с трамваем (tram_transition) между Сычевальней и Шарагой.
## GDD §2, §4: после выхода из Сычевальни — этот экран, затем Шарага.
## План демо §5: в первый день вводный текст и кнопка «Ладно»; картинка итогов
## дня зеркально; музыка гаснет вместе с картинкой.
##
## assets/audio/tram_placeholder.wav — заглушка, не музыка демо. Заменить,
## когда появится настоящая музыка трамвая.

const IMAGE_PATH := "res://assets/ui/itogi.jpg"
const MUSIC_PATH := "res://assets/audio/tram_placeholder.wav"
## Вводный текст. В словаре термина нет — это текст плана демо, не новое имя.
const INTRO_TEXT := "— Чисто теоретически. Если бы у тебя были экзамены, ты ничего не учил и не собирался, а сдать надо — что бы ты делал?\n\n— Пошёл бы в шарагу. Заглядывал бы во все двери. Мир полон возможностей, связей, которыми можно обрасти, и неприятностей, в которые нужно вляпаться."
## Подпись кнопки. В словаре термина нет.
const CONTINUE_TEXT := "Ладно"

const LAYER := 180

## Сколько Сыч едет до вводного текста.
var ride_seconds: float = 3.0
## После кнопки — только картинка, затем затухание.
var tail_seconds: float = 1.0
## Затухание картинки и музыки.
var fade_seconds: float = 2.5
## В остальные дни вводного текста нет: короткий переход.
var short_seconds: float = 1.5
var text_fade_seconds: float = 0.45

## ride / intro / button / tail / fade — для проверки и скриншотов.
signal phase_changed(phase: StringName)

var _playing: bool = false
var _continued: bool = false
var _layer: CanvasLayer = null
var _image: TextureRect = null
var _shade: ColorRect = null
var _intro: Label = null
var _button: Button = null
var _music: AudioStreamPlayer = null
var _prev_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _paused_by_us: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_playing() -> bool:
	return _playing


## Показать переход и, если target задан, прибыть в локацию.
## Пустой target — только экран (для проверки), без travel_to.
func play(target: StringName, entry: StringName = &"") -> void:
	if _playing:
		return
	_playing = true
	_continued = false
	_prev_mouse_mode = Input.get_mouse_mode()
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build()
	var with_intro := DaySystem.day_number == 1
	await _sequence(with_intro)
	if target != &"":
		if not LocationManager.travel_covered.is_connected(_hide):
			LocationManager.travel_covered.connect(_hide, CONNECT_ONE_SHOT)
		await LocationManager.travel_to(target, entry, true)
	_hide()
	_playing = false
	if _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false
	Input.set_mouse_mode(_prev_mouse_mode)
	phase_changed.emit(&"arrive")


## Нажатие «Ладно» (мышь или проверка).
func press_continue() -> void:
	_continued = true


func _sequence(with_intro: bool) -> void:
	_play_music()
	phase_changed.emit(&"ride")
	if with_intro:
		await _wait(ride_seconds)
		await _fade_control(_intro, 1.0)
		phase_changed.emit(&"intro")
		await _fade_control(_button, 1.0)
		_button.disabled = false
		phase_changed.emit(&"button")
		while not _continued:
			await get_tree().process_frame
		_intro.visible = false
		_button.visible = false
		phase_changed.emit(&"tail")
		await _wait(tail_seconds)
	else:
		await _wait(short_seconds)
	phase_changed.emit(&"fade")
	await _fade_out()


func _build() -> void:
	_hide()
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.add_child(root)

	_image = TextureRect.new()
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.texture = load(IMAGE_PATH) as Texture2D
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.flip_h = true
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_image)

	_intro = Label.new()
	_intro.text = INTRO_TEXT
	_intro.visible = false
	_intro.modulate.a = 0.0
	_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro.anchor_left = 0.1
	_intro.anchor_top = 0.46
	_intro.anchor_right = 0.9
	_intro.anchor_bottom = 0.78
	_intro.add_theme_font_size_override("font_size", 22)
	_intro.add_theme_color_override("font_color", Color(1, 0.95, 0.86, 1))
	_intro.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.04, 1))
	_intro.add_theme_constant_override("outline_size", 10)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_intro)

	_button = Button.new()
	_button.text = CONTINUE_TEXT
	_button.visible = false
	_button.disabled = true
	_button.modulate.a = 0.0
	_button.anchor_left = 0.40
	_button.anchor_top = 0.86
	_button.anchor_right = 0.60
	_button.anchor_bottom = 0.96
	_button.add_theme_font_size_override("font_size", 32)
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(press_continue)
	root.add_child(_button)

	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0, 0, 0, 0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_shade)

	_music = AudioStreamPlayer.new()
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	var stream := load(MUSIC_PATH) as AudioStreamWAV
	if stream:
		stream = stream.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_music.stream = stream
	_music.volume_db = -8.0
	_layer.add_child(_music)


func _play_music() -> void:
	if _music and _music.stream:
		_music.play()


func _fade_control(control: CanvasItem, alpha: float) -> void:
	control.visible = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(control, "modulate:a", alpha, text_fade_seconds)
	await tween.finished


func _fade_out() -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(_shade, "color:a", 1.0, fade_seconds)
	if _music:
		tween.tween_property(_music, "volume_db", -40.0, fade_seconds)
	await tween.finished
	if _music:
		_music.stop()


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds, true).timeout


func _hide() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_image = null
	_shade = null
	_intro = null
	_button = null
	_music = null
