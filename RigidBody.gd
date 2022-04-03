extends MeshInstance2D

export var is_static = false

var speed = Vector2.ZERO
var angular_speed = 0
var mass : float = 0.5
var moment_of_inertia = 1e3

var last_speed = Vector2.ZERO
var last_angular_speed = 0
var last_position : Vector2
var last_rotation_degrees = 0

var is_collided = false;

var force : Vector2 = Vector2.ZERO
var torque = 0
var delta = 0

const K = -100
const COLLISION_TOLLERANCE = 1.0

var g = 30.8

func get_points():
	var t1 = Vector2(-scale.x, scale.y).rotated(deg2rad(rotation_degrees))
	var t2 = Vector2(scale.x, -scale.y).rotated(deg2rad(rotation_degrees))
	var t3 = scale.rotated(deg2rad(rotation_degrees))
	var t4 = -scale.rotated(deg2rad(rotation_degrees))
	return [position + t3, position + t4, position + t1, position + t2]

func get_local_points():
	var t1 = Vector2(-scale.x, scale.y)
	var t2 = Vector2(scale.x, -scale.y)
	return [scale, -scale, t1, t2]

func is_inside(p : Vector2):
	var diff : Vector2 = ((p - position).rotated(-rotation_degrees * PI / 180) / scale).abs()
	return max(diff.x, diff.y) < 1
	
func closest_edge_normal_vector(p: Vector2):
	var p_local = ((p - position).rotated(-rotation_degrees * PI / 180) / scale)
	var p_rotated = p_local.rotated(45 * PI / 180).sign()
	var normal = Vector2(
		int(p_rotated.x == p_rotated.y) * p_rotated.x, 
		int(p_rotated.x != p_rotated.y) * p_rotated.y
	)
	return normal.rotated(rotation_degrees * PI / 180).normalized()
	
func closest_edge_force_vector(p: Vector2, inverse_normal = false):
	var p_local = ((p - position).rotated(-rotation_degrees * PI / 180) / scale)
	var p_rotated = p_local.rotated(45 * PI / 180).sign()
	var normal = Vector2(
		int(p_rotated.x == p_rotated.y) * p_rotated.x, 
		int(p_rotated.x != p_rotated.y) * p_rotated.y
	)
	if inverse_normal:
		normal = -normal
	var d = min(1 - abs(p_local.x), 1 - abs(p_local.y)) 
	var dist = d * (normal * scale).length()
	
	var coef = K * (dist - COLLISION_TOLLERANCE)
	return coef * normal.rotated(rotation_degrees * PI / 180)
	
func impulse_response(p, effector, inverse_normal = false):
	var n = effector.closest_edge_normal_vector(p)
	if inverse_normal:
		n = -n
	var r = p - position
	var local_speed = speed + Vector2(r.y * -angular_speed, r.x * angular_speed)
	var j = -local_speed.dot(n) / (1 / mass + r.cross(n) * r.cross(n) / moment_of_inertia)
	speed += j * n / mass
	angular_speed += r.cross(j * n) / moment_of_inertia
	
func contact_force(p, effector, inverse_normal = false):
	var r = p - position
	var f : Vector2 = effector.closest_edge_force_vector(p, inverse_normal)
	force += f
	torque += -f.cross(r.normalized()) * r.length()
	
func process_collision(p, effector, inverse_normal = false):
	contact_force(p, effector, inverse_normal)
	
	if not is_collided:
		is_collided = true
		apply_state()
		
	impulse_response(p, effector)
	
func save_state():
	last_speed = speed
	last_position = position
	last_angular_speed = angular_speed
	last_rotation_degrees = rotation_degrees
	
func apply_state():
	speed = last_speed
	position = last_position
	angular_speed = last_angular_speed
	rotation_degrees = last_rotation_degrees

func collide():
	for node in owner.get_children():
		if node is MeshInstance2D and node != self:
			var mesh : MeshInstance2D = node
			for p in get_points():
				
				if node.is_inside(p):
					
					# body penetrates static object
					if not is_static:
						process_collision(p, node, false)
					
					# static object penetrates body
					if not node.is_static:
						node.process_collision(p, node, true)
						
	return is_collided

# Called when the node enters the scene tree for the first time.
func _ready():
	last_position = position
	last_rotation_degrees = rotation_degrees

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	collide()
	
	if is_static:
		return
		
	save_state()
	
	# Apply force
	var a = force / mass - g * Vector2.UP	
	speed += a * delta
	position += speed * delta
	
	# Apply torque
	var w = torque / moment_of_inertia
	angular_speed += w * delta
	rotate(angular_speed * delta)
	
	# Reset collision
	force = Vector2.ZERO
	torque = 0
	is_collided = false
