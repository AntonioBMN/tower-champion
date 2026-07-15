class_name CombatHUD
extends CanvasLayer

const RELIC_CATALOG = preload("res://items/relics/relic_catalog.gd")
const COMPACT_MAP_PANEL_RECT := Rect2(-242.0, 12.0, 230.0, 150.0)
const EXPANDED_MAP_PANEL_HALF_SIZE := Vector2(410.0, 250.0)
const COMPACT_MAP_POSITION := Vector2(8.0, 8.0)
const COMPACT_MAP_SIZE := Vector2(214.0, 134.0)
const EXPANDED_MAP_POSITION := Vector2(24.0, 56.0)
const EXPANDED_MAP_SIZE := Vector2(772.0, 366.0)
const COMPACT_MAP_COLOR := Color(0.05, 0.06, 0.09, 0.88)
const EXPANDED_MAP_COLOR := Color(0.035, 0.043, 0.065, 0.97)

var health_component: HealthComponent
var relic_component: RelicComponent
var run_inventory: RunInventory
var damage_flash_tween: Tween
var damage_value_tween: Tween
var relic_notice_tween: Tween
var damage_value_start_position: Vector2
var map_expanded: bool = false

@onready var display_manager: Node = get_node("/root/DisplayManager")
@onready var safe_frame: Control = $SafeFrame
@onready var health_bar: ProgressBar = $SafeFrame/HealthPanel/HealthBar
@onready var health_label: Label = $SafeFrame/HealthPanel/HealthLabel
@onready var invulnerability_label: Label = (
	$SafeFrame/HealthPanel/InvulnerabilityLabel
)
@onready var damage_value_label: Label = (
	$SafeFrame/HealthPanel/DamageValueLabel
)
@onready var damage_flash: ColorRect = $SafeFrame/DamageFlash
@onready var death_overlay: ColorRect = $SafeFrame/DeathOverlay
@onready var relic_panel: ColorRect = $SafeFrame/RelicPanel
@onready var relic_list_label: Label = (
	$SafeFrame/RelicPanel/RelicListLabel
)
@onready var relic_notice: Label = $SafeFrame/RelicNotice
@onready var key_label: Label = $SafeFrame/HealthPanel/KeyLabel
@onready var health_title: Label = $SafeFrame/HealthPanel/TitleLabel
@onready var map_backdrop: ColorRect = $SafeFrame/MapBackdrop
@onready var minimap_panel: ColorRect = $SafeFrame/MinimapPanel
@onready var map_title: Label = $SafeFrame/MinimapPanel/TitleLabel
@onready var minimap: FloorMinimap = $SafeFrame/MinimapPanel/Minimap
@onready var map_progress_label: Label = (
	$SafeFrame/MinimapPanel/ProgressLabel
)
@onready var map_legend_label: Label = $SafeFrame/MinimapPanel/LegendLabel
@onready var map_hint_label: Label = $SafeFrame/MinimapPanel/HintLabel
@onready var relic_title: Label = $SafeFrame/RelicPanel/TitleLabel
@onready var debug_panel: ColorRect = $SafeFrame/DebugPanel
@onready var controls_label: Label = $SafeFrame/DebugPanel/ControlsLabel
@onready var death_title: Label = $SafeFrame/DeathOverlay/DeathTitle
@onready var death_hint: Label = $SafeFrame/DeathOverlay/DeathHint
@onready var victory_title: Label = $SafeFrame/VictoryOverlay/VictoryTitle
@onready var victory_hint: Label = $SafeFrame/VictoryOverlay/VictoryHint
@onready var pause_overlay: ColorRect = $SafeFrame/PauseOverlay
@onready var pause_title: Label = (
	$SafeFrame/PauseOverlay/PausePanel/PauseTitle
)
@onready var resolution_label: Label = (
	$SafeFrame/PauseOverlay/PausePanel/ResolutionLabel
)
@onready var resolution_option: OptionButton = (
	$SafeFrame/PauseOverlay/PausePanel/ResolutionOption
)
@onready var apply_resolution_button: Button = (
	$SafeFrame/PauseOverlay/PausePanel/ApplyResolutionButton
)
@onready var resolution_status: Label = (
	$SafeFrame/PauseOverlay/PausePanel/ResolutionStatus
)
@onready var resume_button: Button = (
	$SafeFrame/PauseOverlay/PausePanel/ResumeButton
)
@onready var restart_button: Button = (
	$SafeFrame/PauseOverlay/PausePanel/RestartButton
)
@onready var quit_button: Button = (
	$SafeFrame/PauseOverlay/PausePanel/QuitButton
)


