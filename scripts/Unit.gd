class_name Unit
extends Node2D

signal movement_finished
signal attack_finished
signal damage_taken(remaining_hp: int)
signal defeated

enum Faction { PLAYER, ENEMY, ALLY }

@export_group("Identidad")
@export var character_name: String = "Recluta"
@export var faction: Faction = Faction.PLAYER

@export_group("Estadísticas")
@export var max_hp: int = 10
@export var strength: int = 5
@export var defense: int = 2
@export var move_range: int = 3
@export var is_leader: bool = false

var unit_class: String = str(get_name())
var current_hp: int = 10
var grid_coord: Vector2i = Vector2i.ZERO

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var state_machine: UnitStateMachine = $StateMachine

const CELL_CENTER_OFFSET: Vector2 = Vector2(32, 32)

var has_acted: bool = false:
	
	set(value):
		has_acted = value
		modulate = Color(0.5, 0.5, 0.5) if has_acted else Color.WHITE

func _ready() -> void:
	
	current_hp = max_hp
	grid_coord = Grid.world_to_grid(global_position)
	snap_to_grid()
	state_machine.init_machine(self)

func snap_to_grid() -> void:
	global_position = Grid.grid_to_world(grid_coord) + CELL_CENTER_OFFSET

func follow_path(path: Array[Vector2i]) -> void:
	
	if path.is_empty():
		movement_finished.emit()
		return

	state_machine.transition_to(&"walkstate")
	var tween: Tween = create_tween()

	for cell_step in path:
		if sprite:
			if cell_step.x > grid_coord.x:
				sprite.flip_h = false
			elif cell_step.x < grid_coord.x:
				sprite.flip_h = true

		grid_coord = cell_step
		var step_pos: Vector2 = Grid.grid_to_world(cell_step) + CELL_CENTER_OFFSET
		tween.tween_property(self, "global_position", step_pos, 0.18).set_trans(Tween.TRANS_LINEAR)

	await tween.finished
	state_machine.transition_to(&"idlestate")
	movement_finished.emit()

func play_attack_animation(target_world_pos: Vector2) -> void:
	
	if sprite:
		sprite.flip_h = target_world_pos.x < global_position.x

	state_machine.transition_to(&"attackstate")

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		await sprite.animation_finished
	else:
		var original_pos: Vector2 = global_position
		var dir: Vector2 = (target_world_pos - original_pos).normalized() * 16.0
		var tween: Tween = create_tween()
		tween.tween_property(self, "global_position", original_pos + dir, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "global_position", original_pos, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tween.finished

	state_machine.transition_to(&"idlestate")
	attack_finished.emit()

func take_damage(amount: int) -> bool:
	
	current_hp = maxi(0, current_hp - amount)
	damage_taken.emit(current_hp)

	await play_hit_effect()
	var is_dead: bool = current_hp <= 0
	
	if is_dead:
		defeated.emit()
		
	return is_dead
	
static func calculate_damage(attacker: Unit, defender: Unit) -> int:
	return maxi(1, attacker.strength - defender.defense)

func play_hit_effect() -> void:
	
	var target_visual: CanvasItem = sprite if sprite else self
	var original_pos: Vector2 = target_visual.position
	
	var tween: Tween = create_tween().set_parallel(false)
	
	target_visual.modulate = Color(2.5, 0.4, 0.4) # tono rojizo brillante
	
	var shake_tween: Tween = create_tween().set_parallel(false)
	shake_tween.tween_property(target_visual, "position", original_pos + Vector2(-4, 0), 0.04)
	shake_tween.tween_property(target_visual, "position", original_pos + Vector2(4, 0), 0.04)
	shake_tween.tween_property(target_visual, "position", original_pos, 0.04)
	
	tween.tween_property(target_visual, "modulate", Color.WHITE, 0.12)
	
	await shake_tween.finished

func play_death_effect() -> void:

	var target_visual: CanvasItem = sprite if sprite else self
	var tween: Tween = create_tween().set_parallel(true)
	
	tween.tween_property(target_visual, "modulate", Color(1.0, 0.2, 0.2, 0.0), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(target_visual, "position:y", target_visual.position.y + 8.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(target_visual, "scale", Vector2(0.8, 1.2), 0.2)
	
	await tween.finished
