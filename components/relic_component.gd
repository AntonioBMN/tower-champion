class_name RelicComponent
extends Node

signal relic_collected(relic_id: String, relic_data: Dictionary)
signal relics_changed(collected_ids: Array[String])

const CATALOG = preload("res://items/relics/relic_catalog.gd")

var collected_ids: Array[String] = []


func collect_relic(relic_id: String) -> bool:
	if collected_ids.has(relic_id) or not CATALOG.has_relic(relic_id):
		return false

	var relic_data := CATALOG.get_relic(relic_id)
	var actor := get_parent()
	if not actor.has_method("apply_relic_effects"):
		return false

	actor.apply_relic_effects(relic_data["effects"])
	collected_ids.append(relic_id)
	relic_collected.emit(relic_id, relic_data)
	relics_changed.emit(collected_ids.duplicate())
	return true


func has_relic(relic_id: String) -> bool:
	return collected_ids.has(relic_id)


func get_collected_names() -> Array[String]:
	var names: Array[String] = []
	for relic_id in collected_ids:
		var name_key: String = CATALOG.get_relic(relic_id)["name_key"]
		names.append(TranslationServer.translate(name_key))
	return names
