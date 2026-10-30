class_name TurnManager
extends Node

signal phase_changed(phase: StringName)
signal turn_started(turn_number: int)

const PHASE_PLAYER: StringName = &"player"
const PHASE_ENEMY: StringName = &"enemy"

var current_turn: int = 1
var current_phase: StringName = PHASE_PLAYER

func start_game() -> void:
	current_turn = 1
	current_phase = PHASE_PLAYER
	turn_started.emit(current_turn)
	phase_changed.emit(current_phase)

func switch_to_enemy_phase() -> void:
	current_phase = PHASE_ENEMY
	phase_changed.emit(current_phase)

func switch_to_player_phase() -> void:
	current_turn += 1
	current_phase = PHASE_PLAYER
	turn_started.emit(current_turn)
	phase_changed.emit(current_phase)

func is_player_phase() -> bool:
	return current_phase == PHASE_PLAYER
