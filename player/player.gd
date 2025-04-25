class_name FirstPersonPlayer extends CharacterBody3D


## UX variables -------------------------------------------------------------------------
##
## player UX
enum Controllers {KEYBOARD, JOYSTICK} ## required
var controller := Controllers.KEYBOARD ## required
@export var mouse_vertical_sensitivity: float = 0.15 ## required
@export var mouse_horizontal_sensitivity: float = 0.15 ## required
@export var controller_vertical_sensitivity: float = 2.5 ## required
@export var controller_horizontal_sensitivity: float = 2.5 ## required
@export var controller_left_stick_deadzone: Vector2 = Vector2.ONE * 0.2 ## required: TODO: implement
@export var controller_right_stick_deadzone: Vector2 = Vector2.ONE * 0.2 ## required: TODO: implement

## dev 'player UX'
@export var move_acceleration_rate: float = 0.2 ## core
## selbairav XU -------------------------------------------------------------------------


## core -------------------------------------------------------------------------
##
@export var camera_holder: Node3D ## core
@export var body: Node3D ## core

var in_control: bool = false ## core
var current_actions: Dictionary[Callable, Dictionary]
#@onready var action_func: Callable = flush_action  ## core
#var action_func_arguments: Dictionary = {} ## core

@export var terrestrial: bool = true ## core
var WORLD_GRAVITY: float = ProjectSettings.get_setting("physics/3d/default_gravity") ## core by-extension
@onready var gravity: float = WORLD_GRAVITY ## core

@export var move_direction := Vector3.ZERO ## core


func _physics_process(delta: float) -> void:
	## gravity; NOTE: also added directly to the velocity to keep it from 'lerping' in state.direction
	if terrestrial and not is_on_floor():
		velocity.y -= gravity * delta
		move_direction.y = velocity.y

	#var input_direction := Vector3.ZERO 
#	if action_func and action_func != flush_action:
#		action_func.call(action_func_arguments, delta)
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
#	if action_func == flush_action:
#		return
	
#	action_func = flush_action ## null value
#	action_func_arguments.clear()

func set_action(action_function: Callable, action_func_args: Dictionary) -> void:
	flush_action(action_function)
	current_actions[action_function] = action_func_args
#	action_func = action_function
#	action_func_arguments = action_func_args


func look(turn: Vector2, sensitivity := Vector2(0.15, 0.15)) -> void:

	var holder_rotation_degrees: Vector3 = camera_holder.rotation_degrees

	## horizontal rotation
	holder_rotation_degrees.y -= turn.x * sensitivity.x
	holder_rotation_degrees.y = wrapf(holder_rotation_degrees.y, 0, 360)

	## vertical rotation
	holder_rotation_degrees.x -= turn.y * sensitivity.y
	holder_rotation_degrees.x = clampf(holder_rotation_degrees.x, -80, 80)

	camera_holder.rotation_degrees = holder_rotation_degrees


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
##
const controller_look_inputs: Array[String] = ["look_up", "look_down", "look_left", "look_right"]
const motion_inputs: Array[String] = ["forward", "back", "left", "right"]
const mappable_inputs: Array[String] = ["vertical", "primary", "secondary", "tertiary"]


## Routes 'log' texts from where it is called to Lggr
## prints to 'stdout' and 'stderr' if no Lggr is in the project (probably too verbose)
func log_(text: String, output_type: String = "std") -> void: ## core
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

	return (get_view_basis(camera_holder) * input_vector3).normalized()


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


func action_mapper(input_trigger_name: String) -> void:
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
			_action_function = crouch

	if _action_function:
		_action_function.call(input_trigger_name)
## ytilitu -------------------------------------------------------------------------


## required -------------------------------------------------------------------------
##
var moving: bool = false
enum MoveModes {WALK, RUN, SPRINT, }
var move_mode := MoveModes.WALK


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
		return ## do not proceed if control is paused

	if controller == Controllers.KEYBOARD and event is InputEventMouseMotion:
		look(event.relative, Vector2(mouse_horizontal_sensitivity, mouse_vertical_sensitivity))
	
	for input in motion_inputs:
		if Input.is_action_just_pressed(input):
			motion_mapper()
			return


	for input in mappable_inputs:
		if Input.is_action_just_pressed(input):
			action_mapper(input)
			return


func _process(_delta: float) -> void:
	if controller == Controllers.JOYSTICK:
		look(Input.get_vector("look_left", "look_right", "look_up", "look_down"),
		Vector2(controller_horizontal_sensitivity, controller_vertical_sensitivity))
## deriuqer -------------------------------------------------------------------------


## addons -------------------------------------------------------------------------
##

## basic
@export var absolute_move_speed: float = 3.0 ## base move speed unaffected by multipliers
@onready var move_speed: float = absolute_move_speed ## current move speed
@export var jump_strength: float = 24.0


## --
func move_on_ground() -> void:
	set_action(move_on_ground_process, {"move_speed": move_speed})

func move_on_ground_process(args: Dictionary, _delta: float) -> void:
	move(get_input_direction() * args.move_speed)


## --
func jump(_trigger_input: String) -> void:
	if not is_on_floor(): # change to can_jump or sumn
		return
	
	move_override(Vector3.UP * jump_strength)


## --
func crouch(trigger_input: String) -> void:
	print("crouching with: '", trigger_input, "'")


## --
func prone(_trigger_input: String) -> void:
	pass


## advanced


## +ultra
@export var max_midair_jumps: int = 1
@onready var midair_jumps: int = max_midair_jumps


func double_jump(_trigger_input: String) -> void: ## midair jump
	if midair_jumps <= 0:
		print("no jumps 4 u")
		return
	
	print("jump jump")
	var terrestrial_value = terrestrial
	terrestrial = false
	velocity.y = 0
	move_override(Vector3.UP * jump_strength)
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

## snodda -------------------------------------------------------------------------
