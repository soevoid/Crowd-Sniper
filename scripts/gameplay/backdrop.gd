class_name Backdrop
extends Node2D
## Environment visual: the approved park plaza artwork, drawn to cover the
## whole pannable camera area (AimController.camera_bounds) at its native
## aspect ratio — scaled to the bounds height and centered horizontally, so
## no camera position ever reveals space beyond the artwork.

const TEXTURE := preload("res://assets/backgrounds/crowd_sniper_plaza.png")
## Must cover AimController.camera_bounds: Rect2(-140, -80, 1360, 2140).
const COVER_HEIGHT := 2140.0
const COVER_TOP := -80.0


func _draw() -> void:
	var tex_size := Vector2(TEXTURE.get_size())
	var scale_factor := COVER_HEIGHT / tex_size.y
	var width := tex_size.x * scale_factor
	var rect := Rect2(540.0 - width * 0.5, COVER_TOP, width, COVER_HEIGHT)
	draw_texture_rect(TEXTURE, rect, false)
