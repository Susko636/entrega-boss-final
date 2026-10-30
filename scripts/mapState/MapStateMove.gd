class_name MapStateMove
extends BattleMapState

func enter() -> void:
	map.cursor.is_active = true
	map.reachable_cells = map.get_reachable_cells(map.selected_unit.grid_coord, map.selected_unit.move_range)
	map.draw_overlay(map.reachable_cells.keys(), Color(0.2, 0.5, 1.0, 0.5))

func on_cursor_accept(cell: Vector2i) -> void:
	if cell in map.reachable_cells:
		if map.units_by_cell.has(cell) and map.units_by_cell[cell] != map.selected_unit:
			return
		_commit_move(cell)

func on_cursor_cancel(_cell: Vector2i) -> void:
	map.selected_unit = null
	map.reachable_cells.clear()
	map.change_map_state(&"idle")

func _commit_move(target_cell: Vector2i) -> void:
	var unit: Unit = map.selected_unit
	map.unit_destination_cell = target_cell
	var origin_cell: Vector2i = unit.grid_coord

	map.cursor.is_active = false
	map.overlay_layer.clear()

	if target_cell != origin_cell:
		var path: Array[Vector2i] = map.get_path_to_target(origin_cell, target_cell)
		if not path.is_empty():
			map.units_by_cell.erase(origin_cell)
			map.units_by_cell[target_cell] = unit
			await unit.follow_path(path)

	map.change_map_state(&"menu")
