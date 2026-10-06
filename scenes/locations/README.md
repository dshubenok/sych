# Система локаций

Дискретная (комната = сцена) система локаций. Игрок, камера, HUD и глобальные
системы живут в `scenes/main.tscn` (бутстрап) и **персистентны**; меняется только
содержимое узла `CurrentLocation`, куда `LocationManager` подгружает текущую
локацию.

## Иерархия (источник правды — `LocationRegistry`)

```
Мир (mir)
├── Сычевальня (sychevalnya)                  ← стартовая, реальная сцена
└── Территория шараги (territoriya_sharagi)
    ├── Шарага (sharaga)
    │   ├── Первый этаж (etazh_1)
    │   │   └── Кабинет 1..6 — крылья в меше Шараги
    │   └── Второй этаж (etazh_2)
    │       └── Кабинет 7..10 — два крыла в меше Шараги
    └── Наружа (naruzha)
        ├── Кладбище (kladbische)
        ├── Беседка (besedka)
        └── Сквер с памятником (skver)
```

Дерево задано данными в `scripts/world/location_registry.gd` (автозагрузка).
Сцены о своих родителях ничего не знают — иерархия, хлебные крошки и навигация
строятся из реестра.

## Ключевые элементы

| Файл | Роль |
|---|---|
| `scripts/world/location_types.gd` | enum `LocationType` (ROOT/AREA/BUILDING/FLOOR/ROOM) |
| `scripts/world/location_def.gd` | `LocationDef` — запись реестра (id, title, parent, type, scene) |
| `scripts/world/location_registry.gd` | автозагрузка: дерево + `get_def`/`children`/`breadcrumb_text` |
| `scripts/world/location_manager.gd` | автозагрузка: `start_at()`, `travel_to()`, async-загрузка, fade, перенос игрока, сигналы `location_entered`/`location_exiting` |
| `scripts/world/location.gd` | `Location` — корень сцены локации (id, display_name, entry_points) |
| `scripts/world/placeholder_location.gd` | `PlaceholderLocation` — процедурная комната со стенами-с-проёмами для локаций без арта |
| `scripts/world/location_portal.gd` + `scenes/world/location_portal.tscn` | портал-граница с затемнением (Сычевальня ⇄ Территория) |
| `scripts/world/streaming_door.gd` + `scenes/world/streaming_door.tscn` | бесшовная дверь по «E» (внутри Территории), аддитивная подгрузка соседа |

## Два типа перехода

- **`location_portal.tscn`** — fade-переход (дискретно). Только на границе
  Сычевальня ⇄ Территория шараги.
- **`streaming_door.tscn`** — бесшовная дверь: по «E» подгружает соседа и стыкует
  к проёму, держит до конца дня. Для стыковки сосед должен иметь дверь обратно
  (`target_location_id` = id этой локации). Всё внутри Территории.

## Как добавить настоящую локацию (заменить заглушку)

1. Создать сцену `scenes/locations/.../<id>.tscn`, корень — скрипт `location.gd`
   (`Location`), выставить `location_id` = id из реестра.
2. Добавить узел `PlayerSpawn` (Marker3D) — точку появления игрока.
3. Расставить двери: `streaming_door.tscn` (внутри Территории) или
   `location_portal.tscn` (граница) с нужным `target_location_id`. Двери у обеих
   соседних локаций должны указывать друг на друга — иначе не состыкуются.
4. Путь сцены в реестре уже прописан — менять `location_registry.gd` не нужно,
   если id и путь совпадают.

## Проверка целостности

```
godot --headless --path . res://scenes/tools/validate_locations.tscn
```
Проверяет существование сцен, родителей, целей всех порталов и наличие спавнов.
Код возврата = числу ошибок.
