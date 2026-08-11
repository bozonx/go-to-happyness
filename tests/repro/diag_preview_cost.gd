extends SceneTree

## Сколько стоит `preview.png` (`MapPreviewImage`).
##
## Превью рисуется на КАЖДОЕ сохранение карты, поэтому его цена — это задержка,
## которую автор чувствует пальцами. Первая версия считала по пикселю картинки и
## стоила 560 мс на доске 128² независимо от её размера; этого хватило, чтобы
## сквозной тест редактора перестал укладываться в свои 45 с. Версия по клеткам с
## растягиванием — около 130 мс.
##
## Печатает и не проверяет: бюджет здесь зависит от машины, а регрессия видна по
## порядку величины.

const BOARDS: Array[int] = [32, 64, 128, 256]
const RUNS := 5


func _init() -> void:
	for board: int in BOARDS:
		var document := MapDocument.create(&"bench", "bench", board)
		var started := Time.get_ticks_msec()
		for run in RUNS:
			MapPreviewImage.render(document)
		var elapsed := Time.get_ticks_msec() - started
		print("board %d²: %d ms за %d прогонов (%.1f мс на превью)"
			% [board, elapsed, RUNS, float(elapsed) / float(RUNS)])
	quit(0)
