extends SceneTree

const FIRST_FLOOR_SCENE: PackedScene = preload(
	"res://world/floors/first_floor.tscn"
)

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	TranslationServer.set_locale("en")
	var english_floor := FIRST_FLOOR_SCENE.instantiate()
	root.add_child(english_floor)
	await process_frame
	_expect(
		english_floor.get_node("UI/SafeFrame/HealthPanel/KeyLabel").text
		== "0",
		"icon-based key HUD should remain language neutral"
	)
	_expect(
		english_floor.get_node("UI/SafeFrame/MinimapPanel/TitleLabel").text
		== "FLOOR MAP",
		"expanded map interface should use the English locale"
	)
	_expect(
		english_floor.get_node(
			"UI/SafeFrame/PauseOverlay/PausePanel/ResolutionLabel"
		).text == "RESOLUTION",
		"resolution menu should use the English source locale"
	)
	_expect(
		english_floor.call("_room_type_display_name", "start") == "START",
		"dynamic room labels should use translation keys"
	)
	english_floor.queue_free()
	await process_frame

	TranslationServer.set_locale("pt_BR")
	var portuguese_floor := FIRST_FLOOR_SCENE.instantiate()
	root.add_child(portuguese_floor)
	await process_frame
	_expect(
		portuguese_floor.get_node("UI/SafeFrame/HealthPanel/KeyLabel").text
		== "0",
		"icon-based key HUD should remain language neutral in Portuguese"
	)
	_expect(
		portuguese_floor.get_node("UI/SafeFrame/MinimapPanel/TitleLabel").text
		== "MAPA DO ANDAR",
		"expanded map interface should support Portuguese"
	)
	_expect(
		portuguese_floor.get_node(
			"UI/SafeFrame/PauseOverlay/PausePanel/ResolutionLabel"
		).text == "RESOLUÇÃO",
		"resolution menu should support Portuguese"
	)
	_expect(
		portuguese_floor.call("_room_type_display_name", "start") == "INÍCIO",
		"dynamic room labels should support Portuguese"
	)
	_expect(
		TranslationServer.translate("CHEST_TIER_RED") == "VERMELHO",
		"chest tier names should support Portuguese"
	)
	_expect(
		TranslationServer.translate("PAUSE_RESUME") == "CONTINUAR",
		"pause menu actions should support Portuguese"
	)
	portuguese_floor.queue_free()
	await process_frame

	TranslationServer.set_locale("fr")
	_expect(
		TranslationServer.translate("HUD_HEALTH_TITLE") == "HEALTH",
		"unsupported locales should fall back to English"
	)
	TranslationServer.set_locale("en")

	if failures == 0:
		print("PASS: localization smoke test")

	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
