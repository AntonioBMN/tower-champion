extends SceneTree

const FIRST_FLOOR_SCENE: PackedScene = preload(
	"res://world/floors/first_floor.tscn"
)
const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const RELIC_CATALOG = preload("res://items/relics/relic_catalog.gd")

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor_scene := FIRST_FLOOR_SCENE.instantiate()
	root.add_child(floor_scene)
	current_scene = floor_scene
	await process_frame

	var player := floor_scene.get_node("Player") as CharacterBody2D
	var relic_component := player.get_node("RelicComponent") as RelicComponent
	var health := player.get_node("HealthComponent") as HealthComponent
	var special_room_index: int = floor_scene.get("special_room_index")
	var base_damage: int = player.get("attack_damage")
	var base_speed: float = player.get("speed")
	var base_range: float = player.get("attack_range")
	var base_width: float = player.get("attack_width")
	var base_max_health := health.max_health

	floor_scene.call("_spawn_room_enemies", special_room_index)
	var relics := floor_scene.get_node("Relics")
	_expect(relics.get_child_count() == 1, "sanctuary should spawn one relic")

	var relic_pickup := relics.get_child(0) as Area2D
	var offered_relic_id: String = relic_pickup.get("relic_id")
	_expect(
		RELIC_CATALOG.has_relic(offered_relic_id),
		"offered relic should exist in the catalog"
	)
	_expect(
		relic_pickup.call("_try_collect", player),
		"player should collect the sanctuary relic"
	)
	await process_frame
	_expect(
		relic_component.collected_ids.size() == 1,
		"collected relic should remain registered during the run"
	)
	_expect(
		floor_scene.get_node(
			"UI/SafeFrame/RelicPanel/RelicListLabel"
		).text
		.contains(
			TranslationServer.translate(
				RELIC_CATALOG.get_relic(offered_relic_id)["name_key"]
			)
		),
		"HUD should list the collected relic"
	)

	for relic_id in RELIC_CATALOG.get_all_ids():
		if not relic_component.has_relic(relic_id):
			_expect(
				player.call("collect_relic", relic_id),
				"each unique relic should be collectible"
			)

	_expect(
		relic_component.collected_ids.size() == 4,
		"run should retain all four unique relics"
	)
	_expect(
		player.get("attack_damage") == base_damage + 5,
		"Crimson Blade should add five sword damage"
	)
	_expect(
		is_equal_approx(player.get("speed"), base_speed * 1.15),
		"Wind Boots should increase movement speed by fifteen percent"
	)
	_expect(
		is_equal_approx(player.get("attack_range"), base_range + 24.0)
		and is_equal_approx(player.get("attack_width"), base_width + 8.0),
		"Far Eye should increase sword range and width"
	)
	_expect(
		health.max_health == base_max_health + 15
		and health.current_health == health.max_health,
		"Iron Heart should increase maximum health and heal fifteen"
	)

	var attack_shape := player.get_node(
		"SwordAttack/CollisionShape2D"
	).shape as RectangleShape2D
	_expect(
		attack_shape.size == Vector2(base_range + 24.0, base_width + 8.0),
		"range relic should update the real sword hitbox"
	)
	var damage_after_collection: int = player.get("attack_damage")
	_expect(
		not player.call("collect_relic", "crimson_blade")
		and player.get("attack_damage") == damage_after_collection,
		"duplicate relics should not apply twice"
	)
	_expect(
		floor_scene.get_node("UI/SafeFrame/RelicNotice").visible,
		"collecting a relic should show HUD feedback"
	)
	_expect(
		floor_scene.get_node("UI/SafeFrame/RelicPanel").visible,
		"relic list should only occupy HUD space after collecting a relic"
	)

	var fresh_player := PLAYER_SCENE.instantiate() as CharacterBody2D
	floor_scene.add_child(fresh_player)
	_expect(
		fresh_player.get_node("RelicComponent").collected_ids.is_empty(),
		"a new run player should start without relics"
	)

	await create_timer(0.35, true, false, true).timeout
	if failures == 0:
		print("PASS: relic system smoke test")

	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
