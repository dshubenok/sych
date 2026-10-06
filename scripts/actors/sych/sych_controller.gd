extends CharacterBody3D

@export var speed: float = 10.0
@export var mouse_sensitivity: float = 0.002
@export var run_animation_speed: float = 7.0
@export var gravity: float = 20.0
@export var jump_velocity: float = 8.0
## Минимальный угол наклона камеры (смотреть вверх), в градусах
@export var pitch_min: float = -25.0
## Максимальный угол наклона камеры (смотреть вниз), в градусах
@export var pitch_max: float = 30.0

@onready var body: MeshInstance3D = $Body
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D

var controls_enabled: bool = true
var run_time := 0.0
var _facing_xz := Vector3(0, 0, 1)
## Фиксированный вид локации (Сычевальня). Мышь не крутит камеру,
## WASD считается от этого базиса.
var _view_lock: Node = null
var _locked_basis := Basis.IDENTITY
## Центр спрайта: половина 1 СЫЧа (sych_unit, 2 м), ноги на полу. Bounce только вверх.
var _body_rest_y: float = 1.0


func _ready():
	add_to_group("sych")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if body:
		_body_rest_y = body.position.y


func _input(event):
	if not controls_enabled:
		return

	if event is InputEventMouseMotion and _view_lock == null:
		# Yaw — горизонтальное вращение pivot
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		# Pitch — вертикальное вращение spring arm (clamped)
		var pitch = spring_arm.rotation.x - event.relative.y * mouse_sensitivity
		spring_arm.rotation.x = clamp(pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE and is_on_floor():
			velocity.y = jump_velocity


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if not controls_enabled:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		move_and_slide()
		return

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# WASD относительно вида: pivot Сыча, либо зафиксированная камера локации.
	var axes := _horizontal_axes()
	var forward: Vector3 = axes[0]
	var right: Vector3 = axes[1]
	var direction = (right * input_dir.x + forward * (-input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		run_time += delta * run_animation_speed
		_facing_xz = direction
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		run_time = 0.0
		var cam_fwd := -camera_pivot.global_transform.basis.z
		if _view_lock != null:
			# Лицом к камере, как на концепте комнаты.
			cam_fwd = _locked_basis.z
		cam_fwd.y = 0.0
		if cam_fwd.length_squared() > 0.0001:
			_facing_xz = cam_fwd.normalized()

	move_and_slide()
	_update_sprite_facing()
	_animate_run(direction, delta)


func _update_sprite_facing() -> void:
	var f := _facing_xz
	f.y = 0.0
	if f.length_squared() < 0.0001:
		return
	f = f.normalized()
	body.rotation.y = atan2(f.x, f.z)


func _animate_run(direction: Vector3, _delta: float):
	var moving := direction.length() > 0.1 and is_on_floor()
	body.position.y = _run_sprite_y(moving)
	body.rotation.z = -direction.x * 0.1 if moving else 0.0


func _run_sprite_y(moving: bool) -> float:
	if moving:
		return _body_rest_y + abs(sin(run_time * 2.0)) * 0.06
	return _body_rest_y


func set_view_lock(lock: Node, basis: Basis) -> void:
	_view_lock = lock
	_locked_basis = basis


func clear_view_lock(lock: Node) -> void:
	if _view_lock == lock:
		_view_lock = null


func _horizontal_axes() -> Array:
	var basis := camera_pivot.global_transform.basis
	if _view_lock != null:
		basis = _locked_basis
	var forward := -basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3(0, 0, -1)
	else:
		forward = forward.normalized()
	var right := basis.x
	right.y = 0.0
	if right.length_squared() < 0.0001:
		right = Vector3(1, 0, 0)
	else:
		right = right.normalized()
	return [forward, right]


func set_controls_enabled(enabled: bool):
	controls_enabled = enabled
	if not enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
