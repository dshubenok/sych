extends Resource
class_name InteractionState

## Состояние взаимодействия (interaction_state) интерактивного объекта — GDD §7.
## Набор настроек Interaction для одного состояния: что ворчит Сыч, есть ли действие,
## сколько оно стоит и куда перейти после него. Пример: комикс «не прочитан» →
## ворчание + действие (+1 энергинка) → «прочитан» → только пул ворчания.

@export var id: StringName = &""
## Пул ворчания этого состояния. Пусто — Сыч молчит.
@export var vorchanie_pool: PackedStringArray = []
## Есть ли у состояния действие (помимо ворчания).
@export var has_action: bool = true
## Стоимость действия в энергинках; 0 — бесплатно.
@export var energinka_cost: int = 0
## Лимит действий на день; 0 — без лимита.
@export var uses_per_day: int = 0
## Состояние после выполненного действия. Пусто — остаться в текущем.
@export var next_state: StringName = &""
