extends KinematicBody

export var MOUSE_SENSITIVITY: float = 0.1

export var GRAVITY: float = -24.8
export var MAX_SPEED: float = 20
export var ACCEL: float = 4.5
export var DEACCEL: float = 16
export var MAX_SLOPE_ANGLE: float = 40
export var JUMP_SPEED: float = 18

var input_dir: Vector2 = Vector2()
var vel: Vector3 = Vector3()
var dir: Vector3 = Vector3()

onready var camera: Camera = $Rotation/Camera
onready var rot_cam: Spatial = $Rotation

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_foward") - Input.get_action_strength("move_backward")
	).normalized()
	
	if event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rot_cam.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY))
		rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
	
	var camera_rot := rot_cam.rotation_degrees
	camera_rot.x = clamp(camera_rot.x, -70, 70)
	rot_cam.rotation_degrees = camera_rot
	
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	dir = Vector3()
	var cam_xform := camera.get_global_transform()
	
	dir += -cam_xform.basis.z * input_dir.y
	dir += cam_xform.basis.x * input_dir.x
	
	var snap_vector: Vector3 = Vector3.DOWN
	if is_on_floor():
		if Input.is_action_just_pressed("move_jump"):
			snap_vector = Vector3.ZERO
			vel.y = JUMP_SPEED
	
	dir.y = 0
	dir = dir.normalized()
	
	vel.y += delta * GRAVITY
	
	var hvel := vel
	hvel.y = 0
	
	var target := dir * MAX_SPEED
	
	var accel := ACCEL if dir.dot(hvel) > 0 else DEACCEL
	
	hvel = hvel.linear_interpolate(target, accel * delta)
	vel.x = hvel.x
	vel.z = hvel.z
	
	vel = move_and_slide_with_snap(vel, snap_vector, Vector3.UP, true, 4, deg2rad(MAX_SLOPE_ANGLE), false)
