extends MeshInstance2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var is_static = false

var speed = Vector2.ZERO
var angular_speed = 0
var mass : float = 1
var moment_of_inertia = 1e2
var last_position : Vector2
var force : Vector2 = Vector2.ZERO
var torque = 0

const K = -50
const COLLISION_TOLLERANCE = 2

var g = 20.8

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
	
func closest_edge_force_vector(p: Vector2):
	var p_local = ((p - position).rotated(-rotation_degrees * PI / 180) / scale)
	var p_rotated = p_local.rotated(45 * PI / 180).sign()
	var normal = Vector2(
		int(p_rotated.x == p_rotated.y) * p_rotated.x, 
		int(p_rotated.x != p_rotated.y) * p_rotated.y
	)
	var d = min(1 - abs(p_local.x), 1 - abs(p_local.y)) 
	var dist = d * (normal * scale).length()
	
	var coef = K * (dist - COLLISION_TOLLERANCE)
	return coef * normal.rotated(rotation_degrees * PI / 180)
	

func collide():
	var result = false;
	for node in owner.get_children():
		if node is MeshInstance2D and node != self:
			var mesh : MeshInstance2D = node
			for p in get_points():
				if node.is_inside(p):
					var r
					var j
					var n
					var local_speed
					
					if not is_static:
						n = node.closest_edge_normal_vector(p)
						r = p - position
						local_speed = speed + Vector2(r.y * -angular_speed, r.x * angular_speed)
						j = -local_speed.dot(n) / (1/mass + r.cross(n) * r.cross(n) / moment_of_inertia)
						speed += j * n / mass
						angular_speed += r.cross(j * n) / moment_of_inertia
						var f : Vector2 = node.closest_edge_force_vector(p)
						force += f

					result = true;

					
					if not node.is_static:
						n = node.closest_edge_normal_vector(p)
						r = p - node.position
						local_speed = node.speed + Vector2(r.y * -node.angular_speed, r.x * node.angular_speed)
						j = -local_speed.dot(n) / (1/node.mass + r.cross(n) * r.cross(n) / node.moment_of_inertia)
						node.speed += j * n / node.mass
						node.angular_speed += r.cross(j * n) / node.moment_of_inertia
						var f : Vector2 = node.closest_edge_force_vector(p)
						node.force -= f
						
						
	return result

# Called when the node enters the scene tree for the first time.
func _ready():
	last_position = position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	collide()
	
	if is_static:
		return

	var a =  force / mass - g * Vector2.UP
	speed += a * delta
	position += speed * delta

	rotate(angular_speed * delta)
	
	force = Vector2.ZERO
