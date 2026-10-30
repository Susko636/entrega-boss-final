class_name CombatResolver
extends RefCounted

# Modela el resultado final de un intercambio de golpes
class CombatResult:
	var defender_died: bool = false
	var attacker_died: bool = false

# Resuelve la secuencia de ataque y contraataque
static func execute_combat(attacker: Unit, defender: Unit) -> CombatResult:
	var result: CombatResult = CombatResult.new()
	
	# 1. Golpe del atacante
	result.defender_died = await _apply_strike(attacker, defender)
	if result.defender_died:
		return result
	
	# 2. Contraataque si el defensor sigue vivo y está a rango cuerpo a cuerpo (distancia Manhattan = 1)
	if is_instance_valid(attacker) and is_instance_valid(defender):
		var diff: Vector2i = attacker.grid_coord - defender.grid_coord
		var distance: int = abs(diff.x) + abs(diff.y)
		
		if distance == 1:
			result.attacker_died = await _apply_strike(defender, attacker)
	
	return result

# Ejecuta animación de golpe, cálculo y aplicación de daño
static func _apply_strike(striker: Unit, target: Unit) -> bool:
	if not is_instance_valid(striker) or not is_instance_valid(target):
		return false
		
	# Reproduce la animación de ataque de la StateMachine de la unidad
	await striker.play_attack_animation(target.global_position)
	
	var damage: int = Unit.calculate_damage(striker, target)
	var is_dead: bool = target.take_damage(damage)
	
	# Pausa breve para asimilar el impacto visual
	await striker.get_tree().create_timer(0.25).timeout
	return is_dead
