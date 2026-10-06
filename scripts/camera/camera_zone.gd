extends Area3D
class_name CameraZone

@export_node_path("Camera3D") var target_camera_path: NodePath
@export var zone_priority: int = 0

var _manager: Node
var _camera: Camera3D


func _ready() -> void:
	# Резолвим камеру из NodePath
	if target_camera_path:
		_camera = get_node_or_null(target_camera_path)
	print("[CameraZone] ", name, " camera resolved: ", _camera)
	
	# Убедимся что мониторинг включён
	monitoring = true
	monitorable = true
	# Детектим все collision layers (1 = игрок по умолчанию)
	collision_mask = 0xFFFFFFFF
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Отложенный поиск менеджера
	await get_tree().process_frame
	await get_tree().process_frame
	_manager = get_tree().get_first_node_in_group(&"camera_manager")
	print("[CameraZone] ", name, " ready, manager: ", _manager)
	
	# Проверяем, не находится ли игрок уже внутри зоны при старте
	var bodies = get_overlapping_bodies()
	print("[CameraZone] ", name, " overlapping bodies: ", bodies.size())
	for body in bodies:
		print("[CameraZone] ", name, " found body: ", body.name, " in_sych_group: ", body.is_in_group(&"sych"))
		if body.is_in_group(&"sych"):
			_on_body_entered(body)


func _on_body_entered(body: Node) -> void:
	print("[CameraZone] ", name, " body_entered: ", body.name)
	if body.is_in_group(&"sych"):
		if _manager == null:
			_manager = get_tree().get_first_node_in_group(&"camera_manager")
		if _manager and _camera:
			print("[CameraZone] ", name, " -> zone_entered, camera: ", _camera.name)
			print("[Manager] ", _manager)
			print(_camera.attributes)
			print("123")
			_manager.zone_entered(self, _camera, zone_priority)


func _on_body_exited(body: Node) -> void:
	print("[CameraZone] ", name, " body_exited: ", body.name)
	if body.is_in_group(&"sych"):
		if _manager:
			print("[CameraZone] ", name, " -> zone_exited")
			_manager.zone_exited(self)
