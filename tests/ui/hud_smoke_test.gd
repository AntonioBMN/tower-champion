extends SceneTree

const FIRST_FLOOR_SCENE: PackedScene = preload(
	"res://world/floors/first_floor.tscn"
)

var failures: int = 0


func _initialize() -> void:
	TranslationServer.set_locale("en")
	_run.call_deferred()


func _run() -> void:
	var floor_scene := FIRST_FLOOR_SCENE.instantiate()
	root.add_child(floor_scene)
	await process_frame

	var player := floor_scene.get_node("Player") as CharacterBody2D
	var hud := floor_scene.get_node("UI") as CombatHUD
	var health := player.get_node("HealthComponent") as HealthComponent
	var health_bar := floor_scene.get_node(
		"UI/SafeFrame/HealthPanel/HealthBar"
	) as ProgressBar
	var health_label := floor_scene.get_node(
		"UI/SafeFrame/HealthPanel/HealthLabel"
	) as Label
	var invulnerability_label := floor_scene.get_node(
		"UI/SafeFrame/HealthPanel/InvulnerabilityLabel"
	) as Label
	var death_overlay := floor_scene.get_node(
		"UI/SafeFrame/DeathOverlay"
	) as ColorRect
	var relic_list := floor_scene.get_node(
		"UI/SafeFrame/RelicPanel/RelicListLabel"
	) as Label
	var key_label := floor_scene.get_node(
		"UI/SafeFrame/HealthPanel/KeyLabel"
	) as Label
	var relic_panel := floor_scene.get_node(
		"UI/SafeFrame/RelicPanel"
	) as ColorRect
	var debug_panel := floor_scene.get_node(
		"UI/SafeFrame/DebugPanel"
	) as ColorRect
	var room_info_panel := floor_scene.get_node(
		"UI/SafeFrame/RoomInfoPanel"
	) as ColorRect
	var map_backdrop := floor_scene.get_node(
		"UI/SafeFrame/MapBackdrop"
	) as ColorRect
	var minimap_panel := floor_scene.get_node(
		"UI/SafeFrame/MinimapPanel"
	) as ColorRect
	var minimap := floor_scene.get_node(
		"UI/SafeFrame/MinimapPanel/Minimap"
	) as FloorMinimap
	var map_title := floor_scene.get_node(
		"UI/SafeFrame/MinimapPanel/TitleLabel"
	) as Label
	var map_progress := floor_scene.get_node(
		"UI/SafeFrame/MinimapPanel/ProgressLabel"
	) as Label

	_expect(health.max_health == 90, "player should start with 90 maximum health")
	_expect(health_bar.max_value == 90.0, "health bar maximum should match player")
	_expect(health_bar.value == 90.0, "health bar should start full")
	_expect(health_label.text == "90 / 90", "health text should show initial value")
	_expect(relic_list.text == "None", "relic HUD should start empty")
	_expect(not relic_panel.visible, "empty relic HUD should not occupy screen space")
	_expect(not debug_panel.visible, "technical HUD should start hidden")
	_expect(
		room_info_panel.size.x <= 290.0 and room_info_panel.size.y <= 70.0,
		"room information should remain compact in the lower-right corner"
	)
	var debug_event := InputEventKey.new()
	debug_event.keycode = KEY_F3
	debug_event.pressed = true
	hud._unhandled_input(debug_event)
	_expect(debug_panel.visible, "F3 should reveal technical HUD information")
	hud._unhandled_input(debug_event)
	_expect(not debug_panel.visible, "F3 should hide technical HUD information")
	_expect(key_label.text == "KEYS: 0", "key HUD should start at zero")
	player.call("add_keys", 2)
	_expect(key_label.text == "KEYS: 2", "key HUD should follow inventory")

	_expect(not hud.is_map_expanded(), "minimap should start in compact mode")
	_expect(
		minimap.get_drawn_room_count() == 1
		and minimap.get_discovered_room_count() == 1,
		"compact minimap should hide every unvisited neighboring room"
	)
	var map_event := InputEventAction.new()
	map_event.action = "toggle_map"
	map_event.pressed = true
	hud._unhandled_input(map_event)
	_expect(hud.is_map_expanded(), "map action should expand the minimap")
	_expect(map_backdrop.visible, "expanded map should dim the playfield")
	_expect(map_title.visible, "expanded map should display its title")
	_expect(
		map_progress.text == "EXPLORED ROOMS: 1",
		"expanded map should report exploration progress"
	)
	_expect(
		minimap.get_drawn_room_count() == minimap.get_discovered_room_count()
		and minimap.get_drawn_room_count() == 1
		and minimap.get_drawn_room_count() < minimap.get_total_room_count(),
		"expanded map should not reveal unexplored floor branches"
	)
	_expect(
		minimap_panel.anchor_left == 0.5
		and minimap_panel.anchor_top == 0.5,
		"expanded map should be centered on screen"
	)
	hud._unhandled_input(map_event)
	_expect(not hud.is_map_expanded(), "map action should restore compact mode")
	_expect(not map_backdrop.visible, "compact mode should remove map backdrop")

	health.take_damage(1)
	await process_frame
	_expect(health_bar.value == 89.0, "damage should update the health bar")
	_expect(health_label.text == "89 / 90", "damage should update health text")
	_expect(
		invulnerability_label.visible,
		"invulnerability indicator should appear after damage"
	)

	await create_timer(0.85).timeout
	_expect(
		not invulnerability_label.visible,
		"invulnerability indicator should disappear after its timer"
	)

	health.take_damage(health.current_health)
	await process_frame
	_expect(death_overlay.visible, "death overlay should appear on death")

	if failures == 0:
		print("PASS: combat HUD smoke test")

	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
