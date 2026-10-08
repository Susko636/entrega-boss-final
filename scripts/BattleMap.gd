class_name BattleMap
extends Node2D

signal unit_action_needed(can_attack: bool, menu_pos: Vector2)
signal combat_forecast_requested(attacker: Unit, defender: Unit)
signal combat_forecast_cleared

enum MapState { IDLE, MOVE_TARGET, ACTION_MENU, ATTACK_TARGET }
var current_state: MapState = MapState.IDLE

enum Phase { PLAYER_PHASE, ENEMY_PHASE }
var current_phase: Phase = Phase.PLAYER_PHASE

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
	
	if current_state == MapState.ATTACK_TARGET:
		if new_cell in attackable_cells and units_by_cell.has(new_cell):
			combat_forecast_requested.emit(selected_unit, units_by_cell[new_cell])
		else:
			combat_forecast_cleared.emit()

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
			combat_forecast_cleared.emit()
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
		var first_target_cell = attackable_cells[0]
		cursor.position = Grid.grid_to_world(attackable_cells[0])
		if units_by_cell.has(first_target_cell):         
			combat_forecast_requested.emit(selected_unit, units_by_cell[first_target_cell])
	
func _try_attack_target(target_cell: Vector2i) -> void:
	if target_cell in attackable_cells and units_by_cell.has(target_cell):
		var target_unit: Unit = units_by_cell[target_cell]
		await _resolve_combat(selected_unit, target_unit)
	else:
		print("Casilla no válida para atacar.")

func _resolve_combat(attacker: Unit, defender: Unit) -> void:
	combat_forecast_cleared.emit()
	cursor.is_active = false
	overlay_layer.clear()

	print("Combate: ", attacker.data.character_name, " ataca a ", defender.data.character_name)
	var defender_died: bool = await _apply_attack_strike(attacker, defender)

	if defender_died:
		print(defender.data.character_name, " ha caído.")
		_destroy_unit(defender)
		_finish_unit_turn()
		return

	if is_instance_valid(attacker) and is_instance_valid(defender):
		var diff: Vector2i = attacker.grid_coord - defender.grid_coord
		var distance: int = abs(diff.x) + abs(diff.y)

		if distance == 1:
			print("¡Contraataque! ", defender.data.character_name, " responde.")
			var attacker_died: bool = await _apply_attack_strike(defender, attacker)

			if attacker_died:
				print(attacker.data.character_name, " ha caído en el contraataque.")
				_destroy_unit(attacker)
				selected_unit = null
				reachable_cells.clear()
				attackable_cells.clear()
				
				if current_phase == Phase.PLAYER_PHASE:
					cursor.is_active = true
					current_state = MapState.IDLE
					if not has_remaining_actions(CharacterData.Faction.PLAYER):
						start_enemy_phase()
				return

	_finish_unit_turn()

func _apply_attack_strike(striker: Unit, target: Unit) -> bool:
	var damage: int = Unit.calculate_damage(striker, target)
	var is_dead: bool = target.take_damage(damage)
	await get_tree().create_timer(0.35).timeout
	return is_dead
	
func _finish_unit_turn() -> void:
	
	if is_instance_valid(selected_unit):
		units_by_cell.erase(unit_original_cell)
		units_by_cell[unit_destination_cell] = selected_unit
		selected_unit.has_acted = true

	selected_unit = null
	reachable_cells.clear()
	attackable_cells.clear()
	overlay_layer.clear()

	if current_phase == Phase.PLAYER_PHASE:
		cursor.position = Grid.grid_to_world(unit_destination_cell)
		cursor.is_active = true
		current_state = MapState.IDLE

		if not has_remaining_actions(CharacterData.Faction.PLAYER):
			start_enemy_phase()
	else:
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

func has_remaining_actions(faction: CharacterData.Faction) -> bool:
	for unit in units_by_cell.values():
		if is_instance_valid(unit) and unit.data.faction == faction and not unit.has_acted:
			return true
	return false

func reset_faction_actions(faction: CharacterData.Faction) -> void:
	for unit in units_by_cell.values():
		if is_instance_valid(unit) and unit.data.faction == faction:
			unit.has_acted = false

func start_enemy_phase() -> void:
	current_phase = Phase.ENEMY_PHASE
	cursor.is_active = false
	print("--- INICIO DE FASE ENEMIGA ---")

	reset_faction_actions(CharacterData.Faction.ENEMY)
	await get_tree().create_timer(0.6).timeout

	var enemies: Array[Unit] = []
	for unit in units_by_cell.values():
		if is_instance_valid(unit) and unit.data.faction == CharacterData.Faction.ENEMY:
			enemies.append(unit)

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.has_acted:
			continue
		await _process_enemy_turn(enemy)

	start_player_phase()

