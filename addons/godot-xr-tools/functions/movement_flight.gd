@tool
class_name XRToolsMovementFlight
extends XRToolsMovementProvider


## XR Tools Movement Provider for Flying
##
## This script provides flying movement for the player. The control parameters
## are intended to support a wide variety of flight mechanics.
##
## Pitch and Bearing input devices are selected which produce a "forwards"
## reference frame. The player controls (forwards/backwards and
## left/right) are applied in relation to this reference frame.
##
## The Speed Scale and Traction parameters allow primitive flight where
## the player is in direct control of their speed (in the reference frame).
## This produces an effect described as the "Mary Poppins Flying Umbrella".
##
## The Acceleration, Drag, and Guidance parameters allow for slightly more
## realisitic flying where the player can accelerate in their reference
## frame. The drag is applied against the global reference and can be used
## to construct a terminal velocity.
##
## The Guidance property attempts to lerp the players velocity into flight
## forwards direction as if the player had guide-fins or wings.
##
## The Exclusive property specifies whether flight is exclusive (no further
## physics effects after flying) or whether additional effects such as
## the default player gravity are applied.


## Signal emitted when flight starts
signal flight_started()

## Signal emitted when flight finishes
signal flight_finished()


## Enumeration of controller to use for flight
enum FlightController {
	LEFT,		## Use left controller
	RIGHT,		## Use right controler
}

## Enumeration of pitch control input
enum FlightPitch {
	HEAD,		## Head controls pitch
	CONTROLLER,	## Controller controls pitch
}

## Enumeration of bearing control input
enum FlightBearing {
	HEAD,		## Head controls bearing
	CONTROLLER,	## Controller controls bearing
	BODY,		## Body controls bearing
}


## Constant for extracting the vertical component of a Vector3
const VERTICAL := Vector3(0.0, 1.0, 0.0)

## Constant for extracting the horzontal components of a Vector3
const HORIZONTAL := Vector3(1.0, 0.0, 1.0)


## Movement provider order
@export var order : int = 30

## Flight controller
@export var controller : FlightController = FlightController.LEFT

## Flight toggle button
@export var flight_button : String = "by_button"

## Flight pitch control
@export var pitch : FlightPitch = FlightPitch.CONTROLLER

## Flight bearing control
@export var bearing : FlightBearing = FlightBearing.CONTROLLER

## Flight speed from control
@export var speed_scale : float = 5.0

## Flight traction pulling flight velocity towards the controlled speed
@export var speed_traction : float = 3.0

## Flight acceleration from control
@export var acceleration_scale : float = 0.0

## Flight drag
@export var drag : float = 0.1

## Guidance effect (virtual fins/wings)
@export var guidance : float = 0.0

## If true, flight movement is exclusive preventing further movement functions
@export var exclusive : bool = true


## Flight button state
var _flight_button : bool = false

## Flight controller
var _controller : XRController3D


# Node references
@onready var _camera := XRHelpers.get_xr_camera(self)
@onready var _left_controller := XRHelpers.get_left_controller(self)
@onready var _right_controller := XRHelpers.get_right_controller(self)


# Add support for is_xr_class on XRTools classes
func is_xr_class(name : String) -> bool:
	return name == "XRToolsMovementFlight" or super.is_xr_class(name)


func _ready():
	# In Godot 4 we must now manually call our super class ready function
	super._ready()

	# Get the flight controller
	if controller == FlightController.LEFT:
		_controller = _left_controller
	else:
		_controller = _right_controller


# Process physics movement for
func physics_movement(delta: float, player_body: XRToolsPlayerBody, disabled: bool):
	# Disable flying if requested, or if no controller
	if disabled or !enabled or !_controller.get_is_active():
		set_flying(false)
		return

	# Detect press of flight button
	var old_flight_button = _flight_button
	_flight_button = _controller.is_button_pressed(flight_button)
	if _flight_button and !old_flight_button:
		set_flying(!is_active)

	# Skip if not flying
	if !is_active:
		return

	# Select the pitch vector
	var pitch_vector: Vector3
	if pitch == FlightPitch.HEAD:
		# Use the vertical part of the 'head' forwards vector
		pitch_vector = -_camera.global_transform.basis.z.y * VERTICAL
	else:
		# Use the vertical part of the 'controller' forwards vector
		pitch_vector = -_controller.global_transform.basis.z.y * VERTICAL

	# Select the bearing vector
	var bearing_vector: Vector3
	if bearing == FlightBearing.HEAD:
		# Use the horizontal part of the 'head' forwards vector
		bearing_vector = -_camera.global_transform.basis.z * HORIZONTAL
	elif bearing == FlightBearing.CONTROLLER:
		# Use the horizontal part of the 'controller' forwards vector
		bearing_vector = -_controller.global_transform.basis.z * HORIZONTAL
	else:
		# Use the horizontal part of the 'body' forwards vector
		var left := _left_controller.global_transform.origin
		var right := _right_controller.global_transform.origin
		var left_to_right := (right - left) * HORIZONTAL
		bearing_vector = left_to_right.rotated(Vector3.UP, PI/2)

	# Construct the flight bearing
	var forwards := (bearing_vector.normalized() + pitch_vector).normalized()
	var side := forwards.cross(Vector3.UP)

	# Construct the target velocity
	var joy_forwards := _controller.get_axis("primary").y
	var joy_side := _controller.get_axis("primary").x
	var heading := forwards * joy_forwards + side * joy_side

	# Calculate the flight velocity
	var flight_velocity := player_body.velocity
	flight_velocity *= 1.0 - drag * delta
	flight_velocity = flight_velocity.lerp(heading * speed_scale, speed_traction * delta)
	flight_velocity += heading * acceleration_scale * delta

	# Apply virtual guidance effect
	if guidance > 0.0:
		var velocity_forwards := forwards * flight_velocity.length()
		flight_velocity = flight_velocity.lerp(velocity_forwards, guidance * delta)

	# If exclusive then perform the exclusive move-and-slide
	if exclusive:
		player_body.velocity = player_body.move_body(flight_velocity)
		return true

	# Update velocity and return for additional effects
	player_body.velocity = flight_velocity
	return


func set_flying(active: bool) -> void:
	# Skip if no change
	if active == is_active:
		return

	# Update state
	is_active = active

	# Handle state change
	if is_active:
		emit_signal("flight_started")
	else:
		emit_signal("flight_finished")


# This method verifies the movement provider has a valid configuration.
func _get_configuration_warning():
	# Verify the camera
	if !XRHelpers.get_xr_camera(self):
		return "Unable to find XRCamera3D"

	# Verify the left controller
	if !XRHelpers.get_left_controller(self):
		return "Unable to find left XRController3D node"

	# Verify the right controller
	if !XRHelpers.get_right_controller(self):
		return "Unable to find left XRController3D node"

	# Call base class
	return super._get_configuration_warning()
