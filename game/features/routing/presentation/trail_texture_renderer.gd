class_name TrailTextureRenderer
extends RefCounted

## Presentation-only adapter that turns the application-owned continuous trail
## field into a GPU texture. Navigation state never owns rendering resources.

var _texture: ImageTexture
var _last_uploaded_revision := -1
var _last_upload_time := -INF


func flush(field: TrailFieldService, now_seconds: float) -> Texture2D:
	if field == null or field.visual_resolution() <= 0:
		return null
	var revision := field.visual_revision()
	if _texture != null and (revision == _last_uploaded_revision or now_seconds - _last_upload_time < 0.25):
		return _texture
	var resolution := field.visual_resolution()
	var image := Image.create_from_data(resolution, resolution, false, Image.FORMAT_R8, field.visual_pixels())
	if _texture == null:
		_texture = ImageTexture.create_from_image(image)
	else:
		_texture.update(image)
	_last_uploaded_revision = revision
	_last_upload_time = now_seconds
	return _texture
