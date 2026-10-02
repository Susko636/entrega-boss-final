class_name GridCursor
extends Node2D

# Avisa al resto del juego cuando el cursor se mueve o se presiona un botón
signal cell_changed(new_cell: Vector2i)
signal accept_pressed(cell: Vector2i)
signal cancel_pressed(cell: Vector2i)

# Coordenada actual en el mapa
var cell: Vector2i = Vector2i.ZERO

# Dimensiones del mapa
var bounds: Vector2i = Vector2i(15, 10)

var is_active: bool = true

func _ready() -> void:
	update_visual_position()

func _unhandled_input(event: InputEvent) -> void:
	if !is_active:
		return

	var move_direction: Vector2i = Vector2i.ZERO

	if event.is_action_pressed("mover_der"):
		move_direction.x += 1
	elif event.is_action_pressed("mover_izq"):
		move_direction.x -= 1
	elif event.is_action_pressed("mover_abajo"):
		move_direction.y += 1
	elif event.is_action_pressed("mover_arriba"):
		move_direction.y -= 1

	if move_direction != Vector2i.ZERO:
		_try_move(move_direction)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("aceptar"):
		accept_pressed.emit(cell)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancelar"):
		cancel_pressed.emit(cell)
		get_viewport().set_input_as_handled()

func _try_move(direction: Vector2i) -> void:
	var target_cell: Vector2i = cell + direction

	if Grid.is_within_bounds(target_cell, bounds):
		cell = target_cell
		update_visual_position()
		cell_changed.emit(cell)

func update_visual_position() -> void:
	position = Grid.grid_to_world(cell)
