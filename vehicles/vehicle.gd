extends VehicleBody3D

const STEER_SPEED = 1.5
const STEER_LIMIT = 0.4

@export var is_vehicle_active := false
@export var engine_force_value := 40.0
@export_range(0.0, 1.0) var handbrake_force_value := 0.5

var previous_speed := linear_velocity.length()
var _steer_target := 0.0

@onready var desired_engine_pitch: float = $EngineSound.pitch_scale


func _physics_process(delta: float):
	if !is_vehicle_active:
		return
	
	var fwd_mps := (linear_velocity * transform.basis).x

	_steer_target = Input.get_axis(&"turn_right", &"turn_left")
	_steer_target *= STEER_LIMIT

	# Engine sound simulation (not realistic, as this car script has no notion of gear or engine RPM).
	desired_engine_pitch = 0.05 + linear_velocity.length() / (engine_force_value * 0.5)
	# Change pitch smoothly to avoid abrupt change on collision.
	$EngineSound.pitch_scale = lerpf($EngineSound.pitch_scale, desired_engine_pitch, 0.2)

	if abs(linear_velocity.length() - previous_speed) > 1.0:
		# Sudden velocity change, likely due to a collision. Play an impact sound to give audible feedback,
		# and vibrate for haptic feedback.
		$ImpactSound.play()
		Input.vibrate_handheld(100)
		for joypad in Input.get_connected_joypads():
			Input.start_joy_vibration(joypad, 0.0, 0.5, 0.1)

	if Input.is_action_pressed(&"accelerate"):
		# Increase engine force at low speeds to make the initial acceleration faster.
		var speed := linear_velocity.length()
		if speed < 5.0 and not is_zero_approx(speed):
			engine_force = clampf(engine_force_value * 5.0 / speed, 0.0, 100.0)
		else:
			engine_force = engine_force_value

		# Apply analog throttle factor for more subtle acceleration if not fully holding down the trigger.
		engine_force *= Input.get_action_strength(&"accelerate")
	else:
		engine_force = 0.0

	if Input.is_action_pressed(&"reverse"):
		print("Reverse pressed (fwd_mps: ", fwd_mps, ")")
		# Increase engine force at low speeds to make the initial acceleration faster.
		if fwd_mps >= -1.0:
			var speed := linear_velocity.length()
			print("Meters Per Second is gteq -1 (speed: ", speed, ")")
			if speed < 5.0 and not is_zero_approx(speed):
				print("Reverse Engine")
				engine_force = -clampf(engine_force_value * 5.0 / speed, 0.0, 0.0)
				brake = 0.0
			else:
				print("Shunt Engine force to -40 and reverse")
				engine_force = -engine_force_value
				brake = 0.0

			# Apply analog brake factor for more subtle braking if not fully holding down the trigger.
			if brake == 0.5:
				print("Appling Brake Factor Strength")
				print("Kickstart engine force at its default of 40")
				engine_force = -engine_force_value
				print("brake is locked to 0.5, reset to 0")
				brake = 0.0
			
			engine_force *= Input.get_action_strength(&"reverse")
		else:
			print("Meters per second is lteq -1")
			print("Zero out brake")
			brake = 0.0
	else:
		#print("Reverse is not being pressed")
		brake = 0.0

	if Input.is_action_pressed(&"handbrake"):
		# Immediately halt engine force
		if fwd_mps >= -1.0:
			var speed := linear_velocity.length()
			if speed < 5.0 and not is_zero_approx(speed):
				# print("Clampf engine force to a value near to and eventually 0")
				engine_force = -clampf(engine_force_value * 5.0 / speed, 0.0, 100.0)
				brake = handbrake_force_value
			else:
				# print("Engine force must be zeroed out")
				engine_force = 0
				brake = handbrake_force_value

			engine_force *= 0
			brake = handbrake_force_value
			# print("Handbrake Engine force ", engine_force)
		else:
			brake = 0
	else:
		brake = 0
		
	steering = move_toward(steering, _steer_target, STEER_SPEED * delta)

	previous_speed = linear_velocity.length()

func interact():
	print("Interacted with car")
