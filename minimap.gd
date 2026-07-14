class_name FloorMinimap
extends Control

const ROOM_STEP := Vector2(27.0, 21.0)
const ROOM_SIZE := Vector2(18.0, 12.0)
const CONNECTION_COLOR := Color(0.42, 0.46, 0.56, 0.9)
const VISITED_ROOM_COLOR := Color(0.3, 0.34, 0.43, 1.0)
const CURRENT_ROOM_COLOR := Color(0.96, 0.68, 0.18, 1.0)
const ROOM_BORDER_COLOR := Color(0.76, 0.79, 0.86, 1.0)

var room_positions: Array[Vector2i] = []
var room_connections: Array = []
var visited_rooms: Dictionary = {}
var current_room_index: int = -1


func configure(positions: Array[Vector2i], connections: Array) -> void:
	room_positions.assign(positions)
	room_connections = connections.duplicate(true)
	visited_rooms.clear()
	current_room_index = -1
	queue_redraw()


func visit_room(room_index: int) -> void:
	if room_index < 0 or room_index >= room_positions.size():
		return

	visited_rooms[room_index] = true
	current_room_index = room_index
	queue_redraw()


func _draw() -> void:
	if visited_rooms.is_empty() or current_room_index < 0:
		return

	var map_origin := _calculate_map_origin()

	for room_index in visited_rooms:
		for destination in room_connections[room_index].values():
			if not visited_rooms.has(destination) or room_index >= destination:
				continue

			draw_line(
				_room_draw_position(room_index, map_origin),
				_room_draw_position(destination, map_origin),
				CONNECTION_COLOR,
				4.0,
				true
			)

	for room_index in visited_rooms:
		var center := _room_draw_position(room_index, map_origin)
		var room_rect := Rect2(center - ROOM_SIZE * 0.5, ROOM_SIZE)
		var room_color := (
			CURRENT_ROOM_COLOR
			if room_index == current_room_index
			else VISITED_ROOM_COLOR
		)

		draw_rect(room_rect, room_color, true)
		draw_rect(room_rect, ROOM_BORDER_COLOR, false, 1.5)


func _calculate_map_origin() -> Vector2:
	var first_index: int = visited_rooms.keys()[0]
	var minimum := room_positions[first_index]
	var maximum := room_positions[first_index]

	for room_index in visited_rooms:
		var position := room_positions[room_index]
		minimum.x = mini(minimum.x, position.x)
		minimum.y = mini(minimum.y, position.y)
		maximum.x = maxi(maximum.x, position.x)
		maximum.y = maxi(maximum.y, position.y)

	var grid_center := (Vector2(minimum) + Vector2(maximum)) * 0.5
	return size * 0.5 - grid_center * ROOM_STEP


func _room_draw_position(room_index: int, map_origin: Vector2) -> Vector2:
	return map_origin + Vector2(room_positions[room_index]) * ROOM_STEP
