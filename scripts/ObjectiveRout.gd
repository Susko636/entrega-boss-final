class_name ObjectiveRout
extends MissionObjective

func _init() -> void:
	objective_title = "Derrotar a todos los enemigos"
	objective_type = ObjectiveType.ROUT_ENEMIES

func is_victory_achieved(battle_map: Node) -> bool:
	var remaining_enemies = battle_map.get_units_of_faction(CharacterData.Faction.ENEMY)
	return remaining_enemies.is_empty()
