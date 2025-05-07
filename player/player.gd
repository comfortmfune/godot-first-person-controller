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

@onready var camera_head_follower: Node3D = $HeadFollower ## core
@onready var camera_holder_horizontal: Node3D = $HeadFollower/HeadHorizontal ## core
@onready var camera_holder_vertical: Node3D = $HeadFollower/HeadHorizontal/HeadVertical
@onready var body: Node3D = $body  ## core
@onready var head: Node3D = $StandCollisionShape3D/Head
var tracking_speed: float = 1.0

@onready var collision_shapes: Dictionary[String, CollisionShape3D] = {
	"stand": $StandCollisionShape3D,
	"crouch": $CrouchCollisionShape3D,
	"lay": $LayCollisionShape3D,
}

var in_control: bool = false:  ## core
	set(value):
		in_control = value
		property_changed.emit("in_control")
var control_blocked: bool = false ## core: INFO: not-in_control while in_control
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


func look_head_only(turn: Vector2, sensitivity := Vector2(0.15, 0.15)) -> void:
	var holder_rotation_degrees := Vector3(camera_holder_vertical.rotation_degrees.x, camera_holder_horizontal.rotation_degrees.y, 0)

	## horizontal rotation
	holder_rotation_degrees.y -= turn.x * sensitivity.x
	holder_rotation_degrees.y = wrapf(holder_rotation_degrees.y, 0, 360)

	## vertical rotation
	holder_rotation_degrees.x -= turn.y * sensitivity.y
	holder_rotation_degrees.x = clampf(holder_rotation_degrees.x, -80, 80)

	camera_holder_horizontal.rotation_degrees.y = holder_rotation_degrees.y
	camera_holder_vertical.rotation_degrees.x = holder_rotation_degrees.x


func look_head_only_clamped(turn: Vector2, sensitivity := Vector2(0.15, 0.15), max_angle: float = 75.0, offset: float = 0.0) -> void:
	print("vec: ", -body.global_basis.z)
	var forward_vector: Vector3 = (-body.global_basis.z).rotated(Vector3.UP, deg_to_rad(offset))
	print(forward_vector)
	var angle = forward_vector.signed_angle_to(camera_holder_horizontal.global_basis.z, Vector3.UP)
	var max_radians = deg_to_rad(max_angle)

	print("offset: '", offset, "'")
	if turn.x > 0 and angle < -max_radians:
		print("right lock : '", rad_to_deg(angle), "'")
		return
	elif turn.x < 0 and angle > max_radians:
		print("left lock : '", rad_to_deg(angle), "'")
		return

	look_head_only(turn, sensitivity)
	print("no lock: ", rad_to_deg(angle))


func look_full_body(turn: Vector2, sensitivity := Vector2(0.15, 0.15)) -> void:
	look_head_only(turn, sensitivity)
	#body.rotation.y = lerp(body.rotation.y, camera_holder_horizontal.rotation.y, 0.25)
	body.global_rotation.y = camera_holder_horizontal.global_rotation.y
	collision_shapes.lay.global_rotation.y = camera_holder_horizontal.global_rotation.y


func move(direction: Vector3) -> void:
	move_direction += direction


## INFO: for applying pulses eg jump;
## continuous application == the force;
## if desired override value is '0' use epsilon;
# TODO: fix
func move_override(direction: Vector3) -> void:
	if direction.x != 0:
		move_direction.x = direction.x
	if direction.y != 0:
		move_direction.y = direction.y
	if direction.z != 0:
		move_direction.z = direction.z


func move_over_time(direction: Vector3, duration: float, keep_control: bool = false, predicate: Callable = func(): return true, min_duration: float = -1) -> void:
	while duration > 0 and (min_duration > 0 or predicate.call()):
		move(direction)
		if not keep_control and not control_blocked:
			control_blocked = true

		await get_tree().physics_frame

		duration -= 1 * get_physics_process_delta_time()
		min_duration -= 1 * get_physics_process_delta_time()
	
	if not keep_control:
		control_blocked = false

	return


func move_on_ground_process(args: Dictionary, _delta: float) -> void:	
	move(get_input_direction() * args.move_speed)
## eroc -------------------------------------------------------------------------


## utility -------------------------------------------------------------------------
## dependencies: core
##

const controller_look_inputs: Array[String] = ["look_up", "look_down", "look_left", "look_right"]
const motion_inputs: Array[String] = ["forward", "back", "left", "right"]
const mappable_inputs: Array[String] = ["vertical", "primary", "secondary", "tertiary", "utility"]

enum ViewModes { HEAD, UPPERBODY, FULLBODY }
var view_mode := ViewModes.FULLBODY

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

var rotation_degrees_on_lay: float = 0.0


