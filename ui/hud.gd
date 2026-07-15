class_name CombatHUD
extends CanvasLayer

const RELIC_CATALOG = preload("res://items/relics/relic_catalog.gd")

var health_component: HealthComponent
var relic_component: RelicComponent
var run_inventory: RunInventory
var damage_flash_tween: Tween
var damage_value_tween: Tween
var relic_notice_tween: Tween
var damage_value_start_position: Vector2

@onready var health_bar: ProgressBar = $HealthPanel/HealthBar
@onready var health_label: Label = $HealthPanel/HealthLabel
@onready var invulnerability_label: Label = $HealthPanel/InvulnerabilityLabel
@onready var damage_value_label: Label = $HealthPanel/DamageValueLabel
@onready var damage_flash: ColorRect = $DamageFlash
@onready var death_overlay: ColorRect = $DeathOverlay
@onready var relic_panel: ColorRect = $RelicPanel
@onready var relic_list_label: Label = $RelicPanel/RelicListLabel
@onready var relic_notice: Label = $RelicNotice
@onready var key_label: Label = $HealthPanel/KeyLabel
@onready var health_title: Label = $HealthPanel/TitleLabel
@onready var map_title: Label = $MinimapPanel/TitleLabel
@onready var relic_title: Label = $RelicPanel/TitleLabel
@onready var debug_panel: ColorRect = $DebugPanel
@onready var controls_label: Label = $DebugPanel/ControlsLabel
@onready var death_title: Label = $DeathOverlay/DeathTitle
@onready var death_hint: Label = $DeathOverlay/DeathHint
@onready var victory_title: Label = $VictoryOverlay/VictoryTitle
@onready var victory_hint: Label = $VictoryOverlay/VictoryHint
@onready var pause_overlay: ColorRect = $PauseOverlay
@onready var pause_title: Label = $PauseOverlay/PausePanel/PauseTitle
@onready var resume_button: Button = $PauseOverlay/PausePanel/ResumeButton
@onready var restart_button: Button = $PauseOverlay/PausePanel/RestartButton
@onready var quit_button: Button = $PauseOverlay/PausePanel/QuitButton


func _ready() -> void:
	_apply_static_translations()
	damage_value_start_position = damage_value_label.position
	damage_flash.hide()
	death_overlay.hide()
	invulnerability_label.hide()
	damage_value_label.hide()
	relic_notice.hide()
	relic_panel.hide()
	debug_panel.hide()
	pause_overlay.hide()
	resume_button.pressed.connect(close_pause_menu)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _apply_static_translations() -> void:
	health_title.text = tr("HUD_HEALTH_TITLE")
	map_title.text = tr("HUD_MAP_TITLE")
	relic_title.text = tr("HUD_RELICS_TITLE")
	controls_label.text = tr("HUD_CONTROLS")
	death_title.text = tr("HUD_DEATH_TITLE")
	death_hint.text = tr("HUD_DEATH_HINT")
	victory_title.text = tr("HUD_VICTORY_TITLE")
	victory_hint.text = tr("HUD_VICTORY_HINT")
	pause_title.text = tr("PAUSE_TITLE")
	resume_button.text = tr("PAUSE_RESUME")
	restart_button.text = tr("PAUSE_RESTART")
	quit_button.text = tr("PAUSE_QUIT")


func _unhandled_input(event: InputEvent) -> void:
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
	if death_overlay.visible or $VictoryOverlay.visible:
		return

	pause_overlay.show()
	get_tree().paused = true
	resume_button.grab_focus()


func close_pause_menu() -> void:
	pause_overlay.hide()
	get_tree().paused = false


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
	close_pause_menu()
	invulnerability_label.hide()
	death_overlay.modulate.a = 0.0
	death_overlay.show()

	var tween := create_tween()
	tween.tween_property(death_overlay, "modulate:a", 1.0, 0.18)


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
