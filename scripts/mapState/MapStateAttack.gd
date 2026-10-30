class_name MapStateAttackTarget
extends BattleMapState

func enter() -> void:
	
	map.attackable_cells = map.get_adjacent_enemies(map.unit_destination_cell)
	map.draw_overlay(map.attackable_cells, Color(1.0, 0.2, 0.2, 0.6))
	map.cursor.is_active = true

	if not map.attackable_cells.is_empty():
		var first_target: Vector2i = map.attackable_cells[0]
		map.cursor.position = Grid.grid_to_world(first_target)
		if map.units_by_cell.has(first_target):
			map.combat_forecast_requested.emit(map.selected_unit, map.units_by_cell[first_target])

func on_cursor_cell_changed(cell: Vector2i) -> void:
	
	if cell in map.attackable_cells and map.units_by_cell.has(cell):
		map.combat_forecast_requested.emit(map.selected_unit, map.units_by_cell[cell])
	else:
		map.combat_forecast_cleared.emit()

func on_cursor_accept(cell: Vector2i) -> void:
	
	if cell in map.attackable_cells and map.units_by_cell.has(cell):
		map._try_attack_target(cell)

func on_cursor_cancel(_cell: Vector2i) -> void:
	
	map.combat_forecast_cleared.emit()
	map.change_map_state(&"menu")
