extends Panel
class_name ComicPanel
## Один «кадр» комиксной страницы. Пока показывает цветной плейсхолдер,
## когда появятся PNG — подхватит их в TextureRect.

@onready var _background: ColorRect = $Background
@onready var _image: TextureRect = $Image
@onready var _speaker: Label = $Margin/VBox/Speaker
@onready var _bubble: PanelContainer = $Margin/VBox/Bubble
@onready var _text: Label = $Margin/VBox/Bubble/BubbleMargin/Text


func _ready() -> void:
	set_hidden_placeholder()


func set_hidden_placeholder() -> void:
	_background.color = Color(0.08, 0.08, 0.1, 1.0)
	_image.texture = null
	_speaker.text = ""
	_text.text = ""
	_bubble.visible = false
	modulate = Color(1, 1, 1, 0.15)


func apply_data(data: Dictionary) -> void:
	modulate = Color.WHITE

	var color_hex: String = data.get("color", "")
	if color_hex != "":
		_background.color = Color.html(color_hex)

	var img_path: String = data.get("image", "")
	if img_path != "" and ResourceLoader.exists(img_path):
		_image.texture = load(img_path)
	else:
		_image.texture = null

	_speaker.text = data.get("speaker", "")
	var line: String = data.get("text", "")
	_text.text = line
	_bubble.visible = line != ""
