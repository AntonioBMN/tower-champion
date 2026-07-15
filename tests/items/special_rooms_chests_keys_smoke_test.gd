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
	current_scene = floor_scene
	await process_frame

	var player := floor_scene.get_node("Player") as CharacterBody2D
	var inventory := player.get_node("RunInventory") as RunInventory
	var treasure_room_index: int = floor_scene.get("treasure_room_index")
	var room_types: Array = floor_scene.get("room_types")
	var minimap := floor_scene.get_node("UI/MinimapPanel/Minimap")

	_expect(
		room_types[treasure_room_index] == "treasure",
		"every run should contain a treasure room"
	)
	_expect(
		minimap.call("get_room_type", treasure_room_index) == "treasure",
		"treasure role should be represented on the minimap"
	)

	floor_scene.call("_spawn_room_enemies", treasure_room_index)
	var chests := floor_scene.get_node("Chests")
	_expect(chests.get_child_count() == 1, "treasure room should spawn one chest")
	var chest := chests.get_child(0) as TreasureChest
	chest.configure(TreasureChest.ChestTier.RED)
	floor_scene.set("upgraded_rarity_chance", 1.0)

	_expect(
		not chest.call("_try_open", player),
		"chest should remain locked without a key"
	)
	_expect(not chest.is_open, "failed attempt should not open the chest")

	floor_scene.set("health_drop_chance", 0.0)
	var combat_room_index := room_types.find("normal")
	if combat_room_index < 0:
		combat_room_index = floor_scene.get("final_room_index")
	floor_scene.call(
		"_try_drop_room_reward", combat_room_index, player.global_position
	)
	var key_pickups := floor_scene.get_node("Keys")
	_expect(
		key_pickups.get_child_count() == 1,
		"first cleared combat room should guarantee a key"
	)
	var key_pickup := key_pickups.get_child(0) as KeyPickup
	_expect(key_pickup.call("_try_collect", player), "player should collect the key")
	await process_frame
	_expect(inventory.keys == 1, "collected key should enter run inventory")
	_expect(
		floor_scene.get_node("UI/HealthPanel/KeyLabel").text == "KEYS: 1",
		"HUD should display the collected key"
	)

	var relic_count_before := floor_scene.get_node("Relics").get_child_count()
	_expect(chest.call("_try_open", player), "one key should open the chest")
	await process_frame
	_expect(chest.is_open, "opened chest should retain its state")
	_expect(inventory.keys == 0, "opening a chest should consume exactly one key")
	_expect(
		floor_scene.get_node("Relics").get_child_count() == relic_count_before + 1,
		"red chest should reveal one relic reward"
	)
	_expect(
		not chest.call("_try_open", player),
		"an opened chest should not grant duplicate rewards"
	)

	if failures == 0:
		print("PASS: special rooms, chests and keys smoke test")

	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