func _ready() -> void:
	_apply_static_translations()
	_populate_resolution_options()
	damage_value_start_position = damage_value_label.position
	damage_flash.hide()
	death_overlay.hide()
	invulnerability_label.hide()
	damage_value_label.hide()
	relic_notice.hide()
	relic_panel.hide()
	debug_panel.hide()
	pause_overlay.hide()
	map_backdrop.hide()
	minimap.exploration_changed.connect(_on_map_exploration_changed)
	set_map_expanded(false)
	apply_resolution_button.pressed.connect(_on_apply_resolution_pressed)
	resume_button.pressed.connect(close_pause_menu)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _apply_static_translations() -> void:
	health_title.text = tr("HUD_HEALTH_TITLE")
	map_title.text = tr("HUD_MAP_TITLE")
	map_legend_label.text = tr("HUD_MAP_LEGEND")
	relic_title.text = tr("HUD_RELICS_TITLE")
	controls_label.text = tr("HUD_CONTROLS")
	death_title.text = tr("HUD_DEATH_TITLE")
	death_hint.text = tr("HUD_DEATH_HINT")
	victory_title.text = tr("HUD_VICTORY_TITLE")
	victory_hint.text = tr("HUD_VICTORY_HINT")
	pause_title.text = tr("PAUSE_TITLE")
	resolution_label.text = tr("PAUSE_RESOLUTION_LABEL")
	apply_resolution_button.text = tr("PAUSE_RESOLUTION_APPLY")
	resume_button.text = tr("PAUSE_RESUME")
	restart_button.text = tr("PAUSE_RESTART")
	quit_button.text = tr("PAUSE_QUIT")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		get_viewport().set_input_as_handled()
		if (
			not pause_overlay.visible
			and not death_overlay.visible
			and not $SafeFrame/VictoryOverlay.visible
		):
			set_map_expanded(not map_expanded)
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if (
			key_event.pressed
			and not key_event.echo
			and key_event.keycode == KEY_F3
		):
			debug_panel.visible = not debug_panel.visible
			get_viewport().set_input_as_handled()
			return

	if not event.is_action_pressed("pause"):
		return

	get_viewport().set_input_as_handled()
	if pause_overlay.visible:
		close_pause_menu()
	else:
		open_pause_menu()


func open_pause_menu() -> void:
	if death_overlay.visible or $SafeFrame/VictoryOverlay.visible:
		return

	set_map_expanded(false)
	_select_current_resolution()
	pause_overlay.show()
	get_tree().paused = true
	resume_button.grab_focus()


func close_pause_menu() -> void:
	pause_overlay.hide()
	get_tree().paused = false


func _populate_resolution_options() -> void:
	resolution_option.clear()
	var presets: Array[Vector2i] = display_manager.get_resolution_presets()
	for index in range(presets.size()):
		resolution_option.add_item(display_manager.get_resolution_label(index))
		resolution_option.set_item_metadata(index, presets[index])
	_select_current_resolution()


func _select_current_resolution() -> void:
	if resolution_option.item_count == 0:
		return
	var current_resolution := DisplayServer.window_get_size()
	resolution_option.select(
		display_manager.find_closest_resolution_index(current_resolution)
	)
	_update_resolution_status()


func _update_resolution_status() -> void:
	if Engine.is_embedded_in_editor():
		resolution_status.text = tr("PAUSE_RESOLUTION_EMBEDDED")
		return

	var current_resolution := DisplayServer.window_get_size()
	resolution_status.text = tr("PAUSE_RESOLUTION_STATUS") % [
		current_resolution.x,
		current_resolution.y,
	]


func _on_apply_resolution_pressed() -> void:
	var selected_index := resolution_option.selected
	if selected_index < 0:
		return

	var resolution: Vector2i = resolution_option.get_item_metadata(
		selected_index
	)
	if display_manager.set_windowed_resolution(resolution):
		await get_tree().process_frame
	_update_resolution_status()


