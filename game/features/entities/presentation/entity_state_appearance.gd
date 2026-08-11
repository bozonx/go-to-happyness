class_name EntityStateAppearance
extends RefCounted

## Как состояние сущности превращается во внешний вид её ноды
## (`map_fill_mode.md` §6.1).
##
## Вынесено из `MapEntityPresenter`, потому что нод у одной карты два вида и
## оба обязаны выглядеть одинаково: презентер строит сущности, которых не забрал
## хост, а `AmbientSpawner` — те, что забрал (`WorldSession.claimed_entity_components`).
## Пока это умел только презентер, сезонный перевод доезжал до расставленной
## руками бочки и не доезжал до дерева, потому что дерево строит спавнер.

## Накладывает вариант состояния поверх умолчаний ассета.
##
## `null`-ассет и нода без `apply_fill_properties` — не ошибка: у заглушки
## пропавшего контента нет ни того, ни другого, а карта обязана открываться и с
## неустановленным паком (§11).
static func apply(
	view: Node3D,
	archetype: EntityArchetype,
	state_id: StringName,
	asset: WorldAssetDef,
	extra_appearance: Dictionary = {}
) -> void:
	if view == null or asset == null or archetype == null:
		return
	if not view.has_method("apply_fill_properties"):
		return
	var appearance := asset.default_appearance()
	var state := archetype.states.get_state(state_id)
	if state != null and state.visual_kind == EntityStateDef.VISUAL_VARIANT:
		appearance.merge(asset.state_appearance(state.visual_value), true)
	# Авторские значения кладутся последними: сезон меняет крону, но не отменяет
	# того, что автор сказал про этот конкретный объект.
	if not extra_appearance.is_empty():
		appearance.merge(extra_appearance, true)
	# Gameplay props intentionally do not overwrite visual state: a cold campfire
	# must remain cold even if an old author override set the flame control.
	view.call("apply_fill_properties", appearance)
	# A freshly-instanced FillObjectController applies its defaults in `_ready`.
	# Repeat state one turn later so authored initial state wins regardless of
	# whether the caller ran before or after the child entered the scene tree.
	view.call_deferred("apply_fill_properties", appearance)
