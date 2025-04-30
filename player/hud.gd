class_name HuD extends Control


@export var player: FirstPersonPlayer
var setup_done: bool = false

@onready var pose_mode_select_button: OptionButton = $VBoxContainer/PoseOptionSelect/OptionButton
@onready var move_mode_select_button: OptionButton = $VBoxContainer/MoveOptionSelect/OptionButton


func setup() -> void:
	if not player:
		printerr("Error: player not set in HuD")
		return

	setup_done =  true

	player.property_changed.connect(handle_property_change)
	
	pose_mode_select_button.item_selected.connect(set_property.bind("pose_mode"))
	move_mode_select_button.item_selected.connect(set_property.bind("move_mode"))
	print("HuD setup")



func _process(_delta) -> void:
	if not player:
		return
	elif not setup_done:
		setup()
		return


func handle_property_change(property_name: String) -> void:
	match property_name:
		"pose_mode":
			pose_mode_select_button.select(player.pose_mode)
			if player.pose_mode != player.PoseModes.STAND:
				# enable move keys
				for i in [0, 1]:
					move_mode_select_button.set_item_disabled(i, true)
			else:
				# disable move keys
				for i in [0, 1]:
					move_mode_select_button.set_item_disabled(i, false)

		"move_mode":
			move_mode_select_button.select(player.move_mode)


func set_property(value: int, property_name: String) -> void:
	print("we get here: '", property_name, "'")
	if property_name == "pose_mode":
		match value:
			0:
				player.stand("hud")
			1:
				pass
			2:
				player.prone("hud")
			3:
				player.crouch("hud")
			
	elif property_name == "move_mode":
		player[property_name] = value