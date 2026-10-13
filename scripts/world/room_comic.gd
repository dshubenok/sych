extends Node3D

## Комикс в Сычевальне — источник энергинок (план демо §2.3). Пока записка
## не прочитана — закрыт. Первое E: ворчание + действие (+1 энергинка) одним
## нажатием; дальше действие недоступно, только пул ворчания.

const STATE_UNREAD := &"unread"
const STATE_READ := &"read"

const INTRO_LINE := "Комикс про то, как один Пингвин не справляется. Охренительный."
## Пул ворчания после прочтения.
const DONE_LINES: PackedStringArray = [
	"Всё, начиталась",
	"Не",
	"Уф, буквы",
]

@export var energinka_reward: int = 1

var interaction: Interaction = null


func _ready() -> void:
	interaction = Interaction.ensure(self, 1.05, Vector3(0.0, 0.7, 0.0))
	var unread := InteractionState.new()
	unread.id = STATE_UNREAD
	unread.vorchanie_pool = [INTRO_LINE]
	unread.next_state = STATE_READ
	interaction.add_state(unread)
	var read := InteractionState.new()
	read.id = STATE_READ
	read.vorchanie_pool = DONE_LINES
	read.has_action = false
	interaction.add_state(read)
	interaction.set_interaction_state(STATE_UNREAD)
	interaction.action.connect(_on_action)


func set_interaction_locked(locked: bool) -> void:
	interaction.locked = locked


## Прочитать комикс: получить энергинку.
func _on_action(_interaction: Interaction) -> void:
	EnerginkaSystem.gain_energinka(energinka_reward)
