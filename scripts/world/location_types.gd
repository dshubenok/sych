extends RefCounted
class_name LocationTypes

## Типы узлов в иерархии локаций.
## ROOT     — логический корень («Мир»), не имеет собственной сцены.
## AREA     — крупная зона (Сычевальня).
## BUILDING — здание (Шарага).
## FLOOR    — этаж здания.
## ROOM     — конечная точка (слот кабинета).
enum Type { ROOT, AREA, BUILDING, FLOOR, ROOM }
