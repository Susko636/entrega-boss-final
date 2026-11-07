class_name CombatResolver
extends RefCounted

class CombatResult:
	var defender_died: bool = false
	var attacker_died: bool = false

static func execute_combat(attacker: Unit, defender: Unit) -> CombatResult:
	var result: CombatResult = CombatResult.new()
	
	result.defender_died = await _apply_strike(attacker, defender)
	if result.defender_died:
		return result
	
	if is_instance_valid(attacker) and is_instance_valid(defender):
		var diff: Vector2i = attacker.grid_coord - defender.grid_coord
		var distance: int = abs(diff.x) + abs(diff.y)
		
		if distance == 1:
			result.attacker_died = await _apply_strike(defender, attacker)
	
	return result

static func _apply_strike(striker: Unit, target: Unit) -> bool:
	
	if not is_instance_valid(striker) or not is_instance_valid(target):
		return false
		
	await striker.play_attack_animation(target.global_position)
	
	var damage: int = Unit.calculate_damage(striker, target)
	var is_dead: bool = await target.take_damage(damage)
	
	await striker.get_tree().create_timer(0.25).timeout
	return is_dead
