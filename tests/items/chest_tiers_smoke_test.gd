extends SceneTree

const CHEST_SCENE: PackedScene = preload(
	"res://items/chests/treasure_chest.tscn"
)
const FIRST_FLOOR_SCENE: PackedScene = preload(
	"res://world/floors/first_floor.tscn"
)
const RELIC_CATALOG = preload("res://items/relics/relic_catalog.gd")
const CHEST_TEXTURE_PATH := (
	"res://assets/sprites/items/chests/fantasy_rpg_toony_chests_32x32.png"
)

var failures: int = 0


func _initialize() -> void:
	TranslationServer.set_locale("en")
	_run.call_deferred()


func _run() -> void:
	var tier_cases := [
		[TreasureChest.ChestTier.WOOD, Vector2i(96, 128), "WOODEN"],
		[TreasureChest.ChestTier.SILVER, Vector2i(192, 128), "SILVER"],
		[TreasureChest.ChestTier.RED, Vector2i(0, 0), "RED"],
	]

	for tier_case in tier_cases:
		var chest := CHEST_SCENE.instantiate() as TreasureChest
		chest.configure(tier_case[0])
		root.add_child(chest)
		await process_frame
		var sprite := chest.get_node("ChestSprite") as Sprite2D
		_expect(
			chest.get_atlas_origin() == tier_case[1]
			and Vector2i(sprite.region_rect.position) == tier_case[1],
			"each chest tier should use its correct 32x32 atlas region"
		)
		_expect(
			sprite.texture.resource_path == CHEST_TEXTURE_PATH,
			"chest tiers should use the imported source sprite sheet"
		)
		_expect(
			chest.get_node("PromptLabel").text.contains(tier_case[2]),
			"chest prompt should identify its localized tier"
		)
		chest.call("_set_opening_frame", 3)
		_expect(
			Vector2i(sprite.region_rect.position)
			== tier_case[1] + Vector2i(0, 96),
			"opening animation should advance through four vertical frames"
		)
		chest.queue_free()
		await process_frame

	var floor_scene := FIRST_FLOOR_SCENE.instantiate()
	root.add_child(floor_scene)
	await process_frame
	var player := floor_scene.get_node("Player") as CharacterBody2D
	var animated_chest := CHEST_SCENE.instantiate() as TreasureChest
	animated_chest.configure(TreasureChest.ChestTier.SILVER)
	root.add_child(animated_chest)
	await process_frame
	player.call("add_keys", 1)
	_expect(
		animated_chest.call("_try_open", player),
		"a chest with an available key should start opening"
	)
	await create_timer(0.5, true, false, true).timeout
	var animated_sprite := animated_chest.get_node("ChestSprite") as Sprite2D
	_expect(
		Vector2i(animated_sprite.region_rect.position) == Vector2i(192, 224),
		"opening tween should finish on the fourth vertical frame"
	)
	animated_chest.queue_free()
	floor_scene.set("wood_chest_health_chance", 0.0)
	floor_scene.set("upgraded_rarity_chance", 1.0)

	var rare_id: String = floor_scene.call(
		"_take_chest_relic_id", TreasureChest.ChestTier.RED
	)
	var uncommon_id: String = floor_scene.call(
		"_take_chest_relic_id", TreasureChest.ChestTier.SILVER
	)
	var common_id: String = floor_scene.call(
		"_take_chest_relic_id", TreasureChest.ChestTier.WOOD
	)
	_expect(
		RELIC_CATALOG.get_relic(rare_id).get("rarity") == "rare",
		"red chests should prioritize rare relics"
	)
	_expect(
		RELIC_CATALOG.get_relic(uncommon_id).get("rarity") == "uncommon",
		"silver chests should prioritize uncommon relics"
	)
	_expect(
		RELIC_CATALOG.get_relic(common_id).get("rarity") == "common",
		"wooden chests should use common relics when they do not drop health"
	)

	_assert_forced_roll(
		floor_scene, Vector3(1.0, 0.0, 0.0), TreasureChest.ChestTier.WOOD
	)
	_assert_forced_roll(
		floor_scene, Vector3(0.0, 1.0, 0.0), TreasureChest.ChestTier.SILVER
	)
	_assert_forced_roll(
		floor_scene, Vector3(0.0, 0.0, 1.0), TreasureChest.ChestTier.RED
	)

	if failures == 0:
		print("PASS: chest tiers smoke test")

	quit(failures)


func _assert_forced_roll(
	floor_scene: Node,
	weights: Vector3,
	expected_tier: int
) -> void:
	floor_scene.set("wood_chest_weight", weights.x)
	floor_scene.set("silver_chest_weight", weights.y)
	floor_scene.set("red_chest_weight", weights.z)
	_expect(
		floor_scene.call("_roll_chest_tier") == expected_tier,
		"configured chest weights should control tier selection"
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
