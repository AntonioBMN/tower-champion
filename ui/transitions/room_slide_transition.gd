class_name RoomSlideTransition
extends Control

const DISPLAY_PROFILE = preload("res://ui/display/display_profile.gd")
const DEPARTING_ROOM_FINAL_TINT := Color(0.2, 0.22, 0.28, 1.0)
const ENTERING_ROOM_INITIAL_TINT := Color(0.26, 0.29, 0.37, 1.0)

var world_viewport: Viewport
var transition_direction := Vector2i.ZERO
var previous_view: TextureRect
var destination_view: TextureRect
var transition_player: AnimatedSprite2D
var tracked_player: CanvasItem
var tracked_player_sprite: AnimatedSprite2D


static func get_gameplay_size() -> Vector2:
	return Vector2(DISPLAY_PROFILE.DESIGN_SIZE)


static func calculate_slide_offset(
	direction: Vector2i,
	viewport_size: Vector2
) -> Vector2:
	return Vector2(direction) * viewport_size


static func world_to_screen_position(
	world_position: Vector2,
	camera_center: Vector2,
	camera_zoom: Vector2,
	viewport_size: Vector2
) -> Vector2:
	return (
		(world_position - camera_center) * camera_zoom
		+ viewport_size * 0.5
	)


func prepare(
	viewport_value: Viewport,
	camera_center: Vector2,
	camera_zoom: Vector2,
	direction: Vector2i,
	player_value: CanvasItem,
	player_sprite: AnimatedSprite2D
) -> bool:
	world_viewport = viewport_value
	transition_direction = direction
	tracked_player = player_value
	tracked_player_sprite = player_sprite
	if (
		not is_instance_valid(tracked_player)
		or not is_instance_valid(tracked_player_sprite)
	):
		return false

	_configure_overlay()
	_create_player_visual(
		world_to_screen_position(
			tracked_player_sprite.global_position,
			camera_center,
			camera_zoom,
			get_gameplay_size()
		)
	)
	tracked_player.hide()
	var previous_texture := await _capture_world_view(
		camera_center,
		camera_zoom
	)
	if not is_instance_valid(previous_texture):
		restore_player()
		return false

	_build_room_views(previous_texture)
	return true


func play(
	camera_center: Vector2,
	camera_zoom: Vector2,
	duration: float
) -> bool:
	var destination_texture := await _capture_world_view(
		camera_center,
		camera_zoom
	)
	if not is_instance_valid(destination_texture):
		restore_player()
		return false
	if (
		not is_instance_valid(previous_view)
		or not is_instance_valid(destination_view)
		or not is_instance_valid(transition_player)
	):
		restore_player()
		return false

	destination_view.texture = destination_texture
	var travel_offset := calculate_slide_offset(
		transition_direction,
		get_gameplay_size()
	)
	var slide_tween := create_tween()
	slide_tween.set_parallel(true)
	slide_tween.set_trans(Tween.TRANS_SINE)
	slide_tween.set_ease(Tween.EASE_IN_OUT)
	slide_tween.tween_property(
		previous_view,
		"position",
		-travel_offset,
		duration
	)
	slide_tween.tween_property(
		destination_view,
		"position",
		Vector2.ZERO,
		duration
	)
	slide_tween.tween_property(
		previous_view,
		"modulate",
		DEPARTING_ROOM_FINAL_TINT,
		duration
	)
	slide_tween.tween_property(
		destination_view,
		"modulate",
		Color.WHITE,
		duration
	)
	slide_tween.tween_property(
		transition_player,
		"position",
		world_to_screen_position(
			tracked_player_sprite.global_position,
			camera_center,
			camera_zoom,
			get_gameplay_size()
		),
		duration
	)
	await slide_tween.finished
	transition_player.hide()
	restore_player()
	return true


func get_destination_start_position() -> Vector2:
	if not is_instance_valid(destination_view):
		return Vector2.ZERO
	return destination_view.position


func restore_player() -> void:
	if is_instance_valid(transition_player):
		transition_player.hide()
	if is_instance_valid(tracked_player):
		tracked_player.show()


func _capture_world_view(
	camera_center: Vector2,
	camera_zoom: Vector2
) -> Texture2D:
	# The dummy renderer used by headless smoke tests has no readable texture.
	if DisplayServer.get_name() == "headless":
		return null

	var viewport_size := DISPLAY_PROFILE.DESIGN_SIZE
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return null

	var capture_viewport := SubViewport.new()
	capture_viewport.size = viewport_size
	capture_viewport.world_2d = world_viewport.world_2d
	capture_viewport.transparent_bg = false
	capture_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(capture_viewport)

	var capture_camera := Camera2D.new()
	capture_camera.position = camera_center
	capture_camera.zoom = camera_zoom
	capture_viewport.add_child(capture_camera)
	capture_camera.enabled = true

	# Wait until the newly created viewport has completed an actual draw. Reading
	# it after only a process frame can return its initial black clear texture.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var image := capture_viewport.get_texture().get_image()
	capture_viewport.queue_free()
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _configure_overlay() -> void:
	var viewport_size := get_gameplay_size()
	name = "RoomTransitionOverlay"
	position = Vector2.ZERO
	size = viewport_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -100


func _create_player_visual(screen_position: Vector2) -> void:
	transition_player = AnimatedSprite2D.new()
	transition_player.name = "TransitionPlayer"
	transition_player.position = screen_position
	transition_player.sprite_frames = tracked_player_sprite.sprite_frames
	transition_player.animation = tracked_player_sprite.animation
	transition_player.frame = tracked_player_sprite.frame
	transition_player.scale = tracked_player_sprite.global_transform.get_scale()
	transition_player.flip_h = (
		transition_direction.x < 0
		if transition_direction.x != 0
		else tracked_player_sprite.flip_h
	)
	transition_player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	transition_player.z_index = 10
	add_child(transition_player)
	if transition_player.sprite_frames.has_animation(&"walk"):
		transition_player.play(&"walk")
	else:
		transition_player.play()


func _build_room_views(previous_texture: Texture2D) -> void:
	var viewport_size := get_gameplay_size()
	previous_view = _create_texture_rect(
		previous_texture,
		Vector2.ZERO,
		viewport_size
	)
	destination_view = _create_texture_rect(
		null,
		calculate_slide_offset(transition_direction, viewport_size),
		viewport_size
	)
	destination_view.modulate = ENTERING_ROOM_INITIAL_TINT
	add_child(previous_view)
	add_child(destination_view)


func _create_texture_rect(
	texture_value: Texture2D,
	position_value: Vector2,
	size_value: Vector2
) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.texture = texture_value
	texture_rect.position = position_value
	texture_rect.size = size_value
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture_rect
