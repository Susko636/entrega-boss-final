class_name BattleMap
extends Node2D

signal unit_action_needed(can_attack: bool, menu_pos: Vector2)

enum MapState { IDLE, MOVE_TARGET, ACTION_MENU, ATTACK_TARGET }
var current_state: MapState = MapState.IDLE

# Tamaño del mapa en casillas 
@export var map_size: Vector2i = Vector2i(15, 10)

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var overlay_layer: TileMapLayer = $OverlayLayer
@onready var units_container: Node2D = $Units
@onready var cursor: GridCursor = $GridCursor

var units_by_cell: Dictionary = {}
var selected_unit: Unit = null
var reachable_cells: Dictionary = {}
var attackable_cells: Array[Vector2i] = []

var unit_original_cell: Vector2i = Vector2i.ZERO
var unit_destination_cell: Vector2i = Vector2i.ZERO

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

func _on_cursor_cell_changed(new_cell: Vector2i) -> void:
	if units_by_cell.has(new_cell):
		var unit: Unit = units_by_cell[new_cell]
		print("Cursor sobre: ", unit.data.character_name, " (HP: ", unit.current_hp, ")")

func _on_cursor_accept(selected_cell: Vector2i) -> void:
	match current_state:
		MapState.IDLE:
			if units_by_cell.has(selected_cell):
				var unit: Unit = units_by_cell[selected_cell]
				if unit.data.faction == CharacterData.Faction.PLAYER and not unit.has_acted:
					_select_unit(unit)

		MapState.MOVE_TARGET:
			_try_select_destination(selected_cell)

		MapState.ATTACK_TARGET:
			_try_attack_target(selected_cell)

func _on_cursor_cancel(_selected_cell: Vector2i) -> void:
	match current_state:
		MapState.MOVE_TARGET:
			_deselect_unit()
		MapState.ATTACK_TARGET:
			overlay_layer.clear()
			current_state = MapState.ACTION_MENU
			cursor.is_active = false
			var menu_pos: Vector2 = Grid.grid_to_world(unit_destination_cell) + Vector2(20, -4)
			unit_action_needed.emit(true, menu_pos)

func _select_unit(unit: Unit) -> void:
	selected_unit = unit
	unit_original_cell = unit.grid_coord
	current_state = MapState.MOVE_TARGET
	reachable_cells = get_reachable_cells(unit.grid_coord, unit.data.move_range)
	draw_overlay(reachable_cells.keys(), Color(0.2, 0.5, 1.0, 0.5))

func _deselect_unit() -> void:
	selected_unit = null
	reachable_cells.clear()
	overlay_layer.clear()
	current_state = MapState.IDLE

func _try_select_destination(target_cell: Vector2i) -> void:
	if target_cell in reachable_cells:
		if units_by_cell.has(target_cell) and units_by_cell[target_cell] != selected_unit:
			return

		var unit: Unit = selected_unit
		unit_destination_cell = target_cell
		var origin_cell: Vector2i = unit.grid_coord
		var path: Array[Vector2i] = get_path_to_target(origin_cell, target_cell)

		cursor.is_active = false
		overlay_layer.clear()

		await unit.follow_path(path)

		current_state = MapState.ACTION_MENU
		var can_attack: bool = has_adjacent_enemy(target_cell)
		var menu_pos: Vector2 = Grid.grid_to_world(target_cell) + Vector2(20, -4)
		unit_action_needed.emit(can_attack, menu_pos)

func has_adjacent_enemy(cell: Vector2i) -> bool:
	return get_adjacent_enemies(cell).size() > 0

func get_adjacent_enemies(cell: Vector2i) -> Array[Vector2i]:
	var enemies: Array[Vector2i] = []
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in directions:
		var neighbor: Vector2i = cell + dir
		if units_by_cell.has(neighbor):
			var occupier: Unit = units_by_cell[neighbor]
			if occupier.data.faction == CharacterData.Faction.ENEMY:
				enemies.append(neighbor)
	return enemies

