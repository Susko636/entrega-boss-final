class_name UnitStateMachine
extends Node

@export var initial_state: UnitState

var current_state: UnitState
var states: Dictionary = {}

func init_machine(parent_unit: Unit) -> void:
	
	for child in get_children():
		if child is UnitState:
			var state_key: StringName = StringName(child.name.to_lower())
			states[state_key] = child
			child.unit = parent_unit
			child.transitioned.connect(transition_to)

	if initial_state:
		transition_to(StringName(initial_state.name.to_lower()))
	elif get_child_count() > 0 and get_child(0) is UnitState:
		transition_to(StringName(get_child(0).name.to_lower()))

func transition_to(target_state_name: StringName) -> void:
	
	var state_key: StringName = StringName(target_state_name.to_lower())
	if not states.has(state_key):
		push_warning("El estado '%s' no existe en la StateMachine de %s" % [state_key, get_parent().name])
		return

	if current_state:
		current_state.exit()

	current_state = states[state_key]
	current_state.enter()

func _process(delta: float) -> void:
	
	if current_state:
		current_state.update(delta)
