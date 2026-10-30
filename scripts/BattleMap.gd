class_name BattleMap
extends Node2D

signal unit_action_needed(can_attack: bool, menu_pos: Vector2)
signal combat_forecast_requested(attacker: Unit, defender: Unit)
signal combat_forecast_cleared
signal match_won
signal match_lost
signal phase_changed(phase: StringName)
signal cursor_hovered_unit(unit: Unit)

const CELL_SIZE: Vector2 = Vector2(64, 64)

@export var map_size: Vector2i = Vector2i(15, 10)

@onready var turn_manager: TurnManager = $TurnManager
@onready var terrain_layer: TileMapLayer = $GroundBase
@onready var overlay_layer: TileMapLayer = $OverlayLayer
@onready var cursor: GridCursor = $GridCursor
@onready var camera: Camera2D = get_node_or_null("Camera2D")

@export_group("Objetivo de Misión")
@export var victory_condition: VictoryCondition

var current_state: BattleMapState
var states: Dictionary = {}

var units_by_cell: Dictionary = {}
var selected_unit: Unit = null
var reachable_cells: Dictionary = {}
var attackable_cells: Array[Vector2i] = []

var unit_original_cell: Vector2i = Vector2i.ZERO
var unit_destination_cell: Vector2i = Vector2i.ZERO

var triggers_by_cell: Dictionary = {}

func _ready() -> void:
	
	cursor.bounds = map_size
	cursor.cell_changed.connect(_on_cursor_cell_changed)
	cursor.accept_pressed.connect(_on_cursor_accept)
	cursor.cancel_pressed.connect(_on_cursor_cancel)
	_setup_camera_limits()
	register_units()
	
	turn_manager.phase_changed.connect(_on_turn_phase_changed)
	turn_manager.start_game()
	_init_map_states()
	_register_interactables()
	
func _setup_camera_limits() -> void:
	
	if not camera:
		return
	
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map_size.x * 64
	camera.limit_bottom = map_size.y * 64	
	
func is_cell_blocked_by_physics(cell: Vector2i) -> bool:
	
	var world_center: Vector2 = Grid.grid_to_world(cell) + Vector2(32, 32)
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_center
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_point(query, 1)
	return result.size() > 0
	
func register_units() -> void:
	
	units_by_cell.clear()
	
	var player_spawns = get_node_or_null("PlayerSpawn")
	if player_spawns:
		for spawn_point in player_spawns.get_children():
			for child in spawn_point.get_children():
				if child is Unit:
					child.grid_coord = Grid.world_to_grid(child.global_position)
					units_by_cell[child.grid_coord] = child

	var npcs = get_node_or_null("NPCs")
	
	if npcs:
		for child in npcs.get_children():
			if child is Unit:
				child.grid_coord = Grid.world_to_grid(child.global_position)
				units_by_cell[child.grid_coord] = child

	var enemys = get_node_or_null("Enemys")
	if enemys:
		for child in enemys.get_children():
			if child is Unit:
				child.grid_coord = Grid.world_to_grid(child.global_position)
				units_by_cell[child.grid_coord] = child

func _on_cursor_cell_changed(new_cell: Vector2i) -> void:
	
	if camera:
		camera.position = Grid.grid_to_world(new_cell) + Vector2(32, 32)

	var hovered_unit: Unit = get_unit_at_cell(new_cell)
	cursor_hovered_unit.emit(hovered_unit)

	if current_state:
		current_state.on_cursor_cell_changed(new_cell)

func _on_cursor_accept(selected_cell: Vector2i) -> void:
	
	if current_state:
		current_state.on_cursor_accept(selected_cell)

func _on_cursor_cancel(selected_cell: Vector2i) -> void:
	
	if current_state:
		current_state.on_cursor_cancel(selected_cell)

func has_adjacent_enemy(cell: Vector2i) -> bool:
	return get_adjacent_enemies(cell).size() > 0

func get_adjacent_enemies(cell: Vector2i) -> Array[Vector2i]:
	
	var enemies: Array[Vector2i] = []
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in directions:
		var neighbor: Vector2i = cell + dir
		if units_by_cell.has(neighbor):
			var occupier: Unit = units_by_cell[neighbor]
			if occupier.faction == Unit.Faction.ENEMY:
				enemies.append(neighbor)
	return enemies

