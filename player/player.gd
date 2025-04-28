class_name FirstPersonPlayer extends CharacterBody3D

## UX variables -------------------------------------------------------------------------
##
## player UX
enum Controllers { KEYBOARD, JOYSTICK }  ## required
var controller := Controllers.KEYBOARD  ## required
@export var mouse_vertical_sensitivity: float = 0.15  ## required
@export var mouse_horizontal_sensitivity: float = 0.15  ## required
@export var controller_vertical_sensitivity: float = 2.5  ## required
@export var controller_horizontal_sensitivity: float = 2.5  ## required
@export var controller_left_stick_deadzone: Vector2 = Vector2.ONE * 0.2  ## required: TODO: implement
@export var controller_right_stick_deadzone: Vector2 = Vector2.ONE * 0.2  ## required: TODO: implement
@export var key_hold_register_delay: float = 0.3

## dev 'player UX'
@export var move_acceleration_rate: float = 0.2  ## core
## selbairav XU -------------------------------------------------------------------------


## core -------------------------------------------------------------------------
##

signal property_changed(property_name)

@export var camera_holder: Node3D  ## core
@export var body: Node3D  ## core

var in_control: bool = false  ## core
var current_actions: Dictionary[Callable, Dictionary]

@export var terrestrial: bool = true  ## core
var WORLD_GRAVITY: float = ProjectSettings.get_setting("physics/3d/default_gravity")  ## core by-extension
@onready var gravity: float = WORLD_GRAVITY  ## core

@export var move_direction := Vector3.ZERO  ## core
var moving: bool = false  ## utility


func _physics_process(delta: float) -> void:
	## gravity; NOTE: also added directly to the velocity to keep it from 'lerping' in state.direction
	if terrestrial and not is_on_floor():
		velocity.y -= gravity * delta
		move_direction.y = velocity.y

	if not current_actions.is_empty():
		for action_key in current_actions:
			action_key.call(current_actions[action_key], delta)

	velocity = lerp(velocity, move_direction, move_acceleration_rate)
	move_and_slide()
	move_direction = Vector3.ZERO


func flush_action(action_key: Callable = _physics_process) -> void:
	if action_key == _physics_process:
		current_actions.clear()
	elif current_actions.has(action_key):
		current_actions.erase(action_key)


func set_action(action_function: Callable, action_func_args: Dictionary) -> void:
	flush_action(action_function)
	current_actions[action_function] = action_func_args


func look(turn: Vector2, sensitivity := Vector2(0.15, 0.15)) -> void:

	var holder_rotation_degrees := Vector3(camera_holder.rotation_degrees.x, rotation_degrees.y, 0)

	## horizontal rotation
	holder_rotation_degrees.y -= turn.x * sensitivity.x
	holder_rotation_degrees.y = wrapf(holder_rotation_degrees.y, 0, 360)

	## vertical rotation
	holder_rotation_degrees.x -= turn.y * sensitivity.y
	holder_rotation_degrees.x = clampf(holder_rotation_degrees.x, -80, 80)

	rotation_degrees.y = holder_rotation_degrees.y
	camera_holder.rotation_degrees.x = holder_rotation_degrees.x


func move(direction: Vector3) -> void:
	move_direction += direction


## INFO: for applying pulses eg jump;
## continuous application == the force;
## if desired override value is '0' use epsilon;
func move_override(direction: Vector3) -> void:
	if direction.x != 0:
		move_direction.x = direction.x
	if direction.y != 0:
		move_direction.y = direction.y
	if direction.z != 0:
		move_direction.z = direction.z
## eroc -------------------------------------------------------------------------


## utility -------------------------------------------------------------------------
## dependencies: core
##
const controller_look_inputs: Array[String] = ["look_up", "look_down", "look_left", "look_right"]
const motion_inputs: Array[String] = ["forward", "back", "left", "right"]
const mappable_inputs: Array[String] = ["vertical", "primary", "secondary", "tertiary", "utility"]

enum PoseModes { STAND, SIT, LAY, CROUCH }
var pose_mode := PoseModes.STAND:
	set(value):
		pose_mode = value
		set_collision_shape(value)

		property_changed.emit("pose_mode")

enum MoveModes { WALK, RUN, SPRINT }
var move_mode := MoveModes.WALK:
	set(value):
		move_mode = value
		property_changed.emit("move_mode")


