extends CanvasLayer

## Записка на весь экран: тёмный фон, картинка и кнопка «Назад».

signal closed

@onready var _image: TextureRect = $Root/Image
@onready var _back: Button = $Root/Back


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_back.pressed.connect(_on_back)


func show_note(texture: Texture2D) -> void:
	_image.texture = texture


func _input(event: InputEvent) -> void:
	# Клавиши не уходят в дверь и доску. Клик по «Назад» обрабатывает сам интерфейс.
	if event is InputEventKey:
		get_viewport().set_input_as_handled()


func _on_back() -> void:
	closed.emit()
	queue_free()
