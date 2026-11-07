class_name CombatHD
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
	
	attacker_name.text = attacker.character_name
	attacker_hp.text = "HP: %d/%d" % [attacker.current_hp, attacker.max_hp]
	attacker_dmg.text = "Atk: %d" % (attacker.strength)
	attacker_def.text = "Def: %d" % (attacker.defense)

	defender_name.text = defender.character_name
	defender_hp.text = "HP: %d/%d" % [defender.current_hp, defender.max_hp]
	defender_dmg.text = "Atk: %d" % (defender.strength)
	defender_def.text = "Def: %d" % (defender.defense)

	show()

func close() -> void:
	hide()
