extends Area3D
class_name CameraTrackZone

## Камера в начальной точке (игрок далеко от POI)
@export_node_path("Camera3D") var start_camera_path: NodePath
## Камера в конечной точке (игрок рядом с POI)
@export_node_path("Camera3D") var end_camera_path: NodePath
## Объект интереса — к нему игрок приближается
@export_node_path("Node3D") var point_of_interest_path: NodePath
## Приоритет зоны (как в CameraZone)
@export var zone_priority: int = 0
## Скорость сглаживания движения камеры (больше = резче)
@export var smooth_speed: float = 3.0
## Максимальная дистанция (при ней t=0). Если 0 — рассчитается автоматически из позиции start_camera.
@export var max_distance: float = 0.0

var _manager: Node
var _start_cam: Camera3D
var _end_cam: Camera3D
var _poi: Node3D
var _sych: Node3D
var _track_camera: Camera3D
var _current_t: float = 0.0
var _is_active: bool = false


func _ready() -> void:
	_start_cam = get_node_or_null(start_camera_path)
	_end_cam = get_node_or_null(end_camera_path)
	_poi = get_node_or_null(point_of_interest_path)

	# Создаём виртуальную камеру, которая будет двигаться между start и end
	_track_camera = Camera3D.new()
	_track_camera.name = "TrackCam_" + name
	add_child(_track_camera)
	if _start_cam:
		_track_camera.global_transform = _start_cam.global_transform
		_track_camera.fov = _start_cam.fov

	# Автоматический расчёт max_distance из позиции start_camera до POI
	if max_distance <= 0.0 and _start_cam and _poi:
		max_distance = _start_cam.global_position.distance_to(_poi.global_position)

	monitoring = true
	monitorable = true
	collision_mask = 0xFFFFFFFF

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	await get_tree().process_frame
	await get_tree().process_frame
	_manager = get_tree().get_first_node_in_group(&"camera_manager")
	_sych = get_tree().get_first_node_in_group(&"sych")
	print("[CameraTrackZone] ", name, " ready. start_cam: ", _start_cam, " end_cam: ", _end_cam, " poi: ", _poi, " max_dist: ", max_distance)

	# Проверяем, не находится ли игрок уже внутри зоны при старте
	for body in get_overlapping_bodies():
		if body.is_in_group(&"sych"):
			_on_body_entered(body)


func _process(delta: float) -> void:
	if not _is_active or not _sych or not _poi or not _start_cam or not _end_cam:
		return

	var target_t = _calculate_progress()

	# Плавная интерполяция прогресса
	_current_t = lerp(_current_t, target_t, smooth_speed * delta)
	_current_t = clamp(_current_t, 0.0, 1.0)

	# Интерполируем transform и fov виртуальной камеры
	_track_camera.global_transform = _start_cam.global_transform.interpolate_with(
		_end_cam.global_transform, _current_t
	)
	_track_camera.fov = lerp(_start_cam.fov, _end_cam.fov, _current_t)


func _calculate_progress() -> float:
	if max_distance < 0.01:
		return 0.0
	var sych_dist = _sych.global_position.distance_to(_poi.global_position)
	# Чем ближе к POI — тем больше t (ближе к end_camera)
	var t = 1.0 - (sych_dist / max_distance)
	return clamp(t, 0.0, 1.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(&"sych"):
		print("[CameraTrackZone] ", name, " sych entered")
		_is_active = true
		# Инициализируем t на основе текущей позиции игрока
		if _sych and _poi and max_distance > 0.01:
			_current_t = _calculate_progress()
		if _manager == null:
			_manager = get_tree().get_first_node_in_group(&"camera_manager")
		if _manager and _track_camera:
			_manager.zone_entered(self, _track_camera, zone_priority, true)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group(&"sych"):
		print("[CameraTrackZone] ", name, " sych exited")
		_is_active = false
		if _manager:
			_manager.zone_exited(self)
