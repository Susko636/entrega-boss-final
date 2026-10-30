class_name ReachSpotCondition
extends VictoryCondition

@export var target_spot: Vector2i = Vector2i(0, 0)

func _init() -> void:
	objective_description = "Llega a la zona de escape"

func is_victory_achieved(map: BattleMap) -> bool:

	var unit: Unit = map.get_unit_at_cell(target_spot)
	
	if not is_instance_valid(unit) or unit.faction != Unit.Faction.PLAYER:
		return false

	return unit.is_leader