func execute_action(action: String) -> void:
	
	match action:
		"Esperar":
			_finish_unit_turn()
		"Atacar":
			change_map_state(&"attack")
		"Interactuar":
			if selected_unit:
				var trigger = get_adjacent_interaction(selected_unit.grid_coord)
				if trigger:
					await trigger.trigger_interaction(selected_unit)
				change_map_state(&"menu")

func cancel_move() -> void:

	if unit_destination_cell != unit_original_cell:
		units_by_cell.erase(unit_destination_cell)
		units_by_cell[unit_original_cell] = selected_unit

	selected_unit.grid_coord = unit_original_cell
	selected_unit.snap_to_grid()

	cursor.position = Grid.grid_to_world(unit_original_cell)
	change_map_state(&"move")
	
func _finish_unit_turn() -> void:
	
	if is_instance_valid(selected_unit):
		units_by_cell.erase(unit_original_cell)
		units_by_cell[unit_destination_cell] = selected_unit
		selected_unit.has_acted = true

	selected_unit = null
	reachable_cells.clear()
	attackable_cells.clear()
	overlay_layer.clear()

	if turn_manager.is_player_phase():
		cursor.position = Grid.grid_to_world(unit_destination_cell)
		cursor.is_active = true
		change_map_state(&"idle")
		
		check_mission_status()

		if not has_remaining_actions(Unit.Faction.PLAYER):
			start_enemy_phase()
	else:
		change_map_state(&"idle")

func _end_game(won: bool) -> void:
	
	change_map_state(&"game_over")
	overlay_layer.clear()

	if won:
		match_won.emit()
	else:
		match_lost.emit()

func _try_attack_target(target_cell: Vector2i) -> void:
	
	if not (target_cell in attackable_cells and units_by_cell.has(target_cell)):
		print("Casilla no válida para atacar.")
		return

	combat_forecast_cleared.emit()
	cursor.is_active = false
	overlay_layer.clear()

	var target_unit: Unit = units_by_cell[target_cell]
	print("Iniciando combate: ", selected_unit.character_name, " vs ", target_unit.character_name)

	var result: CombatResolver.CombatResult = await CombatResolver.execute_combat(selected_unit, target_unit)

	if result.defender_died:
		print(target_unit.character_name, " ha caído.")
		_destroy_unit(target_unit)
		_finish_unit_turn()
		return

	if result.attacker_died:
		print(selected_unit.character_name, " ha caído en el contraataque.")
		_destroy_unit(selected_unit)
		selected_unit = null
		reachable_cells.clear()
		attackable_cells.clear()
		
		if turn_manager.is_player_phase():
			cursor.is_active = true
			change_map_state(&"idle")
			if not has_remaining_actions(Unit.Faction.PLAYER):
				start_enemy_phase()
		return

	_finish_unit_turn()

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

			if not Grid.is_within_bounds(neighbor, map_size):
				continue
				
			if is_cell_blocked_by_physics(neighbor):
				continue

			if _is_edge_blocked(current_cell, neighbor):
				continue

			if units_by_cell.has(neighbor):
				var occupier: Unit = units_by_cell[neighbor]
				if occupier.faction == Unit.Faction.ENEMY:
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

	queue.append([start, selected_unit.move_range])
	visited[start] = selected_unit.move_range

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
				
			if is_cell_blocked_by_physics(neighbor):
				continue
				
			if _is_edge_blocked(current_cell, neighbor):
				continue
				
			if units_by_cell.has(neighbor):
				var occupier: Unit = units_by_cell[neighbor]
				if occupier.faction == Unit.Faction.ENEMY:
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

func has_remaining_actions(faction: Unit.Faction) -> bool:
	for unit in units_by_cell.values():
		if is_instance_valid(unit) and unit.faction == faction and not unit.has_acted:
			return true
	return false

func reset_faction_actions(faction: Unit.Faction) -> void:
	for unit in units_by_cell.values():
		if is_instance_valid(unit) and unit.faction == faction:
			unit.has_acted = false

