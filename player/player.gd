class_name Player extends CharacterBody3D


## variables -------------------------------------------------------------------------
@export var camera_holder: Node3D ## core
@export var body: Node3D ## core

@export var terrestrial: bool = true ## core
var WORLD_GRAVITY: float = ProjectSettings.get_setting("physics/3d/default_gravity") ## core-by extension
@onready var gravity: float = WORLD_GRAVITY ## core
@export var jump_strength: float = 24.0

@export var move_direction := Vector3.ZERO ## core
@export var absolute_move_direction: float = 3.0
@onready var move_speed: float = absolute_move_direction

var in_control: bool = false
var mappable_inputs: Array[String] = ["vertical", "primary", "secondary", "tertiary"]

## player UX
@export var vertical_sensitivity: float = 0.15 ## core
@export var horizontal_sensitivity: float = 0.15 ## core

## dev UX
@export var move_acceleration_rate: float = 0.2 ## core


## functions -------------------------------------------------------------------------
## core
func _physics_process(delta: float) -> void:
	## gravity; NOTE: also added directly to the velocity to keep it from 'lerping' in state.direction
	if terrestrial and not is_on_floor():
		velocity.y -= gravity * delta
		move_direction.y = velocity.y

	velocity = lerp(velocity, move_direction, move_acceleration_rate)
	move_and_slide()
	move_direction = Vector3.ZERO


func look(turn: Vector2) -> void:
	var holder_rotation_degrees: Vector3 = camera_holder.rotation_degrees

	holder_rotation_degrees.y -= turn.x * vertical_sensitivity
	holder_rotation_degrees.y = wrapf(holder_rotation_degrees.y, 0, 360)

	holder_rotation_degrees.x -= turn.y * horizontal_sensitivity
	holder_rotation_degrees.x = clampf(holder_rotation_degrees.x, -80, 80)

	camera_holder.rotation_degrees = holder_rotation_degrees


func move(direction: Vector3) -> void:
	move_direction += direction


## for applying pulses eg jump
## continuous application == the force
## if desired override value is '0' use epsilon 
func move_override(direction: Vector3) -> void:
	if direction.x != 0:
		move_direction.x = direction.x
	if direction.y != 0:
		move_direction.y = direction.y
	if direction.z != 0:
		move_direction.z = direction.z
## eroc


## required (only if you want to use the controller)
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause_control"):
		if in_control:
			in_control = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			in_control = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	## do not proceed if control is paused
	if not in_control:
		return

	if event is InputEventMouseMotion:
		look(event.relative)
	
	for input in mappable_inputs:
		if Input.is_action_just_pressed(input):
			action_mapper(input)
			return


func _process(_delta: float) -> void:
	if in_control:
		move(get_input_direction() * move_speed)


func get_input_direction() -> Vector3:
	var input_vector: Vector2 = Input.get_vector("left", "right", "forward", "back")
	var input_vector3 := Vector3(input_vector.x, 0, input_vector.y)

	return (get_view_basis(camera_holder) * input_vector3).normalized()


func get_view_basis(looker: Node3D, up_dir := Vector3.UP) -> Basis:
	var angle: float = looker.global_rotation.y
	var forward_dir := Vector3.FORWARD.rotated(Vector3.UP, angle)
	return Basis(
		up_dir,
		Vector3.FORWARD.signed_angle_to(forward_dir, Vector3.UP)
	)
## deriuqer


## utility
## ytilitu


## addons
func action_mapper(action_name: String):
	# add modifier logic
	var action_function: String = ""
	match action_name:
		"vertical":
			action_function = "jump"
		"primary":
			pass
		"secondary":
			pass
		"tertiary":
			action_function = "crouch"

	if action_function != "" and has_method(action_function):
		call(action_function, action_name)


func jump(trigger_input: String):
	if is_on_floor(): # change to can_jump or sumn
		move_override(Vector3.UP * jump_strength)


func crouch(trigger_input: String) -> void:
	print("crouching with: '", trigger_input, "'")


func prone(trigger_input: String) -> void:
	pass
## snodda
