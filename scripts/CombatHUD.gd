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
	
	attacker_name.text = attacker.data.character_name
	attacker_hp.text = "HP: %d/%d" % [attacker.current_hp, attacker.max_hp]
	attacker_dmg.text = "Atk: %d" % (attacker.data.strength if "strength" in attacker.data else 0)
	attacker_def.text = "Def: %d" % (attacker.data.defense if "defense" in attacker.data else 0)

	defender_name.text = defender.data.character_name
	defender_hp.text = "HP: %d/%d" % [defender.current_hp, defender.max_hp]
	defender_dmg.text = "Atk: %d" % (defender.data.strength if "strength" in defender.data else 0)
	defender_def.text = "Def: %d" % (defender.data.defense if "defense" in defender.data else 0)

	show()

func close() -> void:
	hide()
