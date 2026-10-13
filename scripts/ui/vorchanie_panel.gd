extends CanvasLayer
class_name VorchaniePanel

## Поле ворчания (vorchanie_panel): постоянная зона снизу игрового экрана — GDD §8.
## Поле зарезервировано всегда; реплика проявляется, висит тем дольше, чем длиннее,
## и гаснет сама. Кнопки пропуска нет. E поле не глушит: ворчание и действие
## идут одним нажатием (GDD §7).

signal finished

## Прозрачность пустого поля: место под ворчание видно, но не отвлекает.
const IDLE_ALPHA := 0.28
const FADE_IN := 0.18
const FADE_OUT := 0.3

@onready var _bubble: Control = $Root/Bottom/Bubble
@onready var _label: Label = $Root/Bottom/Bubble/Label

var _speaking: bool = false
var _hide_token: int = 0
var _tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label.text = ""
	_bubble.modulate.a = IDLE_ALPHA
	VorchanieSystem.register_panel(self)


func _exit_tree() -> void:
	VorchanieSystem.unregister_panel(self)


func is_speaking() -> bool:
	return _speaking


## Ворчать: показать реплику. Новая реплика сменяет текущую.
func play(text: String) -> void:
	_speaking = true
	_hide_token += 1
	var token := _hide_token
	_label.text = text
	_kill_tween()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_bubble, "modulate:a", 1.0, FADE_IN)
	var timer := get_tree().create_timer(seconds_for(text), true)
	timer.timeout.connect(func() -> void:
		if token == _hide_token:
			_hide()
	)


## Чем длиннее реплика, тем дольше она висит (GDD §8).
static func seconds_for(text: String) -> float:
	return clampf(1.8 + text.length() * 0.05, 2.6, 7.5)


func _hide() -> void:
	if not _speaking:
		return
	_speaking = false
	_kill_tween()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_bubble, "modulate:a", IDLE_ALPHA, FADE_OUT)
	_tween.tween_callback(func() -> void:
		if not _speaking:
			_label.text = ""
		finished.emit()
	)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