func execute_action(action: String) -> void:
	match action:
		"Esperar":
			_finish_unit_turn()

		"Atacar":
			_start_attack_selection()

func _start_attack_selection() -> void:
	current_state = MapState.ATTACK_TARGET
	attackable_cells = get_adjacent_enemies(unit_destination_cell)
	
	draw_overlay(attackable_cells, Color(1.0, 0.2, 0.2, 0.6))
	
	cursor.is_active = true
	
	if attackable_cells.size() > 0:
		cursor.position = Grid.grid_to_world(attackable_cells[0])

func _try_attack_target(target_cell: Vector2i) -> void:
	if target_cell in attackable_cells and units_by_cell.has(target_cell):
		var target_unit: Unit = units_by_cell[target_cell]
		_resolve_combat(selected_unit, target_unit, target_cell)
	else:
		print("Casilla no válida para atacar.")

func _resolve_combat(attacker: Unit, defender: Unit, defender_cell: Vector2i) -> void:
	cursor.is_active = false
	overlay_layer.clear()

	var atk_stat: int = attacker.data.strength if "strength" in attacker.data else 5
	var def_stat: int = defender.data.defense if "defense" in defender.data else 1
	var damage_to_defender: int = maxi(1, atk_stat - def_stat)

	print("Combate: ", attacker.data.character_name, " golpea a ", defender.data.character_name, " por ", damage_to_defender, " de daño.")
	var defender_died: bool = defender.take_damage(damage_to_defender)

	await get_tree().create_timer(0.35).timeout

	if defender_died:
		units_by_cell.erase(defender_cell)
		_finish_unit_turn()
		return

	var distance: int = abs(attacker.grid_coord.x - defender.grid_coord.x) + abs(attacker.grid_coord.y - defender.grid_coord.y)
	
	if distance == 1:
		var counter_atk_stat: int = defender.data.strength if "strength" in defender.data else 5
		var counter_def_stat: int = attacker.data.defense if "defense" in attacker.data else 1
		var damage_to_attacker: int = maxi(1, counter_atk_stat - counter_def_stat)

		print("¡Contraataque! ", defender.data.character_name, " responde con ", damage_to_attacker, " de daño.")
		var attacker_died: bool = attacker.take_damage(damage_to_attacker)

		await get_tree().create_timer(0.35).timeout

		if attacker_died:
			units_by_cell.erase(unit_original_cell)
			selected_unit = null
			reachable_cells.clear()
			attackable_cells.clear()
			cursor.is_active = true
			current_state = MapState.IDLE
			return

	_finish_unit_turn()

func _finish_unit_turn() -> void:
	units_by_cell.erase(unit_original_cell)
	units_by_cell[unit_destination_cell] = selected_unit
	selected_unit.has_acted = true

	selected_unit = null
	reachable_cells.clear()
	attackable_cells.clear()
	overlay_layer.clear()

	cursor.position = Grid.grid_to_world(unit_destination_cell)
	cursor.is_active = true
	current_state = MapState.IDLE

func cancel_move() -> void:
	selected_unit.grid_coord = unit_original_cell
	selected_unit.snap_to_grid()
	
	cursor.position = Grid.grid_to_world(unit_original_cell)
	cursor.is_active = true
	
	current_state = MapState.MOVE_TARGET
	draw_overlay(reachable_cells.keys(), Color(0.2, 0.5, 1.0, 0.5))

func get_reachable_cells(start: Vector2i, max_range: int) -> Dictionary:
	var visited: Dictionary = {}
	var queue: Array = []
	queue.append([start, selected_unit.data.move_range])
	visited[start] = selected_unit.data.move_range

	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	while queue.size() > 0:
		var current = queue.pop_front()
		var current_cell: Vector2i = current[0]
		var moves_left: int = current[1]

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

func draw_overlay(cells: Array, color: Color = Color.WHITE) -> void:
	overlay_layer.clear()
	overlay_layer.modulate = color
	for c in cells:
		overlay_layer.set_cell(c, 0, Vector2i.ZERO)
