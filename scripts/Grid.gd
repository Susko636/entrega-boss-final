class_name Grid
extends RefCounted

# Tamaño en pixeles de cada casilla (tengo que ver de que tamaño van a ser los sprites todavia) 
const CELL_SIZE: Vector2i = Vector2i(16, 16)

# Convierte una coordenada de celda a pixeles en pantalla 
static func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * CELL_SIZE)

# Convierte pixeles en pantalla a la coordenada entera de celda correspondiente
static func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i((world_pos / Vector2(CELL_SIZE)).floor())

# Verifica si la celda esta dentro de los limites del mapa actual
static func is_within_bounds(cell: Vector2i, bounds: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < bounds.x and cell.y < bounds.y
