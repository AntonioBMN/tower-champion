extends SceneTree

const FIRST_FLOOR_SCENE: PackedScene = preload("res://first_floor.tscn")

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor_scene := FIRST_FLOOR_SCENE.instantiate()
	root.add_child(floor_scene)
	await process_frame

	var player := floor_scene.get_node("Player") as CharacterBody2D
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

	_expect(health_bar.max_value == 5.0, "health bar maximum should match player")
	_expect(health_bar.value == 5.0, "health bar should start full")
	_expect(health_label.text == "5 / 5", "health text should show initial value")
	_expect(relic_list.text == "Nenhuma", "relic HUD should start empty")

	health.take_damage(1)
	await process_frame
	_expect(health_bar.value == 4.0, "damage should update the health bar")
	_expect(health_label.text == "4 / 5", "damage should update health text")
	_expect(
		invulnerability_label.visible,
		"invulnerability indicator should appear after damage"
	)

	await create_timer(0.85).timeout
	_expect(
		not invulnerability_label.visible,
		"invulnerability indicator should disappear after its timer"
	)

	health.take_damage(99)
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
