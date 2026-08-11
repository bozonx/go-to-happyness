class_name SeasonalEntityService
extends RefCounted

## Переводит сущности карты по сезону (`map_fill_mode.md` §6.1).
##
## `EntityStateSet.FOLLOW_SEASON` — состояние ПО УМОЛЧАНИЮ у каждой записи, а
## `state_for("season", …)` не вызывал никто. Это значит не «лес не желтеет»: это
## значит, что `seasonal` не разрешался ни во что и `MapEntityPresenter` не
## находил состояния с таким именем, — то есть объявленные ассетами `autumn` и
## `winter` были недостижимы вообще ничем. Ветка формата была мёртвой.
##
## Три границы, из-за которых это отдельная служба, а не строчка в презентере:
##
## * **Сезон приходит одним снимком.** Служба подписана на `season_changed`
##   директора и не читает ни календарь, ни погоду (`world_environment.md` §2).
## * **Переход владеет runtime, а не автор.** Служба пишет через
##   `MapEntityRuntime.set_state`, поэтому сезонная смена состояния попадает в
##   `lifecycle_snapshot` и переживает сохранение так же, как любая другая.
## * **Прикреплённое состояние — исключение, и оно уважается.** Автор, выбравший
##   `winter` для одинокой ели посреди лета, сказал это осознанно (§6.1), и
##   сезон его не переубеждает. Признак прикрепления один: `initial_state`
##   записи не равен `seasonal`.

var _runtime: MapEntityRuntime = null
var _season: StringName = &""


## `director` может быть `null`: карта, открытая в редакторе, сезона не имеет.
func configure(runtime: MapEntityRuntime, director: EnvironmentDirector) -> void:
	_runtime = runtime
	if director == null:
		return
	if not director.season_changed.is_connected(apply_season):
		director.season_changed.connect(apply_season)
	# Первый перевод — сразу, а не со сменой сезона: карта, запущенная в январе,
	# обязана быть зимней с первого кадра, а не с первого марта.
	apply_season(director.snapshot().season)


## Сезон, по которому сущности стоят сейчас. Для тестов и для отладочных панелей.
func current_season() -> StringName:
	return _season


func apply_season(season: StringName) -> void:
	_season = season
	if _runtime == null or season == &"":
		return
	for entity: MapEntityRuntime.RuntimeEntity in _runtime.all():
		if not follows_season(entity):
			continue
		var next := entity.archetype.states.state_for(&"season", season)
		# Архетип, не объявивший состояния для этого сезона, остаётся как есть:
		# у ели нет осени, и это не повод красить её в летнее.
		if next != &"":
			_runtime.set_state(entity.id, next)


## Запись следует за сезоном, если автор не прикрепил ей состояние вручную.
## Проверяется `initial_state`, а не текущее: сущность, уже переведённая этой же
## службой в `autumn`, должна перейти дальше в `winter`, а не замереть осенней.
static func follows_season(entity: MapEntityRuntime.RuntimeEntity) -> bool:
	return entity != null and entity.initial_state == EntityStateSet.FOLLOW_SEASON