func set_collision_shape(mode: PoseModes):
	var node_keys_collision_values: Dictionary[String, bool] = {
	"stand": true,
	"crouch": true,
	"lay": true,
	}

	match mode:
		PoseModes.STAND:
			node_keys_collision_values["stand"] = false
		PoseModes.SIT:
			node_keys_collision_values["stand"] = false
		PoseModes.LAY:
			node_keys_collision_values["lay"] = false
		PoseModes.CROUCH:
			node_keys_collision_values["crouch"] = false

	for node_name in node_keys_collision_values:
		var collision_shape: CollisionShape3D = collision_shapes[node_name]
		if collision_shape.disabled != node_keys_collision_values[node_name]:
			collision_shape.disabled = node_keys_collision_values[node_name]


func motion_mapper_property_checker(property_name: String) -> void:
	if property_name == "pose_mode" or property_name == "move_mode":
		motion_mapper()


func update_motion_control() -> void:
	if not property_changed.is_connected(motion_mapper_property_checker) and in_control and not control_blocked:
		property_changed.connect(motion_mapper_property_checker)
		motion_mapper()
	elif property_changed.is_connected(motion_mapper):
		property_changed.disconnect(motion_mapper)
		flush_action(move_on_ground_process)


## Routes 'log' texts from where it is called to Lggr;
## prints to 'stdout' and 'stderr' if no Lggr is in the project (probably too verbose);
## called in: 'core'
@export var lggr: Resource

func log_(text: String, output_type: String = "std") -> void:
	if not type_exists("Lggr") or not lggr:
		var output: String = "lggr-in: '" + text + "' [ALERT: no Lggr to receive input]"
		if output_type == "err":
			printerr(output)
		else:
			print(output)
		return

	lggr.log(text, output_type)


func get_input_direction() -> Vector3:
	var input_vector: Vector2 = Input.get_vector("left", "right", "forward", "back")
	var input_vector3 := Vector3(input_vector.x, 0, input_vector.y)

	return (get_view_basis(camera_holder_horizontal) * input_vector3).normalized()


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
	if old_value == new_value:
		print("maintaining same value: skipping...")
		return
	
	object[property_name] = new_value
	var _count: int = 0

	while Input.is_action_pressed(key_name):
		#print("maintaining '", key_name, "' hold. _count @ '", count, "'")
		_count +=1
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
## required only if you want to do anything with the controller
## dependencies: utility, core

func _ready() -> void:
	camera_head_follower.top_level = true

	property_changed.connect(
		func (prop_name: String):
			match prop_name:
				"in_control":
					update_motion_control()

				"control_blocked":
					update_motion_control()

				"pose_mode":
					if pose_mode != PoseModes.LAY:
						rotation_degrees_on_lay = 0
	)

	update_motion_control()
	pose_mode = PoseModes.STAND


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
		if view_mode == ViewModes.FULLBODY:
			look_full_body(event.relative, Vector2(mouse_horizontal_sensitivity, mouse_vertical_sensitivity))
		else:
			if pose_mode == PoseModes.LAY:
				look_head_only_clamped(event.relative, Vector2(mouse_horizontal_sensitivity, mouse_vertical_sensitivity), 90.0, rotation_degrees_on_lay)
			else:
				look_head_only_clamped(event.relative, Vector2(mouse_horizontal_sensitivity, mouse_vertical_sensitivity))
	
	elif control_blocked:
		return ## buffer input

	for input in motion_inputs:
		if Input.is_action_just_pressed(input):
			
			return

	for input in mappable_inputs:
		if Input.is_action_just_pressed(input):
			var input_held: bool = await pressed_key_held(input)
			action_mapper(input, input_held)
			return


func _process(_delta: float) -> void:
	if head:
		camera_head_follower.global_position = lerp(camera_head_follower.global_position, head.global_position, tracking_speed)

	if controller == Controllers.JOYSTICK:
		look_head_only(Input.get_vector("look_left", "look_right", "look_up", "look_down"),
		Vector2(controller_horizontal_sensitivity, controller_vertical_sensitivity))
## deriuqer -------------------------------------------------------------------------


## API -------------------------------------------------------------------------

## utility-function for mapping executable-movement-actions (addons) to keypresses;
## not an addon; only delete if changing related 'utility' or 'core' functionality
func motion_mapper() -> void:
	match pose_mode:
		PoseModes.LAY:
			crawl("")
		PoseModes.CROUCH:
			crouch_walk("")
		PoseModes.STAND:
			match move_mode:
				MoveModes.WALK:
					walk("")
				MoveModes.RUN:
					run("")
				MoveModes.SPRINT:
					sprint("")


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
			if hold:
				maintain_property_on_hold(input_trigger_name, self, "view_mode", ViewModes.UPPERBODY)
		"tertiary":
			if hold:
				_action_function = slide
			else:
				_action_function = dive
		"utility":
			if Input.is_action_pressed("modifier"):
				if pose_mode != PoseModes.STAND:
					pass
				elif hold: # add; toggle mode
					maintain_property_on_hold(input_trigger_name, self, "move_mode", MoveModes.SPRINT)
				else:
					if move_mode == MoveModes.RUN:
						move_mode = MoveModes.WALK
					else:
						move_mode = MoveModes.RUN
				return
			else:
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

	if _action_function:
		_action_function.call(input_trigger_name)
