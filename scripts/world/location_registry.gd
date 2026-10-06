extends Node

## Единый источник правды по иерархии локаций (автозагрузка).
## Дерево из дизайн-документа описано здесь как данные; сцены и менеджер
## переходов опираются на этот реестр.

const SCENES_ROOT := "res://scenes/locations"

var _defs: Dictionary = {}      # StringName -> LocationDef
var _children: Dictionary = {}  # StringName -> Array[StringName]
var _order: Array[StringName] = []

func _ready() -> void:
	_build_tree()

func _build_tree() -> void:
	var T := LocationTypes.Type
	# 1. Мир
	_add(&"mir", "Мир", &"", T.ROOT, "")
	# 1.1. Сычевальня
	_add(&"sychevalnya", "Сычевальня", &"mir", T.AREA,
		"%s/sychevalnya/sychevalnya.tscn" % SCENES_ROOT)
	# 1.2. Территория шараги
	_add(&"territoriya_sharagi", "Территория шараги", &"mir", T.AREA,
		"%s/territoriya_sharagi/territoriya_sharagi.tscn" % SCENES_ROOT)
	# 1.2.1. Шарага
	_add(&"sharaga", "Шарага", &"territoriya_sharagi", T.BUILDING,
		"%s/sharaga/sharaga.tscn" % SCENES_ROOT)
	# 1.2.1.1. Первый этаж (крылья в меше Шараги)
	_add(&"etazh_1", "Первый этаж", &"sharaga", T.FLOOR, "")
	for i in range(1, 7):
		_add(StringName("kabinet_%d" % i), "Кабинет %d" % i, &"etazh_1", T.ROOM, "")
	# 1.2.1.2. Второй этаж (крылья в меше Шараги)
	_add(&"etazh_2", "Второй этаж", &"sharaga", T.FLOOR, "")
	for i in range(7, 11):
		_add(StringName("kabinet_%d" % i), "Кабинет %d" % i, &"etazh_2", T.ROOM, "")
	# 1.2.2. Наружа
	_add(&"naruzha", "Наружа", &"territoriya_sharagi", T.AREA,
		"%s/naruzha/naruzha.tscn" % SCENES_ROOT)
	_add(&"kladbische", "Кладбище", &"naruzha", T.ROOM,
		"%s/naruzha/kladbische.tscn" % SCENES_ROOT)
	_add(&"besedka", "Беседка", &"naruzha", T.ROOM,
		"%s/naruzha/besedka.tscn" % SCENES_ROOT)
	_add(&"skver", "Сквер с памятником", &"naruzha", T.ROOM,
		"%s/naruzha/skver.tscn" % SCENES_ROOT)

func _add(id: StringName, title: String, parent_id: StringName,
		type: LocationTypes.Type, scene_path: String) -> void:
	var def := LocationDef.new()
	def.id = id
	def.title = title
	def.parent_id = parent_id
	def.type = type
	def.scene_path = scene_path
	_defs[id] = def
	_order.append(id)
	if not _children.has(parent_id):
		_children[parent_id] = [] as Array[StringName]
	(_children[parent_id] as Array).append(id)

# --- Запросы -------------------------------------------------------------

func has(id: StringName) -> bool:
	return _defs.has(id)

func get_def(id: StringName) -> LocationDef:
	return _defs.get(id, null)

func get_title(id: StringName) -> String:
	var d: LocationDef = _defs.get(id, null)
	return d.title if d else String(id)

func parent_of(id: StringName) -> StringName:
	var d: LocationDef = _defs.get(id, null)
	return d.parent_id if d else &""

func children(id: StringName) -> Array:
	return _children.get(id, [])

func all_ids() -> Array[StringName]:
	return _order

## Цепочка от корня до id (массив LocationDef).
func breadcrumb(id: StringName) -> Array:
	var chain: Array = []
	var cur := id
	while cur != &"" and _defs.has(cur):
		chain.push_front(_defs[cur])
		cur = (_defs[cur] as LocationDef).parent_id
	return chain

## Хлебные крошки строкой: «Мир › Территория шараги › Шарага › …».
func breadcrumb_text(id: StringName, sep: String = " › ") -> String:
	var parts: Array = []
	for d in breadcrumb(id):
		parts.append((d as LocationDef).title)
	return sep.join(parts)
