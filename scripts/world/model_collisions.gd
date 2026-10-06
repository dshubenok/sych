extends Node3D
class_name ModelCollisions

## Тримеш-коллизии для импортированной модели, с вырезом проёмов под двери
## и порталы той же локации. Крупные стены — это 1–2 треугольника на всю грань,
## поэтому пересекающие проём грани subdivидятся, а куски внутри двери отбрасываются.

const DOOR_HALF_WIDTH := 1.4
const DOOR_HEIGHT := 2.9
const DOOR_Y_MIN := 0.22
const DOOR_DEPTH := 1.6
const SUBDIV_DEPTH := 5

func _ready() -> void:
	call_deferred("_build")


func _build() -> void:
	var doors: Array[Transform3D] = []
	var loc := _owner_location()
	if loc:
		_collect_doors(loc, doors)
	_generate(self, doors)


func _owner_location() -> Node:
	var n := get_parent()
	while n:
		if n is Location:
			return n
		n = n.get_parent()
	return get_parent()


func _collect_doors(node: Node, acc: Array[Transform3D]) -> void:
	for child in node.get_children():
		if child is StreamingDoor or child is LocationPortal:
			acc.append((child as Node3D).global_transform)
		_collect_doors(child, acc)


func _generate(node: Node, doors: Array[Transform3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		_create_collision(node as MeshInstance3D, doors)
	for child in node.get_children():
		_generate(child, doors)


func _create_collision(mi: MeshInstance3D, doors: Array[Transform3D]) -> void:
	var mesh: Mesh = mi.mesh
	var faces := PackedVector3Array()
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices != null and indices.size() >= 3:
			var i := 0
			while i + 2 < indices.size():
				_add_filtered_tri(faces, mi, doors,
					verts[indices[i]], verts[indices[i + 1]], verts[indices[i + 2]], 0)
				i += 3
		else:
			var i := 0
			while i + 2 < verts.size():
				_add_filtered_tri(faces, mi, doors, verts[i], verts[i + 1], verts[i + 2], 0)
				i += 3
	if faces.size() < 9:
		push_warning("[ModelCollisions] Нет треугольников для коллизии у %s" % mi.name)
		return
	# Толстая плита пола из тримеша затягивает капсулу внутрь объёма,
	# и CharacterBody3D перестаёт ехать по горизонтали. Для такой плиты
	# ставим выпуклый короб: верхняя грань — поверхность, по которой ходят.
	if _is_floor_slab(mi, faces):
		_add_box(mi, _aabb_of(faces))
		return
	var body := StaticBody3D.new()
	body.name = "%s_col" % mi.name
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	mi.add_child(body)


func _is_floor_slab(mi: MeshInstance3D, faces: PackedVector3Array) -> bool:
	var bounds: AABB = mi.global_transform * _aabb_of(faces)
	var size := bounds.size
	if size.y <= 0.0 or size.y > 0.45:
		return false
	if size.x < 1.0 or size.z < 1.0:
		return false
	if size.y > size.x * 0.2 or size.y > size.z * 0.2:
		return false
	return true


func _aabb_of(faces: PackedVector3Array) -> AABB:
	var bounds := AABB(faces[0], Vector3.ZERO)
	for p in faces:
		bounds = bounds.expand(p)
	return bounds


func _add_box(mi: MeshInstance3D, bounds: AABB) -> void:
	var body := StaticBody3D.new()
	body.name = "%s_col" % mi.name
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	cs.position = bounds.get_center()
	var box := BoxShape3D.new()
	box.size = bounds.size
	cs.shape = box
	body.add_child(cs)
	mi.add_child(body)


func _add_filtered_tri(faces: PackedVector3Array, mi: MeshInstance3D,
		doors: Array[Transform3D], a: Vector3, b: Vector3, c: Vector3, depth: int) -> void:
	var xf := mi.global_transform
	var wa := xf * a
	var wb := xf * b
	var wc := xf * c
	var door_i := _overlapping_door_index(wa, wb, wc, doors)
	if door_i < 0:
		faces.append(a)
		faces.append(b)
		faces.append(c)
		return
	var door: Transform3D = doors[door_i]
	if _point_in_door(wa, door) and _point_in_door(wb, door) and _point_in_door(wc, door):
		return
	if depth >= SUBDIV_DEPTH:
		if _aabb_overlaps_door(wa, wb, wc, door):
			return
		faces.append(a)
		faces.append(b)
		faces.append(c)
		return
	var ab := (a + b) * 0.5
	var bc := (b + c) * 0.5
	var ca := (c + a) * 0.5
	_add_filtered_tri(faces, mi, doors, a, ab, ca, depth + 1)
	_add_filtered_tri(faces, mi, doors, ab, b, bc, depth + 1)
	_add_filtered_tri(faces, mi, doors, ca, bc, c, depth + 1)
	_add_filtered_tri(faces, mi, doors, ab, bc, ca, depth + 1)


func _overlapping_door_index(a: Vector3, b: Vector3, c: Vector3,
		doors: Array[Transform3D]) -> int:
	for i in range(doors.size()):
		if _aabb_overlaps_door(a, b, c, doors[i]):
			return i
	return -1


func _aabb_overlaps_door(a: Vector3, b: Vector3, c: Vector3, door: Transform3D) -> bool:
	var la: Vector3 = door.affine_inverse() * a
	var lb: Vector3 = door.affine_inverse() * b
	var lc: Vector3 = door.affine_inverse() * c
	var mn := Vector3(minf(la.x, minf(lb.x, lc.x)), minf(la.y, minf(lb.y, lc.y)), minf(la.z, minf(lb.z, lc.z)))
	var mx := Vector3(maxf(la.x, maxf(lb.x, lc.x)), maxf(la.y, maxf(lb.y, lc.y)), maxf(la.z, maxf(lb.z, lc.z)))
	return mx.x >= -DOOR_HALF_WIDTH and mn.x <= DOOR_HALF_WIDTH \
		and mx.y >= DOOR_Y_MIN and mn.y <= DOOR_HEIGHT \
		and mx.z >= -DOOR_DEPTH and mn.z <= DOOR_DEPTH


func _point_in_door(world: Vector3, door: Transform3D) -> bool:
	var local: Vector3 = door.affine_inverse() * world
	return absf(local.x) <= DOOR_HALF_WIDTH \
		and local.y >= DOOR_Y_MIN and local.y <= DOOR_HEIGHT \
		and absf(local.z) <= DOOR_DEPTH
