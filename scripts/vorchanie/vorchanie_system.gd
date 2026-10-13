extends Node

## Ворчание (vorchanie) — короткие реплики Сыча в поле ворчания снизу экрана (GDD §8).
## Поле постоянно: VorchaniePanel стоит в scenes/main.tscn и регистрируется здесь.
## Если поля ещё нет (тесты, запуск отдельной сцены), оно создаётся при первой реплике.
## E ворчание не глушит: по Interaction Model ворчание и действие — одно нажатие (GDD §7).
##
##   VorchanieSystem.vorchat("Записка? Под моей дверью? У МЕНЯ ТАЙНЫЙ ПОКЛОННИК")
##   VorchanieSystem.vorchat_from_pool(["Всё, начиталась", "Не", "Уф, буквы"])

const PANEL_SCENE := preload("res://scenes/ui/vorchanie_panel.tscn")

## Реплика догорела и поле снова пустое.
signal finished
## Сыч проворчал реплику.
signal vorchal(text: String)

var _panel: VorchaniePanel = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func register_panel(panel: VorchaniePanel) -> void:
	if _panel == panel:
		return
	if is_instance_valid(_panel) and _panel != panel:
		_panel.queue_free()
	_panel = panel
	if not panel.finished.is_connected(_on_panel_finished):
		panel.finished.connect(_on_panel_finished)


func unregister_panel(panel: VorchaniePanel) -> void:
	if _panel == panel:
		_panel = null


func has_panel() -> bool:
	return _panel != null and is_instance_valid(_panel)


## Реплика сейчас на экране.
func is_active() -> bool:
	return has_panel() and _panel.is_speaking()


## Ворчать: показать реплику в поле ворчания. По умолчанию новая реплика сменяет текущую;
## replace = false — не перебивать, если Сыч ещё говорит.
func vorchat(text: String, replace: bool = true) -> bool:
	if text.strip_edges().is_empty():
		return false
	if not replace and is_active():
		return false
	_ensure_panel()
	if not has_panel():
		return false
	_panel.play(text)
	vorchal.emit(text)
	return true


## Ворчать случайной репликой из пула ворчания (vorchanie_pool).
func vorchat_from_pool(pool: PackedStringArray, replace: bool = true) -> bool:
	if pool.is_empty():
		return false
	return vorchat(pool[randi() % pool.size()], replace)


func _ensure_panel() -> void:
	if has_panel():
		return
	var tree := get_tree()
	if tree == null:
		return
	var panel := PANEL_SCENE.instantiate() as VorchaniePanel
	tree.root.add_child(panel)
	# Панель регистрируется сама в _ready; здесь — на случай, если _ready отложен.
	register_panel(panel)


func _on_panel_finished() -> void:
	finished.emit()
