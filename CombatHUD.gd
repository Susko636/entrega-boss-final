class_name CombatHUD
extends PanelContainer

@onready var attacker_name: Label = $HBoxContainer/AttackerInfo/AttackerName
@onready var attacker_hp: Label = $HBoxContainer/AttackerInfo/AttackerHP
@onready var attacker_dmg: Label = $HBoxContainer/AttackerInfo/AttackerDmg
@onready var attacker_def: Label = $HBoxContainer/AttackerInfo/AttackerDef

@onready var defender_name: Label = $HBoxContainer/DefenderInfo/DefenderName
@onready var defender_hp: Label = $HBoxContainer/DefenderInfo/DefenderHP
@onready var defender_dmg: Label = $HBoxContainer/DefenderInfo/DefenderDmg
@onready var defender_def: Label = $HBoxContainer/DefenderInfo/DefenderDef

func _ready() -> void:
	hide()

func display_forecast(attacker: Unit, defender: Unit) -> void:
	
	#Datos del Atacante
	attacker_name.text = attacker.data.character_name
	attacker_hp.text = "HP: %d/%d" % [attacker.current_hp, attacker.max_hp]
	
	var atk_strength: int = attacker.data.strength if "strength" in attacker.data else 0
	var atk_defense: int = attacker.data.defense if "defense" in attacker.data else 0
	attacker_dmg.text = "Atk: %d" % atk_strength
	attacker_def.text = "Def: %d" % atk_defense

	#Datos del Defensor
	defender_name.text = defender.data.character_name
	defender_hp.text = "HP: %d/%d" % [defender.current_hp, defender.max_hp]
	
	var def_strength: int = defender.data.strength if "strength" in defender.data else 0
	var def_defense: int = defender.data.defense if "defense" in defender.data else 0
	defender_dmg.text = "Atk: %d" % def_strength
	defender_def.text = "Def: %d" % def_defense

	show()

func close() -> void:
	hide()
