class_name DefeatAllEnemiesCondition
extends VictoryCondition

func _init() -> void:
	objective_description = "Derrota a todos los enemigos"

func is_victory_achieved(map: BattleMap) -> bool:
	var enemies: Array[Unit] = map.get_units_of_faction(Unit.Faction.ENEMY)
	return enemies.is_empty()
