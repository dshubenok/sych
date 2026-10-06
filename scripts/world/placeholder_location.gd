extends Location
class_name PlaceholderLocation

## Временная локация без 3D-арта. Строит пол, стены с проёмами,
## двери (стримеры/порталы), точку спавна, подпись и зону присутствия Сыча.
## Когда появится модель — сцена заменяется на полноценную, реестр не трогаем.

const STREAMING_DOOR := preload("res://scenes/world/streaming_door.tscn")
const PORTAL_SCENE := preload("res://scenes/world/location_portal.tscn")

@export var location_size: Vector3 = Vector3(16.0, 4.0, 16.0)
@export var floor_color: Color = Color(0.28, 0.28, 0.34)
@export var wall_color: Color = Color(0.20, 0.20, 0.26)
## Соседи с бесшовными дверьми-стримерами (открываются по «E»).
@export var stream_exits: Array[StringName] = []
## Соседи с порталами-затемнением (граница между дискретными зонами, например Сычевальня ⇄ Шарага).
@export var portal_exits: Array[StringName] = []

var _door_t: Array[float] = []  # позиции дверей по периметру (для проёмов в стенах)

func _ready() -> void:
	super._ready()
	_build_floor()
	_build_spawn()
	_build_title()
	_build_doors()
	_build_walls()
	_build_presence()

func _build_floor() -> void:
	var body := _make_box_body(Vector3(location_size.x, 0.4, location_size.z), floor_color)
	body.name = "Floor"
	body.position = Vector3(0, -0.2, 0)
	add_child(body)

func _build_spawn() -> void:
	var spawn := Marker3D.new()
	spawn.name = "SychSpawn"
	spawn.position = Vector3(0, 1.0, 0)
	add_child(spawn)

func _build_title() -> void:
	var label := Label3D.new()
	label.name = "Title"
	label.text = display_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.font_size = 64
	label.outline_size = 16
	label.modulate = Color(1, 0.94, 0.72)
	label.position = Vector3(0, 2.6, 0)
	add_child(label)

func _build_doors() -> void:
	var doors: Array = []
	for id in stream_exits:
		doors.append({"id": id, "stream": true})
	for id in portal_exits:
		doors.append({"id": id, "stream": false})
	var n := doors.size()
	if n == 0:
		return
	# По стенам, с отступом от углов: периметр t = (i+0.5)/n сажает дверь в угол.
	var by_wall: Array = [[], [], [], []]
	for i in range(n):
		by_wall[i % 4].append(doors[i])
	for w in range(4):
		var group: Array = by_wall[w]
		for j in range(group.size()):
			var spec: Dictionary = group[j]
			var t := _wall_door_t(w, j, group.size())
			var pn := _perimeter_point(t)
			var door: Node3D
			if spec["stream"]:
				door = STREAMING_DOOR.instantiate()
			else:
				door = PORTAL_SCENE.instantiate()
			door.target_location_id = spec["id"]
			door.transform = Transform3D(_outward_basis(pn["normal"]), pn["pos"])
			add_child(door)
			_door_t.append(t)

func _build_walls() -> void:
	var perim := 2.0 * (location_size.x + location_size.z)
	var seg := 2.0
	var count := int(ceil(perim / seg))
	var gap := 2.5  # половина ширины проёма (мир. единицы)
	for i in range(count):
		var t := (float(i) + 0.5) / float(count)
		var skip := false
		for dt in _door_t:
			if _perim_dist(t, dt) * perim < gap:
				skip = true
				break
		if skip:
			continue
		var pn := _perimeter_point(t)
		var wall := _make_box_body(Vector3(seg + 0.1, location_size.y, 0.4), wall_color)
		wall.name = "WallSeg"
		wall.transform = Transform3D(_outward_basis(pn["normal"]),
			pn["pos"] + Vector3(0, location_size.y * 0.5, 0))
		add_child(wall)

func _build_presence() -> void:
	var area := Area3D.new()
	area.name = "PresenceArea"
	area.collision_mask = 0xFFFFFFFF
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(location_size.x - 0.5, 2.0, location_size.z - 0.5)
	cs.shape = box
	cs.position = Vector3(0, 1.0, 0)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_presence)

func _on_presence(body: Node) -> void:
	if body.is_in_group(&"sych"):
		LocationManager.notify_sych_entered(location_id)

# --- Геометрия периметра --------------------------------------------------

## t ∈ [0,1) для двери на стене `wall` (0: −Z, 1: +X, 2: +Z, 3: −X).
func _wall_door_t(wall: int, index: int, count: int) -> float:
	var hx := location_size.x
	var hz := location_size.z
	var perim := 2.0 * (hx + hz)
	var lengths := [hx, hz, hx, hz]
	var starts := [0.0, hx, hx + hz, hx + hz + hx]
	var length: float = lengths[wall]
	var inset := minf(2.0, length * 0.25)
	var usable: float = maxf(length - 2.0 * inset, length * 0.5)
	inset = (length - usable) * 0.5
	var along := inset + usable * (float(index) + 0.5) / float(maxi(count, 1))
	return (starts[wall] + along) / perim

## Точка на периметре прямоугольника по параметру t ∈ [0,1) и внешняя нормаль.
func _perimeter_point(t: float) -> Dictionary:
	var hx := location_size.x * 0.5
	var hz := location_size.z * 0.5
	var d := t * 2.0 * (location_size.x + location_size.z)
	if d < location_size.x:
		return {"pos": Vector3(-hx + d, 0, -hz), "normal": Vector3(0, 0, -1)}
	d -= location_size.x
	if d < location_size.z:
		return {"pos": Vector3(hx, 0, -hz + d), "normal": Vector3(1, 0, 0)}
	d -= location_size.z
	if d < location_size.x:
		return {"pos": Vector3(hx - d, 0, hz), "normal": Vector3(0, 0, 1)}
	d -= location_size.x
	return {"pos": Vector3(-hx, 0, hz - d), "normal": Vector3(-1, 0, 0)}

## Базис, у которого +Z = внешняя нормаль (дверь смотрит наружу локации).
func _outward_basis(normal: Vector3) -> Basis:
	var z := normal.normalized()
	var y := Vector3.UP
	var x := y.cross(z).normalized()
	return Basis(x, y, z)

## Кратчайшее расстояние по периметру (с учётом замыкания), в долях [0..0.5].
func _perim_dist(a: float, b: float) -> float:
	var d: float = absf(a - b)
	return minf(d, 1.0 - d)

func _make_box_body(size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat
	body.add_child(mesh_instance)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body
