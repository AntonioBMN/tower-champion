class_name GameDisplayProfile
extends RefCounted

const DESIGN_SIZE := Vector2i(1152, 648)
const MINIMUM_WINDOW_SIZE := Vector2i(960, 540)
const DESIGN_ASPECT_RATIO := 16.0 / 9.0


static func get_safe_rect(output_size: Vector2i) -> Rect2i:
	if output_size.x <= 0 or output_size.y <= 0:
		return Rect2i()

	var scale_factor := minf(
		float(output_size.x) / float(DESIGN_SIZE.x),
		float(output_size.y) / float(DESIGN_SIZE.y)
	)
	var safe_size := Vector2i(
		maxi(1, roundi(DESIGN_SIZE.x * scale_factor)),
		maxi(1, roundi(DESIGN_SIZE.y * scale_factor))
	)
	var safe_position := Vector2i(
		(output_size.x - safe_size.x) / 2,
		(output_size.y - safe_size.y) / 2
	)
	return Rect2i(safe_position, safe_size)


static func window_to_design_position(
	window_position: Vector2,
	output_size: Vector2i
) -> Vector2:
	var safe_rect := get_safe_rect(output_size)
	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return Vector2.ZERO

	var normalized_position := (
		window_position - Vector2(safe_rect.position)
	) / Vector2(safe_rect.size)
	return normalized_position * Vector2(DESIGN_SIZE)


static func design_to_window_position(
	design_position: Vector2,
	output_size: Vector2i
) -> Vector2:
	var safe_rect := get_safe_rect(output_size)
	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return Vector2.ZERO

	var normalized_position := design_position / Vector2(DESIGN_SIZE)
	return (
		Vector2(safe_rect.position)
		+ normalized_position * Vector2(safe_rect.size)
	)
