class_name MissionObjective
extends Resource

enum ObjectiveType { ROUT_ENEMIES, SURVIVE_TURNS, REACH_ESCAPE_POINT }

@export var objective_title: String = "Derrotar a todos los enemigos"
@export var objective_type: ObjectiveType = ObjectiveType.ROUT_ENEMIES

func is_victory_achieved(battle_map: Node) -> bool:
	return false

func is_defeat_incurred(battle_map: Node) -> bool:
	var remaining_players: Array[Unit] = battle_map.get_units_of_faction(CharacterData.Faction.PLAYER)

	if remaining_players.is_empty():
		return true

	var leader_alive: bool = false
	for player in remaining_players:
		if player.data and "is_leader" in player.data and player.data.is_leader:
			leader_alive = true
			break

	if !leader_alive:
		return true

	return false

func on_turn_advanced(_current_turn: int, _battle_map: Node) -> void:
	pass