func _process_enemy_turn(enemy: Unit) -> void:

	cursor.position = Grid.grid_to_world(enemy.grid_coord)
	await get_tree().create_timer(0.3).timeout

	var reachable: Dictionary = get_reachable_cells_for_faction(enemy.grid_coord, enemy.data.move_range, CharacterData.Faction.ENEMY)

	var player_units: Array[Unit] = _get_units_of_faction(CharacterData.Faction.PLAYER)
	if player_units.is_empty():
		enemy.has_acted = true
		return

	var best_attack_dest: Vector2i = Vector2i(-1, -1)
	var chosen_target: Unit = null

	for player in player_units:
		var attack_spots: Array[Vector2i] = _get_valid_attack_spots_for_target(player.grid_coord, reachable, enemy)
		if not attack_spots.is_empty():
			best_attack_dest = attack_spots[0] 
			chosen_target = player
			break

	if chosen_target != null:
		selected_unit = enemy
		unit_original_cell = enemy.grid_coord
		unit_destination_cell = best_attack_dest

		if best_attack_dest != enemy.grid_coord:
			var path: Array[Vector2i] = get_path_for_faction(enemy.grid_coord, best_attack_dest, enemy.data.move_range, CharacterData.Faction.ENEMY)
			await enemy.follow_path(path)

		await _resolve_combat(enemy, chosen_target)
		await get_tree().create_timer(0.3).timeout
		return

	var closest_player: Unit = _get_closest_unit(enemy.grid_coord, player_units)
	var best_approach_cell: Vector2i = _get_best_approach_cell(reachable, closest_player.grid_coord, enemy)

	if best_approach_cell != enemy.grid_coord:
		var path: Array[Vector2i] = get_path_for_faction(enemy.grid_coord, best_approach_cell, enemy.data.move_range, CharacterData.Faction.ENEMY)
		await enemy.follow_path(path)

		units_by_cell.erase(enemy.grid_coord)
		units_by_cell[best_approach_cell] = enemy
		enemy.grid_coord = best_approach_cell

	enemy.has_acted = true
	await get_tree().create_timer(0.2).timeout

func _get_units_of_faction(faction: CharacterData.Faction) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in units_by_cell.values():
		if is_instance_valid(unit) and unit.data.faction == faction:
			result.append(unit)
	return result

func _get_valid_attack_spots_for_target(target_cell: Vector2i, reachable: Dictionary, moving_unit: Unit) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in directions:
		var neighbor: Vector2i = target_cell + dir
		if reachable.has(neighbor):
			if not units_by_cell.has(neighbor) or units_by_cell[neighbor] == moving_unit:
				spots.append(neighbor)
	return spots

func _get_closest_unit(origin: Vector2i, targets: Array[Unit]) -> Unit:
	var closest: Unit = targets[0]
	var min_distance: int = 999999
	for target in targets:
		var dist: int = abs(origin.x - target.grid_coord.x) + abs(origin.y - target.grid_coord.y)
		if dist < min_distance:
			min_distance = dist
			closest = target
	return closest

func _get_best_approach_cell(reachable: Dictionary, target_cell: Vector2i, moving_unit: Unit) -> Vector2i:
	var best_cell: Vector2i = moving_unit.grid_coord
	var min_distance: int = abs(best_cell.x - target_cell.x) + abs(best_cell.y - target_cell.y)

	for cell in reachable.keys():
		if not units_by_cell.has(cell) or units_by_cell[cell] == moving_unit:
			var dist: int = abs(cell.x - target_cell.x) + abs(cell.y - target_cell.y)
			if dist < min_distance:
				min_distance = dist
				best_cell = cell

	return best_cell
	
func get_reachable_cells_for_faction(start: Vector2i, max_range: int, faction: CharacterData.Faction) -> Dictionary:
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

			if not Grid.is_within_bounds(neighbor, map_size):
				continue

			if units_by_cell.has(neighbor):
				var occupier: Unit = units_by_cell[neighbor]
				if is_instance_valid(occupier) and occupier.data.faction != faction:
					continue

			var remaining: int = moves_left - 1

			if not visited.has(neighbor) or remaining > visited[neighbor]:
				visited[neighbor] = remaining
				queue.append([neighbor, remaining])

	return visited

func get_path_for_faction(start: Vector2i, target: Vector2i, max_range: int, faction: CharacterData.Faction) -> Array[Vector2i]:
	var visited: Dictionary = {}
	var came_from: Dictionary = {}
	var queue: Array = []

	queue.append([start, max_range])
	visited[start] = max_range

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
				if is_instance_valid(occupier) and occupier.data.faction != faction:
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

func _get_adjacent_player_targets(cell: Vector2i) -> Array[Unit]:
	var players: Array[Unit] = []
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in directions:
		var neighbor: Vector2i = cell + dir
		if units_by_cell.has(neighbor):
			var occupier: Unit = units_by_cell[neighbor]
			if is_instance_valid(occupier) and occupier.data.faction == CharacterData.Faction.PLAYER:
				players.append(occupier)
	return players

func start_player_phase() -> void:
	current_phase = Phase.PLAYER_PHASE
	print("--- INICIO DE FASE DEL JUGADOR ---")

	reset_faction_actions(CharacterData.Faction.PLAYER)

	cursor.is_active = true
	current_state = MapState.IDLE

func _destroy_unit(unit: Unit) -> void:
	if not is_instance_valid(unit):
		return
		
	for coord in units_by_cell.keys():
		if units_by_cell[coord] == unit:
			units_by_cell.erase(coord)
			break
			
	unit.queue_free()
