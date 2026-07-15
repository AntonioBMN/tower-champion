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

	var hud := floor_scene.get_node("UI") as CombatHUD
	var display_manager := root.get_node("DisplayManager")
	var pause_overlay := hud.get_node("SafeFrame/PauseOverlay") as ColorRect
	var pause_title := hud.get_node(
		"SafeFrame/PauseOverlay/PausePanel/PauseTitle"
	) as Label
	var resolution_label := hud.get_node(
		"SafeFrame/PauseOverlay/PausePanel/ResolutionLabel"
	) as Label
	var resolution_option := hud.get_node(
		"SafeFrame/PauseOverlay/PausePanel/ResolutionOption"
	) as OptionButton
	var apply_resolution_button := hud.get_node(
		"SafeFrame/PauseOverlay/PausePanel/ApplyResolutionButton"
	) as Button
	var resolution_status := hud.get_node(
		"SafeFrame/PauseOverlay/PausePanel/ResolutionStatus"
	) as Label
	var resume_button := hud.get_node(
		"SafeFrame/PauseOverlay/PausePanel/ResumeButton"
	) as Button
	var restart_button := hud.get_node(
		"SafeFrame/PauseOverlay/PausePanel/RestartButton"
	) as Button
	var quit_button := hud.get_node(
		"SafeFrame/PauseOverlay/PausePanel/QuitButton"
	) as Button

	_expect(not paused, "scene tree should start unpaused")
	_expect(not pause_overlay.visible, "pause menu should start hidden")
	hud.open_pause_menu()
	_expect(paused, "opening the pause menu should pause the scene tree")
	_expect(pause_overlay.visible, "opening the pause menu should show its overlay")
	_expect(pause_title.text == "GAME PAUSED", "pause title should be localized")
	_expect(
		resolution_label.text == "RESOLUTION"
		and apply_resolution_button.text == "APPLY",
		"pause menu should localize its resolution controls"
	)
	_expect(resume_button.text == "RESUME", "resume action should be localized")
	var presets: Array[Vector2i] = display_manager.get_resolution_presets()
	_expect(
		resolution_option.item_count == presets.size(),
		"pause menu should list every resolution test preset"
	)
	var listed_resolutions: Array[Vector2i] = []
	for item_index in range(resolution_option.item_count):
		listed_resolutions.append(
			resolution_option.get_item_metadata(item_index)
		)
	_expect(
		listed_resolutions.has(Vector2i(1024, 768))
		and listed_resolutions.has(Vector2i(1280, 800))
		and listed_resolutions.has(Vector2i(1600, 700)),
		"resolution presets should cover 4:3, 16:10 and ultrawide"
	)
	_expect(
		resolution_status.text.contains("Current:"),
		"pause menu should report the active window resolution"
	)
	_expect(
		restart_button.pressed.get_connections().size() == 1
		and quit_button.pressed.get_connections().size() == 1
		and apply_resolution_button.pressed.get_connections().size() == 1,
		"pause actions and resolution apply button should be connected"
	)

	resume_button.pressed.emit()
	_expect(not paused, "resume button should unpause the scene tree")
	_expect(not pause_overlay.visible, "resume button should hide the menu")

	var pause_event := InputEventAction.new()
	pause_event.action = "pause"
	pause_event.pressed = true
	hud._unhandled_input(pause_event)
	_expect(paused and pause_overlay.visible, "pause action should open the menu")
	hud._unhandled_input(pause_event)
	_expect(not paused and not pause_overlay.visible, "pause action should resume")

	hud.get_node("SafeFrame/DeathOverlay").show()
	hud.open_pause_menu()
	_expect(
		not paused and not pause_overlay.visible,
		"pause menu should stay disabled during death feedback"
	)
	hud.get_node("SafeFrame/DeathOverlay").hide()
	hud.get_node("SafeFrame/VictoryOverlay").show()
	hud.open_pause_menu()
	_expect(
		not paused and not pause_overlay.visible,
		"pause menu should stay disabled after victory"
	)

	paused = false
	if failures == 0:
		print("PASS: pause menu smoke test")

	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
