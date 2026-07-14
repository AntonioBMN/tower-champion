class_name CombatHUD
extends CanvasLayer

var health_component: HealthComponent
var damage_flash_tween: Tween
var damage_value_tween: Tween
var damage_value_start_position: Vector2

@onready var health_bar: ProgressBar = $HealthPanel/HealthBar
@onready var health_label: Label = $HealthPanel/HealthLabel
@onready var invulnerability_label: Label = $HealthPanel/InvulnerabilityLabel
@onready var damage_value_label: Label = $HealthPanel/DamageValueLabel
@onready var damage_flash: ColorRect = $DamageFlash
@onready var death_overlay: ColorRect = $DeathOverlay


func _ready() -> void:
	damage_value_start_position = damage_value_label.position
	damage_flash.hide()
	death_overlay.hide()
	invulnerability_label.hide()
	damage_value_label.hide()


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
	invulnerability_label.hide()
	death_overlay.modulate.a = 0.0
	death_overlay.show()

	var tween := create_tween()
	tween.tween_property(death_overlay, "modulate:a", 1.0, 0.18)