func set_map_expanded(value: bool) -> void:
	map_expanded = value
	map_backdrop.visible = value
	map_title.visible = value
	map_progress_label.visible = value
	map_legend_label.visible = value
	minimap_panel.color = (
		EXPANDED_MAP_COLOR if value else COMPACT_MAP_COLOR
	)

	if value:
		minimap_panel.anchor_left = 0.5
		minimap_panel.anchor_top = 0.5
		minimap_panel.anchor_right = 0.5
		minimap_panel.anchor_bottom = 0.5
		minimap_panel.offset_left = -EXPANDED_MAP_PANEL_HALF_SIZE.x
		minimap_panel.offset_top = -EXPANDED_MAP_PANEL_HALF_SIZE.y
		minimap_panel.offset_right = EXPANDED_MAP_PANEL_HALF_SIZE.x
		minimap_panel.offset_bottom = EXPANDED_MAP_PANEL_HALF_SIZE.y
		minimap.position = EXPANDED_MAP_POSITION
		minimap.size = EXPANDED_MAP_SIZE
		map_hint_label.position = Vector2(600.0, 466.0)
		map_hint_label.size = Vector2(196.0, 20.0)
		map_hint_label.text = tr("HUD_MAP_CLOSE_HINT")
	else:
		minimap_panel.anchor_left = 1.0
		minimap_panel.anchor_top = 0.0
		minimap_panel.anchor_right = 1.0
		minimap_panel.anchor_bottom = 0.0
		minimap_panel.offset_left = COMPACT_MAP_PANEL_RECT.position.x
		minimap_panel.offset_top = COMPACT_MAP_PANEL_RECT.position.y
		minimap_panel.offset_right = COMPACT_MAP_PANEL_RECT.end.x
		minimap_panel.offset_bottom = COMPACT_MAP_PANEL_RECT.end.y
		minimap.position = COMPACT_MAP_POSITION
		minimap.size = COMPACT_MAP_SIZE
		map_hint_label.position = Vector2(180.0, 126.0)
		map_hint_label.size = Vector2(34.0, 18.0)
		map_hint_label.text = tr("HUD_MAP_EXPAND_HINT")

	minimap.set_expanded(value)
	_update_map_progress()


func _update_map_progress() -> void:
	map_progress_label.text = (
		tr("HUD_MAP_PROGRESS") % minimap.get_visited_room_count()
	)


func _on_map_exploration_changed(
	_visited_count: int,
	_total_count: int
) -> void:
	_update_map_progress()


func is_map_expanded() -> bool:
	return map_expanded


func _on_restart_pressed() -> void:
	close_pause_menu()
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	close_pause_menu()
	get_tree().quit()


func bind_health(component: HealthComponent) -> void:
	if health_component == component:
		return

	_disconnect_health_signals()
	health_component = component

	health_component.health_changed.connect(_on_health_changed)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	health_component.invulnerability_started.connect(
		_on_invulnerability_started
	)
	health_component.invulnerability_ended.connect(
		_on_invulnerability_ended
	)

	_on_health_changed(
		health_component.current_health,
		health_component.max_health
	)
	invulnerability_label.visible = health_component.is_invulnerable
	death_overlay.visible = health_component.is_dead


func bind_relics(component: RelicComponent) -> void:
	if relic_component == component:
		return

	if is_instance_valid(relic_component):
		if relic_component.relics_changed.is_connected(_on_relics_changed):
			relic_component.relics_changed.disconnect(_on_relics_changed)
		if relic_component.relic_collected.is_connected(_on_relic_collected):
			relic_component.relic_collected.disconnect(_on_relic_collected)

	relic_component = component
	relic_component.relics_changed.connect(_on_relics_changed)
	relic_component.relic_collected.connect(_on_relic_collected)
	_on_relics_changed(relic_component.collected_ids)


func bind_inventory(inventory: RunInventory) -> void:
	if run_inventory == inventory:
		return

	if (
		is_instance_valid(run_inventory)
		and run_inventory.keys_changed.is_connected(_on_keys_changed)
	):
		run_inventory.keys_changed.disconnect(_on_keys_changed)

	run_inventory = inventory
	run_inventory.keys_changed.connect(_on_keys_changed)
	_on_keys_changed(run_inventory.keys)


func _on_keys_changed(current_keys: int) -> void:
	key_label.text = tr("HUD_KEY_COUNT") % current_keys


