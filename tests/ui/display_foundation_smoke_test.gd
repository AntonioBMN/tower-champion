extends SceneTree

const DISPLAY_PROFILE = preload("res://ui/display/display_profile.gd")
const FIRST_FLOOR_SCENE: PackedScene = preload(
	"res://world/floors/first_floor.tscn"
)
const ROOM_SLIDE_TRANSITION = preload(
	"res://ui/transitions/room_slide_transition.gd"
)
const TEST_SEED := 52026

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_validate_project_display_settings()
	_validate_safe_rect_calculation()
	_validate_coordinate_conversion()
	await _validate_safe_frame_scene()
	await _validate_layout_is_viewport_independent()

	if failures == 0:
		print("PASS: multiple resolutions and 16:9 safe frame smoke test")

	quit(failures)


func _validate_project_display_settings() -> void:
	var main_window := root as Window
	var display_manager := root.get_node("DisplayManager")
	var resolution_presets: Array[Vector2i] = (
		display_manager.get_resolution_presets()
	)
	_expect(
		DISPLAY_PROFILE.DESIGN_SIZE == Vector2i(1152, 648),
		"gameplay should have one 1152x648 logical design resolution"
	)
	_expect(
		is_equal_approx(DISPLAY_PROFILE.DESIGN_ASPECT_RATIO, 16.0 / 9.0),
		"logical gameplay frame should use a 16:9 aspect ratio"
	)
	_expect(
		ProjectSettings.get_setting("display/window/stretch/mode")
		== "canvas_items",
		"the project should render fonts at the output resolution"
	)
	_expect(
		ProjectSettings.get_setting("display/window/stretch/aspect") == "keep",
		"the project should preserve 16:9 with letterbox or pillarbox"
	)
	_expect(
		main_window.content_scale_size == DISPLAY_PROFILE.DESIGN_SIZE,
		"display manager should apply the logical resolution at startup"
	)
	_expect(
		main_window.content_scale_mode
		== Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		and main_window.content_scale_aspect
		== Window.CONTENT_SCALE_ASPECT_KEEP,
		"display manager should protect composition without scaling rendered text"
	)
	_expect(
		resolution_presets.has(Vector2i(1024, 768))
		and resolution_presets.has(Vector2i(1280, 800))
		and resolution_presets.has(Vector2i(1600, 700)),
		"display manager should expose aspect-ratio test presets"
	)
	_expect(
		display_manager.find_closest_resolution_index(Vector2i(1280, 800))
		== resolution_presets.find(Vector2i(1280, 800)),
		"display manager should select an exact active resolution preset"
	)


func _validate_safe_rect_calculation() -> void:
	var expected_rects := {
		Vector2i(1280, 720): Rect2i(0, 0, 1280, 720),
		Vector2i(1920, 1200): Rect2i(0, 60, 1920, 1080),
		Vector2i(2560, 1080): Rect2i(320, 0, 1920, 1080),
		Vector2i(1024, 768): Rect2i(0, 96, 1024, 576),
	}
	for output_size in expected_rects:
		_expect(
			DISPLAY_PROFILE.get_safe_rect(output_size)
			== expected_rects[output_size],
			"safe frame should be centered at output size %s" % output_size
		)


func _validate_coordinate_conversion() -> void:
	var output_size := Vector2i(2560, 1080)
	var design_center := Vector2(DISPLAY_PROFILE.DESIGN_SIZE) * 0.5
	var window_center := DISPLAY_PROFILE.design_to_window_position(
		design_center,
		output_size
	)
	_expect(
		window_center.distance_to(Vector2(1280.0, 540.0)) < 0.01,
		"design center should remain centered inside an ultrawide output"
	)
	_expect(
		DISPLAY_PROFILE.window_to_design_position(
			window_center,
			output_size
		).distance_to(design_center) < 0.01,
		"window and design coordinate conversion should round-trip"
	)


func _validate_safe_frame_scene() -> void:
	var floor_scene := FIRST_FLOOR_SCENE.instantiate()
	floor_scene.set("randomize_layout", false)
	floor_scene.set("fixed_seed", TEST_SEED)
	root.add_child(floor_scene)
	await process_frame

	var safe_frame := floor_scene.get_node("UI/SafeFrame") as Control
	_expect(
		safe_frame.size == Vector2(DISPLAY_PROFILE.DESIGN_SIZE),
		"HUD safe frame should match the logical gameplay resolution"
	)
	for overlay_name in [
		"DamageFlash",
		"DeathOverlay",
		"VictoryOverlay",
		"TransitionFade",
		"PauseOverlay",
	]:
		var overlay := safe_frame.get_node(overlay_name) as Control
		_expect(
			overlay.anchor_right == 1.0
			and overlay.anchor_bottom == 1.0
			and overlay.size == safe_frame.size,
			"%s should cover the complete safe frame" % overlay_name
		)

	_expect(
		ROOM_SLIDE_TRANSITION.get_gameplay_size()
		== Vector2(DISPLAY_PROFILE.DESIGN_SIZE),
		"room transitions should capture only the protected gameplay frame"
	)
	floor_scene.queue_free()
	await process_frame


func _validate_layout_is_viewport_independent() -> void:
	var wide_signature: Dictionary = await _layout_signature_for_viewport(
		Vector2i(2560, 1080)
	)
	var classic_signature: Dictionary = await _layout_signature_for_viewport(
		Vector2i(1024, 768)
	)
	_expect(
		wide_signature == classic_signature,
		"the same seed should keep rooms and doors identical across aspects"
	)
	_expect(
		wide_signature["screen_room_size"] == Vector2i(16, 7),
		"regular rooms should derive from the logical resolution, not the window"
	)


func _layout_signature_for_viewport(viewport_size: Vector2i) -> Dictionary:
	var test_viewport := SubViewport.new()
	test_viewport.size = viewport_size
	test_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(test_viewport)

	var floor_scene := FIRST_FLOOR_SCENE.instantiate()
	floor_scene.set("randomize_layout", false)
	floor_scene.set("fixed_seed", TEST_SEED)
	test_viewport.add_child(floor_scene)
	await process_frame

	var signature := {
		"screen_room_size": floor_scene.call("_screen_room_size"),
		"room_positions": floor_scene.get("room_grid_positions").duplicate(true),
		"room_bounds": floor_scene.get("room_bounds").duplicate(true),
		"room_connections": floor_scene.get("room_connections").duplicate(true),
		"room_door_cells": floor_scene.get("room_door_cells").duplicate(true),
		"room_door_ratios": floor_scene.get("room_door_ratios").duplicate(true),
		"large_room_footprints": floor_scene.get(
			"large_room_footprints"
		).duplicate(true),
	}
	test_viewport.queue_free()
	await process_frame
	return signature


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
