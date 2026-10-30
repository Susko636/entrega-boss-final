class_name VictoryCondition
extends Resource

@export var objective_description: String = "Objetivo principal"

func is_victory_achieved(_map: BattleMap) -> bool:
	return false

func is_defeat_achieved(map: BattleMap) -> bool:
	
	var player_units: Array[Unit] = map.get_units_of_faction(Unit.Faction.PLAYER)
	var leader_alive: bool = false

	if player_units.is_empty():
		return true

	for unit in player_units:
		if is_instance_valid(unit) and unit.is_leader:
			leader_alive = true
			break

	return not leader_alive
