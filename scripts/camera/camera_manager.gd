extends Node
class_name CameraManager

@export_node_path("Camera3D") var blend_camera_path: NodePath
@export var blend_time: float = 0.5
## Скорость слежения BlendCamera за камерой игрока в дефолтном режиме
@export var default_smooth: float = 15.0

var _active_zones: Array = []
var _target_camera: Camera3D
var _is_dynamic_target: bool = false
var _tween: Tween
var _player: Node3D
var _player_cam: Camera3D
var blend_camera: Camera3D


func _ready() -> void:
	add_to_group(&"camera_manager")

	if blend_camera_path:
		blend_camera = get_node_or_null(blend_camera_path)

	if blend_camera:
		blend_camera.make_current()

	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group(&"player")

	if _player:
		_player_cam = _player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D")

	if _active_zones.is_empty() and _player_cam and blend_camera:
		_target_camera = _player_cam
		blend_camera.global_transform = _player_cam.global_transform
		blend_camera.fov = _player_cam.fov


func _process(delta: float) -> void:
	if _target_camera == _player_cam:
		if blend_camera and _player_cam:
			blend_camera.global_transform = blend_camera.global_transform.interpolate_with(
				_player_cam.global_transform, delta * default_smooth
			)
			blend_camera.fov = lerp(blend_camera.fov, _player_cam.fov, delta * default_smooth)
	elif _is_dynamic_target and blend_camera and _target_camera:
		blend_camera.global_transform = blend_camera.global_transform.interpolate_with(
			_target_camera.global_transform, delta * 5.0
		)
		blend_camera.fov = lerp(blend_camera.fov, _target_camera.fov, delta * 5.0)


func zone_entered(zone: Node, cam: Camera3D, priority: int, dynamic: bool = false, snap: bool = false) -> void:
	_active_zones.append({
		"zone": zone, "cam": cam, "priority": priority, "dynamic": dynamic, "snap": snap,
	})
	_recalculate()


func zone_exited(zone: Node) -> void:
	for i in range(_active_zones.size() - 1, -1, -1):
		if _active_zones[i]["zone"] == zone:
			_active_zones.remove_at(i)
	_recalculate()


func _recalculate() -> void:
	if _active_zones.is_empty():
		_is_dynamic_target = false
		if _player_cam != null and _target_camera != _player_cam:
			_target_camera = _player_cam
			if _tween and _tween.is_running():
				_tween.kill()
			_copy_camera_extras(_player_cam)
		return

	var best = _active_zones[0]
	for entry in _active_zones:
		if entry["priority"] > best["priority"]:
			best = entry

	var cam: Camera3D = best["cam"]
	var dynamic: bool = best.get("dynamic", false)

	if cam != null and cam != _target_camera:
		_target_camera = cam
		_is_dynamic_target = dynamic
		if not _is_dynamic_target:
			if best.get("snap", false):
				_snap_to(_target_camera)
			else:
				_blend_to(_target_camera)
		else:
			if _tween and _tween.is_running():
				_tween.kill()
			_copy_camera_extras(_target_camera)


func _snap_to(cam: Camera3D) -> void:
	if blend_camera == null or cam == null:
		return
	if _tween and _tween.is_running():
		_tween.kill()
	blend_camera.global_transform = cam.global_transform
	_copy_camera_extras(cam)


func _copy_camera_extras(cam: Camera3D) -> void:
	if blend_camera == null or cam == null:
		return
	blend_camera.fov = cam.fov
	blend_camera.near = cam.near
	blend_camera.far = cam.far
	blend_camera.environment = cam.environment


func _blend_to(cam: Camera3D) -> void:
	if blend_camera == null or cam == null:
		return

	if _tween and _tween.is_running():
		_tween.kill()

	_copy_camera_extras(cam)
	_tween = create_tween()
	_tween.tween_property(blend_camera, "global_transform", cam.global_transform, blend_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(blend_camera, "fov", cam.fov, blend_time)
