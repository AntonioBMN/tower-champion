class_name HealthComponent
extends Node

signal damaged(amount: int, current_health: int)
signal health_changed(current_health: int, max_health: int)
signal died
signal invulnerability_started(duration: float)
signal invulnerability_ended

@export_group("Health")
@export_range(1, 100000, 1) var max_health: int = 100
@export_range(0.0, 10.0, 0.05) var invulnerability_duration: float = 0.0

var current_health: int
var is_invulnerable: bool = false
var is_dead: bool = false

var _invulnerability_timer: Timer


func _ready() -> void:
	_invulnerability_timer = Timer.new()
	_invulnerability_timer.name = "InvulnerabilityTimer"
	_invulnerability_timer.one_shot = true
	_invulnerability_timer.timeout.connect(_end_invulnerability)
	add_child(_invulnerability_timer)

	reset_health()


func take_damage(amount: int) -> bool:
	if amount <= 0 or is_dead or is_invulnerable:
		return false

	current_health = maxi(current_health - amount, 0)
	damaged.emit(amount, current_health)
	health_changed.emit(current_health, max_health)

	if current_health == 0:
		is_dead = true
		died.emit()
	elif invulnerability_duration > 0.0:
		_begin_invulnerability()

	return true


func heal(amount: int) -> bool:
	if amount <= 0 or is_dead or current_health >= max_health:
		return false

	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
	return true


func increase_max_health(amount: int, heal_amount: int = 0) -> bool:
	if amount <= 0 or is_dead:
		return false

	max_health += amount
	current_health = mini(current_health + maxi(heal_amount, 0), max_health)
	health_changed.emit(current_health, max_health)
	return true


func reset_health() -> void:
	current_health = max_health
	is_dead = false
	is_invulnerable = false

	if is_instance_valid(_invulnerability_timer):
		_invulnerability_timer.stop()

	health_changed.emit(current_health, max_health)


func _begin_invulnerability() -> void:
	is_invulnerable = true
	_invulnerability_timer.start(invulnerability_duration)
	invulnerability_started.emit(invulnerability_duration)


func _end_invulnerability() -> void:
	is_invulnerable = false
	invulnerability_ended.emit()