## IPA -------------------------------------------------------------------------


## addons -------------------------------------------------------------------------
## dependencies: required, utility, core
##

## basic --------------------------------

## ----
@export var absolute_walk_speed: float = 2.0 ## base move speed unaffected by multipliers
@export var absolute_run_speed: float = 4.0 ## base move speed unaffected by multipliers


func stand(_trigger_input: String) -> void:
	pose_mode = PoseModes.STAND
	head = collision_shapes.stand.get_node("Head")
	$body/MeshInstance3D.rotation_degrees = Vector3.ZERO
	$body/MeshInstance3D.position.y = 0.9
	$body/MeshInstance3D.position.z = 0


func walk(_trigger_input: String) -> void:
	#print("downing game")
	set_action(move_on_ground_process, {"move_speed": absolute_walk_speed})


func run(_trigger_input: String) -> void:
	#print("normalizing game")
	set_action(move_on_ground_process, {"move_speed": absolute_run_speed})


## -----
@export var absolute_crouch_speed: float = 2.0

func crouch(_trigger_input: String) -> void:
	pose_mode = PoseModes.CROUCH
	move_mode = MoveModes.WALK
	head = collision_shapes.crouch.get_node("Head")
	$body/MeshInstance3D.rotation_degrees = Vector3.ZERO
	$body/MeshInstance3D.position.y = 0.9
	$body/MeshInstance3D.position.z = 0


func crouch_walk(_trigger_input: String) -> void:
	set_action(move_on_ground_process, {"move_speed": absolute_crouch_speed})


## ----
@export var absolute_crawl_speed: float = 1.0

func prone(_trigger_input: String, angle: float = camera_holder_horizontal.rotation_degrees.y, ground_turn: float = 0.0) -> void:
	print("prone-angle: '", angle, "'")
	body.rotation_degrees.y = angle
	rotation_degrees_on_lay = ground_turn

	$body/MeshInstance3D.rotation_degrees.x = -90
	$body/MeshInstance3D.position.y = 0.15
	$body/MeshInstance3D.position.z = 0.75
	pose_mode = PoseModes.LAY
	move_mode = MoveModes.WALK
	head = collision_shapes.lay.get_node("Head")


func crawl(_trigger_input: String) -> void:
	set_action(move_on_ground_process, {"move_speed": absolute_crawl_speed})


## ----
@export var jump_strength: float = 24.0

func jump(_trigger_input: String) -> void:
	if not is_on_floor():
		return

	move_override(Vector3.UP * jump_strength)
	stand(_trigger_input)


## advanced --------------------------------
## ----
@export var absolute_sprint_speed: float = 8.0 ## base move speed unaffected by multipliers

func sprint(_trigger_input: String) -> void:
	#print("upping game")
	set_action(move_on_ground_process, {"move_speed": absolute_sprint_speed})


## ----
@export var absolute_slide_speed: float = 6.0
@export var absolute_slide_time: float = 0.5

func slide(_trigger_input: String) -> void:
	var angle: float = camera_holder_horizontal.rotation_degrees.y - 180.0
	var slide_time: float = absolute_slide_time
	if Input.is_action_pressed(_trigger_input): # condition for longer/inf slide (I effing love ultrakill)
		slide_time = INF
	#print("slide-angle: '", angle, "'")
	prone(_trigger_input, angle)
	move_mode = MoveModes.SPRINT

	var direction: Vector3 = get_input_direction()
	if direction == Vector3.ZERO:
		direction = (get_view_basis(camera_holder_horizontal) * Vector3.FORWARD).normalized()
	
	await move_over_time(direction * absolute_slide_speed, slide_time, false,
	func ():
		return Input.is_action_pressed(_trigger_input),
		absolute_slide_time
	)

	stand(_trigger_input) # end in $USER desired pose
	move_mode = MoveModes.RUN # case: sprint slide


## ----
@export var absolute_dive_speed: float = 3.0

func dive(_trigger_input: String) -> void:
	var direction: Vector3 = get_input_direction()
	if direction == Vector3.ZERO:
		direction = get_view_basis(camera_holder_horizontal) * Vector3.BACK
	var angle: float = Vector3.FORWARD.signed_angle_to(direction, Vector3.UP)
	var view_angle: float = (-body.global_basis.z).signed_angle_to(direction, Vector3.UP)
	angle = rad_to_deg(angle)
	#print("dive-angle: '", angle, "'")

	control_blocked = true
	jump(_trigger_input)
	prone(_trigger_input, angle, view_angle)
	await move_over_time(direction * absolute_dive_speed, INF, false,
	func () -> bool:
		return not is_on_floor(), 0.1) ## NOTE: min time is so the player can get off the ground first
	
	control_blocked = false


## ----
func vault(_trigger_input: String) -> void:
	pass


## +ultra --------------------------------

## ----
@export var max_midair_jumps: int = 1
@onready var midair_jumps: int = max_midair_jumps
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
