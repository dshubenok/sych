extends CharacterBody3D

# Скорость движения игрока
@export var speed: float = 25.0
# Скорость поворота камеры
@export var mouse_sensitivity: float = 0.002
# Скорость анимации бега
@export var run_animation_speed: float = 10.0
# Сила гравитации
@export var gravity: float = 20.0
# Сила прыжка
@export var jump_velocity: float = 8.0

# Ссылка на камеру
@onready var camera: Camera3D = $Camera3D
# Ссылки на части тела для анимации
@onready var body: MeshInstance3D = $Body
@onready var body_material: StandardMaterial3D = body.get_active_material(0)

func _ready():
	# Захватываем мышь для управления камерой
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Игрок готов! Управление: WASD - движение, мышь - поворот камеры, Space - прыжок, Escape - освободить мышь")

func _input(event):
	# Обработка движения мыши для поворота камеры
	if event is InputEventMouseMotion:
		# Поворачиваем игрока влево-вправо
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Ограничиваем вертикальный поворот камеры
		var current_rotation = camera.rotation.x
		var new_rotation = current_rotation - event.relative.y * mouse_sensitivity
		camera.rotation.x = clamp(new_rotation, -0.5, 0.5)
	
	# Прыжок по пробелу
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE and is_on_floor():
			velocity.y = jump_velocity
			print("Прыжок!")
	
	# Выход из захвата мыши по Escape
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				print("Мышь освобождена")
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				print("Мышь захвачена")

func _physics_process(delta):
	# Применяем гравитацию
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Получаем ввод для движения
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Вычисляем направление движения относительно поворота игрока
	var direction = Vector3.ZERO
	direction += transform.basis.x * input_dir.x
	direction += transform.basis.z * input_dir.y
	
	# Нормализуем вектор направления (чтобы диагональное движение не было быстрее)
	direction = direction.normalized()
	
	# Применяем движение
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		# Плавная остановка
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	# Перемещаем персонажа
	move_and_slide()
	
	# Анимация бега
	_animate_run(direction, delta)

func _animate_run(direction: Vector3, delta: float):
	# Анимация только при движении и на полу
	if direction.length() > 0.1 and is_on_floor():
		# Время для анимации
		var time = Time.get_time_dict_from_system()["second"] * run_animation_speed
		
		# Покачивание тела вверх-вниз
		var body_bounce = sin(time * 2) * 0.05
		body.position.y = body_bounce
		
		# Наклон тела в сторону движения
		var lean_amount = direction.x * 0.1
		body.rotation.z = -lean_amount
	else:
		# Возвращаем все в исходное положение при остановке
		body.position.y = 0
		body.rotation.z = 0 