func set_collision_shape(mode: PoseModes):
	var node_keys_collision_values: Dictionary[String, bool] = {
	"CollisionShape3D": true,
	"CrouchCollisionShape3D": true,
	"ProneCollisionShape3D": true,
	}

	match mode:
		PoseModes.STAND:
			node_keys_collision_values["CollisionShape3D"] = false
		PoseModes.SIT:
			node_keys_collision_values["CollisionShape3D"] = false
		PoseModes.LAY:
			node_keys_collision_values["ProneCollisionShape3D"] = false
		PoseModes.CROUCH:
			node_keys_collision_values["CrouchCollisionShape3D"] = false

	for node_name in node_keys_collision_values:
		var collision_shape: CollisionShape3D = get_node(node_name)
		if collision_shape.disabled != node_keys_collision_values[node_name]:
			collision_shape.disabled = node_keys_collision_values[node_name]

## Routes 'log' texts from where it is called to Lggr;
## prints to 'stdout' and 'stderr' if no Lggr is in the project (probably too verbose);
## called in: 'core'
func log_(text: String, output_type: String = "std") -> void:
	if not type_exists("Lggr"):
		var output: String = "lggr-in: '" + text + "' [ALERT: no Lggr to receive input]"
		if output_type == "err":
			printerr(output)
		else:
			print(output)
		return
	# somehow use the lggr without explicitly writing it


func get_input_direction() -> Vector3:
	var input_vector: Vector2 = Input.get_vector("left", "right", "forward", "back")
	var input_vector3 := Vector3(input_vector.x, 0, input_vector.y)

	return (get_view_basis(self) * input_vector3).normalized()


func _is_motion_input_zero() -> bool:
	var result: bool = true
	for input in motion_inputs:
		if Input.is_action_pressed(input):
			result = false

	return result


func get_view_basis(looker: Node3D, up_dir := Vector3.UP) -> Basis:
	var angle: float = looker.global_rotation.y
	var forward_dir := Vector3.FORWARD.rotated(Vector3.UP, angle)
	return Basis(
		up_dir,
		Vector3.FORWARD.signed_angle_to(forward_dir, Vector3.UP)
	)


func motion_mapper() -> void:
	if moving:
		return

	moving = true
	move_on_ground()

	while not _is_motion_input_zero():
		await get_tree().physics_frame

	moving = false


func pressed_key_held(key_name: String) -> bool:
	var key_held: bool = false
	var time_to_register: float = key_hold_register_delay

	while Input.is_action_pressed(key_name):
		if time_to_register <= 0:
			key_held = true
			break
		await get_tree().process_frame
		time_to_register -= get_process_delta_time()

	return key_held


func maintain_property_on_hold(key_name: String, object: Object, property_name: String, new_value, force: bool = false, maintain_old_value: bool = false) -> void:
	var old_value = object[property_name]
	object[property_name] = new_value

	while Input.is_action_pressed(key_name):
		print("maintaining '", key_name, "' hold")
		if object[property_name] != new_value:
			if force:
				object[property_name] = new_value
			else:
				if not maintain_old_value:
					old_value = object[property_name]
				break

		await get_tree().process_frame
	
	object[property_name] = old_value
	

## ytilitu -------------------------------------------------------------------------


## required -------------------------------------------------------------------------
## dependencies: utility, core

func _unhandled_input(event: InputEvent) -> void:
	## toggle control/cursor
	if Input.is_action_just_pressed("pause_control"):
		if in_control:
			in_control = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			in_control = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if not in_control:
		return  ## do not proceed if control is paused

	if controller == Controllers.KEYBOARD and event is InputEventMouseMotion:
		look(event.relative, Vector2(mouse_horizontal_sensitivity, mouse_vertical_sensitivity))

	for input in motion_inputs:
		if Input.is_action_just_pressed(input):
			motion_mapper()
			return

	for input in mappable_inputs:
		if Input.is_action_just_pressed(input):
			var input_held: bool = await pressed_key_held(input)
			action_mapper(input, input_held)
			return


func _process(_delta: float) -> void:
	if controller == Controllers.JOYSTICK:
		look(Input.get_vector("look_left", "look_right", "look_up", "look_down"),
		Vector2(controller_horizontal_sensitivity, controller_vertical_sensitivity))
