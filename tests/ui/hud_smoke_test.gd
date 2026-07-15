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
		"UI/HealthPanel/HealthBar"
	) as ProgressBar
	var health_label := floor_scene.get_node(
		"UI/HealthPanel/HealthLabel"
	) as Label
	var invulnerability_label := floor_scene.get_node(
		"UI/HealthPanel/InvulnerabilityLabel"
	) as Label
	var death_overlay := floor_scene.get_node("UI/DeathOverlay") as ColorRect
	var relic_list := floor_scene.get_node(
		"UI/RelicPanel/RelicListLabel"
	) as Label
	var key_label := floor_scene.get_node("UI/HealthPanel/KeyLabel") as Label
	var relic_panel := floor_scene.get_node("UI/RelicPanel") as ColorRect
	var debug_panel := floor_scene.get_node("UI/DebugPanel") as ColorRect
	var room_info_panel := floor_scene.get_node("UI/RoomInfoPanel") as ColorRect

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