func start_enemy_phase() -> void:
	
	reset_faction_actions(Unit.Faction.ENEMY)
	cursor.is_active = false
	turn_manager.switch_to_enemy_phase()
	await get_tree().create_timer(1.0).timeout

	reset_faction_actions(Unit.Faction.ENEMY)
	await get_tree().create_timer(0.6).timeout

	var enemies: Array[Unit] = get_units_of_faction(Unit.Faction.ENEMY)
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.has_acted:
			continue
		await _process_enemy_turn(enemy)

	start_player_phase()

func _process_enemy_turn(enemy: Unit) -> void:
	
	if not is_instance_valid(enemy):
		return

	cursor.position = Grid.grid_to_world(enemy.grid_coord)
	await get_tree().create_timer(0.3).timeout

	var reachable: Dictionary = get_reachable_cells_for_faction(enemy.grid_coord, enemy.move_range, Unit.Faction.ENEMY)

	var player_units: Array[Unit] = get_units_of_faction(Unit.Faction.PLAYER)
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
			var old_cell: Vector2i = enemy.grid_coord
			var path: Array[Vector2i] = get_path_for_faction(old_cell, best_attack_dest, enemy.move_range, Unit.Faction.ENEMY)

			if not path.is_empty():
				units_by_cell.erase(old_cell)
				units_by_cell[best_attack_dest] = enemy
				await enemy.follow_path(path)

		var result: CombatResolver.CombatResult = await CombatResolver.execute_combat(enemy, chosen_target)
		
		if result.defender_died:
			_destroy_unit(chosen_target)
		elif result.attacker_died:
			_destroy_unit(enemy)

		if is_instance_valid(enemy):
			enemy.has_acted = true
		selected_unit = null
		await get_tree().create_timer(0.3).timeout
		return

	var closest_player: Unit = _get_closest_unit(enemy.grid_coord, player_units)
	var best_approach_cell: Vector2i = _get_best_approach_cell(reachable, closest_player.grid_coord, enemy)

	if best_approach_cell != enemy.grid_coord:
		var old_cell: Vector2i = enemy.grid_coord
		var path: Array[Vector2i] = get_path_for_faction(old_cell, best_approach_cell, enemy.move_range, Unit.Faction.ENEMY)

		if not path.is_empty():
			units_by_cell.erase(old_cell)
			units_by_cell[best_approach_cell] = enemy
			await enemy.follow_path(path)

	if is_instance_valid(enemy):
		enemy.has_acted = true
	await get_tree().create_timer(0.2).timeout

func get_units_of_faction(faction: Unit.Faction) -> Array[Unit]:
	
	var result: Array[Unit] = []
	for unit in units_by_cell.values():
		if is_instance_valid(unit) and unit.faction == faction:
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

func get_reachable_cells_for_faction(start: Vector2i, max_range: int, faction: Unit.Faction) -> Dictionary:
	
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
				
			if is_cell_blocked_by_physics(neighbor):
				continue
				
			if _is_edge_blocked(current_cell, neighbor):
				continue

			if units_by_cell.has(neighbor):
				var occupier: Unit = units_by_cell[neighbor]
				if is_instance_valid(occupier) and occupier.faction != faction:
					continue

			var remaining: int = moves_left - 1

			if not visited.has(neighbor) or remaining > visited[neighbor]:
				visited[neighbor] = remaining
				queue.append([neighbor, remaining])

	return visited

func get_path_for_faction(start: Vector2i, target: Vector2i, max_range: int, faction: Unit.Faction) -> Array[Vector2i]:

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
				
			if is_cell_blocked_by_physics(neighbor):
				continue
				
			if _is_edge_blocked(current_cell, neighbor):
				continue
				
			if units_by_cell.has(neighbor):
				var occupier: Unit = units_by_cell[neighbor]
				if is_instance_valid(occupier) and occupier.faction != faction:
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
			if is_instance_valid(occupier) and occupier.faction == Unit.Faction.PLAYER:
				players.append(occupier)
	return players