func _on_relics_changed(collected_ids: Array[String]) -> void:
	if collected_ids.is_empty():
		relic_list_label.text = tr("HUD_NONE")
		relic_panel.hide()
		return

	var lines: Array[String] = []
	for relic_id in collected_ids:
		var relic_data := RELIC_CATALOG.get_relic(relic_id)
		lines.append("- " + tr(relic_data["name_key"]))
	relic_list_label.text = "\n".join(lines)
	relic_list_label.size.y = collected_ids.size() * 18.0
	relic_panel.size.y = 36.0 + relic_list_label.size.y
	relic_panel.show()


func _on_relic_collected(
	_relic_id: String,
	relic_data: Dictionary
) -> void:
	if is_instance_valid(relic_notice_tween):
		relic_notice_tween.kill()

	relic_notice.text = tr("HUD_RELIC_ACQUIRED") % tr(relic_data["name_key"])
	relic_notice.modulate = relic_data["color"]
	relic_notice.modulate.a = 0.0
	relic_notice.show()
	relic_notice_tween = create_tween()
	relic_notice_tween.tween_property(relic_notice, "modulate:a", 1.0, 0.18)
	relic_notice_tween.tween_interval(1.5)
	relic_notice_tween.tween_property(relic_notice, "modulate:a", 0.0, 0.3)
	relic_notice_tween.tween_callback(relic_notice.hide)


func _disconnect_health_signals() -> void:
	if not is_instance_valid(health_component):
		return

	var connections := [
		[health_component.health_changed, _on_health_changed],
		[health_component.damaged, _on_damaged],
		[health_component.died, _on_died],
		[
			health_component.invulnerability_started,
			_on_invulnerability_started,
		],
		[health_component.invulnerability_ended, _on_invulnerability_ended],
	]

	for connection in connections:
		var signal_value: Signal = connection[0]
		var callable_value: Callable = connection[1]

		if signal_value.is_connected(callable_value):
			signal_value.disconnect(callable_value)


func _on_health_changed(current_health: int, max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_label.text = "%d / %d" % [current_health, max_health]

	var ratio := float(current_health) / float(maxi(max_health, 1))
	var fill_style := health_bar.get_theme_stylebox("fill") as StyleBoxFlat

	if fill_style == null:
		return

	if ratio > 0.6:
		fill_style.bg_color = Color(0.2, 0.78, 0.32, 1.0)
	elif ratio > 0.3:
		fill_style.bg_color = Color(0.95, 0.65, 0.12, 1.0)
	else:
		fill_style.bg_color = Color(0.88, 0.18, 0.16, 1.0)


func _on_damaged(amount: int, _current_health: int) -> void:
	_show_damage_flash()
	_show_damage_value(amount)


func _show_damage_flash() -> void:
	if is_instance_valid(damage_flash_tween):
		damage_flash_tween.kill()

	damage_flash.show()
	damage_flash.modulate.a = 1.0
	damage_flash_tween = create_tween()
	damage_flash_tween.tween_property(
		damage_flash,
		"modulate:a",
		0.0,
		0.24
	)
	damage_flash_tween.tween_callback(damage_flash.hide)


func _show_damage_value(amount: int) -> void:
	if is_instance_valid(damage_value_tween):
		damage_value_tween.kill()

	damage_value_label.text = "-%d" % amount
	damage_value_label.position = damage_value_start_position
	damage_value_label.modulate = Color.WHITE
	damage_value_label.show()
	damage_value_tween = create_tween().set_parallel(true)
	damage_value_tween.tween_property(
		damage_value_label,
		"position:y",
		damage_value_start_position.y - 14.0,
		0.4
	)
	damage_value_tween.tween_property(
		damage_value_label,
		"modulate:a",
		0.0,
		0.4
	)
	damage_value_tween.chain().tween_callback(damage_value_label.hide)


func _on_invulnerability_started(_duration: float) -> void:
	invulnerability_label.show()


func _on_invulnerability_ended() -> void:
	invulnerability_label.hide()


func _on_died() -> void:
	set_map_expanded(false)
	close_pause_menu()
	invulnerability_label.hide()
	death_overlay.modulate.a = 0.0
	death_overlay.show()

	var tween := create_tween()
	tween.tween_property(death_overlay, "modulate:a", 1.0, 0.18)


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