## deriuqer -------------------------------------------------------------------------


## addons -------------------------------------------------------------------------
## dependencies: required, utility, core
##

## utility-function for mapping executable-actions (addons) to keypresses;
## not an addon; only delete if changing related 'utility' or 'core' functionality
func action_mapper(input_trigger_name: String, hold: bool = false) -> void:
	# add modifier logic
	var _action_function: Callable
	match input_trigger_name:
		"vertical":
			if is_on_floor():
				_action_function = jump
			else:
				_action_function = double_jump
		"primary":
			pass
		"secondary":
			pass
		"tertiary":
			if hold:
				if pose_mode != PoseModes.LAY:
					_action_function = prone
				else:
					_action_function = stand
			else:
				if pose_mode == PoseModes.CROUCH:
					_action_function = stand
				else:
					_action_function = crouch
		"utility":
			if hold:
				maintain_property_on_hold(input_trigger_name, self, "move_mode", MoveModes.SPRINT)
			else:
				if move_mode == MoveModes.RUN:
					move_mode = MoveModes.WALK
				else:
					move_mode = MoveModes.RUN
			return

	if _action_function:
		_action_function.call(input_trigger_name)


## basic --------------------------------


## ----
func stand(_trigger_input: String) -> void:
	pose_mode = PoseModes.STAND
	camera_holder.position = Vector3(0, 1.5, 0)


## -----
func crouch(_trigger_input: String) -> void:
	pose_mode = PoseModes.CROUCH
	move_mode = MoveModes.WALK
	camera_holder.position = Vector3(0, 1.0, 0)


## ----
func prone(_trigger_input: String) -> void:
	pose_mode = PoseModes.LAY
	move_mode = MoveModes.WALK
	camera_holder.position = Vector3(0.75, 0.25, 0)

## ----
@export var absolute_walk_speed: float = 2.0 ## base move speed unaffected by multipliers
@export var absolute_run_speed: float = 4.0 ## base move speed unaffected by multipliers
@export var absolute_sprint_speed: float = 8.0 ## base move speed unaffected by multipliers
@onready var move_speed_multiplier: float = 1.0


func move_on_ground() -> void:
	set_action(move_on_ground_process, {})


func move_on_ground_process(_args: Dictionary, _delta: float) -> void:
	var speed: float = absolute_walk_speed
	match move_mode:
		MoveModes.RUN:
			speed = absolute_run_speed
		MoveModes.SPRINT:
			speed = absolute_sprint_speed
	
	move(get_input_direction() * speed * move_speed_multiplier)


## ----
@export var jump_strength: float = 24.0

func jump(_trigger_input: String) -> void:
	if not is_on_floor():
		return

	move_override(Vector3.UP * jump_strength)
	stand(_trigger_input)


## advanced --------------------------------
## ----
func sprint(_trigger_input: String) -> void:
	pass


## ----
func slide(_trigger_input: String) -> void:
	pass


## ----
func vault(_trigger_input: String) -> void:
	pass

## +ultra --------------------------------
@export var max_midair_jumps: int = 1
@onready var midair_jumps: int = max_midair_jumps


## ----
@export var midair_jump_strength: float = 24.0
func double_jump(_trigger_input: String) -> void:  ## midair jump
	if midair_jumps <= 0:
		print("no jumps 4 u")
		return

	print("jump jump")
	var terrestrial_value = terrestrial
	terrestrial = false
	velocity.y = 0
	move_override(Vector3.UP * midair_jump_strength)
	midair_jumps -= 1
	var _value: int = midair_jumps

	await get_tree().physics_frame
	await get_tree().physics_frame
	terrestrial = terrestrial_value

	while _value == midair_jumps:
		if is_on_floor():
			midair_jumps = max_midair_jumps
			print("jump reset")
			break
		await get_tree().physics_frame


## ----
func wall_run(_trigger_input: String) -> void:
	pass


## ----
func wall_jump(_trigger_input: String) -> void:
	pass


## ----
func dash(_trigger_input: String) -> void:
	pass


## tools --------------------------------
## ----
func glide(_trigger_input: String) -> void:
	pass


## ----
func grapple(_trigger_input: String) -> void:
	pass

## snodda -------------------------------------------------------------------------
