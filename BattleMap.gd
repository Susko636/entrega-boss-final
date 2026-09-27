class_name BattleMap
extends Node2D

# Tamaño del mapa en casillas 
@export var map_size: Vector2i = Vector2i(15, 10)

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var overlay_layer: TileMapLayer = $OverlayLayer
@onready var units_container: Node2D = $Units
@onready var cursor: GridCursor = $GridCursor

var units_by_cell: Dictionary = {}

var selected_unit: Unit = null

var reachable_cells: Dictionary = {}

func _ready() -> void:
	cursor.bounds = map_size

	cursor.cell_changed.connect(_on_cursor_cell_changed)
	cursor.accept_pressed.connect(_on_cursor_accept)
	cursor.cancel_pressed.connect(_on_cursor_cancel)
	
	register_units()
	
func register_units() -> void:
	units_by_cell.clear()
	for child in units_container.get_children():
		if child is Unit:
			units_by_cell[child.grid_coord] = child
			print("Registrado: ", child.data.character_name, " en casilla ", child.grid_coord)

func _on_cursor_cell_changed(new_cell: Vector2i) -> void:
	if units_by_cell.has(new_cell):
		var unit: Unit = units_by_cell[new_cell]
		print("Cursor sobre: ", unit.data.character_name, " (HP: ", unit.data.max_hp, ")")

func _on_cursor_accept(selected_cell: Vector2i) -> void:
	
	if selected_unit != null:
		_try_select_destination(selected_cell)
		return

	if units_by_cell.has(selected_cell):
		var unit: Unit = units_by_cell[selected_cell]
		if unit.data.faction == CharacterData.Faction.PLAYER and !unit.has_acted:
			_select_unit(unit)

func _on_cursor_cancel(_selected_cell: Vector2i) -> void:
	if selected_unit != null:
		_deselect_unit()

func _select_unit(unit: Unit) -> void:
	selected_unit = unit
	reachable_cells = get_reachable_cells(unit.grid_coord, unit.data.move_range)
	draw_overlay(reachable_cells.keys())
	print("Unidad seleccionada: ", unit.data.character_name, ". Casillas alcanzables: ", reachable_cells.size())

func _deselect_unit() -> void:
	selected_unit = null
	reachable_cells.clear()
	overlay_layer.clear()
	print("Selección cancelada.")

func _try_select_destination(target_cell: Vector2i) -> void:
	
	if target_cell in reachable_cells:
		if units_by_cell.has(target_cell) and units_by_cell[target_cell] != selected_unit:
			print("Casilla ocupada por otra unidad.")
			return

		var unit: Unit = selected_unit
		var origin_cell: Vector2i = unit.grid_coord

		var path: Array[Vector2i] = get_path_to_target(origin_cell, target_cell)

		cursor.is_active = false

		overlay_layer.clear()

		units_by_cell.erase(origin_cell)
		units_by_cell[target_cell] = unit

		await unit.follow_path(path)

		unit.has_acted = true

		cursor.is_active = true
		selected_unit = null
		reachable_cells.clear()
	else:
		print("Destino fuera de rango.")

#Algoritmo BFS
func get_reachable_cells(start: Vector2i, max_range: int) -> Dictionary:
	
	var visited: Dictionary = {}
	var queue: Array = []

	queue.append([start, max_range])
	visited[start] = max_range

	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	while queue.size() > 0:
		var current = queue.pop_front()
		var current_cell: Vector2i = current[0]
		var moves_left: int = current[1]

		if moves_left <= 0:
			continue

		for dir in directions:
			var neighbor: Vector2i = current_cell + dir

			#No salir de los límites del mapa
			if not Grid.is_within_bounds(neighbor, map_size):
				continue

			#Bloqueo por enemigos (no se puede atravesar casillas ocupadas por enemigos)
			if units_by_cell.has(neighbor):
				var occupier: Unit = units_by_cell[neighbor]
				if occupier.data.faction == CharacterData.Faction.ENEMY:
					continue

			var remaining: int = moves_left - 1

			if not visited.has(neighbor) or remaining > visited[neighbor]:
				visited[neighbor] = remaining
				queue.append([neighbor, remaining])

	return visited
	
func get_path_to_target(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	
	var visited: Dictionary = {}
	var came_from: Dictionary = {}
	var queue: Array = []

	queue.append([start, selected_unit.data.move_range])
	visited[start] = selected_unit.data.move_range

	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	while queue.size() > 0:
		var current = queue.pop_front()
		var current_cell: Vector2i = current[0]
		var moves_left: int = current[1]

		if current_cell == target:
			break

		if moves_left <= 0:
			continue

		for dir in directions:
			var neighbor: Vector2i = current_cell + dir

			if not Grid.is_within_bounds(neighbor, map_size):
				continue

			if units_by_cell.has(neighbor):
				var occupier: Unit = units_by_cell[neighbor]
				if occupier.data.faction == CharacterData.Faction.ENEMY:
					continue

			var remaining: int = moves_left - 1

			if not visited.has(neighbor) or remaining > visited[neighbor]:
				visited[neighbor] = remaining
				came_from[neighbor] = current_cell
				queue.append([neighbor, remaining])

	var path: Array[Vector2i] = []
	var curr: Vector2i = target
	while curr != start:
		path.append(curr)
		if not came_from.has(curr):
			return []
		curr = came_from[curr]

	path.reverse()
	return path

func draw_overlay(cells: Array) -> void:
	overlay_layer.clear()
	for c in cells:
		overlay_layer.set_cell(c, 0, Vector2i.ZERO)