func start_player_phase() -> void:
	
	turn_manager.switch_to_player_phase()
	await get_tree().create_timer(1.0).timeout

	check_mission_status()
	reset_faction_actions(Unit.Faction.PLAYER)

	cursor.is_active = true
	change_map_state(&"idle")

func _destroy_unit(unit: Unit) -> void:
	
	if not is_instance_valid(unit):
		return
		
	for coord in units_by_cell.keys():
		if units_by_cell[coord] == unit:
			units_by_cell.erase(coord)
			break
			
	unit.queue_free()
	
	await get_tree().process_frame
	check_mission_status()
	
func _init_map_states() -> void:
	
	states[&"idle"] = MapStateIdle.new()
	states[&"move"] = MapStateMove.new()
	states[&"menu"] = MapStateActionMenu.new()
	states[&"attack"] = MapStateAttackTarget.new()
	states[&"game_over"] = MapStateGameOver.new()

	for state in states.values():
		state.map = self

	change_map_state(&"idle")

func change_map_state(state_name: StringName) -> void:
	
	if not states.has(state_name):
		#push_warning("El estado de mapa '%s' no existe." % state_name)
		return
	if current_state:
		current_state.exit()
	current_state = states[state_name]
	current_state.enter()

func check_mission_status() -> void:
	
	if not victory_condition:
		return

	if victory_condition.is_defeat_achieved(self):
		change_map_state(&"game_over")
		match_lost.emit()
		return

	if victory_condition.is_victory_achieved(self):
		change_map_state(&"game_over")
		match_won.emit()
		return

#func _is_victory_achieved() -> bool:

	#match objective_type:
		#ObjectiveType.ROUT_ENEMIES:
			#var enemies: Array[Unit] = get_units_of_faction(Unit.Faction.ENEMY)
			#return enemies.is_empty()
#
		#ObjectiveType.REACH_ESCAPE_POINT:
			#if units_by_cell.has(target_escape_cell):
				#var occupier: Unit = units_by_cell[target_escape_cell]
				#if is_instance_valid(occupier) and occupier.faction == Unit.Faction.PLAYER:
					#return true
			#return false
#
		#ObjectiveType.SURVIVE_TURNS:
			#return 100 > turns_to_survive
#
	#return false

func _is_defeat_incurred() -> bool:
	
	var remaining_players: Array[Unit] = get_units_of_faction(Unit.Faction.PLAYER)
	if remaining_players.is_empty():
		return true

	var leader_alive: bool = false
	for player in remaining_players:
		if "is_leader" in player and player.is_leader:
			leader_alive = true
			break
			
		leader_alive = true 

	return not leader_alive

func get_unit_at_cell(cell: Vector2i) -> Unit:
	return units_by_cell.get(cell, null)

func _on_turn_phase_changed(phase: StringName) -> void:
	phase_changed.emit(phase)

func _is_edge_blocked(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if not space_state:
		return false

	var from_pos: Vector2 = Grid.grid_to_world(from_cell) + Vector2(32, 32)
	var to_pos: Vector2 = Grid.grid_to_world(to_cell) + Vector2(32, 32)

	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit: Dictionary = space_state.intersect_ray(query)
	return not hit.is_empty()

func get_adjacent_interaction(cell: Vector2i) -> MapInteractionTrigger:
	
	var neighbors: Array[Vector2i] = [
		cell + Vector2i.UP,
		cell + Vector2i.DOWN,
		cell + Vector2i.LEFT,
		cell + Vector2i.RIGHT
	]
	for n in neighbors:
		if triggers_by_cell.has(n):
			var trigger: MapInteractionTrigger = triggers_by_cell[n]
			if is_instance_valid(trigger) and trigger.is_active:
				return trigger
	return null

func can_unit_interact() -> bool:
	
	if not selected_unit:
		return false
		
	var trigger = get_adjacent_interaction(selected_unit.grid_coord)
	return trigger != null

func _register_interactables() -> void:
	
	triggers_by_cell.clear()
	
	for node in get_tree().get_nodes_in_group("interaction_triggers"):
		if node is MapInteractionTrigger and node.is_active:
			for cell in node.trigger_cells:
				triggers_by_cell[cell] = node
